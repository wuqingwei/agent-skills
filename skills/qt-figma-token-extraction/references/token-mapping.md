# Figma Variable Type → QML Type Mapping

Read this file before generating any QML properties. Apply these rules to every token in `design-tokens.json`.

---

## Type Mapping Table

| Figma type | Token category | QML property type | Notes |
|---|---|---|---|
| `COLOR` | colors, semanticColors | `readonly property color` | Use hex string `"#rrggbb"` or `"#aarrggbb"` for alpha. Never use `Qt.rgba()` unless the value has a non-1.0 alpha. |
| `FLOAT` — whole pixel size | spacing, radii, icon sizes, border widths, font sizes | `readonly property int` | Use only when the value is truly whole. Round if Figma exports a near-integer. |
| `FLOAT` — fractional size | letter spacing, line height, `font.pointSize` | `readonly property real` | Keep the decimal. Rounding letter spacing or line height loses fidelity; rounding 0.5 px border doubles a hairline stroke. |
| `FLOAT` — font weight | typography | `readonly property int` | **Qt 5 uses the 0–99 `Font.Weight` scale** (not Qt 6's 100–900 OpenType scale). Map Figma weights to `Font.*` constants: Thin→`Font.Thin` (0), ExtraLight→`Font.ExtraLight` (12), Light→`Font.Light` (25), Regular→`Font.Normal` (50), Medium→`Font.Medium` (57), SemiBold→`Font.DemiBold` (63), Bold→`Font.Bold` (75), ExtraBold→`Font.ExtraBold` (81), Black→`Font.Black` (87). Passing 400–900 to `font.weight` in Qt 5 clamps out-of-range values to Black. |
| `FLOAT` — opacity / scale | effects | `readonly property real` | Keep as decimal (0.0–1.0). Do not convert to int. |
| `STRING` | font families, text content | `readonly property string` | Use double-quoted string literals. |
| `BOOLEAN` | feature flags, states | `readonly property bool` | `true` / `false`. |
| `EFFECT` — drop shadow | shadows | Multiple typed properties | Split into individual typed properties — see Shadow Tokens below. |

---

## Color Values

Always write color values as string literals — never as `color` function calls unless necessary:

```qml
// Correct
readonly property color background_primary: "#ffffff"
readonly property color overlay_dark: "#80000000"   // 50% black (ARGB format)

// Avoid unless alpha is a variable
readonly property color overlay_dark: Qt.rgba(0, 0, 0, 0.5)
```

For multi-mode (Light/Dark) semantic colors, use a ternary on `isDark`:

```qml
readonly property color background_primary: isDark ? "#1f1f1f" : "#ffffff"
```

---

## Spacing and Size Values

Use `int` only when the value is truly whole. Use `real` when the value can be fractional.

```qml
// Whole pixel values → int
readonly property int x4:              8     // spacing
readonly property int corner_radius_m: 8     // radius
readonly property int h1_size:         36    // font size (px)
readonly property int border_width:    1     // border (truly 1 px)

// Fractional values → real
readonly property real h1_line_height:   1.5   // line height multiplier
readonly property real h1_letter_spacing: 0.0  // letter spacing (px, often fractional)
```

If Figma exports a spacing or radius as a near-integer decimal (e.g. `8.0`), use `int`. If it is genuinely fractional (e.g. `0.5` border), keep it as `real` — do not round:

```qml
readonly property real border_width_subtle: 0.5  // Figma: 0.5px — keep as real
```

---

## Typography Values

Font families and font weight names map as follows:

```qml
// Font family — always a string
readonly property string font_family_heading: "Titillium Web"
readonly property string font_family_body:    "Inter"

// Font weight — always an int using Qt 5's Font.Weight enum (0–99 scale, NOT 100–900)
readonly property int weight_thin:       Font.Thin        // 0  (Figma 100)
readonly property int weight_light:      Font.Light       // 25 (Figma 300)
readonly property int weight_regular:    Font.Normal      // 50 (Figma 400)
readonly property int weight_medium:     Font.Medium      // 57 (Figma 500)
readonly property int weight_semi_bold:  Font.DemiBold    // 63 (Figma 600)
readonly property int weight_bold:       Font.Bold        // 75 (Figma 700)
readonly property int weight_extra_bold: Font.ExtraBold   // 81 (Figma 800)
readonly property int weight_black:      Font.Black       // 87 (Figma 900)
```

In Theme.typography, refer to the named weight constants rather than raw numbers where possible:

```qml
readonly property int h1_weight: weight_semi_bold   // Font.DemiBold (63)
```

---

## Shadow / Effect Tokens

Figma EFFECT tokens (drop shadows) have no direct QML equivalent. Store them as individual typed properties, then apply via `DropShadow` from `import QtGraphicalEffects 1.15`.

> **Qt 5 uses `QtGraphicalEffects`.** There is no `MultiEffect` / `QtQuick.Effects` and no `Qt5Compat.GraphicalEffects` in Qt 5 — `DropShadow` and friends live in `QtGraphicalEffects`. `DropShadow` takes pixel values directly (`radius`, `samples`); store Figma's pixel blur as a token and bind it as-is.

```qml
// ── Shadow / Low ──────────────────────────────────────────────────────────
// Figma: Shadow/Low — offset(0,1), blur 3px, spread 0, rgba(0,0,0,0.12)
// Note: spread has no DropShadow equivalent — omit or approximate with radius
readonly property int   shadow_low_offset_x: 0
readonly property int   shadow_low_offset_y: 1
readonly property real  shadow_low_blur:     3     // pixels — DropShadow.radius
readonly property color shadow_low_color:    "#1f000000"  // 12% opacity black
```

Usage in a QML component:

```qml
import QtGraphicalEffects 1.15

DropShadow {
    source:                theItem
    anchors.fill:          theItem
    color:                 Theme.shadow_low_color
    horizontalOffset:      Theme.shadow_low_offset_x
    verticalOffset:        Theme.shadow_low_offset_y
    radius:                Theme.shadow_low_blur
    samples:               9   // odd value >= 2 * radius + 1 for quality
}
```

---

## What NOT to Do

- Do not use `var` — always use a typed property
- Do not use `property` without `readonly` for design tokens — tokens are immutable
- Do not mix types (e.g. assigning a hex string to an `int` property)
- Do not leave Figma internal alias names (e.g. `{Global/Neutral/000}`) as values — all aliases must be resolved to concrete values before writing QML
