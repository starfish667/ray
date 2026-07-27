#ifndef HITTABLE_H
#define HITTABLE_H
#include"ray.h"
#include"interval.h"
class hit_record {
public:
	point3 hit_point;
	double t;
	vec3 normal;
	bool front_face;
	void set_normal(const ray& r, const vec3& outward_normal) {
		if(dot(r.direction(), outward_normal)<0)
			front_face=true, normal=outward_normal;
		else front_face=false, normal=-outward_normal;
	}
};
class hittable {
public:
	virtual bool hit(const ray& r, interval t_range, hit_record& hr) = 0;
	virtual ~hittable() = default;
};
#endif
