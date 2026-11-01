# Qt5 QML Review Checklist (linter rules)

Rationale for every rule enforced by `qt_qml_lint.py`. The linter
message carries the actionable part; this file is the long-form
reference for humans and for writing mitigations. Semantic rules that
need an agent live in `agent-rules.md`.

**Token note**: the orchestrator does not need to load this file
during a review -- lint messages are self-describing. Consult it only
when a mitigation needs more background than the message gives.

---

## 1. Imports

### IMP-2: Unversioned imports
Qt 5 requires explicit major.minor versions on every module import.
`import QtQuick` alone fails to resolve ("module not installed").
Always write `import QtQuick 2.15`, `import QtQuick.Controls 2.15`,
`import MyModule 1.0`, etc. Versionless imports are a Qt 6 relaxation.
(String imports such as `import "qrc:/..."` never take versions.)

### IMP-4: Import ordering
Order imports: Qt modules first, then third-party, then local C++,
then QML folder imports. Consistent ordering aids readability.
If this causes shadowing issues, because types with the same name
are defined in various modules, use a namespaced import:
`import mymodule 1.0 as MM`

### IMP-5: Qt.include() deprecated
`Qt.include()` was deprecated in Qt 5.14. Use ES module imports or
explicit QML imports instead.

### IMP-6: Duplicate imports
The same module imported more than once. Remove the duplicate.

### Note: QtGraphicalEffects is correct in Qt 5
`import QtGraphicalEffects 1.15` is the standard Qt 5 way to get
blur, glow, desaturation and similar effects. (`MultiEffect` and
`QtQuick.Effects` are Qt 6.5+ and do not exist in Qt 5.)

---

## 2. Attribute Ordering

### ORD-1: QML attribute ordering convention
Within each QML object block, attributes must appear in this order:

1. `id`
2. Property declarations (`property type name`, `required property`)
3. Signal declarations (`signal name()`)
4. Property assignments (`width: 100`, `color: "red"`)
5. Attached properties (`Layout.fillWidth`, `Drag.active`)
6. `states`
7. `transitions`
8. Signal handlers (`onClicked`, `Component.onCompleted`)
9. Child objects (visual first, then non-visual)
10. JavaScript functions

This ordering ensures the most intrinsic properties are visible
first. Signal handlers should be grouped by semantic relation,
and ordered shortest-first as a fallback.

The linter reports only the first ordering violation per block.
Blocks with special internal structure (Connections, Behavior,
animation types, State, Transition, PropertyChanges) are exempt.

---

## 3. Bindings & Properties

### BND-1: property var
Use typed properties (`int`, `string`, `color`, etc.) instead of
`property var`. Typed properties enable type checking and cheaper
property access, and eliminate meta-object overhead.

### BND-2: Imperative = destroys binding
Any `property = value` in JavaScript permanently replaces the
declarative binding with a static value. Use `Qt.binding(() => expr)`
to restore reactivity if needed. The `qt.qml.binding.removal`
logging category (Qt 5.10+) is the only runtime diagnostic. qmllint
does NOT detect this.

### BND-3: Qt.binding with old-style function
Use arrow syntax: `Qt.binding(() => expr)` not
`Qt.binding(function() { return expr })`. Arrow functions avoid
`this` context issues inside `Qt.binding()`.

### BND-5: list<> property type
QML `list` properties have no granular change signals for add, move,
or remove. Only whole-list replacement triggers notification. Binding
expensive operations to list properties causes subtle update bugs.
Consider a `ListModel` or emit change signals manually.

---

## 4. Layout & Anchoring

### LAY-1: anchors + Layout on same item
Anchors and `Layout.*` properties conflict. An item managed by a
Layout must use only `Layout.*` for sizing and positioning.

### LAY-2: Bare width/height inside Layout child
Setting `width` or `height` directly on a Layout-managed item
silently breaks the layout's size negotiation. Use
`Layout.preferredWidth`, `Layout.fillWidth`, etc.

