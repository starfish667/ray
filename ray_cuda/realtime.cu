#ifndef NOMINMAX
#define NOMINMAX
#endif

#include <cuda_runtime.h>
#include <windows.h>

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <sstream>
#include <string>
#include <vector>

#pragma comment(lib, "user32.lib")
#pragma comment(lib, "gdi32.lib")

struct Vec3 {
	float x;
	float y;
	float z;

	__host__ __device__ Vec3() : x(0.0f), y(0.0f), z(0.0f) {}
	__host__ __device__ Vec3(float x_, float y_, float z_) : x(x_), y(y_), z(z_) {}

	__host__ __device__ Vec3 operator-() const {
		return Vec3(-x, -y, -z);
	}

	__host__ __device__ Vec3& operator+=(const Vec3& b) {
		x += b.x;
		y += b.y;
		z += b.z;
		return *this;
	}

	__host__ __device__ Vec3& operator*=(const Vec3& b) {
		x *= b.x;
		y *= b.y;
		z *= b.z;
		return *this;
	}

	__host__ __device__ Vec3& operator/=(float t) {
		x /= t;
		y /= t;
		z /= t;
		return *this;
	}
};

__host__ __device__ inline Vec3 operator+(const Vec3& a, const Vec3& b) {
	return Vec3(a.x + b.x, a.y + b.y, a.z + b.z);
}

__host__ __device__ inline Vec3 operator-(const Vec3& a, const Vec3& b) {
	return Vec3(a.x - b.x, a.y - b.y, a.z - b.z);
}

__host__ __device__ inline Vec3 operator*(const Vec3& a, const Vec3& b) {
	return Vec3(a.x * b.x, a.y * b.y, a.z * b.z);
}

__host__ __device__ inline Vec3 operator*(const Vec3& a, float t) {
	return Vec3(a.x * t, a.y * t, a.z * t);
}

__host__ __device__ inline Vec3 operator*(float t, const Vec3& a) {
	return a * t;
}

__host__ __device__ inline Vec3 operator/(const Vec3& a, float t) {
	return Vec3(a.x / t, a.y / t, a.z / t);
}

__host__ __device__ inline float dot(const Vec3& a, const Vec3& b) {
	return a.x * b.x + a.y * b.y + a.z * b.z;
}

__host__ __device__ inline Vec3 cross(const Vec3& a, const Vec3& b) {
	return Vec3(
		a.y * b.z - a.z * b.y,
		a.z * b.x - a.x * b.z,
		a.x * b.y - a.y * b.x
	);
}

__host__ __device__ inline float length(const Vec3& v) {
	return sqrtf(dot(v, v));
}

__host__ __device__ inline Vec3 unit_vector(const Vec3& v) {
	return v / length(v);
}

__host__ __device__ inline bool near_zero(const Vec3& v) {
	const float eps = 1e-8f;
	return fabsf(v.x) < eps && fabsf(v.y) < eps && fabsf(v.z) < eps;
}

__host__ __device__ inline Vec3 reflect(const Vec3& v, const Vec3& n) {
	return v - 2.0f * dot(v, n) * n;
}

__host__ __device__ inline Vec3 refract(const Vec3& uv, const Vec3& n, float etai_over_etat) {
	float cos_theta = fminf(dot(-uv, n), 1.0f);
	Vec3 r_out_perp = etai_over_etat * (uv + cos_theta * n);
	Vec3 r_out_parallel = -sqrtf(fabsf(1.0f - dot(r_out_perp, r_out_perp))) * n;
	return r_out_perp + r_out_parallel;
}

struct Ray {
	Vec3 orig;
	Vec3 dir;

	__host__ __device__ Ray() {}
	__host__ __device__ Ray(const Vec3& origin, const Vec3& direction)
		: orig(origin), dir(direction) {}

	__host__ __device__ Vec3 at(float t) const {
		return orig + t * dir;
	}
};

enum MaterialType {
	MAT_LAMBERTIAN = 0,
	MAT_METAL = 1,
	MAT_DIELECTRIC = 2
};

struct Material {
	int type;
	Vec3 albedo;
	float fuzz;
	float refraction_index;
};

struct Sphere {
	Vec3 center;
	float radius;
	int material_id;
};

struct Plane {
	Vec3 normal;
	float b;
	int material_id;
};

struct HitRecord {
	Vec3 p;
	Vec3 normal;
	float t;
	bool front_face;
	int material_id;

	__device__ void set_face_normal(const Ray& r, const Vec3& outward_normal) {
		front_face = dot(r.dir, outward_normal) < 0.0f;
		normal = front_face ? outward_normal : -outward_normal;
	}
};

