#include <cuda_runtime.h>

#include <cmath>
#include <cstdio>
#include <cstdint>
#include <vector>

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
	Vec3 forward;
	Vec3 right;
	Vec3 up;
	float viewport_width;
	float viewport_height;
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

		Vec3 unit_direction = unit_vector(r.dir);
		float a = 0.5f * (unit_direction.y + 1.0f);
		Vec3 sky = (1.0f - a) * Vec3(1.0f, 1.0f, 1.0f) + a * Vec3(0.5f, 0.7f, 1.0f);
		return throughput * sky;
	}

	return Vec3(0.0f, 0.0f, 0.0f);
}

__device__ Ray get_camera_ray(const CameraData& cam, int x, int y, uint32_t& rng_state) {
	float dx = random_float(rng_state) - 0.5f;
	float dy = random_float(rng_state) - 0.5f;

	Vec3 viewport_upper_left =
		cam.position
		+ cam.forward
		- 0.5f * cam.viewport_width * cam.right
		+ 0.5f * cam.viewport_height * cam.up;

	Vec3 pixel_delta_u = cam.right * (cam.viewport_width / cam.width);
	Vec3 pixel_delta_v = -cam.up * (cam.viewport_height / cam.height);
	Vec3 pixel00 = viewport_upper_left + 0.5f * (pixel_delta_u + pixel_delta_v);

	Vec3 pixel = pixel00 + pixel_delta_u * (x + dx) + pixel_delta_v * (y + dy);
	return Ray(cam.position, pixel - cam.position);
}

__global__ void render_kernel(
	Vec3* framebuffer,
	CameraData cam,
	const Sphere* spheres,
	int sphere_count,
	const Plane* planes,
	int plane_count,
	const Material* materials,
	int samples_per_pixel,
	int max_depth,
	uint32_t frame_index
) {
	int x = blockIdx.x * blockDim.x + threadIdx.x;
	int y = blockIdx.y * blockDim.y + threadIdx.y;

	if (x >= cam.width || y >= cam.height) {
		return;
	}

	int pixel_index = y * cam.width + x;
	uint32_t rng_state = 1973u * x + 9277u * y + 26699u * frame_index + 89173u;
	xorshift32(rng_state);

	Vec3 pixel_color(0.0f, 0.0f, 0.0f);
	for (int sample = 0; sample < samples_per_pixel; ++sample) {
		Ray r = get_camera_ray(cam, x, y, rng_state);
		pixel_color += ray_color(r, spheres, sphere_count, planes, plane_count, materials, rng_state, max_depth);
	}

	framebuffer[pixel_index] = pixel_color / float(samples_per_pixel);
}

static float clamp01(float x) {
	if (x < 0.0f) {
		return 0.0f;
	}
	if (x > 0.999f) {
		return 0.999f;
	}
	return x;
}

static int to_byte(float linear_value) {
	float gamma_corrected = sqrtf(clamp01(linear_value));
	return int(256.0f * clamp01(gamma_corrected));
}

