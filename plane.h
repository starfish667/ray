#ifndef PLANE_H
#define PLANE_H
#include "hittable.h"
#include <cmath>
class plane : public hittable {
public:
	vec3 normal;
	double b;
	std::shared_ptr<material>mat;
	plane()
		: normal(0.0, 1.0, 0.0),
		  b(0.0) {}

	plane(const vec3& N, double B, std::shared_ptr<material>mat_)
		: normal(N),
		  b(B), mat(mat_) {
		double len = normal.mag();
		if (len == 0.0) {
			normal = vec3(0.0, 1.0, 0.0);
			b = 0.0;
			return;
		}
		normal /= len;
		b /= len;
	}

	bool hit(const ray& r, interval t_range, hit_record& hr) override {
		double denom = dot(r.dir, normal);
		if(std::fabs(denom)<1e-8)return false;
		double t=(-dot(normal, r.orig)-b)/denom;
		if(t_range.contain(t)) {
			hr.hit_point=r.at(t);
			hr.t=t;
			hr.set_normal(r, normal);
			hr.mat=mat;
			return true;
		}
		return false;
	}
};
#endif