### LAY-3: Four anchor edges instead of fill
Setting `anchors.left`, `anchors.right`, `anchors.top`, and
`anchors.bottom` separately to the `parent`'s values is verbose.
Use `anchors.fill: parent`.

### LAY-5: Anchoring to parent.parent
Anchors must only point to the `parent` or sibling items.
`parent.parent` is a fragile cross-branch reference that breaks as
soon as the component is reparented.

### LAY-6: Bare x/y inside Layout child
Layouts manage positioning. Setting `x:` or `y:` on a layout child
is ignored by the layout engine and creates confusion.

---

## 5. Loader & Dynamic Creation

### LDR-1: Loader.item without status guard
With `asynchronous: true`, `Loader.item` is `null` until
`status === Loader.Ready`. Binding to `Loader.item.someProp` without
a guard causes `TypeError`. Use optional chaining (`?.`) or gate on
`Loader.status`.

### LDR-2: Qt.createComponent with string URL
String-based `Qt.createComponent()` is not type-safe and is not supported
by QML tooling. Prefer `Component {}` definitions, or the module URI +
type name overload of `Qt.createComponent`.

### LDR-3: Qt.createQmlObject
Parses a QML string at runtime on every call. No component caching.
Slow and error-prone. Use `Loader` or `Component.createObject()`.

### LDR-5: Loader with both source and sourceComponent
These are mutually exclusive. Setting both is confusing, as the
behavior is unspecified.

---

## 6. ListView & Delegates

### DEL-1: model.roleName without required property
Modern best practice (Qt 5.15+) is to declare `required property` for
each model role. Once any required property is declared, the implicit
`model` context object is no longer injected (but can also be explicitly
requested as a `required property`). Required properties give type
safety and better tooling support. On Qt 5 versions older than 5.15 the
`model.<role>` access is the only option — this rule still helps flag
the migration to 5.15+ code.

### DEL-2: state in delegate with reuseItems
With `reuseItems: true`, a delegate is pooled and rebound rather
than recreated. Bindings to model roles re-evaluate automatically;
all other state persists across reuse and bleeds between items.
Reset non-model-derived state in `ListView.onReused`
(`Component.onCompleted` runs only once, at first creation).

### DEL-3: connect() in Component.onCompleted without receiver
Direct `connect()` without a receiver creates signal connections that
outlive delegate destruction, causing `TypeError` when the signal fires
on a destroyed delegate. Use `Connections {}` objects instead, or pass
an explicit receiver.

### DEL-4: Component.onCompleted with reuseItems
With `reuseItems: true`, a pooled delegate is not recreated, so
`Component.onCompleted` does not fire again when it is reused. Move
per-item initialisation to `ListView.onReused`. (The related check
for a missing `required property int index` needs the delegate
context and is an agent rule, A4.)

---

## 7. States & Transitions

### STA-1: PropertyChanges syntax (retired for Qt 5)
`PropertyChanges { target: myId; property: value }` is the correct and
only form in Qt 5. The `PropertyChanges { myId.property: value }`
syntax is a Qt 6 relaxation and does not parse on Qt 5. This rule is
therefore not enforced by the linter for Qt 5 code.

### STA-2: Transition without from/to
A `Transition {}` without explicit `from`/`to` fires on every state
change, including unintended ones. Use explicit `from`/`to` pairs.
If there are multiple rules, a catch-all transition will only be picked
if no other rule matches either on `from` or `to`.

### STA-3: Top-level states in reusable component
`states` is a `QQmlListProperty` -- assigning from outside a
component *adds* to the existing list rather than replacing it,
causing conflicts. Wrap internal states in a `StateGroup`. Only
flagged when the file has `required property` declarations
(indicating it is a reusable component).

### STA-4: PropertyChanges instead of imperative assignments
Drive state-dependent property values through declarative PropertyChanges
blocks rather than assigning properties imperatively (`obj.prop = ...`)
from signal handlers or scripts. Only the declarative form participates in
`restoreEntryValues`, so original values/bindings are restored when the
state is left.

---

## 8. Images

