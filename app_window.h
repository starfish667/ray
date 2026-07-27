#ifndef APP_WINDOW_H
#define APP_WINDOW_H

#ifndef NOMINMAX
#define NOMINMAX
#endif

#include "camera.h"
#include <windows.h>
#include <algorithm>
#include <cstdint>
#include <string>
#include <vector>

struct frame_input {
	double move_forward = 0.0;
	double move_right = 0.0;
	double move_up = 0.0;
	double mouse_dx = 0.0;
	double mouse_dy = 0.0;
	bool quit = false;
	bool focused = true;
};

class app_window {
public:
	app_window(int render_width, int render_height, int pixel_scale)
		: render_width(render_width),
		  render_height(render_height),
		  pixel_scale(pixel_scale),
		  hwnd(nullptr),
		  is_alive(true),
		  first_mouse_sample(true),
		  w_down(false),
		  a_down(false),
		  s_down(false),
		  d_down(false),
		  space_down(false),
		  shift_down(false),
		  esc_down(false),
		  pixels(render_width * render_height, 0) {
		register_window_class();
		if (is_alive) {
			create_window();
		}
		init_bitmap_info();
		if (hwnd) {
			set_title("Ray - running");
		} else {
			write_startup_error(startup_error);
			MessageBoxA(nullptr, startup_error.c_str(), "Ray startup error", MB_ICONERROR | MB_OK);
		}
	}

	~app_window() {
		ClipCursor(nullptr);
		restore_cursor();
		if (hwnd) {
			DestroyWindow(hwnd);
		}
	}

	bool open() const {
		return is_alive;
	}

	frame_input poll() {
		if (!hwnd) {
			frame_input input;
			input.quit = true;
			input.focused = false;
			return input;
		}

		process_messages();

		frame_input input;
		input.focused = (GetForegroundWindow() == hwnd);
		input.quit = !is_alive || esc_down || key_down(VK_ESCAPE);

		input.move_forward += (w_down || key_down('W')) ? 1.0 : 0.0;
		input.move_forward -= (s_down || key_down('S')) ? 1.0 : 0.0;
		input.move_right += (d_down || key_down('D')) ? 1.0 : 0.0;
		input.move_right -= (a_down || key_down('A')) ? 1.0 : 0.0;
		input.move_up += (space_down || key_down(VK_SPACE)) ? 1.0 : 0.0;
		input.move_up -= (shift_down || key_down(VK_SHIFT)) ? 1.0 : 0.0;

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
				input.mouse_dx = static_cast<double>(cursor.x - center.x);
				input.mouse_dy = static_cast<double>(cursor.y - center.y);
			}
			SetCursorPos(center.x, center.y);
		}

		hide_cursor();
		clip_cursor_to_client();
		return input;
	}

	void display(const camera& cam) {
		if (!hwnd) {
			return;
		}

		for (int y = 0; y < render_height; ++y) {
			for (int x = 0; x < render_width; ++x) {
				color pixel = cam.mat[y][x] * 255.999;
				std::uint8_t r = to_byte(pixel.x());
				std::uint8_t g = to_byte(pixel.y());
				std::uint8_t b = to_byte(pixel.z());
				pixels[y * render_width + x] =
					(static_cast<std::uint32_t>(r) << 16) |
					(static_cast<std::uint32_t>(g) << 8) |
					static_cast<std::uint32_t>(b);
			}
		}

		HDC dc = GetDC(hwnd);
		paint_pixels(dc);
		ReleaseDC(hwnd, dc);
	}

	void set_title(const std::string& title) {
		if (!hwnd) {
			return;
		}

		SetWindowTextA(hwnd, title.c_str());
	}

