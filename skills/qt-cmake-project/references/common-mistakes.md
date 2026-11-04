# Common LLM mistakes — pre-flight checklist

This is the bias-correction layer. Mainstream LLMs emit the mistakes below by default when
generating Qt CMake — overwhelmingly because the model was trained on Qt 6 material and
applies it to Qt 5 projects. Before returning the final output, check the draft against
every item here.

Each entry has the wrong pattern, the right pattern, and the underlying reason.
Knowing the reason matters. It lets the agent generalise to cases this list does not enumerate.

## 1. Qt 6 commands in a Qt 5 project

```cmake
# WRONG — none of these exist in Qt 5
qt_standard_project_setup(REQUIRES 5.15)
qt_add_executable(myapp main.cpp)
qt_add_qml_module(myapp URI MyModule QML_FILES Main.qml)
qt_add_resources(myapp "res" FILES logo.png)
```

```cmake
# RIGHT
find_package(Qt5 5.15 REQUIRED COMPONENTS Quick)
add_executable(myapp main.cpp qml.qrc)   # .qrc + CMAKE_AUTORCC ON
target_link_libraries(myapp PRIVATE Qt5::Quick)
# explicit rcc handling (Qt 5 variable form — note: NOT target-based):
qt5_add_resources(APP_RESOURCES images.qrc)
add_executable(myapp main.cpp ${APP_RESOURCES})
```

**Why:** Qt 5 has no `qt_standard_project_setup()`, no `qt_add_executable()`,
no `qt_add_library()`, no `qt_add_qml_module()`, no `qt_add_translations()`,
and no unprefixed `qt_*` command form. The `qt5_*`-prefixed macros
(`qt5_add_resources`, `qt5_add_plugin`, `qt5_add_translation`, …) are the
correct Qt 5 spelling. This is the inverse of the Qt 6 convention — do not
"modernise" a Qt 5 project by dropping the `5`.

**Signature trap:** `qt5_add_resources` in Qt 5 is **variable-based** —
`qt5_add_resources(<VAR> <.qrc file> ...)` generates source files into
`<VAR>`, which you then add to the target's sources. The Qt 6 form
`qt_add_resources(target "name" PREFIX ... FILES ...)` (target-based,
FILES without a `.qrc`) does **not** exist in Qt 5. Likewise translations:
Qt 5 has `qt5_create_translation` / `qt5_add_translation` (both
variable-based); `qt_add_translations` is Qt 6 only.

## 2. Missing AUTOMOC / AUTOUIC / AUTORCC

```cmake
# WRONG — link errors: "undefined reference to vtable for MyClass"
find_package(Qt5 5.15 REQUIRED COMPONENTS Quick)
add_executable(myapp main.cpp myclass.cpp)
```

```cmake
# RIGHT
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTOUIC ON)   # only when .ui files exist
set(CMAKE_AUTORCC ON)   # only when .qrc files exist
set(CMAKE_INCLUDE_CURRENT_DIR ON)
find_package(Qt5 5.15 REQUIRED COMPONENTS Quick)
add_executable(myapp main.cpp myclass.cpp)
```

**Why:** Qt 5 has no `qt_standard_project_setup()` to do this. Every class
with `Q_OBJECT` needs `moc` output; forgetting `CMAKE_AUTOMOC` is the single
most common cause of "undefined reference to vtable" in fresh Qt 5 builds.

## 3. Manually listing generated outputs

```cmake
# WRONG
add_executable(myapp main.cpp moc_myclass.cpp qrc_qml.cpp ui_mainwindow.h)
```

```cmake
# RIGHT
add_executable(myapp main.cpp myclass.cpp mainwindow.ui qml.qrc)
```

**Why:** with the AUTO switches on, CMake generates and compiles `moc_*`,
`qrc_*` and compiles `ui_*` into users automatically. Listing generated
names either fails at configure time or double-compiles them.

## 4. `find_package(Qt5)` with no version and no components

```cmake
# WRONG
find_package(Qt5 REQUIRED)
```

```cmake
# RIGHT
find_package(Qt5 5.15 REQUIRED COMPONENTS Quick Qml Gui)
```

**Why:** the bare form hides which modules the project really uses and
accepts any Qt 5.x — even ones older than the API the code assumes.

## 5. Linking module names instead of imported targets

```cmake
# WRONG — deprecated or fragile forms
qt5_use_modules(myapp Quick)
target_link_libraries(myapp PRIVATE ${Qt5Quick_LIBRARIES})
include_directories(${Qt5Quick_INCLUDE_DIRS})
```

```cmake
# RIGHT
target_link_libraries(myapp PRIVATE Qt5::Quick)
```