struct CameraData {
	int width;
	int height;
	Vec3 position;
	Vec3 pixel00;
	Vec3 pixel_delta_u;
	Vec3 pixel_delta_v;
};

struct FrameInput {
	float move_forward = 0.0f;
	float move_right = 0.0f;
	float move_up = 0.0f;
	float mouse_dx = 0.0f;
	float mouse_dy = 0.0f;
	bool quit = false;
	bool focused = true;
};

class AppWindow {
public:
	AppWindow(int render_width_, int render_height_, int pixel_scale_)
		: render_width(render_width_),
		  render_height(render_height_),
		  pixel_scale(pixel_scale_),
		  hwnd(nullptr),
		  alive(true),
		  first_mouse_sample(true),
		  w_down(false),
		  a_down(false),
		  s_down(false),
		  d_down(false),
		  space_down(false),
		  shift_down(false),
		  esc_down(false) {
		register_class();
		create_window();
		init_bitmap_info();
		if (hwnd) {
			set_title("Ray CUDA realtime");
		}
	}

	~AppWindow() {
		ClipCursor(nullptr);
		restore_cursor();
		if (hwnd) {
			DestroyWindow(hwnd);
		}
	}

	bool open() const {
		return alive;
	}

	FrameInput poll() {
		process_messages();

		FrameInput input;
		input.focused = hwnd && GetForegroundWindow() == hwnd;
		input.quit = !alive || esc_down || key_down(VK_ESCAPE);

		input.move_forward += (w_down || key_down('W')) ? 1.0f : 0.0f;
		input.move_forward -= (s_down || key_down('S')) ? 1.0f : 0.0f;
		input.move_right += (d_down || key_down('D')) ? 1.0f : 0.0f;
		input.move_right -= (a_down || key_down('A')) ? 1.0f : 0.0f;
		input.move_up += (space_down || key_down(VK_SPACE)) ? 1.0f : 0.0f;
		input.move_up -= (shift_down || key_down(VK_SHIFT)) ? 1.0f : 0.0f;

		if (!input.focused) {
			first_mouse_sample = true;
			ClipCursor(nullptr);
			return input;
		}

		POINT cursor;
		POINT center = client_center();
		if (GetCursorPos(&cursor)) {
			if (first_mouse_sample) {
				first_mouse_sample = false;
			} else {
				input.mouse_dx = float(cursor.x - center.x);
				input.mouse_dy = float(cursor.y - center.y);
			}
			SetCursorPos(center.x, center.y);
		}

		hide_cursor();
		clip_cursor_to_client();
		return input;
	}

	void display(const std::uint32_t* pixels) {
		if (!hwnd) {
			return;
		}

		HDC dc = GetDC(hwnd);
		paint_pixels(dc, pixels);
		ReleaseDC(hwnd, dc);
	}

	void set_title(const std::string& title) {
		if (hwnd) {
			SetWindowTextA(hwnd, title.c_str());
		}
	}

private:
	int render_width;
	int render_height;
	int pixel_scale;
	HWND hwnd;
	bool alive;
	bool first_mouse_sample;
	bool w_down;
	bool a_down;
	bool s_down;
	bool d_down;
	bool space_down;
	bool shift_down;
	bool esc_down;
	BITMAPINFO bitmap_info;

	static constexpr const char* class_name = "RayCudaRealtimeWindow";

	static bool key_down(int key) {
		return (GetAsyncKeyState(key) & 0x8000) != 0;
	}

	static LRESULT CALLBACK window_proc(HWND hwnd_, UINT message, WPARAM wparam, LPARAM lparam) {
		AppWindow* window = reinterpret_cast<AppWindow*>(GetWindowLongPtr(hwnd_, GWLP_USERDATA));

		if (message == WM_NCCREATE) {
			CREATESTRUCT* create = reinterpret_cast<CREATESTRUCT*>(lparam);
			window = reinterpret_cast<AppWindow*>(create->lpCreateParams);
			SetWindowLongPtr(hwnd_, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(window));
			return TRUE;
		}

		if (window) {
			return window->handle_message(message, wparam, lparam);
		}

		return DefWindowProc(hwnd_, message, wparam, lparam);
	}

