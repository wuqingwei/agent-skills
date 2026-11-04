# Qt 5 Port Handover Document

> This repository is the **Qt 5 adaptation** of
> [wuqingwei/agent-skills](https://github.com/wuqingwei/agent-skills) (a mirror of The Qt
> Company's official Qt AI Skills). This document records the porting work completed in
> November 2026 so future maintainers understand the scope, rules and caveats.
>
> Principles: **every skill keeps its original name**; content that does not apply to
> Qt 5 was removed; everything else was ported to Qt 5 semantics.

---

## 1. Background and goals

The upstream repository is The Qt Company's official set of AI coding skills for
**Qt 6** (code review, QML best practices, documentation generation, profiling,
testing, Figma design-system integration, CMake projects, and more).
Because mainstream LLM training corpora are dominated by Qt 6, applying the upstream
skills to a Qt 5 project systematically produces Qt 6-only constructs
(`qt_add_qml_module`, versionless imports, `pragma ComponentBehavior`, `MultiEffect`,
`loadFromModule`, …) that fail to compile or load on Qt 5.

Goals of this repository:

1. Adapt all skills to **Qt 5.15 LTS** (the last and most feature-complete Qt 5 release);
2. Remove features/tooling that do not exist in Qt 5 (e.g. the Qt 6.12 Canvas2D module,
   the official MCP servers);
3. **Keep every skill directory name and `name` field identical to upstream**, so the
   upstream documentation and toolchains still map 1:1;
4. Preserve the upstream BSD-3-Clause license and copyright notices.

## 2. How the source was fetched

- A direct `git clone https://github.com/wuqingwei/agent-skills.git` timed out on
  github.com:442 in parts of this network; **codeload.github.com was reachable**,
  so the working tree was produced by downloading and extracting
  `https://codeload.github.com/wuqingwei/agent-skills/zip/refs/heads/main`.
- Before the handover commit, upstream history was re-attached via `git fetch`, so the
  port commits sit on top of upstream `main` and diff/pull work normally (see §13).

## 3. Porting baseline

| Item | Value |
|---|---|
| Qt version | **5.15 LTS** (`metadata.qt-version: "5.15"` in every SKILL.md) |
| Language standard | C++11 or newer (required by Qt 5.12+); examples use 14/17 where needed |
| QML modules | QtQuick 2.15 / QtQuick.Controls 2.15 / QtQuick.Layouts 1.15 / QtQuick.Templates 2.15 / QtTest 1.15 / QtGraphicalEffects 1.15 |
| Build system | CMake ≥ 3.5 (`find_package(Qt5 ...)` + `AUTOMOC/AUTOUIC/AUTORCC` + `qt5_*` macros + `.qrc`) |
| Skills kept | 12 (upstream has 13; `qt-canvas2d` was removed) |

Feature availability used by this repository's examples and rules, by introducing
version — check this table before rolling anything back for a pre-5.15 target:

| Feature | Introduced in |
|---|---|
| `TestCase.createTemporaryObject()` / `createTemporaryQmlObject` / `createTemporaryItem` | **Qt 5.9** |
| `Binding.restoreMode` | **Qt 5.14** |
| `required property` | Qt 5.15 |
| inline components (`component Foo: Bar {}`) | Qt 5.15 |
| `ListView.reuseItems` | Qt 5.15 |

For targets older than the respective version, replace with older idioms such as
`model.<role>` access or manual `Component.onCompleted` cleanup (the rule files
note this). Do **not** treat 5.15 as the floor for every feature —
`createTemporaryObject` has been available since 5.9 and `restoreMode` since 5.14.

## 4. Removed content (not applicable to Qt 5)

| Removed | Reason |
|---|---|
| `skills/qt-canvas2d/` (whole directory) | The `QtCanvasPainter`/Canvas2D module it teaches is new API from **Qt 6.12**; Qt 5 only has the legacy Qt Quick `Canvas` element, which the skill explicitly distinguishes itself from |
| `mcp/qt-documentation-mcp/` | The hosted MCP (`https://qt-docs-mcp.qt.io/mcp`) serves only the latest Qt 6 release and active LTS branches — misleading for Qt 5 work |
| `mcp/qml-live-preview-mcp/` | The live-preview MCP depends on the `qmlpreview` service in QmlDebug, **requires Qt 6.12+**, and is installed via the Qt online installer |
| `.mcp.json` | Registered only the qt-docs MCP above |
| `docs/mcp/` (5 pages) | Companion site docs for the MCPs above |
| `skills/qt-qml/references/qmlpreview.md` | Usage reference for the live-preview MCP (Qt 6.12+); the "scan for a `run_qmlPreview` tool on every invocation" logic was also removed from the qt-qml SKILL.md |
| `skills/qt-figma-component-generation/assets/qt-controls/TreeViewDelegate.qml` + `TreeViewDelegateStyle.qml` | `TreeView`/`TreeViewDelegate` belong to Qt Quick Controls **Qt 6.4+**; the Qt 5 Controls 1 TreeView is a different, deprecated API |
| MCP Tools nav section in `mkdocs.yml` | Followed the removal of docs/mcp |
| `docs/images/codex-mcp-setup.webp` | Orphaned screenshot of the Codex MCP setup; unreferenced after docs/mcp was removed (found in the third review pass, §14.6) |

## 5. Per-skill change details

### 5.1 qt-cmake-project (largest change)

- `SKILL.md`: all 10 hard rules rewritten for Qt 5 (each is the inverse of upstream):
  - Use `find_package(Qt5 <ver> REQUIRED COMPONENTS ...)`, `add_executable/add_library`,
    `qt5_add_resources`, `qt5_add_plugin`, `qt5_add_translation`;
    forbid `qt_standard_project_setup` / `qt_add_*` / unprefixed `qt_*` (Qt 6 API);
  - Set `CMAKE_AUTOMOC ON` explicitly (+ AUTOUIC/AUTORCC) together with
    `set(CMAKE_INCLUDE_CURRENT_DIR ON)` — Qt 5 has no helper that does this, and a
    missing AUTOMOC is the most common cause of "undefined reference to vtable";
  - QML ships through `.qrc` (or the filesystem) + `engine.load(QUrl("qrc:/..."))` +
    the `qmlRegisterType` family; QML imports must carry versions;
  - Always link `Qt5::Module` imported targets (the deprecated `qt5_use_modules` is banned);
  - `CMAKE_CXX_STANDARD` goes before `find_package`.
- All six `references/` files rewritten:
  - `simple-project.md`: minimal Qt 5 project template (qml.qrc + main.cpp templates);
  - `common-mistakes.md`: 14 frequent LLM mistakes as inverted Qt 6 warnings
    (§1 Qt 6 commands, §2 missing AUTOMOC, §3 hand-written moc_/qrc_ outputs,
    §7 `qrc:/qt/qml/` paths, §8 registering after load, §9 versionless imports,
    §10 the Qt 6-only API list, …);
  - `modular-architecture.md`: `add_library` + alias targets + `VERSION/SOVERSION` +
    `qt5_add_plugin` (including static plugins via `Q_IMPORT_PLUGIN` /
    `qt5_import_plugins`, noted as 5.14+);
  - `qml-integration.md`: Qt 5 has no `qt_add_qml_module` — hand-written qmldir modules,
    `pragma Singleton` + the qmldir `singleton` line, `qmlRegisterSingletonType`
    (URL form and factory form), registration must happen before `engine.load()`;
  - `resources.md`: `.qrc` first-class (hand-written `.qrc` is the standard, not a
    legacy form, in Qt 5), fonts via `QFontDatabase::addApplicationFont`, translations
    via `qt5_create_translation/qt5_add_translation`, app icons on three platforms;
  - `configure.md`: `cmake -B build -DCMAKE_PREFIX_PATH=<Qt5.15 kit>`, plus a table of
    Qt 5 installation roots.
- After the first review, the `qt5_add_resources` signature was corrected to the Qt 5
  variable form and `qt5_add_translations` (a Qt 6 macro name) was replaced — see §14.

### 5.2 qt-qml

- Removed the entire "scan connected MCP servers for `run_qmlPreview` + verify
  Qt ≥ 6.12" section and `references/qmlpreview.md`.
- Imports rules inverted: **every Qt 5 module import carries a version**; string
  imports (`import "..."`) never do; `QtQuick.Window 2.15` must be imported
  explicitly; `QtQuick.Controls.Basic` does not exist — runtime style selection uses
  `QT_QUICK_CONTROLS_STYLE` / `qtquickcontrols2.conf`, and style-specific attached
  properties use modules like `import QtQuick.Controls.Material 2.15`.
- States: `PropertyChanges { target: id; ... }` is the only correct form in Qt 5
  (the `id.prop` form is Qt 6).
- Delegates: `required property` and `reuseItems` annotated as Qt 5.15+.
- Performance: `MultiEffect` (Qt 6.5+) does not exist → use `QtGraphicalEffects`
  (GaussianBlur, DropShadow, …).
- Pre-output checklist updated.

### 5.3 qt-qml-review

- **Linter `references/lint-scripts/qt_qml_lint.py`** (details in §7.1).
- `references/qt-qml-review-checklist.md`: dropped the Qt 6 semantics of
  IMP-1/IMP-3/IMP-7 and STA-1, inverted IMP-2 to "missing version numbers", added the
  note that `QtGraphicalEffects` is the correct module in Qt 5; BND-1/DEL-1 lost their
  qmlsc/qmlls (Qt 6 tooling) references.
- `references/agent-rules.md`: retitled and re-semantics for Qt 5; removed the
  missing-`pragma ComponentBehavior: Bound` check (a Qt 6.5+ feature); the
  context-property advice now points at `qmlRegisterSingletonType`; the
  `Binding.restoreMode` note now describes Qt 5 semantics (introduced in
  **Qt 5.14**, not 5.15 — corrected in review, see §14.6).
- `SKILL.md`: description says Qt 5, rule count 48+ → 46+ (after the IMP-7
  re-add, see §7.1), qmllint repositioned as a
  "syntax-level checker" (Qt 5 qmllint has no semantic analysis and no `--json`),
  discovery paths switched to Qt 5 kits (`~/Qt*`, `clang_64`, `msvc2019_64`,
  `mingw81_64`), and the example report row reads `IMP-2 Unversioned import`.
- `platforms/windsurf.md`: condensed rules synced.

### 5.4 qt-cpp-review

- **Linter `references/lint-scripts/qt_review_lint.py`** (details in §7.2).
- `references/qt-deprecated-classes.md`: removed the QPair/QSharedDataPointer/QChar
  rows (idiomatic in Qt 5), added a "not flagged in Qt 5" paragraph; the
  `q20::make_unique_for_overwrite` advice (a Qt 6 shim) replaced by std equivalents.
- `references/qt-framework-checklist.md`: FW-DOC-2 → "What's New in Qt 5.15";
  FW-VAL-5 inverted (Q_DECLARE_METATYPE is required in Qt 5); FW-REL-1 no longer
  depends on q20; FW-SMF-4 dropped `Q_IMPLICIT` (a Qt 6.4 macro).
- `SKILL.md`: Qt 5, rule count 60+ → 55+; `references/agent-rules.md` and
  `qt-review-checklist.md` retitled; `platforms/windsurf.md` synced.
- `agents/cpp-review-agent.md`: "Qt6 C++ reviewer" → "Qt5 C++ reviewer".
- `tests/qt-cpp-review/`: removed the expectations and fixtures for the five dropped
  rules (DEP-5/DEP-6/DEP-13/VAL-6/PAT-6); the regression suite stayed green (§8).

### 5.5 qt-qml-test

- Import rule: test files use `import QtQuick 2.15` + `import QtTest 1.15`
  (upstream said "without versions").
- **`references/qt-quick-test-source-import.md` fully rewritten**: upstream's
  `qt_add_qml_module` / library-vs-executable classification does not exist in Qt 5;
  the new decision tree is (1) a `qmlRegisterType`/`qmlRegisterSingletonType`
  registration or an on-disk qmldir module → versioned `import <URI> <maj.min>`;
  (2) otherwise → a relative directory import `import "../..."`; plus the caveat that
  qrc-only resources cannot be reached by a relative import from a test on disk.
- The "skip Qt Quick 3D sources" rule (rule 45) was removed and rules 46/47
  renumbered to 45/46 (46 rules total), with all cross-references synced
  (SKILL.md, rules, pitfalls, pre-send-scan, copilot variant). The first commit
  missed the renumbering inside `qt-quick-test-rules.md` itself — fixed in review,
  see §14.
- Every `QT_QML_SINGLETON_TYPE TRUE` (a Qt 6 CMake property) replaced by the qmldir
  `singleton` line / `qmlRegisterSingletonType` semantics.
- `references/qt-quick-test-template.md`: all template imports versioned; Variant 7's
  URL table switched to the Qt 5 decision (reachable from the test binary's own qrc →
  `qrc:/<Prefix>/<Path>`; otherwise `Qt.resolvedUrl("../..")`); removed `qrc:/qt/qml/`
  paths and the `availableStyles: ["Basic"]` example value.
- `references/qt-quick-test-project-context.md`: context reading now greps
  `qmlRegisterType`/`qmlRegisterSingletonType`/`qmlRegisterUncreatableType` instead of
  `qt_add_qml_module URI`.
- `platforms/copilot.prompt.md`: the self-contained variant synced with all of the above.

### 5.6 qt-qml-test-run

- **`references/qt-quick-test-cmake.md` fully rewritten (491 lines → Qt 5 version)**:
  - Wiring template: `find_package(Qt5 5.15 REQUIRED COMPONENTS QuickTest)` +
    `add_executable` + `set(CMAKE_AUTOMOC ON)` (nothing sets it for you in Qt 5);
    the Widgets/Charts/WebEngineWidgets variant selection was kept;
  - Dropped the Qt 6-only module-on-executable refactor and STATIC plugin machinery;
    added a "how the project exposes its QML types" detection (registering library to
    link / qrc ownership / on-disk qmldir + `-import`);
  - The common-failure list rewritten for Qt 5 (QuickTest dev package, missing
    AUTOMOC, `-import` paths, …);
  - Kept binary-direct JUnit output (`-o report.xml,junitxml`) and the detection
    patterns.
- `SKILL.md`: the Step 3 exception is now "a URI registered from C++ cannot be
  resolved by a standalone qmltestrunner → wiring is the only path"; Step 4a became
  the "project QML type exposure check"; Step 4b skip conditions Qt 5-ified; the Qt
  installation table now lists 5.x paths (`/home/*/Qt5.*/5.*/gcc_64`, `/usr/lib/qt5`,
  `clang_64`, `mingw81_64`).

### 5.7 qt-qml-profiler

- `SKILL.md`: Qt discovery paths switched to 5.x; `$Qt6_DIR` → `$Qt5_DIR`;
  the qrc source-mapping note now says `qrc:/<prefix>/<File>.qml` (Qt 5 has no
  implicit `qrc:/qt/qml/` prefix); the Quick 3D scope note reduced to a safety guard
  (standard Qt 5 applications contain no 3D events).
- `references/scripts/parse-qmlprofiler-trace.py` and
  `qml-performance-anti-patterns.md` are format-level implementations (the `.qtd`
  format is identical on Qt 5.15) and were left semantically unchanged.

### 5.8 qt-figma-token-extraction

- Step 0: the scaffold `main.cpp` went from `engine.loadFromModule()` to
  `engine.load(QUrl("qrc:/main.qml"))`; removed the `qrc:/qt/qml/` and `_qs` Qt 6
  notes; the placeholder went back from `Main.qml` to `main.qml` with a versioned import.
- Step 6 generation rules: imports must carry versions; the effects module went from
  `MultiEffect`/`QtQuick.Effects` to `import QtGraphicalEffects 1.15`; singleton
  registration went from the CMake `set_source_files_properties` property to
  `qmlRegisterSingletonType`.
- Step 7: the CMake template replaced wholesale with the Qt 5 version
  (AUTOMOC/AUTORCC + `qml.qrc`), with a `main.cpp` example registering all four
  singletons via `qmlRegisterSingletonType` (URL form and factory form).
- Step 8 summary and the Token Categories Checklist synced.
- `references/token-mapping.md`: shadow tokens now map to `DropShadow` pixel
  radius + samples instead of `MultiEffect`'s normalized blur (0.0–1.0).
- The five `examples/` QML templates followed the §6 mechanical conversion.

### 5.9 qt-figma-component-generation

- Base-type table: `(from QtQuick.Controls.Basic)` → `(from QtQuick.Controls 2.15)`.
- The Step 7 closing advice went from `qt_add_qml_module QML_FILES` to "add to the
  project's `qml.qrc` + register C++ types with `qmlRegisterType`".
- Example imports versioned; the skill reference `qt-development-skills:qt-qml` → `qt-qml`.
- The 77 `assets/qt-controls/` QML files and 5 `references/` QML files followed the
  §6 mechanical conversion; the two `TreeViewDelegate*.qml` files were removed.

### 5.10 qt-cpp-docs / qt-qml-docs / qt-ui-design (light)

- All three SKILL.md metadata blocks Qt 5-ified.
- qt-cpp-docs §13 QML Exposure: registration went from the `QML_ELEMENT`/
  `QML_SINGLETON` macros to `qmlRegisterType`/`qmlRegisterUncreatableType`/
  `qmlRegisterSingletonType` (Qt 5 has no registration macros).
- qt-ui-design: the style list now reads Default/Fusion/Imagine/Material/Universal
  (iOS and FluentWinUI3 are Qt 6.7+); the TypeScale singleton example went from
  `qt_add_qml_module` to a qmldir + `engine.addImportPath`; the
  `prefers-reduced-motion` paragraph reworded for Qt 5; doc links
  `doc.qt.io/qt-6/...` → `doc.qt.io/qt-5.15/...`.

## 6. Mechanical conversion of the Figma assets

`assets/qt-controls/` (77 files), `references/` (5 files) and the token-extraction
`examples/` (5 files) were converted by script:

| Conversion | Rule |
|---|---|
| Versioned imports | QtQuick→2.15, QtQuick.Window→2.15, QtQuick.Controls→2.15, QtQuick.Layouts→1.15, QtQuick.Templates→2.15, QtGraphicalEffects→1.15, QtTest→1.15, QtQml.Models→2.15, QtQuick.Shapes→1.15, …; **aliased imports handled too** |
| Style imports | `import QtQuick.Controls.Basic` → `import QtQuick.Controls 2.15` (Qt 5 has no Basic style) |
| Qt 6 pragma | all `pragma ComponentBehavior: Bound` lines removed (Qt 6.5+) |
| Typed function annotations | `function f(...): int` → `function f(...)` (avoids pre-5.15 parse differences) |
| Project-local URIs | `import Qt.Fonts as Fonts`, `import Qt.Themes as Themes`, … left unversioned — they are placeholders for the demo project's own modules and should be replaced by the project's registered URI + version in real use |

Features Qt 5.15 already supports (`required property`, inline components,
`HoverHandler`, …) were kept.

## 7. Lint script change details

### 7.1 qt_qml_lint.py (QML linter, 46+ rules)

- **IMP-2 inverted**: "versioned import" error (Qt 6) → "unversioned Qt module
  import" error (`import QtQuick` fires; `import "qrc:/..."` and `import ..` do not).
  After review this became an **allowlist rule**: only Qt-shipped modules in the
  built-in KNOWN_QT_MODULES list require a version; project-local URIs starting with
  `Qt` (e.g. the figma assets' `Qt.Fonts`/`Qt.Themes`) are legal unversioned in Qt 5
  and are not flagged (see §14).
- Qt 6-only rules removed: IMP-1 (redundant QtQuick.Window), IMP-3 (Controls.Basic
  style qualification), STA-1 (PropertyChanges `target:` deprecation — the only
  correct form in Qt 5).
- **IMP-7 inverted, not removed**: upstream's IMP-7 flagged
  `QtGraphicalEffects`/`Qt5Compat.GraphicalEffects` imports in a Qt 6 project and
  pointed at `MultiEffect`. For Qt 5 the direction flips: the linter now flags
  `import QtQuick.Effects`, any `import Qt5Compat.*`, and any `MultiEffect` **use**
  (both the import line and the usage emit IMP-7), pointing at
  `import QtGraphicalEffects 1.15` instead. Re-added in review after the initial
  port had dropped the rule entirely, leaving Qt 6 effects unflagged (see §14.6).
- Message fixes: BND-1/DEL-1 lost their qmlsc references; the IMP-4 note lost
  `qmlformat --sort-imports` (a Qt 6 tool).
- **qmllint integration rewritten**: Qt 5's qmllint is a syntax-level checker (no
  `--json`, no warning ids), so `run_qmllint()` now parses its text output
  (`Warning: file:line: msg` plus a fallback; unlocatable lines aggregate into a
  line-0 `QL` finding); kit discovery switched to Qt 5: `qtpaths`/`qmake` (the `*6`
  variants dropped), installer roots globbed as `~/Qt*` (covering the Qt 5 installer's
  `~/Qt5.15.2/5.15.2/<kit>` double layout), version regex `5\.(\d+)\.(\d+)`.
- Reuse-related rules kept: `reuseItems`/DEL-2/DEL-4 (Qt 5.15), SIG-2 (the old
  `onFoo:` style deprecated since Qt 5.15, consistent with Qt 5).

### 7.2 qt_review_lint.py (C++ linter, 55+ rules)

Five rules that only hold on Qt 6 were removed, with their regexes and test fixtures
cleaned up:

| Rule | Why removed |
|---|---|
| DEP-5 QPair→std::pair | QPair is idiomatic in Qt 5 (only an alias since Qt 6.0) |
| DEP-6 QSharedDataPointer→QExplicitly… | QSDP is the standard Qt 5 COW idiom |
| DEP-13 QChar→char16_t | QChar is the normal Qt 5 character type |
| VAL-6 Q_DECLARE_METATYPE removal | Required in Qt 5 for QVariant and queued signal arguments |
| PAT-6 q20::make_unique_for_overwrite | `q20::*` is a Qt 6 internal shim |

The remaining DEP rules (QScopedPointer→unique_ptr, foreach→range-for, qMin→std::min,
…) are generic modern-C++ advice that also holds on Qt 5 and were kept. TMO-1's
`QDeadlineTimer` is Qt 5.8+ and was kept.

## 8. Testing and verification record

| Verification | Result |
|---|---|
| `tests/qt-cpp-review/run_tests.py` (C++ linter regression) | **55/55 universal + 3/3 framework + `--diff` mode all pass** (fixtures synced with the dropped rules) |
| QML linter smoke (constructed samples) | unversioned import correctly fires IMP-2; `QtGraphicalEffects 1.15` no longer false-positives; `PropertyChanges target:` no longer fires STA-1; IMG-1/IMG-2/BND-1 and other regular rules behave |
| QML linter on the figma examples | 9 findings (ORD/STY), no script errors |
| Repo-wide grep | zero Qt 6 constructs left in the QML assets; the only "Qt 6" mentions left in SKILL.md files are defensive warnings ("do not write X in Qt 5"); zero unversioned Qt imports |
| `ast.parse` on both lint scripts | syntax OK |

## 9. Auxiliary files and metadata changes

| File | Change |
|---|---|
| `README.md` | Rewritten: Qt 5 positioning and port notes, the 12-skill table, removal notes, install commands (`qt5-development-skills`), repo structure (mcp/ gone), example frontmatter (`qt-version: "5.15"`), trimmed docs-site sections |
| `.claude-plugin/plugin.json` | Plugin name `qt-development-skills` → `qt5-development-skills`, version 1.8.0 → 1.0.0, MCP wording removed from the description |
| `.claude-plugin/marketplace.json` | Renamed/reversioned in sync; `qt5` added to keywords, `mcp` removed; repository URL points at wuqingwei/agent-skills |
| `gemini-extension.json` | name → `qt5skills`, description Qt 5-ified |
| `mkdocs.yml` | site_description Qt 5-ified; MCP Tools nav removed; repo_url → wuqingwei/agent-skills |
| `docs/index.md` / `docs/getting-started.md` | Rewritten: MCP cards/sections gone, positioning now "models hurt Qt 5 projects with Qt 6 idioms"; install commands updated |
| `docs/skills/requirements.md` | Every dependency row Qt 5-ified (qmlprofiler/qmltestrunner 5.15, CMake 3.5+, generated tests use versioned imports, …) |
| `docs/skills/concepts.md` | Trigger descriptions Qt 6→Qt 5 |
| `gen_skills.py` | `GITHUB_BLOB` → wuqingwei/agent-skills |
| `CONTRIBUTING.md` | Example description Qt 6→Qt 5; after review also `qt-version: "6.x"` → `"5.15"` and `author: qt-ai-skills` → `qt5skills` (see §14.5) |
| `agents/cpp-review-agent.md` / `agents/qml-review-agent.md` | "Qt6 … reviewer" → "Qt5 … reviewer" |
| `tools/`, `LICENSE`, `overrides/`, `requirements-docs.txt` | Unchanged (tool scripts and branding are Qt-version-agnostic); `tools/README.md` lost a "MCP server" mention in review (see §14.5) |

## 10. Known limitations and caveats

1. **Qt version floor**: the rules and examples assume 5.15 as the overall baseline,
   but feature floors differ — see the table in §3. On Qt 5.12–5.14,
   `required property`, inline components and `ListView.reuseItems` (all 5.15) are
   unavailable, while `createTemporaryObject` (5.9) and `Binding.restoreMode` (5.14)
   **are** available and must not be rolled back unnecessarily. Consult the §3 table
   before downgrading any idiom.
2. **qmllint is syntax-level only**: Qt 5's qmllint does no semantic/type checking;
   qt-qml-review relies on the Python linter + deep-analysis agents for type-level
   issues.
3. **Project placeholder URIs in the figma assets**: `import Qt.Fonts as Fonts`,
   `import Qt.Themes as Themes` are placeholders for the demo project's own modules;
   replace them with the project's registered URI + version in real use.
4. **Docs site**: `mkdocs build --strict` was verified on 2026-11-04 (Python 3.10.12 +
   all of `requirements-docs.txt`; builds in ~2.3 s with zero warnings, see §14.4);
   `mkdocs serve` for local preview. Pages were not eyeballed one by one.
5. **Upstream sync**: upstream keeps evolving for Qt 6; when merging upstream commits,
   Qt 6-related changes need human review before being brought in.
6. **License and branding**: the upstream BSD-3-Clause license, The Qt Company
   copyright headers and the Qt commercial licensing notice were preserved.

### Intentional design trade-offs (recorded, not gaps)

- **No qmake skill.** Upstream ships none either — only `qt-cmake-project` — and
  that skill's hard rules explicitly forbid generating `.pro` files. qmake users
  are out of scope by design.
- **No Trae/ZCode-specific install section in the README.** The install chapter
  covers Claude Code, Codex CLI, Copilot, VSCode agents, Gemini and
  Cursor/Windsurf (as upstream did); tools that read `~/.agents/skills/` or
  `.agents/skills/` are covered by the generic note in the Codex section.
- **No MCP servers, and that is final.** `mcp/`, `.mcp.json` and `docs/mcp/` were
  removed with the port (§4), and the leftover "MCP server" wording was scrubbed
  from CONTRIBUTING.md and tools/README.md in `ba2a14d`. A Qt 5-specific MCP
  surface would have to be built and hosted before any of this content could
  come back.

## 11. Installation quick start

```bash
# Claude Code (plugin route)
/plugin marketplace add wuqingwei/agent-skills
/plugin install qt5-development-skills

# or copy a single skill
cp -r skills/qt-qml-review ~/.claude/skills/qt-qml-review
# review skills: also install the review agents
cp agents/cpp-review-agent.md agents/qml-review-agent.md ~/.claude/agents/
```

Other platforms (Codex CLI / Copilot / Gemini / Cursor / Windsurf): see the
installation section of `README.md`.

## 12. Quick change index

- Deleted: `skills/qt-canvas2d/**`, `mcp/**`, `.mcp.json`, `docs/mcp/**`,
  `skills/qt-qml/references/qmlpreview.md`,
  `skills/qt-figma-component-generation/assets/qt-controls/TreeViewDelegate*.qml`
- Fully rewritten: `skills/qt-cmake-project/**` (SKILL + 6 references),
  `skills/qt-qml-test-run/references/qt-quick-test-cmake.md`,
  `skills/qt-qml-test/references/qt-quick-test-source-import.md`,
  `README.md`, `docs/index.md`, `docs/getting-started.md`
- Heavily modified: both lint scripts and their references; the SKILL.md files and
  references of qt-qml / qt-qml-test / qt-qml-profiler / qt-figma-*; all 87 figma QML
  assets; the platform variants (windsurf ×4, copilot ×1); agents ×2;
  tests/qt-cpp-review; plugin and site metadata (plugin/marketplace/gemini/mkdocs/
  gen_skills/CONTRIBUTING/docs/skills)

The full diff is the git history: `git log --stat` and `git show`.

## 13. Handover commit notes

- The port sits on top of upstream `main` (history re-attached via fetch, working-tree
  changes committed on top), as a single commit for easy review and rollback; split it
  per the §12 index if you need to cherry-pick in batches.
- Going forward: follow the upstream format conventions when adding or changing skills
  (SKILL.md frontmatter, progressive disclosure, platforms/ variants) and the Qt 5
  baseline rules of §3 and §6.

---

## 14. Review and fixes (2026-11-04)

The first port commit (`96c369a`) was re-reviewed item by item; four issues were
found and fixed.

### 14.1 Issues found

| # | Severity | Issue | Location |
|---|---|---|---|
| 1 | High | `qt-qml-test/references/qt-quick-test-rules.md` numbering jumped 44 → 46/47 after the 3D rule (45) was deleted, and a leftover `## Qt Quick 3D source handling` heading sat on top of the Unreachable-inner-items rule; it was out of sync with the "rule 45/46" cross-references already used by SKILL.md / pitfalls / pre-send-scan / copilot | `skills/qt-qml-test/references/qt-quick-test-rules.md` |
| 2 | High | `qt5_add_resources` was written with the **Qt 6 target-based signature** (`qt_add_resources(target "name" PREFIX ... FILES ...)`) in three places — Qt 5 only has the variable form `qt5_add_resources(<VAR> <.qrc> ...)`; `qt5_add_translations` does not exist (Qt 5 has `qt5_add_translation` / `qt5_create_translation`). Found inside the very file that exists to correct such LLM mistakes | `qt-cmake-project/SKILL.md`, `references/common-mistakes.md`, `references/resources.md` |
| 3 | Medium | QML linter IMP-2 false positive: any unversioned import starting with `Qt` was flagged, but a project-local URI (the figma assets' `Qt.Fonts`/`Qt.Themes`, 10 occurrences) is legal unversioned in Qt 5 when its qmldir declares no versions | `qt-qml-review/references/lint-scripts/qt_qml_lint.py` |
| 4 | Low | HANDOVER §5.5 claimed "all cross-references synced" but rules.md had in fact been missed (issue 1) — the document did not match the repository | `HANDOVER.md` |

### 14.2 Fixes

1. rules.md: `## Qt Quick 3D source handling` → `## Unreachable inner items`;
   rules `46. **Inner items…` → `45.` and `47. **Every test function…` → `46.`, making
   the numbering continuous 1–46 and aligned with the other files' cross-references.
2. CMake macro signatures switched to the real Qt 5 forms:
   - `SKILL.md` hard rule 1: the command list now reads `qt5_add_translation` /
     `qt5_create_translation`, with `qt5_add_resources` explicitly marked as the
     variable form and `qt5_add_translations` marked Qt 6 only;
   - `common-mistakes.md` §1: the RIGHT example uses `.qrc` + AUTORCC and
     `qt5_add_resources(APP_RESOURCES images.qrc)` + `add_executable(... ${APP_RESOURCES})`,
     plus a new "Signature trap" paragraph comparing both signatures;
   - `resources.md`: table and example switched to the variable form, noting Qt 5 has
     no FILES-only resource form.
3. `qt_qml_lint.py`: added the `KNOWN_QT_MODULES` allowlist (QtQuick/Controls/…/
   Qt.labs.* and other Qt-shipped modules); IMP-2 is now special-cased in the Tier A
   dispatch and only emits when the module is on the list; the
   `qt-qml-review-checklist.md` IMP-2 entry documents the allowlist semantics and when
   a project-local URI is legal.
4. HANDOVER: this section, plus the §5.5 and §7.1 wording corrections.

### 14.3 Review verification

| Verification | Result |
|---|---|
| `tests/qt-cpp-review/run_tests.py` | 55/55 universal + 3/3 framework + `--diff` all pass (unaffected) |
| IMP-2 allowlist smoke | `import Qt.Fonts as Fonts` / `Qt.Themes` no longer flagged; unversioned `import QtQuick` still correctly flagged; figma assets (Button.qml/SwitchStyle.qml) produce zero IMP-2 false positives |
| Rule numbering | rules.md continuous 1–46 (awk scan, no gaps); SKILL.md/copilot in sync |
| Internal reference integrity | every relative link in every SKILL.md points at an existing file (script scan) |
| References to deleted files | zero remaining mentions of `qmlpreview.md`/`qt-canvas2d`/`docs/mcp`/`TreeViewDelegate` (outside the intentional removal notes in HANDOVER/README) |
| Qt 6-only API re-scan of the figma assets | zero hits for `IconPosition`/`popupType`/`palette:`/`Overlay.overlay` etc.; `required property` and other 5.15 features confirmed inside the baseline |
| `ast.parse` on the lint scripts | syntax OK |

### 14.4 Docs-site verification (closed 2026-11-04)

- `mkdocs build --strict` now verified locally: Python 3.10.12 + everything in
  `requirements-docs.txt` (mkdocs 1.6.1, mkdocs-material, mkdocs-gen-files 0.5.0,
  mkdocs-literate-nav 0.6.1, pyyaml) — builds clean in ~2.3 s with zero warnings and
  zero broken links; the output contains all 12 skill pages with no qt-canvas2d/mcp
  leftovers, and `site/` stays git-ignored. When `python3-venv` is missing,
  `pip3 install --user -r requirements-docs.txt` works as a fallback. The README's
  Python requirement was corrected from 3.12+ to the tested 3.10+.
- The output shown by the build (a red "Warning from the Material for MkDocs team"
  about MkDocs 2.0) is an upstream industry announcement from the theme, not a build
  warning.

### 14.5 Second review pass (2026-11-04, English conversion + full-diff sweep)

A second full review of every commit since the fork point (`96c369a` → `b943176` →
`88726eb`, 182 files, +1947/−6952 vs upstream) was performed, this time reading the
files that had only been grepped before (CONTRIBUTING.md, both parser scripts,
qt-quick-test-report-format.md, qt-quick-test-controls/properties/pitfalls.md, the
qt-qml-docs windsurf variant, tools/, overrides/, gen_skills.py, the remaining
sections of the figma and ui-design SKILL.md files). Findings, all fixed:

1. `CONTRIBUTING.md`: the frontmatter example still read `qt-version: "6.x"` and
   `author: qt-ai-skills` — corrected to `"5.15"` / `qt5skills`.
2. `skills/qt-figma-token-extraction/SKILL.md` (Step 7 validation list): the example
   `import QtQuick` was versionless, contradicting the same file's own Step 6 rule —
   now `import QtQuick 2.15`.
3. `skills/qt-qml-test/references/qt-quick-test-pitfalls.md`: the "Missing
   `import QtTest`" symptom now names the versioned form `import QtTest 1.15`.
4. `CONTRIBUTING.md` and `tools/README.md`: release-flow wording mentioned adding an
   "MCP server" as possible new content — reduced to "(skill, etc.)" since this
   repository carries no MCP servers.
5. All remaining Chinese in the repository (HANDOVER.md, 3166 characters; README.md,
   13 characters) was translated to English; this document is now fully English.

Everything else re-checked clean: both parser scripts contain no Qt 6-specific code
(they parse the format-level `.qtd`/JUnit outputs, which are identical on Qt 5.15);
`overrides/` is upstream Qt branding kept on purpose; `gen_skills.py` and
`docs/skills/concepts.md` carry no version hardcoding; the qt-qml-docs windsurf
variant needed no changes.

### 14.6 Third review pass (2026-11-04, external findings)

Three externally reported issues, all confirmed real and fixed, plus one more of
the same kind found while fixing them:

1. **Wrong version claims in HANDOVER.** §3 said `createTemporaryObject` was
   introduced in Qt 5.15 and §5.3/§10.1 treated `Binding.restoreMode` as 5.15;
   the real floors are **Qt 5.9** and **Qt 5.14** respectively. Anyone using
   HANDOVER as the rollback authority for a 5.12–5.14 target would have removed
   APIs that work fine there. §3 is now a per-feature availability table, §10.1
   points at it, and §5.3 states 5.14. The same restoreMode error also lived in
   `skills/qt-qml-review/references/agent-rules.md` ("Qt 5.15+ has restoreMode")
   and was corrected to 5.14 there too.
2. **IMP-7 was missing entirely.** The initial port dropped upstream's IMP-7
   (which flags `QtGraphicalEffects` in Qt 6) without adding the Qt 5-side
   counterpart, so `import QtQuick.Effects`, `import Qt5Compat.*` and
   `MultiEffect` uses went completely unflagged by the linter — only a prose note
   in the checklist mentioned them. IMP-7 was re-added in inverted form: both the
   import line and any `MultiEffect` usage emit IMP-7 pointing at
   `QtGraphicalEffects 1.15`. Verified by smoke test: the bad sample
   (QtQuick.Effects + MultiEffect) reports IMP-7 on both lines; the good sample
   (QtGraphicalEffects 1.15 + DropShadow) reports nothing.
3. **Rule count still inconsistent.** The qt-qml-review SKILL.md frontmatter
   said "45+ rules" while its body still carried upstream's "(48+ checks)".
   Both now read **46+** (the re-added IMP-7 brings the count up), and HANDOVER
   §5.3/§7.1 were updated to match.

The remaining observations from the same review were confirmed as intentional
design trade-offs rather than defects, and are now recorded in §10 (no qmake
skill, no per-tool install sections beyond upstream's set, no MCP servers).
