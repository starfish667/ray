#ifndef INTERVAL_H
#define INTERVAL_H
class interval {
public:
	double l, r;
	interval(){}
	interval(double l_, double r_): l(l_), r(r_) {}
	bool contain(double x) {
		return x>=l && x<=r;
	}
	bool surround(double x) {
		return x>l && x<r;
	}
};
#endif