private:
	int render_width;
	int render_height;
	int pixel_scale;
	HWND hwnd;
	bool is_alive;
	bool first_mouse_sample;
	bool w_down;
	bool a_down;
	bool s_down;
	bool d_down;
	bool space_down;
	bool shift_down;
	bool esc_down;
	std::string startup_error;
	BITMAPINFO bitmap_info;
	std::vector<std::uint32_t> pixels;

	static constexpr const char* class_name = "RayTracerWindow";

	static bool key_down(int key) {
		return (GetAsyncKeyState(key) & 0x8000) != 0;
	}

	static std::uint8_t to_byte(double value) {
		return static_cast<std::uint8_t>(std::clamp(value, 0.0, 255.0));
	}

	static LRESULT CALLBACK window_proc(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
		app_window* window = reinterpret_cast<app_window*>(GetWindowLongPtr(hwnd, GWLP_USERDATA));

		if (message == WM_NCCREATE) {
			CREATESTRUCT* create = reinterpret_cast<CREATESTRUCT*>(lparam);
			window = reinterpret_cast<app_window*>(create->lpCreateParams);
			SetWindowLongPtr(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(window));
			return TRUE;
		}

		if (window) {
			return window->handle_message(message, wparam, lparam);
		}

		return DefWindowProc(hwnd, message, wparam, lparam);
	}

	LRESULT handle_message(UINT message, WPARAM wparam, LPARAM lparam) {
		switch (message) {
		case WM_CLOSE:
			is_alive = false;
			DestroyWindow(hwnd);
			return 0;
		case WM_DESTROY:
			is_alive = false;
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
		case WM_PAINT: {
			PAINTSTRUCT paint;
			HDC dc = BeginPaint(hwnd, &paint);
			paint_pixels(dc);
			EndPaint(hwnd, &paint);
			return 0;
		}
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

	void register_window_class() {
		WNDCLASSA window_class{};
		window_class.style = CS_HREDRAW | CS_VREDRAW;
		window_class.lpfnWndProc = app_window::window_proc;
		window_class.hInstance = GetModuleHandle(nullptr);
		window_class.lpszClassName = class_name;
		window_class.hCursor = LoadCursor(nullptr, IDC_ARROW);
		window_class.hbrBackground = reinterpret_cast<HBRUSH>(GetStockObject(BLACK_BRUSH));

		ATOM atom = RegisterClassA(&window_class);
		if (!atom) {
			DWORD error = GetLastError();
			if (error != ERROR_CLASS_ALREADY_EXISTS) {
				startup_error = "RegisterClassA failed. error=" + std::to_string(error);
				is_alive = false;
				return;
			}
		}
	}

	void create_window() {
		DWORD style = WS_OVERLAPPEDWINDOW | WS_VISIBLE;
		RECT rect{
			0,
			0,
			render_width * pixel_scale,
			render_height * pixel_scale
		};
		AdjustWindowRect(&rect, style, FALSE);

		hwnd = CreateWindowExA(
			0,
			class_name,
			"Ray",
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
			startup_error = "CreateWindowExA failed. error=" + std::to_string(GetLastError());
			is_alive = false;
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
				is_alive = false;
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

	void paint_pixels(HDC dc) const {
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
			pixels.data(),
			&bitmap_info,
			DIB_RGB_COLORS,
			SRCCOPY
		);
	}

	POINT client_center() const {
		RECT rect{0, 0, 0, 0};
		GetClientRect(hwnd, &rect);

		POINT center{
			(rect.left + rect.right) / 2,
			(rect.top + rect.bottom) / 2
		};
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

		RECT screen_rect{
			top_left.x,
			top_left.y,
			bottom_right.x,
			bottom_right.y
		};
		ClipCursor(&screen_rect);
	}

	static void hide_cursor() {
		SetCursor(nullptr);
		ShowCursor(FALSE);
	}

	static void restore_cursor() {
		SetCursor(LoadCursor(nullptr, IDC_ARROW));
		ShowCursor(TRUE);
	}

	static void write_startup_error(const std::string& message) {
		char temp_path[MAX_PATH]{};
		DWORD length = GetTempPathA(MAX_PATH, temp_path);
		if (length == 0 || length >= MAX_PATH) {
			return;
		}

		std::string path = std::string(temp_path) + "ray_window_startup_error.txt";
		HANDLE file = CreateFileA(
			path.c_str(),
			GENERIC_WRITE,
			FILE_SHARE_READ,
			nullptr,
			CREATE_ALWAYS,
			FILE_ATTRIBUTE_NORMAL,
			nullptr
		);
		if (file == INVALID_HANDLE_VALUE) {
			return;
		}

		DWORD bytes_written = 0;
		WriteFile(file, message.c_str(), static_cast<DWORD>(message.size()), &bytes_written, nullptr);
		CloseHandle(file);
	}
};

#endif
