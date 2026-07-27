#include <iostream>
#include <chrono>
#include <thread>
#include <iomanip>
#include <sstream>
#include "sphere.h"
#include "camera.h"
#include "app_window.h"

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
	hittable_list world;
	world.add(std::make_shared<sphere>(sphere(point3(1, 1, 1), 1)));
	world.add(std::make_shared<sphere>(sphere(point3(5, 5, 5), 2)));
	int screen_width = 200; 
	int screen_height = 113;
	camera cam(screen_width, screen_height);
	app_window window(screen_width, screen_height, 10);
	
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
			std::this_thread::sleep_for(frameDuration - timeTaken);
		}
	}
	
	return 0;
}