	LRESULT handle_message(UINT message, WPARAM wparam, LPARAM lparam) {
		switch (message) {
		case WM_CLOSE:
			alive = false;
			DestroyWindow(hwnd);
			return 0;
		case WM_DESTROY:
			alive = false;
			hwnd = nullptr;
			PostQuitMessage(0);
			return 0;
		case WM_SETFOCUS:
			first_mouse_sample = true;
			hide_cursor();
			center_cursor();
			clip_cursor_to_client();
			return 0;
		case WM_KILLFOCUS:
			first_mouse_sample = true;
			ClipCursor(nullptr);
			return 0;
		case WM_SETCURSOR:
			if (LOWORD(lparam) == HTCLIENT) {
				SetCursor(nullptr);
				return TRUE;
			}
			break;
		case WM_KEYDOWN:
		case WM_SYSKEYDOWN:
			set_key_state(static_cast<WORD>(wparam), true);
			return 0;
		case WM_KEYUP:
		case WM_SYSKEYUP:
			set_key_state(static_cast<WORD>(wparam), false);
			return 0;
		default:
			break;
		}

		return DefWindowProc(hwnd, message, wparam, lparam);
	}

	void register_class() {
		WNDCLASSA wc{};
		wc.style = CS_HREDRAW | CS_VREDRAW;
		wc.lpfnWndProc = AppWindow::window_proc;
		wc.hInstance = GetModuleHandle(nullptr);
		wc.lpszClassName = class_name;
		wc.hCursor = nullptr;
		wc.hbrBackground = reinterpret_cast<HBRUSH>(GetStockObject(BLACK_BRUSH));

		ATOM atom = RegisterClassA(&wc);
		if (!atom && GetLastError() != ERROR_CLASS_ALREADY_EXISTS) {
			alive = false;
		}
	}

	void create_window() {
		if (!alive) {
			return;
		}

		DWORD style = WS_OVERLAPPEDWINDOW | WS_VISIBLE;
		RECT rect{0, 0, render_width * pixel_scale, render_height * pixel_scale};
		AdjustWindowRect(&rect, style, FALSE);

		hwnd = CreateWindowExA(
			0,
			class_name,
			"Ray CUDA realtime",
			style,
			CW_USEDEFAULT,
			CW_USEDEFAULT,
			rect.right - rect.left,
			rect.bottom - rect.top,
			nullptr,
			nullptr,
			GetModuleHandle(nullptr),
			this
		);

		if (!hwnd) {
			alive = false;
			MessageBoxA(nullptr, "CreateWindowExA failed.", "Ray CUDA realtime", MB_ICONERROR | MB_OK);
			return;
		}

		ShowWindow(hwnd, SW_SHOWNORMAL);
		UpdateWindow(hwnd);
	}

	void init_bitmap_info() {
		bitmap_info = {};
		bitmap_info.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
		bitmap_info.bmiHeader.biWidth = render_width;
		bitmap_info.bmiHeader.biHeight = -render_height;
		bitmap_info.bmiHeader.biPlanes = 1;
		bitmap_info.bmiHeader.biBitCount = 32;
		bitmap_info.bmiHeader.biCompression = BI_RGB;
	}

	void process_messages() {
		MSG message;
		while (PeekMessage(&message, nullptr, 0, 0, PM_REMOVE)) {
			if (message.message == WM_QUIT) {
				alive = false;
				return;
			}

			TranslateMessage(&message);
			DispatchMessage(&message);
		}
	}

	void set_key_state(WORD virtual_key, bool is_down) {
		switch (virtual_key) {
		case 'W':
			w_down = is_down;
			break;
		case 'A':
			a_down = is_down;
			break;
		case 'S':
			s_down = is_down;
			break;
		case 'D':
			d_down = is_down;
			break;
		case VK_SPACE:
			space_down = is_down;
			break;
		case VK_SHIFT:
		case VK_LSHIFT:
		case VK_RSHIFT:
			shift_down = is_down;
			break;
		case VK_ESCAPE:
			esc_down = is_down;
			break;
		default:
			break;
		}
	}

	void paint_pixels(HDC dc, const std::uint32_t* pixels) const {
		RECT client_rect{0, 0, 0, 0};
		GetClientRect(hwnd, &client_rect);
		int client_width = client_rect.right - client_rect.left;
		int client_height = client_rect.bottom - client_rect.top;

		StretchDIBits(
			dc,
			0,
			0,
			client_width,
			client_height,
			0,
			0,
			render_width,
			render_height,
			pixels,
			&bitmap_info,
			DIB_RGB_COLORS,
			SRCCOPY
		);
	}

	POINT client_center() const {
		RECT rect{0, 0, 0, 0};
		GetClientRect(hwnd, &rect);

		POINT center{(rect.left + rect.right) / 2, (rect.top + rect.bottom) / 2};
		ClientToScreen(hwnd, &center);
		return center;
	}

	void center_cursor() const {
		if (!hwnd) {
			return;
		}

		POINT center = client_center();
		SetCursorPos(center.x, center.y);
	}

