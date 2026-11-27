# Subdirectories, Qt libraries, plugins

Covers a complex project across `add_subdirectory()` boundaries, with special or multiple targets,
including libraries, Qt plugins.

## When to add a subdirectory

Use `add_subdirectory()` when one or more of these is true:

- The directory produces its own target (executable, library, plugin).
- The directory has a meaningfully different dependency set from its parent
  (e.g. only the GUI subdir needs `Qt5::Quick`).
- The directory is reusable across projects.

Do **not** add a subdirectory just to group source files — for that,
use folders and `target_sources(... PRIVATE …)` from the parent's `CMakeLists.txt`.

## Subdirectory pattern

Top-level `CMakeLists.txt` after the project setup block:

```cmake
add_subdirectory(src/core)          # internal library
add_subdirectory(src/widgets)       # Qt library exposing widgets
add_subdirectory(src/app)           # the executable lives here
add_subdirectory(src/plugins/csvio) # Qt plugin
```

Each subdirectory's `CMakeLists.txt` declares its own target and linkages. The parent never sets
sources for a child target — that is the child's responsibility. This keeps targets self-contained
and lets you move directories without rewriting parent files.

## Qt library (`add_library`)

Qt 5 has no `qt_add_library()` — use plain CMake `add_library()`.
AUTOMOC is enabled project-wide (top-level `set(CMAKE_AUTOMOC ON)`), so
`Q_OBJECT` classes in the library are handled automatically.

`src/core/CMakeLists.txt`:

```cmake
add_library(myapp_core STATIC
    notebook.cpp
    notebook.h
    notestore.cpp
    notestore.h
)

target_include_directories(myapp_core
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/include
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}
)

target_link_libraries(myapp_core
    PUBLIC
        Qt5::Core         # exposed in public headers
    PRIVATE
        Qt5::Sql          # used only in .cpp
)

add_library(MyApp::core ALIAS myapp_core)
```

### Shared library

For a shared library, add versioning and export handling:

```cmake
add_library(myapp_core SHARED
    notebook.cpp
    notebook.h
)

set_target_properties(myapp_core PROPERTIES
    VERSION   ${PROJECT_VERSION}    # libname.so.<version>
    SOVERSION ${PROJECT_VERSION_MAJOR}   # libname.so.<soversion>
)

target_compile_definitions(myapp_core PRIVATE MYAPP_CORE_LIBRARY)
```

- Headers use an export macro:

  ```cpp
  #if defined(_WIN32)
  #  define MYAPP_CORE_EXPORT __declspec(dllexport/dllimport)  // via MYAPP_CORE_LIBRARY
  #else
  #  define MYAPP_CORE_EXPORT __attribute__((visibility("default")))
  #endif
  ```

  or generate it with `include(GenerateExportHeader)` +
  `generate_export_header(myapp_core)`.
- Namespaced alias — consumers link `MyApp::core`, not bare `myapp_core`.
- soname versioning — prevents ABI-mismatch crashes when multiple
  versions of this library exist on the system.

### Public-header convention

- Installable libraries keep public headers in `include/` and set that
  directory `PUBLIC` in `target_include_directories`.
- `Q_OBJECT` classes in a **shared** library must have their `moc` output
  compiled into that library — AUTOMOC handles this as long as the header
  is listed in the target sources (or is included by a listed source and
  AUTOMOC can find it; listing the header explicitly is the robust form).

### Linking the library from the executable

```cmake
add_executable(myapp main.cpp)
target_link_libraries(myapp
    PRIVATE
        MyApp::core
        Qt5::Quick
)
```

## Qt plugin (`add_library(... MODULE ...)`)

Qt 5 has no `qt_add_plugin()` or `qt5_add_plugin()` macro — create a plugin
with standard CMake `add_library(... MODULE ...)` (for dynamic plugins) or
`add_library(... STATIC ...)` (for static plugins), with `Q_PLUGIN_METADATA`
in the plugin class header and `AUTOMOC` enabled:

```cmake
add_library(csvio MODULE
    csvio.cpp
    csvio.h
)

target_link_libraries(csvio
    PUBLIC
        MyApp::core
        Qt5::Core
)
```

### Static vs. dynamic plugins

- **Dynamic** (`MODULE`): the plugin is a shared object loaded at runtime
  from the `plugins/` directory of the Qt installation or `QT_PLUGIN_PATH`
  via `QPluginLoader`.
- **Static** (`STATIC`): declare `add_library(csvio STATIC ...)` with
  `target_compile_definitions(csvio PRIVATE QT_STATICPLUGIN)`, link `csvio`
  into the executable (`target_link_libraries(myapp PRIVATE csvio)`), and
  import it with `Q_IMPORT_PLUGIN(CsvIoPlugin)` in a `.cpp` of the
  executable. For Qt's own static plugins, CMake also provides
  `qt5_import_plugins(myapp INCLUDE ...)` (available since Qt 5.14).

### QML extension plugin

For a QML extension plugin (a plugin that registers QML types), inherit
`QQmlExtensionPlugin`, declare `Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)`,
and call `qmlRegisterType` inside `registerTypes(const char *uri)`.
The plugin must live in a directory matching its URI and ship a `qmldir`
with a `plugin` line — see `references/qml-integration.md`.

## Dependency direction

- Executables depend on libraries; libraries never depend on executables.
- Low-level libraries must not link GUI modules. If `core` needs a signal,
  it needs `Qt5::Core` only.
- A plugin links its host library's interface, never the host executable.

## Naming conventions

- Target names: lowercase with underscores (`myapp_core`); alias targets
  namespaced (`MyApp::core`).
- Keep one target per directory — the directory name usually matches the
  target name.
- Plugins: name the target after the plugin class's module
  (`csvio` → `libcsvio.so`).
