# Configure & Build Project

Covers trying out the project by locating framework and tool requirements,
configuring and building the project.

## Locating Requirements

**Locate cmake and ninja-build** tools so they can be called from command line by using the
commands `cmake` and `ninja`.

**Locate the installed Qt SDK** by determining the host OS first and then searching for typical
locations of the framework on that specific OS.
Keep in mind that in case of development environments, a local Qt installation can reside in the
user's folder instead of being installed on the system.
The goal is to find the framework's installation folder which contains the toolchain commands in
the `bin` folder and under it, locate `bin/qmake` (or a `Qt5Config.cmake` under
`lib/cmake/Qt5`). Use the found path as `CMAKE_PREFIX_PATH` below.
If not found or unsure, ask the user.

Typical Qt 5 installation roots:

| OS | Typical roots |
|----|---------------|
| Linux | `/home/*/Qt5.15.2/5.15.2/gcc_64`, `/opt/Qt/5.15.2/gcc_64`, `/usr/lib/qt5` (distro packages) |
| macOS | `/Users/*/Qt5.15.2/5.15.2/clang_64`, `/opt/Qt/5.15.2/clang_64` |
| Windows | `C:\Qt\5.15.2\msvc2019_64`, `C:\Qt\5.15.2\mingw81_64`, `%USERPROFILE%\Qt5.15.2\...` |

## Configuring the project for the first time

We prefer doing out-of-tree builds where the build folder is separate outside of the project folder.
In case of the sample project located in `MyApp` folder, on Unix-like platforms this looks like:

```bash
cmake -S MyApp -B MyApp-build -G Ninja \
      -DCMAKE_BUILD_TYPE=RelWithDebInfo \
      -DCMAKE_PREFIX_PATH="/path/to/Qt/5.15.2/gcc_64"
cmake --build MyApp-build
```

On Windows with multiple Visual Studio versions installed, add
`-G "Visual Studio 16 2019"` (or the matching generator) to the first command.

If `find_package(Qt5 ...)` fails, the usual causes are:

- `CMAKE_PREFIX_PATH` not pointing at the Qt 5 kit root (the folder that
  contains `bin/qmake`), or
- the requested component not installed (check the `lib/cmake/Qt5*`
  folders of the kit).

## Building from the command line

```bash
cmake --build MyApp-build
# with Ninja you can also run ninja directly:
#   cd MyApp-build && ninja
```

## Running the application

Make sure the Qt runtime libraries are findable:

- **Linux/macOS** with an installer-based Qt: run the binary with the kit's
  `bin` on `LD_LIBRARY_PATH`/`DYLD_LIBRARY_PATH`, or use
  `qmake -query QT_INSTALL_BINS` to locate the kit. `windeployqt`/`macdeployqt`
  equivalents: `linuxdeployqt` or manual `rpath`.
- **Windows**: run `windeployqt <binary>.exe` once to collect the Qt DLLs
  and plugins next to the binary, or add `<Qt>\bin` to `PATH`.
