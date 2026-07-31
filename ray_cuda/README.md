# ray_cuda

A tiny CUDA ray tracing demo for comparing the CPU style with the GPU style.

Key differences:

- CPU code often uses `virtual hittable`, `shared_ptr`, and recursive `ray_color()`.
- GPU code works better with flat arrays: `Sphere[]`, `Plane[]`, and `Material[]`.
- Each CUDA thread renders one pixel.
- Recursive path tracing is rewritten as a `for depth` loop.

Build and run:

```bat
build.bat
```

`build.bat` builds and runs the realtime Win32 window:

- WASD: move
- Space / Shift: up / down
- Mouse: look around
- Esc: quit

The realtime renderer has two modes. While moving, it uses a deterministic `preview` mode with no random path scattering, so the image is more stable. When the camera is still, it switches back to `trace` mode; the `accum` value in the window title rises and the image becomes cleaner.

The still-image version is kept in `main.cu`:

```bat
build_image.bat
```

The still-image program writes:

```text
cuda_output.ppm
```

On Windows, CUDA usually needs Visual Studio or Visual Studio Build Tools with C++ support. This `build.bat` tries to load common `vcvars64.bat` paths automatically.
