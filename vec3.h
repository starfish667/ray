#ifndef VEC3_H
#define VEC3_H
#include"rtweekend.h"
#include<cmath>
#include<iostream>
class vec3 {
private:
	double e[3];
public:
	vec3(){}
	vec3(double x, double y, double z) {
		e[0]=x, e[1]=y, e[2]=z;
	}
	double x() const {return e[0];};
	double y() const {return e[1];};
	double z() const {return e[2];};
	double& operator[](int i) {return e[i];}
	double operator[](int i) const {return e[i];}
	vec3 operator-() const{
		return vec3(-e[0], -e[1], -e[2]);
	}
	vec3& operator+=(const vec3 &b) {
		e[0]+=b.e[0];
		e[1]+=b.e[1];
		e[2]+=b.e[2];
		return (*this);
	}
	vec3& operator-=(const vec3 &b) {
		e[0]-=b.e[0];
		e[1]-=b.e[1];
		e[2]-=b.e[2];
		return (*this);
	}
	vec3& operator*=(const vec3 &b) {
		e[0]*=b.e[0];
		e[1]*=b.e[1];
		e[2]*=b.e[2];
		return (*this);
	}
	vec3& operator*=(double x) {
		e[0]*=x;
		e[1]*=x;
		e[2]*=x;
		return (*this);
	}
	vec3& operator/=(double x) {
		e[0]/=x;
		e[1]/=x;
		e[2]/=x;
		return (*this);
	}
	double mag() const {
		return std::sqrt(e[0]*e[0]+e[1]*e[1]+e[2]*e[2]);
	}
	double mag_sq() const {
		return e[0]*e[0]+e[1]*e[1]+e[2]*e[2];
	}
	vec3& normalize() {
		double mag=(this->mag());
		return (*this)/=mag;
	}
	static vec3 random() {
		return vec3(random_double(), random_double(), random_double());
	}
	static vec3 random(double min, double max) {
		return vec3(random_double(min, max), random_double(min, max), random_double(min, max));
	}
	bool near_zero() const {
		double eps=1e-8;
		return (fabs(e[0])<eps) && (fabs(e[1])<eps) && (fabs(e[2])<eps);
	}
};
std::ostream& operator<<(std::ostream& out, const vec3& v) {
	return out<<v.x()<<' '<<v.y()<<' '<<v.z();
}
vec3 operator+(const vec3& a, const vec3& b) {
	return vec3(a.x()+b.x(), a.y()+b.y(), a.z()+b.z());
}
vec3 operator-(const vec3& a, const vec3& b) {
	return vec3(a.x()-b.x(), a.y()-b.y(), a.z()-b.z());
}
vec3 operator*(const vec3& a, const vec3& b) {
	return vec3(a.x()*b.x(), a.y()*b.y(), a.z()*b.z());
}
vec3 operator*(const vec3& a, double x) {
	return vec3(a.x()*x, a.y()*x, a.z()*x);
}
vec3 operator*(double x, const vec3& a) {
	return vec3(a.x()*x, a.y()*x, a.z()*x);
}
vec3 operator/(const vec3& a, double x) {
	return vec3(a.x()/x, a.y()/x, a.z()/x);
}
double dot(const vec3& a, const vec3& b) {
	return a.x()*b.x()+a.y()*b.y()+a.z()*b.z();
}
vec3 cross(const vec3& e, const vec3& f) {
	return vec3(e[1]*f[2]-e[2]*f[1], 
				e[2]*f[0]-e[0]*f[2], 
				e[0]*f[1]-e[1]*f[0]);
}
vec3 random_in_unit_sphere() {
	double r=random_double();
	double yaw=random_double(0, 2*pi);
	double pitch=random_double(-pi/2, pi/2);
	using std::sin, std::cos;
	return vec3(r*cos(pitch)*cos(yaw), r*cos(pitch)*sin(yaw), r*sin(pitch));
}
vec3 unit_vector(const vec3& v) {
	return v/v.mag();
}
vec3 random_unit_vector() {
	return unit_vector(vec3::random(-1, 1));
}
vec3 random_on_hemisphere(const vec3& normal) {
	vec3 v=random_unit_vector();
	if(dot(v, normal))return v;
	return -v;
}
typedef vec3 point3;
#endif
