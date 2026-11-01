---
trigger: model_decision
description: "Review Qt5 QML code for correctness and best practices"
---

# Qt QML Review

**Imports**: Version numbers required on every module import
(`import QtQuick 2.15`). Sort: Qt modules, third-party, local, QML
folders. `QtGraphicalEffects 1.15` is the correct effects module.

**Bindings**: Use typed properties not `property var`. Imperative `=`
destroys bindings. Watch for multi-cycle binding loops.

**Layout**: Never mix anchors + Layout.* on same item. No bare
width/height on Layout children; use Layout.* properties. Do not
anchor to invisible items. No parent.parent in anchor targets.

**Loader**: Guard Loader.item with status check. No
Qt.createComponent(url) strings. No Qt.createQmlObject(). Track and
destroy dynamic objects.

**Delegates**: Use `required property` for roles (Qt 5.15+). Also
declare `required property int index` when index is accessed. No var
in delegates with reuseItems. No connect() in Component.onCompleted.

**States**: PropertyChanges uses `target: id; prop: val` (the Qt 5
form; `id.prop: val` is Qt 6 only). Transitions need explicit
from/to. No imperative = in PropertyChanges.

**Signals**: Connections must have explicit target. Use
`function onFoo()` syntax (Qt 5.15+). Never mix old and new syntax in
same Connections block.

**Performance**: Use Item not transparent Rectangle for grouping.
visible: false not opacity: 0. Text.PlainText when possible. Cache
expensive bindings in readonly property.

**Images**: Always set sourceSize. asynchronous: true for network
sources. Check Image.status for error handling on dynamic sources.

**JS**: let/const not var. Strict === not ==.

**Errors**: Use https:// not http://. No hardcoded Unix paths
like /tmp/ -- use QStandardPaths.
