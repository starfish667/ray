@echo off
setlocal

set "GXX=g++"
where g++ >nul 2>nul
if errorlevel 1 set "GXX=C:\Program Files\RedPanda-Cpp\mingw64\bin\g++.exe"

"%GXX%" -std=c++17 -Wall -Wextra -pedantic main.cc -static -static-libgcc -static-libstdc++ -lgdi32 -luser32 -o ray.exe
if errorlevel 1 (
	echo Build failed.
	exit /b 1
)

echo Built ray.exe
