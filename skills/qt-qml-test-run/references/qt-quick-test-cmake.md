# Qt Quick Test — CMake wiring recipe (Qt 5)

The recipe the skill writes when a project has no test
infrastructure, plus the detection rules and common failure
modes.

The skill always writes new files (`tests/CMakeLists.txt` and
`tests/main.cpp`). It **never** mutates the root
`CMakeLists.txt` silently — the proposed three-line addition
is printed for review and applied only with the user's
explicit OK.

## tests/CMakeLists.txt — `QUICK_TEST_MAIN` harness

The skill uses the C++ harness for all CMake projects. It works
whether the project registers its own QML types via
`qmlRegisterType` or not, so a separate "direct mode" is not
needed.

Two variants are emitted depending on the project's modules.
**Pick the Widgets variant** if any of the following matches in
the project's root `CMakeLists.txt` `find_package(Qt5 ...
COMPONENTS …)` list, or in any `target_link_libraries` for
project targets:

- `Widgets` / `Qt5::Widgets`
- `Charts` / `Qt5::Charts` — QtCharts privately links Widgets
  and spawns widget internals; without a `QApplication` the
  test binary segfaults at first chart draw.
- `WebEngineWidgets` — same reason.
- `Multimedia` (when paired with widgets-based renderers).
- `PrintSupport`.

Otherwise emit the **GuiApplication variant**.

### GuiApplication variant (default)

`tests/CMakeLists.txt`:

```cmake
set(CMAKE_AUTOMOC ON)

add_executable(tst_qmltests main.cpp)

target_compile_definitions(tst_qmltests PRIVATE
    QUICK_TEST_SOURCE_DIR="${CMAKE_CURRENT_SOURCE_DIR}"
)

target_link_libraries(tst_qmltests PRIVATE
    Qt5::Gui
    Qt5::QuickTest
    # Add the project's own QML-registering library here, e.g.:
    # MyAppCore
)

add_test(NAME tst_qmltests COMMAND tst_qmltests)
```

`tests/main.cpp`:

```cpp
#include <QtQuickTest>
#include <QCoreApplication>
#include <QObject>

class Setup : public QObject
{
    Q_OBJECT
public slots:
    void applicationAvailable()
    {
        // Required for QML Settings / QSettings to initialise
        // cleanly. Replace the strings with the project's identity
        // if it ships its own.
        QCoreApplication::setOrganizationName("QtProject");
        QCoreApplication::setOrganizationDomain("qt.io");
        QCoreApplication::setApplicationName("qmltests");
    }
};

QUICK_TEST_MAIN_WITH_SETUP(qmltests, Setup)

