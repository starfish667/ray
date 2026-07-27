# Ray

A small C++ ray tracing playground with a Win32 preview window and free-fly camera controls.

## Current Features

- Win32 window output using a CPU color buffer.
- WASD movement, Space/Shift vertical movement, Esc to quit.
- FPS-style mouse look with hidden and recentered cursor.
- Camera basis vectors: `forward`, `right`, and `up`.
- Basic `ray`, `hittable`, `hittable_list`, `sphere`, and `interval` types.
- Simple hit visualization: rays that hit an object are colored blue.

## Build

Run from this directory:

```bat
build.bat
```

The build script uses MinGW g++ and links statically:

```bat
g++ -std=c++17 -Wall -Wextra -pedantic main.cc -static -static-libgcc -static-libstdc++ -lgdi32 -luser32 -o ray.exe
```

## Controls

- `W/S`: move forward/back along the camera forward axis.
- `A/D`: move left/right along the camera right axis.
- `Space/Shift`: move up/down in world space.
- Mouse: update yaw and pitch.
- `Esc`: quit.

## Coordinate System

- `+X`: right
- `+Y`: up
- `-Z`: initial forward direction

Camera angles are stored in radians.