	void clip_cursor_to_client() const {
		if (!hwnd) {
			return;
		}

		RECT rect{0, 0, 0, 0};
		GetClientRect(hwnd, &rect);
		POINT top_left{rect.left, rect.top};
		POINT bottom_right{rect.right, rect.bottom};
		ClientToScreen(hwnd, &top_left);
		ClientToScreen(hwnd, &bottom_right);

		RECT screen_rect{top_left.x, top_left.y, bottom_right.x, bottom_right.y};
		ClipCursor(&screen_rect);
	}

	static void hide_cursor() {
		SetCursor(nullptr);
		while (ShowCursor(FALSE) >= 0) {
		}
	}

	static void restore_cursor() {
		SetCursor(LoadCursor(nullptr, IDC_ARROW));
		while (ShowCursor(TRUE) < 0) {
		}
	}
};

struct HostCamera {
	Vec3 position;
	Vec3 forward;
	Vec3 right;
	Vec3 up;
	float yaw;
	float pitch;
	float move_speed;
	float mouse_sensitivity;
	float viewport_height;
	float viewport_width;
	int width;
	int height;

	HostCamera(int width_, int height_)
		: position(0.0f, 0.0f, 2.0f),
		  forward(0.0f, 0.0f, -1.0f),
		  right(1.0f, 0.0f, 0.0f),
		  up(0.0f, 1.0f, 0.0f),
		  yaw(0.0f),
		  pitch(0.0f),
		  move_speed(4.0f),
		  mouse_sensitivity(0.0025f),
		  viewport_height(2.0f),
		  viewport_width(2.0f * float(width_) / float(height_)),
		  width(width_),
		  height(height_) {
		update_basis();
	}

	void move_local(float move_forward, float move_right, float move_up, float delta_time) {
		float input_mag = sqrtf(move_forward * move_forward + move_right * move_right + move_up * move_up);
		if (input_mag > 1.0f) {
			move_forward /= input_mag;
			move_right /= input_mag;
			move_up /= input_mag;
		}

		Vec3 world_up(0.0f, 1.0f, 0.0f);
		position += (forward * move_forward + right * move_right + world_up * move_up) * (move_speed * delta_time);
	}

	void turn(float mouse_dx, float mouse_dy) {
		yaw += mouse_dx * mouse_sensitivity;
		pitch -= mouse_dy * mouse_sensitivity;

		const float max_pitch = 1.55334306f;
		pitch = std::clamp(pitch, -max_pitch, max_pitch);
		update_basis();
	}

	CameraData to_device_data() const {
		CameraData cam;
		cam.width = width;
		cam.height = height;
		cam.position = position;

		Vec3 viewport_upper_left =
			position
			+ forward
			- 0.5f * viewport_width * right
			+ 0.5f * viewport_height * up;

		cam.pixel_delta_u = right * (viewport_width / float(width));
		cam.pixel_delta_v = -up * (viewport_height / float(height));
		cam.pixel00 = viewport_upper_left + 0.5f * (cam.pixel_delta_u + cam.pixel_delta_v);
		return cam;
	}

private:
	void update_basis() {
		forward = Vec3(
			cosf(pitch) * sinf(yaw),
			sinf(pitch),
			-cosf(pitch) * cosf(yaw)
		);
		forward = unit_vector(forward);

		Vec3 world_up(0.0f, 1.0f, 0.0f);
		right = unit_vector(cross(forward, world_up));
		up = unit_vector(cross(right, forward));
	}
};

__device__ uint32_t xorshift32(uint32_t& state) {
	state ^= state << 13;
	state ^= state >> 17;
	state ^= state << 5;
	return state;
}

__device__ float random_float(uint32_t& state) {
	return (xorshift32(state) & 0x00ffffff) / 16777216.0f;
}

__device__ Vec3 random_in_unit_sphere(uint32_t& state) {
	while (true) {
		Vec3 p(
			2.0f * random_float(state) - 1.0f,
			2.0f * random_float(state) - 1.0f,
			2.0f * random_float(state) - 1.0f
		);
		if (dot(p, p) < 1.0f) {
			return p;
		}
	}
}

__device__ Vec3 random_unit_vector(uint32_t& state) {
	return unit_vector(random_in_unit_sphere(state));
}