#include "main.moc"
```

### Widgets variant (Charts / Widgets / WebEngineWidgets / …)

Differs from the GuiApplication variant in two places:

1. `tests/CMakeLists.txt` links `Qt5::Widgets`:

   ```cmake
   target_link_libraries(tst_qmltests PRIVATE
       Qt5::Gui
       Qt5::Widgets
       Qt5::QuickTest
       # …project libraries…
   )
   ```

2. `tests/main.cpp` constructs `QApplication` explicitly before
   handing control to the runner — `QUICK_TEST_MAIN_WITH_SETUP`
   creates a `QGuiApplication` by default, which is not enough
   for code paths that touch `QWidget*`:

   ```cpp
   #include <QtQuickTest>
   #include <QApplication>
   #include <QObject>

   class Setup : public QObject
   {
       Q_OBJECT
   public slots:
       void applicationAvailable()
       {
           QCoreApplication::setOrganizationName("QtProject");
           QCoreApplication::setOrganizationDomain("qt.io");
           QCoreApplication::setApplicationName("qmltests");
       }
   };

   int main(int argc, char *argv[])
   {
       QApplication app(argc, argv);
       Setup setup;
       return quick_test_main_with_setup(argc, argv, "qmltests",
                                         QUICK_TEST_SOURCE_DIR, &setup);
   }

   #include "main.moc"
   ```

When emitting the Widgets variant, also add `Widgets` to the
project's root `find_package(Qt5 ... COMPONENTS …)` list at
Step 5c if it is not already present.

### Both variants

`QUICK_TEST_MAIN_WITH_SETUP` takes a class with
`applicationAvailable()` (and optionally `qmlEngineAvailable()`)
slots; the runner invokes them after the `QCoreApplication`
exists but before the first QML file loads. The org/domain/app
names are required by `QSettings` and the QML `Settings`
element; without them, every `Settings` instance prints "Failed
to initialize QSettings instance" at construction.

`QUICK_TEST_SOURCE_DIR` points at the directory containing
`tst_*.qml` files at configure time and is baked into the
binary, so moving the test files later requires a re-configure.

The commented `target_link_libraries` lines must be filled in
by the project owner **if the project ships a C++ library that
registers the QML types under test** (anything calling
`qmlRegisterType` that tests need to instantiate). The skill
cannot reliably guess the library target name; it surfaces this
gap in the console output and the run report. Projects that
only exercise Qt-shipped QML modules can leave those lines
commented.

To run via the test executable instead of CTest:

```bash
./build/tests/tst_qmltests -o report.xml,junitxml
```

The flags accepted by the test executable are the same as
`qmltestrunner` (it embeds the runner).

## Root `CMakeLists.txt` — proposed addition

The skill never silently mutates the root file. With
`--wire-up`, it prints these three lines for confirmation:

```cmake
find_package(Qt5 5.15 REQUIRED COMPONENTS QuickTest)
enable_testing()
add_subdirectory(tests)
```

Add after any existing `find_package(Qt5 ...)` call, or merge
the `QuickTest` component into the existing call's `COMPONENTS`
list. The `add_subdirectory(tests)` line goes near the bottom,
after the project's main targets are defined.

## Wire-up procedure

When the runner's Step 5 needs to wire up missing test
infrastructure, apply the following sub-steps in order:

**5a — Write `tests/CMakeLists.txt`.** Pick the variant per
the GuiApplication vs Widgets criteria above and write the
matching template. Auto-fill the `target_link_libraries`
project-library line per the next section; leave the
commented placeholder only when no QML-registering library is
found. Create the `tests/` directory if missing. **Never
overwrite** an existing `tests/CMakeLists.txt` — if the file
is already there, surface its content and stop with a "merge
manually" message.

**5b — Write `tests/main.cpp`.** Use the template matching
the variant chosen at 5a. Both variants use
`QUICK_TEST_MAIN_WITH_SETUP` with a `Setup` class that sets
organization / domain / application names (required by QML
`Settings` and `QSettings`). Do **not** emit the bare
`QUICK_TEST_MAIN(qmltests)` form. Same no-overwrite policy
as 5a.

**5c — Propose root `CMakeLists.txt` edits.** Print the
three-line addition above (and, for the Widgets variant,
also merge `Widgets` into the same `find_package`
`COMPONENTS` list). Show the existing root `CMakeLists.txt`
so the user can locate the right insertion points. Apply
**only after the user confirms with an explicit "yes" or
"apply"**.

**5d — Recipe-only path.** When the user reached Step 5 via
Step 4b explicitly asking for wire-up but did not pass
`--wire-up`, do not write or modify any files. Print the
`tests/CMakeLists.txt` template, the `tests/main.cpp`
template, the three-line root addition, and the instruction
"Re-run with `--wire-up` after reviewing, or apply
manually." Stop; do not proceed to Step 6.

## Binary-direct JUnit invocation (not `ctest --output-junit`)

For CMake projects, Step 7 invokes the built test binary
directly to get JUnit XML at per-QML-function granularity:

```bash
"./build/tests/tst_qmltests" -o "<report.xml>,junitxml"
```

Do **not** use `ctest --output-junit` as the parser source.
CTest aggregates JUnit output at the CTest-target level: a
test binary that runs 100+ QML test functions appears in the
XML as a single `<testcase name="tst_qmltests" ...>` entry.
The parser in Step 8 would then report "1 test passed" — or,
worse, "1 test failed" with no per-function breakdown — even
on a fully-passing suite.

The test binary's `-o report.xml,junitxml` form produces one
`<testcase>` per QML `function test_*()`, which is what the
parser and the Markdown report need. CTest is still useful
for a smoke pass (`ctest --test-dir build --output-on-failure`),
just not as the JUnit source.

## Detection patterns — is wiring already present?

Grep the project's CMakeLists.txt files (root and one level
deep). If **any** of these match, treat the test
infrastructure as present and skip wiring.

| Pattern (regex) | What it indicates |
|---|---|
| `find_package\([^)]*QuickTest` | `Qt5::QuickTest` is available |
| `quick_test_main\b` or `QUICK_TEST_MAIN` | C++ harness present |
| `QUICK_TEST_SOURCE_DIR` | Test source directory configured |

All three are QuickTest-specific — none of them fire on a
C++ QTest-only project. Generic CTest signals like
`enable_testing()` or `add_test(... tst_...)` are not used
for detection because a C++ QTest project sets both without
involving QML Quick Test.

### Additional detection — how the project exposes its QML types

Separately from the wiring-already-present check, determine how
the tests can reach the project's own QML components:

- **`qmlRegisterType`/`qmlRegisterSingletonType` in a linked
  library** — tests link that library target and import the
  registered URI with its version. Fill the
  `target_link_libraries` placeholder with the library target
  name.
- **QML files listed in a `.qrc` that only the app links** —
  the test binary cannot load those resource URLs (the qrc
  lives in the app binary). Tests must import the sources via
  a relative directory import (`import "../src"`) against the
  on-disk files, or the project must expose the types through
  a registration in a library the test links.
- **`qmldir` module directories on disk** — tests can import
  them with the module's version; add
  `-import <parent-dir>` to the run invocation, or call
  `engine.addImportPath(...)` in `qmlEngineAvailable()`.

This only matters when the test is expected to reach the
project's own QML types. If the test only exercises Qt-shipped
modules (`QtQuick.Controls`, `Qt.labs.*`, etc.), no project
library is needed.

## Common failure modes after wiring

- **`find_package(Qt5 ... QuickTest)` missing** — `add_executable`
  succeeds but `target_link_libraries(... Qt5::QuickTest)`
  fails with "Target Qt5::QuickTest not found". Fix: add
  `QuickTest` to the root `find_package` components list
  (it lives in the `qtquick1`-independent `QtQuickTest` config;
  on some distro packages it is a separate `qtquick1`/`qtdeclarative`
  subpackage — install `qtdeclarative5-dev` or the matching
  QuickTest development package).
- **`main.moc: No such file or directory`** at compile time —
  the test binary's `main.cpp` declares `class Setup : public
  QObject { Q_OBJECT … };` and ends with `#include "main.moc"`,
  which requires AUTOMOC to generate the `.moc` file.
  Qt 5 has no helper that enables AUTOMOC for you.
  Fix: ensure the project's root `CMakeLists.txt` sets
  `set(CMAKE_AUTOMOC ON)`, or
  `set_target_properties(tst_qmltests PROPERTIES AUTOMOC ON)`
  on the test target.
