@echo off
setlocal

where nvcc >nul 2>nul
if errorlevel 1 (
    echo nvcc was not found. Install CUDA Toolkit or add it to PATH.
    exit /b 1
)

where cl.exe >nul 2>nul
if errorlevel 1 (
    if exist "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
)

where cl.exe >nul 2>nul
if errorlevel 1 (
    if exist "C:\Program Files\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" call "C:\Program Files\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
)

where cl.exe >nul 2>nul
if errorlevel 1 (
    echo cl.exe was not found.
    echo CUDA on Windows usually needs Visual Studio or Visual Studio Build Tools with C++ support.
    exit /b 1
)

nvcc -std=c++17 -O2 realtime.cu -o ray_cuda_realtime.exe user32.lib gdi32.lib
if errorlevel 1 (
    echo Build failed.
    exit /b 1
)

ray_cuda_realtime.exe
