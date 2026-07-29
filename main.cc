#include <iostream>
#include <chrono>
#include <iomanip>
#include <sstream>
#include <ctime>
#include "plane.h"
#include "sphere.h"
#include "camera.h"
#include "app_window.h"
#include "material.h"

std::string debug_title(const camera& cam) {
	std::ostringstream title;
	title << std::fixed << std::setprecision(3)
		<< "Ray  "
		<< "yaw: " << cam.yaw
		<< "  pitch: " << cam.pitch
		<< "  pos_x: " << cam.position.x()
		<< "  pos_y: " << cam.position.y()
		<< "  pos_z: " << cam.position.z()
		<< "  fwd_x: " << cam.forward.x()
		<< "  fwd_y: " << cam.forward.y()
		<< "  fwd_z: " << cam.forward.z()
		<< "  right: (" << cam.right.x() << "," << cam.right.y() << "," << cam.right.z() << ")"
		<< "  up: (" << cam.up.x() << "," << cam.up.y() << "," << cam.up.z() << ")";
	return title.str();
}

int main() {
	std::srand(static_cast<unsigned>(std::time(nullptr)));
	hittable_list world;    
	auto material_ground = make_shared<lambertian>(color(0.8, 0.8, 0.0));
    auto material_center = make_shared<lambertian>(color(0.7, 0.3, 0.3));
    auto material_left   = make_shared<metal>(color(0.8, 0.8, 0.8), 0);
    auto material_right  = make_shared<metal>(color(0.8, 0.6, 0.2), 0.5);
    world.add(make_shared<sphere>(point3( 0.0, -100.5, -1.0), 100.0, material_ground));
    world.add(make_shared<sphere>(point3( 0.0,    0.0, -1.0),   0.5, material_center));
    world.add(make_shared<sphere>(point3(-1.0,    0.0, -1.0),   0.5, material_left));
    world.add(make_shared<sphere>(point3( 1.0,    0.0, -1.0),   0.5, material_right));
										// std::make_shared<lambertian>(lambertian(color(0, 1, 0))))));
	// world.add(std::make_shared<plane>(plane(vec3(0.1, 2, 0.1), 2.2, 
										// std::make_shared<lambertian>(lambertian(color(0.5, 0.7, 0.2))))));
//	world.add(std::make_shared<plane>(plane(vec3(0.1, 2, 0.1), 2.2)));
	int screen_width = 400; 
	int screen_height = 225;
	int pixel_scale = 6;
	camera cam(screen_width, screen_height);
	app_window window(screen_width, screen_height, pixel_scale);
	
	float time_offset = 0.0f;
	
	const int TARGET_FPS = 30;
	const std::chrono::milliseconds frameDuration(1000 / TARGET_FPS);
	auto previous_frame = std::chrono::high_resolution_clock::now();
	
	while (window.open()) {
		auto frameStart = std::chrono::high_resolution_clock::now();
		float delta_time = std::chrono::duration<float>(frameStart - previous_frame).count();
		previous_frame = frameStart;
		
		frame_input controls = window.poll();
		if (controls.quit) {
			break;
		}
		
		cam.move_local(controls.move_forward, controls.move_right, controls.move_up, delta_time);
		cam.turn(controls.mouse_dx, controls.mouse_dy);
		
		time_offset += 0.05f;
		
		cam.render(world, time_offset);
		window.display(cam);
		window.set_title(debug_title(cam));
		
		auto frameEnd = std::chrono::high_resolution_clock::now();
		auto timeTaken = std::chrono::duration_cast<std::chrono::milliseconds>(frameEnd - frameStart);
		
		if (timeTaken < frameDuration) {
			Sleep(static_cast<DWORD>((frameDuration - timeTaken).count()));
		}
	}
	
	return 0;
}