__device__ bool hit_sphere(const Sphere& sphere, const Ray& r, float t_min, float t_max, HitRecord& rec) {
	Vec3 oc = r.orig - sphere.center;
	float a = dot(r.dir, r.dir);
	float half_b = dot(oc, r.dir);
	float c = dot(oc, oc) - sphere.radius * sphere.radius;
	float discriminant = half_b * half_b - a * c;

	if (discriminant < 0.0f) {
		return false;
	}

	float sqrtd = sqrtf(discriminant);
	float root = (-half_b - sqrtd) / a;
	if (root <= t_min || root >= t_max) {
		root = (-half_b + sqrtd) / a;
		if (root <= t_min || root >= t_max) {
			return false;
		}
	}

	rec.t = root;
	rec.p = r.at(root);
	rec.set_face_normal(r, (rec.p - sphere.center) / sphere.radius);
	rec.material_id = sphere.material_id;
	return true;
}

__device__ bool hit_plane(const Plane& plane, const Ray& r, float t_min, float t_max, HitRecord& rec) {
	float denom = dot(r.dir, plane.normal);
	if (fabsf(denom) < 1e-8f) {
		return false;
	}

	float t = (-dot(plane.normal, r.orig) - plane.b) / denom;
	if (t <= t_min || t >= t_max) {
		return false;
	}

	rec.t = t;
	rec.p = r.at(t);
	rec.set_face_normal(r, plane.normal);
	rec.material_id = plane.material_id;
	return true;
}

__device__ bool hit_world(
	const Sphere* spheres,
	int sphere_count,
	const Plane* planes,
	int plane_count,
	const Ray& r,
	float t_min,
	float t_max,
	HitRecord& rec
) {
	HitRecord temp_rec;
	bool hit_anything = false;
	float closest = t_max;

	for (int i = 0; i < sphere_count; ++i) {
		if (hit_sphere(spheres[i], r, t_min, closest, temp_rec)) {
			hit_anything = true;
			closest = temp_rec.t;
			rec = temp_rec;
		}
	}

	for (int i = 0; i < plane_count; ++i) {
		if (hit_plane(planes[i], r, t_min, closest, temp_rec)) {
			hit_anything = true;
			closest = temp_rec.t;
			rec = temp_rec;
		}
	}

	return hit_anything;
}

__device__ bool scatter(
	const Material* materials,
	const Ray& r_in,
	const HitRecord& rec,
	uint32_t& rng_state,
	Vec3& attenuation,
	Ray& scattered
) {
	Material mat = materials[rec.material_id];

	if (mat.type == MAT_LAMBERTIAN) {
		Vec3 scatter_direction = rec.normal + random_unit_vector(rng_state);
		if (near_zero(scatter_direction)) {
			scatter_direction = rec.normal;
		}

		scattered = Ray(rec.p, scatter_direction);
		attenuation = mat.albedo;
		return true;
	}

	if (mat.type == MAT_METAL) {
		Vec3 reflected = reflect(unit_vector(r_in.dir), rec.normal);
		scattered = Ray(rec.p, reflected + mat.fuzz * random_in_unit_sphere(rng_state));
		attenuation = mat.albedo;
		return dot(scattered.dir, rec.normal) > 0.0f;
	}

	if (mat.type == MAT_DIELECTRIC) {
		attenuation = mat.albedo;
		float refraction_ratio = rec.front_face ? (1.0f / mat.refraction_index) : mat.refraction_index;
		Vec3 unit_direction = unit_vector(r_in.dir);

		float cos_theta = fminf(dot(-unit_direction, rec.normal), 1.0f);
		float sin_theta = sqrtf(1.0f - cos_theta * cos_theta);
		bool cannot_refract = refraction_ratio * sin_theta > 1.0f;

		float r0 = (1.0f - refraction_ratio) / (1.0f + refraction_ratio);
		r0 = r0 * r0;
		float one_minus_cos = 1.0f - cos_theta;
		float reflectance = r0 + (1.0f - r0) * one_minus_cos * one_minus_cos * one_minus_cos * one_minus_cos * one_minus_cos;

		Vec3 direction = (cannot_refract || reflectance > random_float(rng_state))
			? reflect(unit_direction, rec.normal)
			: refract(unit_direction, rec.normal, refraction_ratio);

		scattered = Ray(rec.p, direction);
		return true;
	}

	return false;
}

__device__ float schlick_reflectance(float cosine, float refraction_ratio) {
	float r0 = (1.0f - refraction_ratio) / (1.0f + refraction_ratio);
	r0 = r0 * r0;
	float one_minus_cos = 1.0f - cosine;
	return r0 + (1.0f - r0) * one_minus_cos * one_minus_cos * one_minus_cos * one_minus_cos * one_minus_cos;
}

__device__ Vec3 sky_color(const Ray& r) {
	Vec3 unit_direction = unit_vector(r.dir);
	float a = 0.5f * (unit_direction.y + 1.0f);
	return (1.0f - a) * Vec3(1.0f, 1.0f, 1.0f) + a * Vec3(0.5f, 0.7f, 1.0f);
}