**Why:** `qt5_use_modules()` is deprecated. The variable forms work but do
not carry usage requirements; the imported `Qt5::*` targets propagate
include directories and compile definitions automatically.

## 6. `QT += quick` or other `.pro` syntax

```cmake
# WRONG (qmake leftover pasted into CMake)
set(QT += quick)
CONFIG += c++11
RESOURCES += qml.qrc
```

**Why:** CMake is not qmake. Never emit `QT +=`, `CONFIG +=`, `HEADERS =`,
`SOURCES =`, or `.pro` file content. Do not generate a `.pro` file even if
the user asks "for both build systems" — ask which one they want instead.

## 7. Loading QML with a Qt 6-style resource path

```cpp
// WRONG — Qt 6 layout; silently fails to load in Qt 5
engine.loadFromModule("MyModule", "Main");
engine.load(QUrl(QStringLiteral("qrc:/qt/qml/MyModule/Main.qml")));
```

```cpp
// RIGHT — path must match the .qrc prefix exactly
engine.load(QUrl(QStringLiteral("qrc:/MyModule/Main.qml")));
```

**Why:** Qt 5 has no `loadFromModule()` and no implicit `qrc:/qt/qml/`
prefix. A `qrc` URL is exactly `<prefix>/<file-path-as-written>` from the
`.qrc` file. A mismatch only prints
`QQmlApplicationEngine failed to load component` and leaves
`rootObjects()` empty.

## 8. Registering C++ types after loading the engine

```cpp
// WRONG — QML reports "MyClass is not a type"
QQmlApplicationEngine engine;
engine.load(QUrl(QStringLiteral("qrc:/main.qml")));
qmlRegisterType<MyClass>("MyModule", 1, 0, "MyClass");
```

```cpp
// RIGHT — register before load
qmlRegisterType<MyClass>("MyModule", 1, 0, "MyClass");
QQmlApplicationEngine engine;
engine.load(QUrl(QStringLiteral("qrc:/main.qml")));
```

**Why:** registration populates the QML type registry; anything the engine
loads before the type is registered cannot resolve it.

## 9. QML imports without a version

```qml
// WRONG in Qt 5 — "module \"QtQuick\" is not installed"
import QtQuick
import MyModule
```

```qml
// RIGHT
import QtQuick 2.15
import MyModule 1.0
```

**Why:** versionless imports are a Qt 6 relaxation. Every Qt 5 module
import needs an explicit major.minor version.

## 10. Qt 6-only QML/C++ API in source files

`pragma ComponentBehavior`, `import QtQuick.Controls.Basic`,
`MultiEffect` (QtQuick.Effects), `QML_ELEMENT`/`QML_NAMED_ELEMENT`,
`Q_PROPERTY(... BINDABLE ...)`, `QHttpHeaders` — all are Qt 6isms.
The Qt 5 equivalents: plain `import QtQuick.Controls 2.15` + explicit
properties, `QtGraphicalEffects`, `qmlRegisterType`, and the Qt 5 API
surface. Check the Qt 5 docs when unsure whether an API exists in 5.15.

## 11. Wrong `target_link_libraries` visibility

```cmake
# WRONG — exposes Quick to consumers of myapp_core unnecessarily
target_link_libraries(myapp_core PUBLIC Qt5::Quick)
```

```cmake
# RIGHT — Quick is an implementation detail of myapp_core
target_link_libraries(myapp_core PRIVATE Qt5::Quick)
```

**Why:** use `PRIVATE` unless the module's public headers include the
linked module's headers; then `PUBLIC`.

## 12. Hardcoded Qt paths

```cmake
# WRONG
include_directories("C:/Qt/5.15.2/mingw81_64/include")
link_directories("/usr/lib/x86_64-linux-gnu/qt5/lib")
```

```cmake
# RIGHT — let find_package resolve everything
find_package(Qt5 5.15 REQUIRED COMPONENTS Quick)
# and on the command line:
#   cmake -B build -DCMAKE_PREFIX_PATH=/path/to/Qt/5.15.2/gcc_64
```

**Why:** hardcoded paths break on every other machine, OS, and compiler.
`find_package` plus `CMAKE_PREFIX_PATH` is the only portable mechanism.

## 13. Version mismatch between declared and used Qt

If the project calls Qt 5.15-only API (`QRandomGenerator::global()`,
`createTemporaryObject()` in tests, `required property` in QML), the
`find_package` minimum must be 5.15 — not 5.9. Set the minimum to the
oldest version whose API the code actually uses.

## 14. Generating a `.pro` file alongside `CMakeLists.txt`

Same rule as always: one build system per project. If the user asks for
both, ask which one they want and generate only that.