- **`enable_testing()` missing** — `add_test` calls are silently
  ignored; CTest reports "no tests found". Fix: add the line
  to the root `CMakeLists.txt` *before* any `add_subdirectory`
  that contains `add_test` calls.
- **`QUICK_TEST_SOURCE_DIR` mismatch** — the harness reports
  "no tests" because the configured directory is empty or
  wrong. The skill writes the macro pointing at
  `${CMAKE_CURRENT_SOURCE_DIR}`, which is the directory
  containing the generated `tests/CMakeLists.txt`. Move
  `tst_*.qml` files into that directory or update the macro.
- **`module "<URI>" is not installed` at runtime** — the test
  imports a project URI the test binary does not know. Fix:
  link the project library that performs the `qmlRegisterType`
  calls (edit the commented `target_link_libraries` line), or
  add `-import <dir>` so the engine finds the on-disk `qmldir`.
- **`"<Type> is not a type"`** when loading a file that
  references a same-module sibling without an explicit import —
  add the missing relative import path (`-import`) or import
  the module explicitly in the test file.
- **GL/platform errors in CI** — prepend
  `QT_QPA_PLATFORM=offscreen` to the test invocation (see the
  runner skill, Step 7).

## Why this is "starter" wiring

The template above is the minimum that gets a test running.
Production setups commonly add:

- **Per-test `add_test` granularity** (one CTest target per
  `tst_*.qml`) for parallelism and failure isolation.
- **Test data directories** copied into the build tree at
  configure time.
- **Environment overrides** (`QT_QPA_PLATFORM=offscreen`,
  `QT_LOGGING_RULES=*.debug=false`) on `add_test` via
  `set_tests_properties(... ENVIRONMENT ...)`.
- **CTest labels** for selective execution (`unit`, `slow`,
  `gui`).

The skill does not generate these by default; the project
owner can add them after the initial wiring is verified to
work.