__device__ Vec3 preview_surface_color(const Ray& r, const HitRecord& rec, const Material* materials) {
	Material mat = materials[rec.material_id];
	Vec3 light_dir = unit_vector(Vec3(-0.6f, 1.0f, 0.35f));
	float diffuse = fmaxf(dot(rec.normal, light_dir), 0.0f);
	float shade = 0.18f + 0.82f * diffuse;

	if (mat.type == MAT_METAL) {
		Vec3 reflected = reflect(unit_vector(r.dir), rec.normal);
		Vec3 reflected_sky = sky_color(Ray(rec.p, reflected));
		return 0.35f * mat.albedo * shade + 0.65f * mat.albedo * reflected_sky;
	}

	return mat.albedo * shade;
}

__device__ Vec3 ray_color(
	const Ray& start_ray,
	const Sphere* spheres,
	int sphere_count,
	const Plane* planes,
	int plane_count,
	const Material* materials,
	uint32_t& rng_state,
	int max_depth
) {
	Ray r = start_ray;
	Vec3 throughput(1.0f, 1.0f, 1.0f);

	for (int depth = 0; depth < max_depth; ++depth) {
		HitRecord rec;
		if (hit_world(spheres, sphere_count, planes, plane_count, r, 0.001f, 1.0e30f, rec)) {
			Ray scattered;
			Vec3 attenuation;
			if (!scatter(materials, r, rec, rng_state, attenuation, scattered)) {
				return Vec3(0.0f, 0.0f, 0.0f);
			}

			throughput *= attenuation;
			r = scattered;
			continue;
		}

		return throughput * sky_color(r);
	}

	return Vec3(0.0f, 0.0f, 0.0f);
}

__device__ Vec3 preview_ray_color(
	const Ray& start_ray,
	const Sphere* spheres,
	int sphere_count,
	const Plane* planes,
	int plane_count,
	const Material* materials
) {
	Ray r = start_ray;
	Vec3 throughput(1.0f, 1.0f, 1.0f);

	for (int depth = 0; depth < 6; ++depth) {
		HitRecord rec;
		if (!hit_world(spheres, sphere_count, planes, plane_count, r, 0.001f, 1.0e30f, rec)) {
			return throughput * sky_color(r);
		}

		Material mat = materials[rec.material_id];
		if (mat.type != MAT_DIELECTRIC) {
			return throughput * preview_surface_color(r, rec, materials);
		}

		Vec3 unit_direction = unit_vector(r.dir);
		float refraction_ratio = rec.front_face ? (1.0f / mat.refraction_index) : mat.refraction_index;
		float cos_theta = fminf(dot(-unit_direction, rec.normal), 1.0f);
		float sin_theta = sqrtf(1.0f - cos_theta * cos_theta);
		bool cannot_refract = refraction_ratio * sin_theta > 1.0f;
		float reflectance = schlick_reflectance(cos_theta, refraction_ratio);

		Vec3 direction = (cannot_refract || reflectance > 0.28f)
			? reflect(unit_direction, rec.normal)
			: refract(unit_direction, rec.normal, refraction_ratio);

		throughput *= mat.albedo;
		r = Ray(rec.p, direction);
	}

	return Vec3(0.0f, 0.0f, 0.0f);
}

__device__ Ray get_camera_ray(const CameraData& cam, int x, int y, uint32_t& rng_state, bool jitter_pixels) {
	float dx = 0.0f;
	float dy = 0.0f;
	if (jitter_pixels) {
		dx = random_float(rng_state) - 0.5f;
		dy = random_float(rng_state) - 0.5f;
	}
	Vec3 pixel = cam.pixel00 + cam.pixel_delta_u * (float(x) + dx) + cam.pixel_delta_v * (float(y) + dy);
	return Ray(cam.position, pixel - cam.position);
}

__device__ float clamp01_device(float x) {
	if (x < 0.0f) {
		return 0.0f;
	}
	if (x > 0.999f) {
		return 0.999f;
	}
	return x;
}

__device__ std::uint32_t pack_color(Vec3 color) {
	float r = sqrtf(clamp01_device(color.x));
	float g = sqrtf(clamp01_device(color.y));
	float b = sqrtf(clamp01_device(color.z));

	std::uint32_t ir = std::uint32_t(256.0f * clamp01_device(r));
	std::uint32_t ig = std::uint32_t(256.0f * clamp01_device(g));
	std::uint32_t ib = std::uint32_t(256.0f * clamp01_device(b));
	return (ir << 16) | (ig << 8) | ib;
}