static void write_ppm(const char* filename, const Vec3* pixels, int width, int height) {
	FILE* file = nullptr;
#if defined(_MSC_VER)
	fopen_s(&file, filename, "w");
#else
	file = fopen(filename, "w");
#endif

	if (!file) {
		std::fprintf(stderr, "Failed to open %s\n", filename);
		return;
	}

	std::fprintf(file, "P3\n%d %d\n255\n", width, height);
	for (int y = 0; y < height; ++y) {
		for (int x = 0; x < width; ++x) {
			Vec3 c = pixels[y * width + x];
			std::fprintf(file, "%d %d %d\n", to_byte(c.x), to_byte(c.y), to_byte(c.z));
		}
	}

	std::fclose(file);
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

static std::vector<Sphere> make_sphere_rows() {
	std::vector<Sphere> spheres;
	const int columns = 10;
	const int rows = 5;
	const float ground_y = -0.5f;
	const float x_spacing = 0.68f;
	const float z_spacing = 0.92f;
	const int material_ids[] = {1, 6, 9, 2, 7, 10, 3, 8, 4, 5};

	spheres.reserve(columns * rows);
	for (int row = 0; row < rows; ++row) {
		for (int col = 0; col < columns; ++col) {
			float radius = 0.12f + 0.035f * float((row * 3 + col * 5) % 6);
			float row_offset = (row % 2 == 0) ? 0.0f : 0.22f;
			float x = (float(col) - 0.5f * float(columns - 1)) * x_spacing + row_offset;
			float y = ground_y + radius;
			float z = -1.2f - float(row) * z_spacing - 0.08f * float(col % 3);
			int material_id = material_ids[(col + row * 3) % (sizeof(material_ids) / sizeof(material_ids[0]))];

			spheres.push_back({ Vec3(x, y, z), radius, material_id });
		}
	}

	return spheres;
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
	const int width = 800;
	const int height = 450;
	const int samples_per_pixel = 16;
	const int max_depth = 8;

	Material materials[] = {
		{ MAT_LAMBERTIAN, Vec3(0.8f, 0.8f, 0.0f), 0.0f, 1.0f },
		{ MAT_LAMBERTIAN, Vec3(0.7f, 0.3f, 0.3f), 0.0f, 1.0f },
		{ MAT_LAMBERTIAN, Vec3(0.2f, 0.5f, 0.9f), 0.0f, 1.0f },
		{ MAT_LAMBERTIAN, Vec3(0.2f, 0.8f, 0.35f), 0.0f, 1.0f },
		{ MAT_LAMBERTIAN, Vec3(0.65f, 0.25f, 0.9f), 0.0f, 1.0f },
		{ MAT_LAMBERTIAN, Vec3(0.95f, 0.95f, 0.9f), 0.0f, 1.0f },
		{ MAT_METAL, Vec3(0.8f, 0.8f, 0.85f), 0.0f, 1.0f },
		{ MAT_METAL, Vec3(0.95f, 0.72f, 0.25f), 0.18f, 1.0f },
		{ MAT_METAL, Vec3(0.8f, 0.45f, 0.28f), 0.45f, 1.0f },
		{ MAT_DIELECTRIC, Vec3(1.0f, 1.0f, 1.0f), 0.0f, 1.5f },
		{ MAT_DIELECTRIC, Vec3(0.9f, 0.98f, 1.0f), 0.0f, 1.33f }
	};

	std::vector<Sphere> spheres = make_sphere_rows();

	Plane planes[] = {
		make_plane(Vec3(0.0f, 1.0f, 0.0f), 0.5f, 0)
	};

	CameraData cam;
	cam.width = width;
	cam.height = height;
	cam.position = Vec3(0.0f, 1.2f, 2.6f);
	cam.forward = unit_vector(Vec3(0.0f, -0.28f, -1.0f));
	cam.right = Vec3(1.0f, 0.0f, 0.0f);
	cam.up = unit_vector(Vec3(0.0f, 1.0f, -0.28f));
	cam.viewport_height = 2.0f;
	cam.viewport_width = cam.viewport_height * float(width) / float(height);

	Vec3* host_framebuffer = new Vec3[width * height];
	Vec3* device_framebuffer = nullptr;
	Sphere* device_spheres = nullptr;
	Plane* device_planes = nullptr;
	Material* device_materials = nullptr;

	CUDA_CHECK(cudaMalloc(&device_framebuffer, sizeof(Vec3) * width * height));
	CUDA_CHECK(cudaMalloc(&device_spheres, sizeof(Sphere) * spheres.size()));
	CUDA_CHECK(cudaMalloc(&device_planes, sizeof(planes)));
	CUDA_CHECK(cudaMalloc(&device_materials, sizeof(materials)));

	CUDA_CHECK(cudaMemcpy(device_spheres, spheres.data(), sizeof(Sphere) * spheres.size(), cudaMemcpyHostToDevice));
	CUDA_CHECK(cudaMemcpy(device_planes, planes, sizeof(planes), cudaMemcpyHostToDevice));
	CUDA_CHECK(cudaMemcpy(device_materials, materials, sizeof(materials), cudaMemcpyHostToDevice));

	dim3 block(16, 16);
	dim3 grid((width + block.x - 1) / block.x, (height + block.y - 1) / block.y);

	std::printf("Rendering %dx%d, %d samples, depth %d...\n", width, height, samples_per_pixel, max_depth);
	render_kernel<<<grid, block>>>(
		device_framebuffer,
		cam,
		device_spheres,
		int(spheres.size()),
		device_planes,
		int(sizeof(planes) / sizeof(planes[0])),
		device_materials,
		samples_per_pixel,
		max_depth,
		1u
	);

	CUDA_CHECK(cudaGetLastError());
	CUDA_CHECK(cudaDeviceSynchronize());
	CUDA_CHECK(cudaMemcpy(host_framebuffer, device_framebuffer, sizeof(Vec3) * width * height, cudaMemcpyDeviceToHost));

	write_ppm("cuda_output.ppm", host_framebuffer, width, height);
	std::printf("Wrote cuda_output.ppm\n");

	CUDA_CHECK(cudaFree(device_materials));
	CUDA_CHECK(cudaFree(device_planes));
	CUDA_CHECK(cudaFree(device_spheres));
	CUDA_CHECK(cudaFree(device_framebuffer));
	CUDA_CHECK(cudaDeviceReset());

	delete[] host_framebuffer;
	return 0;
}
