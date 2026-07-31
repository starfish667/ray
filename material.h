#ifndef MATERIAL_H
#define MATERIAL_H
#include "ray.h"
#include "color.h"
#include "rtweekend.h"
#include "hittable.h"
class hit_record;
class material {
public:
	virtual ~material() = default;
	virtual bool scatter(const ray& r, const hit_record& hr, color& attenuation, ray& scattered) const = 0;
};
class lambertian : public material {
	color albedo;
public:
	lambertian(const color& a) : albedo(a) {}
	bool scatter(const ray& r, const hit_record& hr, color& attenuation, ray& scattered) const override {
		(void)r;
		vec3 dir=hr.normal+random_unit_vector();
		if(dir.near_zero())dir=hr.normal;
		scattered=ray(hr.hit_point, dir);
		attenuation=albedo;
		return true;
	}
};
vec3 reflect(const vec3& r, const vec3& n) {
	return r-2*dot(r, n)*n;
}
class metal : public material {
	color albedo;
	double fuzz;
public:
	metal(const color& a, double fuzz_): albedo(a), fuzz(fuzz_) {}
	bool scatter(const ray& r, const hit_record& hr, color& attenuation, ray& scattered) const override {
		(void)r;
		vec3 dir=reflect(r.dir, hr.normal)+fuzz*random_unit_vector();
		attenuation=albedo;
		scattered=ray(hr.hit_point, dir);
		return (dot(dir, hr.normal)>0);
	}
};
inline vec3 refract(const vec3& uv, const vec3& n, double etai_over_etat) {
	auto cos_theta = fmin(dot(-uv, n), 1.0);
	vec3 r_out_perp =  etai_over_etat * (uv + cos_theta*n);
	vec3 r_out_parallel = -sqrt(fabs(1.0 - r_out_perp.mag_sq())) * n;
	return r_out_perp + r_out_parallel;
}
class glass : public material {
	double n;
public:
	glass(double n_): n(n_) {}
	bool scatter(const ray& r, const hit_record& hr, color& attenuation, ray& scattered) const override {
		attenuation = color(1.0, 1.0, 1.0);
		double refraction_ratio = hr.front_face ? (1.0/n) : n;
		
		vec3 unit_direction = unit_vector(r.direction());
		double cos_theta = fmin(dot(-unit_direction, hr.normal), 1.0);
		double sin_theta = sqrt(1.0 - cos_theta*cos_theta);
		
		bool cannot_refract = refraction_ratio * sin_theta > 1.0;
		vec3 direction;
		
		if (cannot_refract || reflectance(cos_theta, refraction_ratio) > random_double())
			direction = reflect(unit_direction, hr.normal);
		else
			direction = refract(unit_direction, hr.normal, refraction_ratio);
		
		scattered = ray(hr.hit_point, direction);
		return true;
	}
	static double reflectance(double cosine, double ref_idx) {
		auto r0 = (1-ref_idx) / (1+ref_idx);
		r0 = r0*r0;
		return r0 + (1-r0)*pow((1 - cosine),5);
	}
};

#endif
