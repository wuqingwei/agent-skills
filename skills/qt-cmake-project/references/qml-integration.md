# QML files, modules, reusable controls, C++/QML integration

Covers adding `.qml` files to a Qt 5 project, organising reusable QML into
modules, exposing C++ types to QML, and loading QML from C++.

Qt 5 has **no** `qt_add_qml_module()`: there is no build-time QML module
compilation, no generated `qmldir`, and no automatic type registration.
Everything below is done by hand — resource files, `qmldir` files, and
`qmlRegister*` calls. That is the Qt 5 way; do not emit Qt 6 module CMake.

## Two ways QML files ship in Qt 5

| Mechanism | When to use |
|-----------|-------------|
| `.qrc` resource | The normal case: QML embedded in the binary, loaded via `qrc:/` URLs. |
| Filesystem path | Tools, QML-heavy prototypes, or plugins loaded from disk (`engine.addImportPath(...)`). |

Prefer `.qrc` for applications. The resource path must match the URL used
in `engine.load()` exactly.

## Adding a QML file to an existing project

1. Create the file next to the others.
2. Add it to the `.qrc`:

   ```xml
   <qresource prefix="/">
       <file>main.qml</file>
       <file>AboutDialog.qml</file>
   </qresource>
   ```

3. The CMake target already lists the `.qrc` (`add_executable(myapp ...
   qml.qrc)` with `CMAKE_AUTORCC ON`) — no CMake change needed.
4. Reference it by resource URL: `qrc:/AboutDialog.qml` — or, from another
   QML file in the same prefix, by relative path (`"AboutDialog.qml"`)
   or by name if it is in the same directory (implicit same-directory
   lookup works for files on the resource system too).

## Organising reusable QML into a module

For a set of controls shared across screens (or projects), use a QML
module: a directory with a `qmldir` file.

```
qml/
  MyControls/
    qmldir
    Button.qml
    Card.qml
```

`qml/MyControls/qmldir`:

```
module MyControls
Button 1.0 Button.qml
Card 1.0 Card.qml
```

Then either:

- add the directory to the resource system and call
  `engine.addImportPath("qrc:/")` (the directory must resolve so that
  `<importPath>/MyControls/qmldir` exists), or
- ship it on disk and `engine.addImportPath("qml/")`.

QML files import it with the version: `import MyControls 1.0`.

Module URI should match the directory path (dots become subdirectories):
`MyApp.Controls` lives in `qml/MyApp/Controls/`. Mismatches produce
"module not found" at runtime.

### Version rule

Qt 5 imports always carry versions — both module imports
(`import QtQuick 2.15`) and imports of your own modules
(`import MyControls 1.0`). The version in the `import` must be covered by
the `qmldir` entries (or a later minor of the same major).

## Singletons

1. `pragma Singleton` at the top of the QML file.
2. A `singleton` line in the `qmldir`:

   ```
   module MyControls
   singleton Theme 1.0 Theme.qml
   ```

3. Access as `Theme.color` after `import MyControls 1.0`.

Both the pragma and the qmldir line are required — the pragma alone is
not enough in Qt 5. There is no `set_source_files_properties(...
QT_QML_SINGLETON_TYPE TRUE)` (that is the Qt 6 CMake mechanism).

## Exposing C++ types to QML

Registration happens in C++, before the engine loads anything:

```cpp
#include <QtQml>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    qmlRegisterType<Notebook>("MyApp.Models", 1, 0, "Notebook");
    qmlRegisterUncreatableType<NoteStore>("MyApp.Models", 1, 0,
        "NoteStore", QStringLiteral("Use the shared instance"));
    qmlRegisterSingletonType<Theme>("MyApp.Theme", 1, 0, "Theme",
        [](QQmlEngine *engine, QJSEngine *jsEngine) -> QObject * {
            Q_UNUSED(engine)
            return new Theme(jsEngine);
        });

    QQmlApplicationEngine engine;
    engine.load(QUrl(QStringLiteral("qrc:/main.qml")));
    return app.exec();
}
```

Notes:

- There are no `QML_ELEMENT`/`QML_NAMED_ELEMENT`/`QML_SINGLETON` macros in
  Qt 5 — those are the Qt 6 build-system-driven registration. Qt 5 uses
  explicit `qmlRegister*` calls.
- `qmlRegisterSingletonType` with a factory: the object must not have a
  parent; give it the `QJSEngine` (or `QQmlEngine`) as parent so the
  engine cleans it up.
- `setContextProperty` also exists for simple global objects but bypasses
  type safety and tooling; prefer `qmlRegisterSingletonType` for anything
  reused.
- All registrations must happen **before** `engine.load(...)`.

## Loading a QML module from C++

```cpp
QQmlApplicationEngine engine;
engine.load(QUrl(QStringLiteral("qrc:/main.qml")));   // resource file
// or, for a module mounted under an import path:
engine.load(QUrl(QStringLiteral("qrc:/MyApp/Main.qml")));
```

The URL must match the `.qrc` `<prefix>` + `<file>` path exactly.
`QQmlApplicationEngine` reports
`QQmlApplicationEngine failed to load component` and leaves
`rootObjects()` empty on a bad URL — check for that.

## Mistakes specific to QML in Qt 5

- Emitting `qt_add_qml_module` or `QTP0001`/`QTP0005` policy references —
  Qt 6 only.
- Versionless imports — Qt 6 only.
- `pragma ComponentBehavior: Bound` — Qt 6.5+ only; remove it for Qt 5.
- `import QtQuick.Controls.Basic` — Qt 6 only; use
  `import QtQuick.Controls 2.15` (styles are selected at runtime via
  `QT_QUICK_CONTROLS_STYLE` or `qtquickcontrols2.conf`).
- Forgetting the `singleton` line in `qmldir` — the `pragma Singleton`
  alone makes the type load as a regular component instead.
- Registering a type after `engine.load()` — see above.
