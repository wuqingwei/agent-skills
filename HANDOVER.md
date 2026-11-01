# Qt5 适配交接文档

> 本仓库是 [wuqingwei/agent-skills](https://github.com/wuqingwei/agent-skills)（The Qt Company
> 官方 Qt AI Skills 的镜像仓库）的 **Qt 5 适配版**。本文档记录 2026-11 完成的整体移植工作，
> 供后续维护者了解改动范围、规则与注意事项。
>
> 原则：**skill 名字全部保持原名**；Qt5 中不适用的内容删除；其余内容全部移植到 Qt5 语义。

---

## 1. 背景与目标

上游仓库是 The Qt Company 官方面向 **Qt 6** 的 AI 编程 skills 集合
（代码审查、QML 最佳实践、文档生成、性能剖析、测试、Figma 设计系统接入、CMake 工程等）。
由于主流大模型的训练语料以 Qt 6 为主，直接把上游 skills 用在 Qt 5 项目上会系统性地产出
Qt 6 专属写法（`qt_add_qml_module`、无版本 import、`pragma ComponentBehavior`、
`MultiEffect`、`loadFromModule` 等），在 Qt 5 下无法编译或加载。

本仓库的目标：

1. 全部 skill 适配 **Qt 5.15 LTS**（最后一个、功能最全的 Qt 5 版本）；
2. Qt5 中不存在的功能/工具链（如 Qt 6.12 的 Canvas2D、官方 MCP 服务）直接删除；
3. **skill 目录名与 `name` 字段保持与上游一致**，方便与上游文档/工具链对照；
4. 保留上游的 BSD-3-Clause 许可与版权声明。

## 2. 源码拉取方式

- 直接 `git clone https://github.com/wuqingwei/agent-skills.git` 在部分网络环境下
  连接 github.com:443 超时；经验证 **codeload.github.com 可直连**，改用：
  `https://codeload.github.com/wuqingwei/agent-skills/zip/refs/heads/main`
  下载 zip 后解压为工作树。
- 交接提交前已通过 `git fetch` 接回上游 main 分支历史，本仓库的提交在上游 main 之上，
  可正常 diff/pull（见 §13 提交说明）。

## 3. 适配基线

| 项 | 值 |
|---|---|
| Qt 版本 | **5.15 LTS**（所有 SKILL.md `metadata.qt-version: "5.15"`） |
| 语言标准 | C++11 起（Qt 5.12+ 要求），示例按需 14/17 |
| QML 模块 | QtQuick 2.15 / QtQuick.Controls 2.15 / QtQuick.Layouts 1.15 / QtQuick.Templates 2.15 / QtTest 1.15 / QtGraphicalEffects 1.15 |
| 构建系统 | CMake ≥ 3.5（`find_package(Qt5 ...)` + `AUTOMOC/AUTOUIC/AUTORCC` + `qt5_*` 宏 + `.qrc`） |
| 保留的 skill 数量 | 12（上游 13，删除 qt-canvas2d） |

`required property`、`createTemporaryObject`、`ListView.reuseItems`、inline components
（`component Foo: Bar {}`）均为 **Qt 5.15 引入**的特性，在本仓库的示例与规则中允许使用；
若目标版本低于 5.15 需回退为 `model.<role>` 访问等旧写法（相关规则文件中有说明）。

## 4. 删除内容清单（Qt5 不适用）

| 删除项 | 原因 |
|---|---|
| `skills/qt-canvas2d/`（整个目录） | 讲解的 `QtCanvasPainter`/Canvas2D 模块是 **Qt 6.12** 才引入的新 API；Qt 5 只有旧版 Qt Quick `Canvas` 元素，与该 skill 明确区分的对象 |
| `mcp/qt-documentation-mcp/` | 官方托管 MCP（`https://qt-docs-mcp.qt.io/mcp`）只覆盖 Qt 6 最新版与活跃 LTS 文档，对 Qt 5 开发有误导性 |
| `mcp/qml-live-preview-mcp/` | QML 实时预览 MCP 依赖 QmlDebug 的 `qmlpreview` 服务，**要求 Qt 6.12+**，且需从 Qt 在线安装器安装 |
| `.mcp.json` | 仅注册上述 qt-docs MCP，一并删除 |
| `docs/mcp/`（5 个文档页） | 上述 MCP 的配套站点文档 |
| `skills/qt-qml/references/qmlpreview.md` | QML Live Preview MCP 的使用参考（Qt 6.12+），同时删除了 qt-qml SKILL.md 中"每次调用扫描 run_qmlPreview 工具"的整段逻辑 |
| `skills/qt-figma-component-generation/assets/qt-controls/TreeViewDelegate.qml` + `TreeViewDelegateStyle.qml` | `TreeView`/`TreeViewDelegate` 属 Qt Quick Controls **Qt 6.4+**；Qt 5 的 Controls 1 TreeView 是另一套已废弃 API |
| `mkdocs.yml` 中 MCP Tools 导航节 | 随 docs/mcp 删除 |

## 5. 各 skill 改动明细

### 5.1 qt-cmake-project（改动最大）

- `SKILL.md`：10 条硬性规则全部重写为 Qt5 规范（与上游逐条相反）：
  - 用 `find_package(Qt5 <ver> REQUIRED COMPONENTS ...)`、`add_executable/add_library`、
    `qt5_add_resources/qt5_add_plugin/qt5_add_translation`；
    禁止 `qt_standard_project_setup` / `qt_add_*` / 无前缀 `qt_*`（Qt6 API）；
  - 必须显式 `set(CMAKE_AUTOMOC ON)`（+ AUTOUIC/AUTORCC）与
    `set(CMAKE_INCLUDE_CURRENT_DIR ON)`——Qt5 没有代劳的辅助函数，
    漏配 AUTOMOC 是"undefined reference to vtable"的最常见原因；
  - QML 通过 `.qrc`（或文件系统）+ `engine.load(QUrl("qrc:/..."))` + `qmlRegisterType` 系列注册，
    QML import 必须带版本；
  - 链接一律用 `Qt5::Module` 导入目标（禁用已废弃的 `qt5_use_modules`）；
  - `CMAKE_CXX_STANDARD` 放在 `find_package` 之前。
- `references/` 六个文件全部重写：
  - `simple-project.md`：Qt5 最小工程模板（含 qml.qrc + main.cpp 模板）；
  - `common-mistakes.md`：14 条 LLM 高频错误清单，反向警示 Qt6 写法（§1 Qt6 命令、§2 漏 AUTOMOC、
    §3 手写 moc_/qrc_ 输出、§7 `qrc:/qt/qml/` 路径、§8 注册晚于 load、§9 无版本 import、
    §10 Qt6-only API 清单等）；
  - `modular-architecture.md`：`add_library` + 别名目标 + `VERSION/SOVERSION` +
    `qt5_add_plugin`（含静态插件 `Q_IMPORT_PLUGIN`/`qt5_import_plugins`，注明 5.14+）；
  - `qml-integration.md`：Qt5 没有 `qt_add_qml_module`——qmldir 手写模块、
    `pragma Singleton` + qmldir `singleton` 行、`qmlRegisterSingletonType`（URL 形式与工厂形式）、
    注册必须发生在 `engine.load()` 之前；
  - `resources.md`：`.qrc` 为主（Qt5 中手写 .qrc 不是遗留做法而是标准）、字体
    `QFontDatabase::addApplicationFont`、翻译 `qt5_create_translation/qt5_add_translation`、
    三平台应用图标；
  - `configure.md`：`cmake -B build -DCMAKE_PREFIX_PATH=<Qt5.15 kit>`，Qt5 安装根目录表。

### 5.2 qt-qml

- 删除"每次调用扫描 MCP `run_qmlPreview` 工具 + 校验 Qt ≥ 6.12"整节及 `references/qmlpreview.md`。
- Imports 规则反转：**Qt5 每条模块 import 必须带版本**；字符串 import（`import "..."`）永不带版本；
  `QtQuick.Window 2.15` 需要显式导入；`QtQuick.Controls.Basic` 不存在，
  运行时样式选择用 `QT_QUICK_CONTROLS_STYLE` / `qtquickcontrols2.conf`，
  样式属性用 `import QtQuick.Controls.Material 2.15` 等模块。
- States：`PropertyChanges { target: id; ... }` 是 Qt5 唯一正确形式（`id.prop` 写法为 Qt6）。
- Delegates：`required property` 与 `reuseItems` 标注为 Qt 5.15+。
- Performance：`MultiEffect`（Qt 6.5+）不存在 → 使用 `QtGraphicalEffects`（GaussianBlur/DropShadow 等）。
- 预输出清单同步更新。

### 5.3 qt-qml-review

- **lint 脚本 `references/lint-scripts/qt_qml_lint.py`**（详见 §7.1）。
- `references/qt-qml-review-checklist.md`：删除 IMP-1/IMP-3/IMP-7 与 STA-1 的 Qt6 语义，
  IMP-2 反转为"缺版本号"，新增"QtGraphicalEffects 在 Qt5 是正确模块"的说明；
  BND-1/DEL-1 去除 qmlsc/qmlls 等 Qt6 工具引用。
- `references/agent-rules.md`：标题与语义 Qt5 化；删除 `pragma ComponentBehavior: Bound` 缺失检查
  （Qt 6.5+ 特性）；Context property 建议改为 `qmlRegisterSingletonType`；
  `Binding.restoreMode` 说明改为 Qt5 语义（5.15 引入，更早版本无此属性）。
- `SKILL.md`：描述 Qt5、规则数 48+ → 45+、qmllint 定位改为"语法级检查"（Qt5 qmllint 无语义分析、
  无 `--json`）、探测路径改为 Qt5 kit（`~/Qt*`、`clang_64`、`msvc2019_64`、`mingw81_64`）、
  示例报告行改为 `IMP-2 Unversioned import`。
- `platforms/windsurf.md`：同步压缩版规则。

### 5.4 qt-cpp-review

- **lint 脚本 `references/lint-scripts/qt_review_lint.py`**（详见 §7.2）。
- `references/qt-deprecated-classes.md`：移除 QPair/QSharedDataPointer/QChar 三行（Qt5 中为惯用法），
  新增"Qt5 中不标记"说明段；`q20::make_unique_for_overwrite`（Qt6 shim）改为 std 等价建议。
- `references/qt-framework-checklist.md`：FW-DOC-2 → "What's New in Qt 5.15"；
  FW-VAL-5 反转（Qt5 中 Q_DECLARE_METATYPE 是必需的）；FW-REL-1 去除 q20 依赖；
  FW-SMF-4 去除 `Q_IMPLICIT`（Qt 6.4 宏）。
- `SKILL.md`：Qt5、规则数 60+ → 55+；`references/agent-rules.md`、`qt-review-checklist.md` 标题 Qt5 化；
  `platforms/windsurf.md` 同步。
- `agents/cpp-review-agent.md`："Qt6 C++ reviewer" → "Qt5 C++ reviewer"。
- `tests/qt-cpp-review/`：删除与上述 5 条规则对应的期望项与夹具
  （DEP-5/DEP-6/DEP-13/VAL-6/PAT-6），回归测试保持全绿（见 §8）。

### 5.5 qt-qml-test

- Import 规则：测试文件 `import QtQuick 2.15` + `import QtTest 1.15`（原规则"不带版本"）。
- **`references/qt-quick-test-source-import.md` 整体重写**：Qt6 的
  `qt_add_qml_module`/库-可执行分类不存在；Qt5 判定树改为
  （1）`qmlRegisterType/qmlRegisterSingletonType` 注册或磁盘 qmldir 模块 → 版本化 `import <URI> <maj.min>`；
  （2）其余 → 相对路径 `import "../..."`；并说明 qrc-only 资源不能被磁盘测试相对导入的边界。
- 原"Qt Quick 3D 源跳过"规则（rule 45）删除，rule 46/47 重编号为 45/46（共 46 条），
  全部引用点（SKILL.md、rules、pitfalls、pre-send-scan、copilot 变体）同步。
- `QT_QML_SINGLETON_TYPE TRUE`（Qt6 CMake 属性）全部替换为 qmldir `singleton` 行 /
  `qmlRegisterSingletonType` 语义。
- `references/qt-quick-test-template.md`：模板 import 全部版本化；Variant 7 的 URL 表改为
  Qt5 判定（测试二进制自身 qrc 可达 → `qrc:/<Prefix>/<Path>`；否则 `Qt.resolvedUrl("../..")`），
  移除 `qrc:/qt/qml/` 路径与 `availableStyles: ["Basic"]` 示例值。
- `references/qt-quick-test-project-context.md`：上下文读取从 grep `qt_add_qml_module URI` 改为
  grep `qmlRegisterType`/`qmlRegisterSingletonType`/`qmlRegisterUncreatableType`。
- `platforms/copilot.prompt.md`：自包含变体同步上述全部改动。

### 5.6 qt-qml-test-run

- **`references/qt-quick-test-cmake.md` 整体重写（491 行 → Qt5 版）**：
  - 接线模板：`find_package(Qt5 5.15 REQUIRED COMPONENTS QuickTest)` + `add_executable` +
    `set(CMAKE_AUTOMOC ON)`（Qt5 无自动设置）；Widgets/Charts/WebEngineWidgets 变体判定保留；
  - 删除 Qt6 特有的 module-on-executable 重构与 STATIC 插件机制；
    新增"项目如何暴露 QML 类型"检测（注册库链接 / qrc 归属 / 磁盘 qmldir + `-import`）；
  - 常见失败清单改为 Qt5 语义（QuickTest 包安装、AUTOMOC 缺失、`-import` 路径等）；
  - 保留 JUnit 直连二进制输出（`-o report.xml,junitxml`）与检测模式。
- `SKILL.md`：Step 3 异常条件改为"C++ 注册的 URI 直连 qmltestrunner 无法解析 → 必须接线"；
  Step 4a 从 module-on-executable 检查改为"项目 QML 类型暴露检查"；Step 4b 跳过条件 Qt5 化；
  Qt 安装路径表改 5.x（`/home/*/Qt5.*/5.*/gcc_64`、`/usr/lib/qt5`、`clang_64`、`mingw81_64`）。

### 5.7 qt-qml-profiler

- `SKILL.md`：Qt 安装探测路径全面改为 5.x；`$Qt6_DIR` → `$Qt5_DIR`；
  qrc 源映射说明改为 `qrc:/<prefix>/<File>.qml`（Qt5 无隐式 `qrc:/qt/qml/` 前缀）；
  Quick 3D 范围说明收敛为安全护栏（Qt5 标准应用无 3D 事件）。
- `references/scripts/parse-qmlprofiler-trace.py` 与 `qml-performance-anti-patterns.md`
  为格式级实现（.qtd 格式 Qt5.15 一致），未做语义改动。

### 5.8 qt-figma-token-extraction

- Step 0：脚手架 `main.cpp` 从 `engine.loadFromModule()` 改为
  `engine.load(QUrl("qrc:/main.qml"))`；删除 `qrc:/qt/qml/` 与 `_qs` 的 Qt6 注记；
  占位 `Main.qml` 改回 `main.qml` 并版本化 import。
- Step 6 生成规则：import 必须带版本；效果模块从 `MultiEffect`/`QtQuick.Effects` 改为
  `import QtGraphicalEffects 1.15`；单例注册从 CMake `set_source_files_properties` 改为
  `qmlRegisterSingletonType`。
- Step 7：CMake 模板整体替换为 Qt5 版（AUTOMOC/AUTORCC + `qml.qrc`），
  并给出 `main.cpp` 中四个单例的 `qmlRegisterSingletonType` 注册示例（URL 形式 + 工厂形式）。
- Step 8 汇总与 Token Categories Checklist 同步。
- `references/token-mapping.md`：阴影 token 从 `MultiEffect` 归一化 blur（0.0–1.0）改为
  `DropShadow` 像素 radius + samples 的映射示例。
- `examples/` 5 个 QML 模板随 §6 通用转换同步。

### 5.9 qt-figma-component-generation

- Base type 选择表：`(from QtQuick.Controls.Basic)` → `(from QtQuick.Controls 2.15)`。
- Step 7 收尾建议从 `qt_add_qml_module QML_FILES` 改为"加入项目 `qml.qrc` +
  `qmlRegisterType` 注册"。
- 使用示例 import 版本化；skill 引用名 `qt-development-skills:qt-qml` → `qt-qml`。
- `assets/qt-controls/` 77 个 QML + `references/` 5 个 QML 随 §6 通用转换同步；
  删除 `TreeViewDelegate*.qml` 两个文件。

### 5.10 qt-cpp-docs / qt-qml-docs / qt-ui-design（轻量）

- 三个 SKILL.md 元数据 Qt5 化。
- qt-cpp-docs §13 QML Exposure：注册方式从 `QML_ELEMENT`/`QML_SINGLETON` 宏改为
  `qmlRegisterType`/`qmlRegisterUncreatableType`/`qmlRegisterSingletonType`（Qt5 无注册宏）。
- qt-ui-design：样式清单改为 Qt5 的 Default/Fusion/Imagine/Material/Universal
  （iOS、FluentWinUI3 为 Qt 6.7+）；TypeScale 单例注册示例从 `qt_add_qml_module` 改为
  qmldir + `engine.addImportPath`；`prefers-reduced-motion` 段措辞 Qt5 化；
  文档链接 `doc.qt.io/qt-6/...` → `doc.qt.io/qt-5.15/...`。

## 6. figma assets 的通用脚本化转换

`assets/qt-controls/`（77 文件）、`references/`（5 文件）、token-extraction `examples/`（5 文件）
通过脚本统一转换：

| 转换项 | 规则 |
|---|---|
| import 版本化 | QtQuick→2.15、QtQuick.Window→2.15、QtQuick.Controls→2.15、QtQuick.Layouts→1.15、QtQuick.Templates→2.15、QtGraphicalEffects→1.15、QtTest→1.15、QtQml.Models→2.15、QtQuick.Shapes→1.15 等；**带 `as` 别名的 import 同样处理** |
| 样式导入 | `import QtQuick.Controls.Basic` → `import QtQuick.Controls 2.15`（Qt5 无 Basic 样式） |
| Qt6 pragma | 删除所有 `pragma ComponentBehavior: Bound` 行（Qt 6.5+） |
| 类型化函数注解 | `function f(...): int` → `function f(...)`（避免 5.15 之前的解析差异） |
| 项目自有 URI | `import Qt.Fonts as Fonts`、`import Qt.Themes as Themes` 等保留无版本——它们是演示工程自有模块的占位符，实际使用时应替换为项目注册的 URI+版本 |

其余 Qt5.15 已支持的特性（`required property`、inline components、`HoverHandler` 等）保留。

## 7. Lint 脚本改动明细

### 7.1 qt_qml_lint.py（QML linter，45+ 规则）

- **IMP-2 反转**：原"版本号 import 报错"（Qt6）→ 现"无版本 Qt 模块 import 报错"
  （`import QtQuick` 命中，`import "qrc:/..."`、`import ..` 不命中）。
- 删除 Qt6 专属规则：IMP-1（QtQuick.Window 冗余）、IMP-3（Controls.Basic 样式限定）、
  IMP-7（QtGraphicalEffects 导入报错——Qt5 中它是正确模块）、STA-1（PropertyChanges `target:`
  弃用警告——Qt5 中它是唯一正确形式）。
- 消息修正：BND-1/DEL-1 去除 qmlsc 引用；IMP-4 说明去除 `qmlformat --sort-imports`（Qt6 工具）。
- **qmllint 集成重写**：Qt5 的 qmllint 是语法级检查器（无 `--json`、无警告 ID），
  `run_qmllint()` 改为文本输出解析（`Warning: file:line: msg` 及容错回退，
  无法定位的行聚合为行 0 的 `QL` finding）；kit 探测改为 Qt5：
  `qtpaths/qmake`（去掉 `*6` 变体）、安装器根目录 glob `~/Qt*`（兼容 Qt5 安装器的
  `~/Qt5.15.2/5.15.2/<kit>` 双层布局）、版本正则 `5\.(\d+)\.(\d+)`。
- 复用相关规则保留：`reuseItems`/DEL-2/DEL-4（Qt 5.15 引入）、SIG-2（5.15 起弃用旧式
  `onFoo:`，与 Qt5 一致）。

### 7.2 qt_review_lint.py（C++ linter，55+ 规则）

删除 5 条 Qt6 才成立的规则并同步清理正则与测试夹具：

| 规则 | 删除原因 |
|---|---|
| DEP-5 QPair→std::pair | QPair 在 Qt5 是惯用类型（Qt 6.0 起才成为别名） |
| DEP-6 QSharedDataPointer→QExplicitly… | QSDP 是 Qt5 标准的 COW 惯用法 |
| DEP-13 QChar→char16_t | QChar 是 Qt5 正常字符类型 |
| VAL-6 Q_DECLARE_METATYPE 移除 | Qt5 中 QVariant/排队信号参数必需它 |
| PAT-6 q20::make_unique_for_overwrite | `q20::*` 是 Qt6 内部 shim |

其余 DEP 规则（QScopedPointer→unique_ptr、foreach→range-for、qMin→std::min 等）为通用现代
C++ 建议，Qt5 亦成立，保留。TMO-1 的 `QDeadlineTimer` 为 Qt 5.8+，保留。

## 8. 测试与验证记录

| 验证项 | 结果 |
|---|---|
| `tests/qt-cpp-review/run_tests.py`（C++ linter 回归） | **55/55 universal + 3/3 framework + `--diff` 模式全部通过**（测试夹具同步移除已删规则） |
| QML linter 冒烟（构造样例） | 无版本 import 正确触发 IMP-2；`QtGraphicalEffects 1.15` 不再误报；`PropertyChanges target:` 不再报 STA-1；IMG-1/IMG-2/BND-1 等常规规则正常 |
| QML linter 对 figma examples 实跑 | 正常输出 9 项发现（ORD/STY），无脚本异常 |
| 全仓 grep 复查 | QML assets 中 Qt6 构造零残留；SKILL.md 中仅存的 "Qt 6" 字样均为防御性警示（"Qt5 中不要写 X"类）；无版本 Qt import 残留 0 |
| 两个 lint 脚本 `ast.parse` | 语法通过 |

## 9. 配套设施与元数据改动

| 文件 | 改动 |
|---|---|
| `README.md` | 重写：Qt5 定位与移植说明、12 skill 表、删除项说明、安装命令（`qt5-development-skills`）、仓库结构（去 mcp/）、示例 frontmatter（`qt-version: "5.15"`）、文档站章节精简 |
| `.claude-plugin/plugin.json` | 插件名 `qt-development-skills` → `qt5-development-skills`，版本 1.8.0 → 1.0.0，描述去除 MCP 措辞 |
| `.claude-plugin/marketplace.json` | 同步改名/改版本；keywords 增加 `qt5`、去除 `mcp`；repository URL 指向 wuqingwei/agent-skills |
| `gemini-extension.json` | name → `qt5skills`，描述 Qt5 化 |
| `mkdocs.yml` | site_description Qt5 化；删除 MCP Tools 导航；repo_url 指向 wuqingwei/agent-skills |
| `docs/index.md` / `docs/getting-started.md` | 重写：去除 MCP 卡片/章节，突出"模型会拿 Qt6 写法伤害 Qt5 项目"的定位；安装命令更新 |
| `docs/skills/requirements.md` | 每行依赖 Qt5 化（qmlprofiler/qmltestrunner 5.15、CMake 3.5+、生成测试使用版本化 import 等） |
| `docs/skills/concepts.md` | 触发词描述 Qt6→Qt5 |
| `gen_skills.py` | `GITHUB_BLOB` 指向 wuqingwei/agent-skills |
| `CONTRIBUTING.md` | 示例 description Qt6→Qt5 |
| `agents/cpp-review-agent.md` / `agents/qml-review-agent.md` | "Qt6 … reviewer" → "Qt5 … reviewer" |
| `tools/`、`LICENSE`、`overrides/`、`requirements-docs.txt` | 未改动（工具脚本与品牌样式与 Qt 版本无关） |

## 10. 已知限制与注意事项

1. **Qt 版本下限**：规则与示例假设 5.15。若项目低于 5.15，`required property`、
   `createTemporaryObject`、`ListView.reuseItems`、inline components、`Binding.restoreMode`
   不可用，需按各规则文件中注记回退。
2. **qmllint 仅语法级**：Qt5 的 qmllint 不做语义/类型检查，qt-qml-review 的类型级问题
   靠 Python linter + 深度分析 agent 兜底。
3. **figma assets 中的项目占位 URI**：`import Qt.Fonts as Fonts`、`import Qt.Themes as Themes`
   为演示工程自有模块占位，实际接入需替换为项目注册的 URI+版本。
4. **docs 站点**：MkDocs 导航已更新，`mkdocs serve/build --strict` 未在本环境跑过
   （缺 Python 依赖），发布前建议本地验证一次。
5. **上游同步**：上游仍以 Qt6 为主演进；合并上游提交时，Qt6 相关改动需要人工评审后再带入。
6. **许可与品牌**：保留上游 BSD-3-Clause 与 The Qt Company 版权头；Qt 商业许可条款提示语未动。

## 11. 安装与使用（速览）

```bash
# Claude Code（插件方式）
/plugin marketplace add wuqingwei/agent-skills
/plugin install qt5-development-skills

# 或单 skill 拷贝
cp -r skills/qt-qml-review ~/.claude/skills/qt-qml-review
# 审查类 skill 建议同时安装 review agents：
cp agents/cpp-review-agent.md agents/qml-review-agent.md ~/.claude/agents/
```

其余平台（Codex CLI / Copilot / Gemini / Cursor / Windsurf）见 `README.md` 安装章节。

## 12. 快速变更文件索引

- 删除：`skills/qt-canvas2d/**`、`mcp/**`、`.mcp.json`、`docs/mcp/**`、
  `skills/qt-qml/references/qmlpreview.md`、
  `skills/qt-figma-component-generation/assets/qt-controls/TreeViewDelegate*.qml`
- 全部重写：`skills/qt-cmake-project/**`（SKILL + 6 references）、
  `skills/qt-qml-test-run/references/qt-quick-test-cmake.md`、
  `skills/qt-qml-test/references/qt-quick-test-source-import.md`、
  `README.md`、`docs/index.md`、`docs/getting-started.md`
- 重点修改：两个 lint 脚本及其 references、qt-qml / qt-qml-test / qt-qml-profiler /
  qt-figma-*/ 的 SKILL.md 与 references、全部 figma QML assets（87 个）、
  平台变体（windsurf ×4、copilot ×1）、agents ×2、tests/qt-cpp-review、
  插件与站点元数据（plugin/marketplace/gemini/mkdocs/gen_skills/CONTRIBUTING/docs/skills）

完整差异以 git 历史为准：`git log -1 --stat` 与 `git show`。

## 13. 交接提交说明

- 本提交基于上游 `main`（fetch 后工作树叠加适配改动），单一提交包含全部移植内容，
  便于 review 与回溯；如需拆分，可按 §12 的索引分批 cherry-pick。
- 后续如需继续维护：新增/修改 skill 时沿用上游格式约定
  （SKILL.md frontmatter、progressive disclosure、platforms/ 变体），并遵守本文 §3、§6 的 Qt5 基线规则。
