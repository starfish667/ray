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
class metal : public material {
	color albedo;
	double fuzz;
public:
	metal(const color& a, double fuzz_): albedo(a), fuzz(fuzz_) {}
	bool scatter(const ray& r, const hit_record& hr, color& attenuation, ray& scattered) const override {
		(void)r;
		vec3 dir=r.dir-2*hr.normal*dot(hr.normal, r.dir)+fuzz*random_unit_vector();
		attenuation=albedo;
		scattered=ray(hr.hit_point, dir);
		return (dot(dir, hr.normal)>0);
	}
};
#endif
