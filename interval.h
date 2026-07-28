#ifndef INTERVAL_H
#define INTERVAL_H
#include "rtweekend.h"
class interval {
public:
	double l, r;
	interval(): l(infinity), r(-infinity) {}
	interval(double l_, double r_): l(l_), r(r_) {}
	bool contain(double x) {
		return x>=l && x<=r;
	}
	bool surround(double x) {
		return x>l && x<r;
	}
	double clamp(double x) {
		if(x<l)x=l;
		if(x>r)x=r;
		return x;
	}
	static const interval empty, universe;
};
const interval interval::empty    = interval(+infinity, -infinity);
const interval interval::universe = interval(-infinity, +infinity);
#endif
