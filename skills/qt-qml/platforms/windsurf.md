---
trigger: model_decision
description: "Apply Qt5 QML best practices when writing or modifying QML code"
---

# QML Best Practices

**Imports (Qt 5)**: Version numbers required on every module import
(`import QtQuick 2.15`, `import QtQuick.Controls 2.15`,
`import MyModule 1.0`). String imports (`import "qrc:/..."`) never
take versions.

**Bindings**: Prefer declarative `prop: expr` over imperative `=`.
Imperative `=` permanently destroys bindings. Cache expensive
expressions in `readonly property`. No circular dependencies.

**Layouts**: Never mix anchors + Layout.* on same item. Size Layout
children with Layout.* only -- bare width/height breaks negotiation.
Do not anchor to invisible items or across tree branches.

**Loader**: Use for conditional UI. Guard item with status check.
No Qt.createComponent(url) strings -- use inline Component {}.
createObject() only when parent is dynamic.

**Delegates**: Use `required property` for roles (Qt 5.15+). Keep
delegates minimal. reuseItems: true (Qt 5.15+), reset in onPooled.
No mutable JS vars in delegates.

**States**: PropertyChanges uses `target: id; prop: val` in Qt 5
(`id.prop: val` is Qt 6 only). Target transitions with from/to.

**Images**: Always set sourceSize. asynchronous: true for network
or large files. Check Image.status.

**Pitfalls**: `parent` in delegates is the internal container, not
ListView -- use ListView.view. Dynamic scope is fragile -- use
explicit id refs. Timer.running defaults to false. Connections
targets one object -- use multiple blocks for multiple sources.
