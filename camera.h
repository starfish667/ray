#ifndef CAMERA_H
#define CAMERA_H

#include "rtweekend.h"
#include "hittable_list.h"
#include "color.h"
#include <vector>
#include <iostream>
#include <string>
#include <cmath>
#include <random>

class camera {
public:
	int width;
	int height;
	point3 position;
	vec3 forward;
	vec3 right;
	vec3 up;
	double yaw;
	double pitch;
	double move_speed;
	double mouse_sensitivity;
	double viewport_height;
	double viewport_width;
	point3 viewport_upper_left;
	vec3 pixel_delta_u;
	vec3 pixel_delta_v;
	point3 pixel00;
	std::vector<std::vector<color>> mat; 
	
	camera(int w, int h)
		: width(w),
		  height(h),
		  position(0.0, 0.0, 0.0),
		  forward(0.0, 0.0, -1.0),
		  right(1.0, 0.0, 0.0),
		  up(0.0, 1.0, 0.0),
		  yaw(0.0),
		  pitch(0.0),
		  move_speed(5.0),
		  mouse_sensitivity(0.0025) {
		update_basis();
	    viewport_height = 2.0;
	    viewport_width = viewport_height * (double(width)/double(height));
		mat.resize(height, std::vector<color>(width));
	}
	
	std::vector<color>& operator[](int i) {
		return mat[i];
	}

	void move_local(double move_forward, double move_right, double move_up, double delta_time) {
		double input_mag = std::sqrt(move_forward * move_forward + move_right * move_right + move_up * move_up);
		if (input_mag > 1.0) {
			move_forward /= input_mag;
			move_right /= input_mag;
			move_up /= input_mag;
		}

		vec3 world_up(0.0, 1.0, 0.0);

		position += (forward * move_forward + right * move_right + world_up * move_up) * (move_speed * delta_time);
	}

	void turn(double mouse_dx, double mouse_dy) {
		yaw += mouse_dx * mouse_sensitivity;
		pitch -= mouse_dy * mouse_sensitivity;

		const double max_pitch = 1.5533430342749532; // 89 degrees.
		if (pitch > max_pitch) {
			pitch = max_pitch;
		}
		if (pitch < -max_pitch) {
			pitch = -max_pitch;
		}

		update_basis();
	}

	void update_basis() {
		forward = vec3(
			std::cos(pitch) * std::sin(yaw),
			std::sin(pitch),
			-std::cos(pitch) * std::cos(yaw)
		);
		forward.normalize();

		vec3 world_up(0.0, 1.0, 0.0);
		right = cross(forward, world_up);
		right.normalize();
		up = cross(right, forward);
		up.normalize();
	}
	color ray_color(hittable_list& world, int max_depth, const ray& r) {
		if(max_depth<=0)return color(0, 0, 0);
		hit_record hr;
		if(world.hit(r, interval(0.001, infinity), hr)) {
//			vec3 dir=hr.normal+random_unit_vector();
//			return 0.5*ray_color(world, max_depth-1, ray(hr.hit_point, dir));
//			return (hr.normal+vec3(1, 1, 1))/2;
			ray scattered;
			color attenuation;
			if(hr.mat->scatter(r, hr, attenuation, scattered))
				return attenuation * ray_color(world, max_depth-1, scattered);
			return color(0, 0, 0);
		}
		vec3 unit_direction = unit_vector(r.direction());
		double a = 0.5*(unit_direction.y() + 1.0);
		return (1.0-a)*color(1.0, 1.0, 1.0) + a*color(0.5, 0.7, 1.0);
	}
	ray get_ray(int x, int y) {
		double dx = random_double() - 0.5;
		double dy = random_double() - 0.5;
		
		point3 pixel = pixel00
		+ pixel_delta_u * (x + dx)
		+ pixel_delta_v * (y + dy);
		
		return ray(position, pixel - position);
	}
	color sample_pixel(hittable_list& world, int x, int y) {
		color pixel_color(0, 0, 0);
		const int samples_per_pixel=50;
		for (int s = 0; s < samples_per_pixel; s++) {
			ray r = get_ray(x, y);
			pixel_color += ray_color(world, 3, r);
		}
		
		pixel_color /= samples_per_pixel;
		pixel_color[0]=linear_to_gamma(pixel_color[0]);
		pixel_color[1]=linear_to_gamma(pixel_color[1]);
		pixel_color[2]=linear_to_gamma(pixel_color[2]);
		return pixel_color;
	}
	void render(hittable_list& world, float offset = 0.0f) {
//		for(int y = 0; y < height; y++) {
//			for(int x = 0; x < width; x++) {
//				mat[y][x][0] = std::fmod((1.0 * y / height) + offset, 1.0);
//				mat[y][x][1] = std::fmod((1.0 * x / width) + offset, 1.0);
//				mat[y][x][2] = 0.0;
//			}
//		}
		viewport_upper_left = position + forward-right*viewport_width/2 + up*viewport_height/2;
		pixel_delta_u = right*viewport_width/width;
		pixel_delta_v = -up*viewport_height/height;
		pixel00 = viewport_upper_left + 0.5 * (pixel_delta_u + pixel_delta_v);
		for(int y = 0; y < height; y++) {
			for(int x = 0; x < width; x++) {
//				point3 pixel = pixel00 + pixel_delta_u*x + pixel_delta_v*y;
//				mat[y][x]=ray_color(world, ray(position, pixel-position));
				mat[y][x]=sample_pixel(world, x, y);
			}
		}
	}
	
	void display() const {
		std::string frame_buffer;
		frame_buffer.reserve(width * (height / 2) * 50);
		
		frame_buffer += "\033[H";
		
		for (int y = 0; y < height; y += 2) {
			for (int x = 0; x < width; ++x) {
				color top = mat[y][x] * 255.999;
				
				color bot = {0, 0, 0}; 
				if (y + 1 < height) {
					bot = mat[y + 1][x] * 255.999;
				}
				
				frame_buffer += "\033[38;2;" + std::to_string(int(top.x())) + ";" 
				+ std::to_string(int(top.y())) + ";" 
				+ std::to_string(int(top.z())) + "m";
				
				frame_buffer += "\033[48;2;" + std::to_string(int(bot.x())) + ";" 
				+ std::to_string(int(bot.y())) + ";" 
				+ std::to_string(int(bot.z())) + "m";
				
				frame_buffer += "\xE2\x96\x80";
			}
			frame_buffer += "\033[0m\n";
		}
		std::cout << frame_buffer << std::flush;
	}
};

#endif
