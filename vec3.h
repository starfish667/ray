#ifndef VEC3_H
#define VEC3_H
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
	double mag() {
		return std::sqrt(e[0]*e[0]+e[1]*e[1]+e[2]*e[2]);
	}
	vec3& normalize() {
		double mag=(this->mag());
		return (*this)/=mag;
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
typedef vec3 point3;
#endif
