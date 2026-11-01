# Static resources — images, icons, fonts, translations

Covers adding static resources (images, icons, fonts, JSON, translations)
to a Qt 5 CMake project. Qt 5 has one mechanism: the Qt resource system
(`.qrc`), plus `qt5_*` helpers for translations.

## Two ways to add a `.qrc`

| Approach | When to use |
|----------|-------------|
| `.qrc` file in target sources + `CMAKE_AUTORCC ON` | The normal case. Hand-written, versioned with the code. |
| `qt5_add_resources(target "name" PREFIX ... FILES ...)` | Generated resources assembled from many files without hand-editing XML. |

Do not do both for the same files — the resource gets compiled twice.

```cmake
set(CMAKE_AUTORCC ON)

add_executable(myapp
    main.cpp
    qml.qrc        # hand-written resource file
)
```

```cmake
# or, generated:
qt5_add_resources(myapp "myapp_images"
    PREFIX "/images"
    FILES
        resources/images/logo.png
        resources/images/background.jpg
)
```

## Resource layout conventions

The `<qresource prefix="/...">` plus the `<file>` path define the runtime
URL `qrc:<prefix>/<file-path>`. Keep prefixes deliberate:

```xml
<!DOCTYPE RCC>
<RCC version="1.0">
    <qresource prefix="/qml">
        <file>main.qml</file>
    </qresource>
    <qresource prefix="/images">
        <file>resources/images/logo.png</file>
    </qresource>
</RCC>
```

- `qrc:/qml/main.qml`, `qrc:/images/resources/images/logo.png`.
- Alias an awkward source layout without moving files:
  `<file alias="logo.png">resources/images/logo.png</file>` →
  `qrc:/images/logo.png`.
- The URL in C++ (`QUrl("qrc:/qml/main.qml")`) and QML
  (`source: "/images/logo.png"` or `qrc:/images/...`) must match exactly —
  there is no `qrc:/qt/qml/` implicit prefix in Qt 5.

## Resources referenced from QML

Images used by QML go into the same binary. From QML:

```qml
Image { source: "qrc:/images/resources/images/logo.png" }
// or, relative to the QML file's own resource directory:
Image { source: "../images/resources/images/logo.png" }
```

Prefer the relative form inside a stable directory tree; prefer absolute
`qrc:/` URLs when files are referenced across directories.

## Resources for C++

C++ accesses resources through the same paths:

```cpp
QFile f(QStringLiteral(":/images/resources/images/logo.png"));  // ":/" == "qrc:///"
QIcon icon(QStringLiteral(":/icons/app-icon.svg"));
```

Note `:/` is the C++ spelling of the resource root.

## Application icon

- **Windows**: a `.rc` file referencing an `.ico`, listed in the target
  sources (CMake compiles it with `enable_language(RC)` implicitly on
  MSVC; MinGW needs `windres`, which CMake invokes for `.rc` sources):

  ```rc
  IDI_ICON1 ICON "app-icon.ico"
  ```

- **macOS**: `.icns` in a bundle — set
  `MACOSX_BUNDLE_ICON_FILE` and add the `.icns` to the sources of a
  `MACOSX_BUNDLE` target.
- **Linux desktop**: install the icon file with `install(FILES ...)` and a
  `.desktop` file — not a compile-time resource.

## Fonts

Fonts load from resources with `QFontDatabase`:

```cpp
// Qt 5: load by file; returns the family id (-1 on failure)
int id = QFontDatabase::addApplicationFont(QStringLiteral(":/fonts/TitilliumWeb-Regular.ttf"));
```

In QML, register the font in C++ before loading the engine, then use
`font.family: "Titillium Web"`. (The QML `FontLoader` also works
per-file: `FontLoader { source: "qrc:/fonts/TitilliumWeb-Regular.ttf" }`.)

## Translations

Qt 5 uses the `qt5_create_translation` / `qt5_add_translation` macros —
there is no `qt_add_translations()`:

```cmake
find_package(Qt5 5.15 REQUIRED COMPONENTS LinguistTools)

set(TS_FILES translations/myapp_de.ts translations/myapp_fr.ts)

# Option A: run lupdate + lrelease together (source-level .ts maintained)
qt5_create_translation(QM_FILES ${CMAKE_SOURCE_DIR} ${TS_FILES}
    OPTIONS -I${CMAKE_SOURCE_DIR}/src)

# Option B: only compile existing .ts files (sources translated elsewhere)
# qt5_add_translation(QM_FILES ${TS_FILES})

add_executable(myapp main.cpp qml.qrc ${QM_FILES})
```

Loading at runtime:

```cpp
QTranslator translator;
if (translator.load(QLocale(), QStringLiteral("myapp"), QStringLiteral("_"),
                    QStringLiteral(":/translations"))) {
    QGuiApplication::installTranslator(&translator);
}
```

## Shaders, JSON, CSV, other data files

Everything that is not compiled goes through `.qrc` (or the filesystem).
For large mutable data prefer the filesystem (via `QStandardPaths`) —
the resource system is read-only and compressed into the binary.

## Hand-written `.qrc`

In Qt 5, hand-written `.qrc` is the primary mechanism, not a legacy form.
Keep it deterministic:

- List files explicitly (no globbing — the `.qrc` format has none).
- Keep the file next to the sources it references, using relative paths.
- One resource file per domain (`qml.qrc`, `images.qrc`, `fonts.qrc`)
  keeps merges cheap.