__global__ void render_kernel(
	std::uint32_t* pixels,
	Vec3* accumulation,
	CameraData cam,
	const Sphere* spheres,
	int sphere_count,
	const Plane* planes,
	int plane_count,
	const Material* materials,
	int samples_per_pixel,
	int max_depth,
	std::uint32_t noise_seed,
	std::uint32_t accumulated_frames,
	bool jitter_pixels,
	bool preview_mode
) {
	int x = blockIdx.x * blockDim.x + threadIdx.x;
	int y = blockIdx.y * blockDim.y + threadIdx.y;

	if (x >= cam.width || y >= cam.height) {
		return;
	}

	int pixel_index = y * cam.width + x;
	uint32_t rng_state = 1973u * uint32_t(x) + 9277u * uint32_t(y) + 26699u * noise_seed + 89173u;
	xorshift32(rng_state);

	if (preview_mode) {
		Ray r = get_camera_ray(cam, x, y, rng_state, false);
		Vec3 current_color = preview_ray_color(r, spheres, sphere_count, planes, plane_count, materials);
		accumulation[pixel_index] = current_color;
		pixels[pixel_index] = pack_color(current_color);
		return;
	}

	Vec3 pixel_color(0.0f, 0.0f, 0.0f);
	for (int sample = 0; sample < samples_per_pixel; ++sample) {
		Ray r = get_camera_ray(cam, x, y, rng_state, jitter_pixels);
		pixel_color += ray_color(r, spheres, sphere_count, planes, plane_count, materials, rng_state, max_depth);
	}

	Vec3 current_color = pixel_color / float(samples_per_pixel);
	Vec3 total_color = accumulated_frames == 0
		? current_color
		: accumulation[pixel_index] + current_color;

	accumulation[pixel_index] = total_color;
	pixels[pixel_index] = pack_color(total_color / float(accumulated_frames + 1));
}

static Plane make_plane(Vec3 normal, float b, int material_id) {
	float len = length(normal);
	if (len == 0.0f) {
		normal = Vec3(0.0f, 1.0f, 0.0f);
		b = 0.0f;
	} else {
		normal = normal / len;
		b /= len;
	}

	Plane plane;
	plane.normal = normal;
	plane.b = b;
	plane.material_id = material_id;
	return plane;
}

static std::string make_title(const HostCamera& camera, float fps, int samples_per_pixel, int max_depth, std::uint32_t accumulated_frames, bool preview_mode) {
	std::ostringstream title;
	title.setf(std::ios::fixed);
	title.precision(2);
	title
		<< "Ray CUDA realtime"
		<< "  fps: " << fps
		<< "  mode: " << (preview_mode ? "preview" : "trace")
		<< "  spp: " << samples_per_pixel
		<< "  accum: " << accumulated_frames
		<< "  depth: " << max_depth
		<< "  yaw: " << camera.yaw
		<< "  pitch: " << camera.pitch
		<< "  pos: (" << camera.position.x << ", " << camera.position.y << ", " << camera.position.z << ")"
		<< "  fwd: (" << camera.forward.x << ", " << camera.forward.y << ", " << camera.forward.z << ")";
	return title.str();
}

#define CUDA_CHECK(call) \
	do { \
		cudaError_t err = (call); \
		if (err != cudaSuccess) { \
			std::fprintf(stderr, "CUDA error %s:%d: %s\n", __FILE__, __LINE__, cudaGetErrorString(err)); \
			return 1; \
		} \
	} while (0)

