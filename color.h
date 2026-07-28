#ifndef COLOR_H
#define COLOR_H
#include"vec3.h"
typedef vec3 color;
double linear_to_gamma(double lc) {
	if(lc>0)return std::sqrt(lc);
	return 0;
}
#endif
