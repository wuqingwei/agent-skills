# Simple project, executable target, flat layout

Covers a simple Qt 5 project, producing a runnable application binary and organising a
flat source tree.

## Simple project layout

A minimal Qt Quick app needs almost no structure.
Qt's getting-started shows a single-directory project:

```
MyApp/
  CMakeLists.txt
  main.cpp
  main.qml
  qml.qrc
```

For projects with multiple targets (an app + a library, an app + tests, multiple QML modules),
see `references/modular-architecture.md`.
Default to the flat layout above until you actually need the extra structure.

## CMakeLists.txt template for a simple Qt Quick app

The minimum a fresh Qt 5 Quick app should emit. Adapt the project name, Qt version,
and component list to the actual request, never include components the user did not ask for.

```cmake
cmake_minimum_required(VERSION 3.5)

project(MyProject
    VERSION 0.1.0
    LANGUAGES CXX
)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Qt 5 has no qt_standard_project_setup(): set the AUTO switches yourself.
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_INCLUDE_CURRENT_DIR ON)

find_package(Qt5 5.15 REQUIRED COMPONENTS Quick)

add_executable(myapp
    main.cpp
    qml.qrc   # AUTORCC compiles this into the binary
)

target_link_libraries(myapp PRIVATE Qt5::Quick)
```

Notes:

- `cmake_minimum_required(VERSION 3.5)` is a safe floor for Qt 5 projects.
  Use a higher value if the project's toolchain requires it, but do not
  require a newer CMake than the code needs.
- `set(CMAKE_CXX_STANDARD 11)` — Qt 5.12+ requires C++11. Use 14 or 17 only
  when the codebase actually needs it; do not force a higher standard on an
  existing C++11 codebase.
- `CMAKE_AUTOMOC ON` runs `moc` over sources with `Q_OBJECT`/`Q_GADGET`.
  `CMAKE_AUTORCC ON` compiles `.qrc` files listed in the target sources.
  `CMAKE_INCLUDE_CURRENT_DIR ON` makes the generated `ui_*.h` / `moc_*.cpp`
  output resolvable from the same directory.
- There is **no** `qt_standard_project_setup()`, **no** `qt_add_executable()`
  and **no** `qt_add_qml_module()` in Qt 5 — those are Qt 6 API.
- For a Widgets app, use `find_package(Qt5 5.15 REQUIRED COMPONENTS Widgets)`,
  link `Qt5::Widgets`, and add `WIN32` (Windows GUI subsystem) to
  `add_executable` as usual.
- A QML module's URI name is recommended to not clash with a target executable name because of
  case-insensitive file systems.

## main.qml and qml.qrc

Qt 5 has no QML module build step: QML files are plain files in the
resource system (or on disk). Keep the resource path simple and
mirror it in the C++ load call:

```xml
<!DOCTYPE RCC>
<RCC version="1.0">
    <qresource prefix="/">
        <file>main.qml</file>
    </qresource>
</RCC>
```

Do not generate hand-written `moc_*.cpp`, `ui_*.h`, or `qrc_*.cpp` entries —
AUTOMOC/AUTORCC produce and compile them for you.

## main.cpp template (Qt Quick application)

```cpp
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QUrl>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    QQmlApplicationEngine engine;
    engine.load(QUrl(QStringLiteral("qrc:/main.qml")));
    if (engine.rootObjects().isEmpty())
        return -1;

    return app.exec();
}
```

Notes:

- `engine.load(QUrl("qrc:/main.qml"))` — the URL must match the
  `<qresource prefix="/">` and `<file>` path exactly. A mismatch produces
  the silent-ish `QQmlApplicationEngine failed to load component` warning
  and an empty `rootObjects()`.
- There is no `engine.loadFromModule()` in Qt 5 (that is Qt 6.5+ API).
- Register any C++ types **before** `engine.load(...)` — see
  `references/qml-integration.md`.
- `QQmlApplicationEngine` does not auto-create a root window.
  The loaded type (`main.qml` here) must be a `Window` or `ApplicationWindow`,
  visual Qt Quick items must be placed inside one.
  Loading a plain `Item` or `Rectangle` produces a running app with no visible UI.

Do not generate a `qmake` `.pro` file and do not emit instructions for `qmake -r`.
If the user asks for both build systems, pick one and ask which they prefer.
Supporting both in one commit is almost never what they want.

## When to grow the structure

When a project grows past a single target - adding a library, a plugin, tests,
or multiple QML modules — that's when subdirectories earn their keep.
See `references/modular-architecture.md` for the `add_subdirectory` patterns
and `references/qml-integration.md` for organising QML modules.
