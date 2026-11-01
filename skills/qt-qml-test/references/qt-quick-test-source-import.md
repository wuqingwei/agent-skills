# Qt Quick Test — source import resolution

How to emit the `<source-import>` placeholder in the canonical
template — the import line that makes the component under test
visible to the test file.

Qt 5 has no build-system QML modules: components reach QML either
through `qmlRegisterType` C++ registration, through an on-disk
`qmldir` module, or through plain file paths (`.qrc` or disk).
Pick exactly one of the following forms and resolve in order;
stop at the first match.

## Form 1 — Registered module URI

If the project registers the component's module in C++ or in a
`qmldir`, emit an import with the module's version:

- **`qmlRegisterType<MyType>("MyApp.Models", 1, 0, "MyType")`**
  (or `qmlRegisterUncreatableType` / `qmlRegisterSingletonType`
  with the same URI) in `main.cpp` or a registration header —
  emit:

  ```qml
  import MyApp.Models 1.0
  ```

  Use the exact URI and major.minor from the registration call.

- **An on-disk `qmldir` containing `module <URI>`** (a QML module
  directory shipped on disk or in the resource system) with type
  entries covering the component — emit the same versioned import
  and make sure the test run adds the module's parent directory
  to the import path (`-import <dir>` for `qmltestrunner`, or the
  harness calls `engine.addImportPath(...)`).

Do not emit an unversioned import: Qt 5 requires
`import <URI> <major>.<minor>`.

## Form 2 — Relative directory import

Otherwise (and as the fallback when Form 1's registration cannot
be confirmed), the source is reached via file path. Compute the
relative path from the test file's directory to the source file's
directory and emit:

```qml
import "<relative-path>"
```

For the default destination (`tests/tst_<X>.qml` next to a
source at the project root), this is `import ".."`. For a
source under `app/` it is `import "../app"`.

The QML engine reads the source files from disk (or from the
matching resource path) and resolves sibling types via the
on-disk `qmldir` when one exists. Relative imports work for
files inside the resource system too, as long as both test and
source live under the same `qrc` prefix; a test file on disk
cannot relatively import a file that only exists inside a `.qrc`
— in that case the project must expose the component through a
registration (Form 1) or the test must load the file by resource
URL (see the Window variant in `qt-quick-test-template.md`).

## Hard rule

**Never emit `import my_module` literally** — it is a
documentation placeholder, not a valid import. If neither
resolution form is determinable (e.g., the test target path
overrides the default and the source path can't be reduced
to a relative directory), stop and ask the user for the
correct import line rather than guessing.
