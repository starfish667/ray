#ifndef SPHERE_H
#define SPHERE_H
#include<cmath>
#include"hittable.h"
class sphere : public hittable {
private:
	point3 center;
	double radius;
public:
	sphere() {}
	sphere(const point3& center_, double radius_) : center(center_), radius(radius_) {}
	~sphere() = default;
	bool hit(const ray& r, interval t_range, hit_record& hr) override {
		double a=dot(r.dir, r.dir);
		double b=2*dot(r.dir, r.orig-center);
		double c=dot(r.orig-center, r.orig-center)-radius*radius;
		double delta=b*b-4*a*c;
		if(delta<0)return false;
		double sqrt_delta=std::sqrt(delta);
		double t=(-b-sqrt_delta)/2/a;
		if(t_range.contain(t)) {
			hr.hit_point=r.at(t);
			hr.t=t;
			hr.set_normal(r, (hr.hit_point-center)/radius);
			return true;
		}
		t=(-b+sqrt_delta)/2/a;
		if(t_range.contain(t)) {
			hr.hit_point=r.at(t);
			hr.t=t;
			hr.set_normal(r, (hr.hit_point-center)/radius);
			return true;
		}
		return false;
	}
};
#endif