### IMG-1: Image without sourceSize
Without `sourceSize`, Qt decodes the full-resolution image into GPU
memory. A 4000x3000 photo displayed at 100x75 still allocates ~48MB
of texture memory. Set `sourceSize` to display dimensions for large
images.

### IMG-2: Network Image without asynchronous: true
Image decoding blocks the UI thread by default. For network sources,
the entire download+decode is synchronous without `asynchronous: true`.

---

## 9. Performance & Rendering

### PRF-1: Transparent Rectangle
`Rectangle { color: "transparent" }` creates a scene graph geometry
node even when transparent. Use `Item` for grouping -- it generates
no geometry node. The cost compounds in delegates.

### PRF-2: opacity: 0 without animation
`opacity: 0` still incurs rendering overhead and retains keyboard
focus. `visible: false` skips rendering entirely and removes from
input handling. Use `opacity: 0` only during fade animations.
Suppressed when the file contains opacity animation declarations.

### PRF-3: clip: true
Qt docs: "Clipping is a visual effect, NOT an optimization." Forces a
separate scene graph batch (scissor/stencil). Acceptable on ListView
(many children) but costly on small items.

### PRF-4: font.pixelSize animation
Every `font.pixelSize` change triggers full text relayout (glyph
shaping, line breaking). Use a `scale` transform on the `Text`
element for size animations instead.

### PRF-5: Text.RichText
RichText invokes a full HTML/CSS parser, significantly more expensive
than PlainText or StyledText. Use `textFormat: Text.PlainText` unless
rich formatting is needed.

### PRF-6: layer.enabled
Renders the subtree to an offscreen FBO, then composites as texture.
The layered item cannot be batched with siblings. Multisampling on
layers is especially expensive. Enable only during effects/animations.

---

## 10. Style & Conventions

### STY-1: Top-level component missing id: root
The QML convention is `id: root` on the top-level component. This
enables qualified lookup (`root.someProperty`).

### STY-3: Multiple dot-notation for same group
When setting 3+ sub-properties of the same group (e.g.,
`sourceSize.width`, `sourceSize.height`, `sourceSize...`), use group
notation instead: `sourceSize { width: 32; height: 32 }`. Attached
property namespaces (Layout, Component, etc.) are exempt.

### STY-6: id not camelCase
QML convention is `lowerCamelCase` for ids. Underscore or UPPER ids
break convention.

---

## 11. Signals & Connections

### SIG-1: Connections without explicit target
Default target is `parent`, which causes unintended signal handling
if the parent type changes. Always set `target` explicitly. Set
`target: null` if the real target is assigned later at runtime.

### SIG-2: Deprecated onFoo: handler syntax
The `onFoo:` syntax in `Connections` blocks is deprecated since
Qt 5.15. Use `function onFoo() {}` instead.

### SIG-3: Mixed handler syntax in Connections
Mixing old `onFoo:` handlers with new `function onFoo()` handlers in
the same `Connections` block silently ignores the function-based
handlers. Use one style consistently.

---

## 12. Error Handling & Security

### ERR-1: Hardcoded HTTP URL
Unencrypted `http://` URLs expose data in plaintext. Use `https://`
for any network endpoint. Localhost and test URLs are excluded.

### ERR-2: Hardcoded Unix paths
`/tmp/` and other Unix-specific paths do not exist on Windows. Qt
provides `QStandardPaths::writableLocation(QStandardPaths::TempLocation)`
for cross-platform temporary file access.

---

## 13. JavaScript Quality

### JS-1: var instead of let/const
`var` has function scope and hoisting, causing subtle bugs. `let` and
`const` have block scope. Qt coding instructions mandate `let`/`const`.

### JS-2: Loose equality
Loose equality (`==`/`!=`) performs type coercion, which is almost
never desired in QML property comparisons. Use strict equality
(`===`/`!==`).

### JS-3: Dynamic code execution
Dynamic JS code execution (such as the `eval` function) blocks JIT
compilation in QV4 and is a security risk. qmllint flags it. There
is never a valid use case in QML.

---

Copyright (C) 2026 The Qt Company.