int main() {
	const int width = 640;
	const int height = 360;
	const int pixel_scale = 2;
	const int samples_per_pixel = 1;
	const int max_depth = 8;

	Material materials[] = {
		{ MAT_LAMBERTIAN, Vec3(0.8f, 0.8f, 0.0f), 0.0f, 1.0f },
		{ MAT_LAMBERTIAN, Vec3(0.7f, 0.3f, 0.3f), 0.0f, 1.0f },
		{ MAT_METAL, Vec3(0.8f, 0.8f, 0.8f), 0.0f, 1.0f },
		{ MAT_METAL, Vec3(0.8f, 0.6f, 0.2f), 0.5f, 1.0f },
		{ MAT_LAMBERTIAN, Vec3(0.2f, 0.5f, 0.9f), 0.0f, 1.0f },
		{ MAT_DIELECTRIC, Vec3(1.0f, 1.0f, 1.0f), 0.0f, 1.5f }
	};

	Sphere spheres[] = {
		{ Vec3(0.0f, 0.0f, -1.0f), 0.5f, 1 },
		{ Vec3(-1.0f, 0.0f, -1.0f), 0.5f, 2 },
		{ Vec3(1.0f, 0.0f, -1.0f), 0.5f, 3 },
		{ Vec3(0.0f, 0.7f, -2.3f), 0.35f, 4 },
		{ Vec3(0.0f, 0.05f, -0.45f), 0.22f, 5 }
	};

	Plane planes[] = {
		make_plane(Vec3(0.0f, 1.0f, 0.0f), 0.5f, 0)
	};

	std::vector<std::uint32_t> host_pixels(width * height, 0);
	std::uint32_t* device_pixels = nullptr;
	Vec3* device_accumulation = nullptr;
	Sphere* device_spheres = nullptr;
	Plane* device_planes = nullptr;
	Material* device_materials = nullptr;

	CUDA_CHECK(cudaMalloc(&device_pixels, sizeof(std::uint32_t) * host_pixels.size()));
	CUDA_CHECK(cudaMalloc(&device_accumulation, sizeof(Vec3) * host_pixels.size()));
	CUDA_CHECK(cudaMalloc(&device_spheres, sizeof(spheres)));
	CUDA_CHECK(cudaMalloc(&device_planes, sizeof(planes)));
	CUDA_CHECK(cudaMalloc(&device_materials, sizeof(materials)));

	CUDA_CHECK(cudaMemcpy(device_spheres, spheres, sizeof(spheres), cudaMemcpyHostToDevice));
	CUDA_CHECK(cudaMemcpy(device_planes, planes, sizeof(planes), cudaMemcpyHostToDevice));
	CUDA_CHECK(cudaMemcpy(device_materials, materials, sizeof(materials), cudaMemcpyHostToDevice));

	AppWindow window(width, height, pixel_scale);
	HostCamera camera(width, height);

	dim3 block(16, 16);
	dim3 grid((width + block.x - 1) / block.x, (height + block.y - 1) / block.y);

	std::uint32_t frame_index = 1;
	std::uint32_t accumulated_frames = 0;
	auto previous_frame = std::chrono::high_resolution_clock::now();

	while (window.open()) {
		auto frame_start = std::chrono::high_resolution_clock::now();
		float delta_time = std::chrono::duration<float>(frame_start - previous_frame).count();
		previous_frame = frame_start;

		FrameInput input = window.poll();
		if (input.quit) {
			break;
		}

		bool camera_moved =
			input.move_forward != 0.0f ||
			input.move_right != 0.0f ||
			input.move_up != 0.0f ||
			input.mouse_dx != 0.0f ||
			input.mouse_dy != 0.0f;

		camera.move_local(input.move_forward, input.move_right, input.move_up, delta_time);
		camera.turn(input.mouse_dx, input.mouse_dy);

		std::uint32_t frames_before_render = camera_moved ? 0 : accumulated_frames;
		bool jitter_pixels = !camera_moved;
		bool preview_mode = camera_moved;
		std::uint32_t noise_seed = camera_moved ? 1u : frame_index;

		render_kernel<<<grid, block>>>(
			device_pixels,
			device_accumulation,
			camera.to_device_data(),
			device_spheres,
			int(sizeof(spheres) / sizeof(spheres[0])),
			device_planes,
			int(sizeof(planes) / sizeof(planes[0])),
			device_materials,
			samples_per_pixel,
			max_depth,
			noise_seed,
			frames_before_render,
			jitter_pixels,
			preview_mode
		);

		CUDA_CHECK(cudaGetLastError());
		CUDA_CHECK(cudaDeviceSynchronize());
		CUDA_CHECK(cudaMemcpy(host_pixels.data(), device_pixels, sizeof(std::uint32_t) * host_pixels.size(), cudaMemcpyDeviceToHost));

		window.display(host_pixels.data());

		auto frame_end = std::chrono::high_resolution_clock::now();
		float frame_seconds = std::chrono::duration<float>(frame_end - frame_start).count();
		float fps = frame_seconds > 0.0f ? 1.0f / frame_seconds : 0.0f;
		accumulated_frames = frames_before_render + 1;
		window.set_title(make_title(camera, fps, samples_per_pixel, max_depth, accumulated_frames, preview_mode));

		++frame_index;
	}

	CUDA_CHECK(cudaFree(device_materials));
	CUDA_CHECK(cudaFree(device_planes));
	CUDA_CHECK(cudaFree(device_spheres));
	CUDA_CHECK(cudaFree(device_accumulation));
	CUDA_CHECK(cudaFree(device_pixels));
	CUDA_CHECK(cudaDeviceReset());
	return 0;
}
