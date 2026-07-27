#ifndef HITTABLE_LIST_H
#define HITTABLE_LIST_H
#include "hittable.h"
#include <memory>
#include <vector>
using std::shared_ptr;
using std::make_shared;
class hittable_list : public hittable {
public:
	std::vector<shared_ptr<hittable>>objects;
	hittable_list() {}
	hittable_list(shared_ptr<hittable>object) {add(object);}
	void clear() {objects.clear();}
	void add(shared_ptr<hittable>object) {objects.push_back(object);}
	virtual bool hit(const ray& r, interval t_range, hit_record& hr) override {
		hit_record tmp_hit;
		bool hit_anything=false;
		double closest_ima=t_range.r;
		for(auto object : objects) {
			if(object->hit(r, interval(t_range.l, closest_ima), tmp_hit)) {
				hit_anything=true;
				closest_ima=tmp_hit.t;
				hr=tmp_hit;
			}
		}
		return hit_anything;
	}
};
#endif
