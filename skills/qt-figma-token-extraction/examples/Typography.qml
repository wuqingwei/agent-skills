// Copyright (C) 2026 The Qt Company Ltd.
// SPDX-License-Identifier: LicenseRef-Qt-Commercial OR BSD-3-Clause
// Typography.qml — [Project] Design System — Typography Tokens
// Source: design-tokens.json › typography
// Qt 5: register in main.cpp via qmlRegisterSingletonType(QUrl("qrc:/design-system/Typography.qml"), uri, 1, 0, "Typography")
// Usage:
//   font.family:    Typography.body
//   font.pixelSize: Typography.label_m_size          // 12 px
//   font.weight:    Typography.label_m_default_weight  // Font.Medium (57)
pragma Singleton
import QtQuick 2.15

QtObject {
    // ── Font families ──────────────────────────────────────────────────────────
    // Resolved via FontInterface at runtime — FontInterface must be loaded first.
    readonly property string body:    FontInterface.interFont.name
    readonly property string mono:    FontInterface.inconsolata.name
    readonly property string display: FontInterface.titilliumSemiBold.name

    // ── Font weights (Qt 5 Font.Weight enum: 0–99 scale, NOT Qt 6 100–900) ─────
    readonly property int regular:   Font.Normal    // 50 (Figma 400)
    readonly property int medium:    Font.Medium    // 57 (Figma 500)
    readonly property int semi_bold: Font.DemiBold  // 63 (Figma 600)
    readonly property int bold:      Font.Bold      // 75 (Figma 700)

    // ── Type scale — pixel sizes ───────────────────────────────────────────────
    readonly property int caption_size: 10   // Inter/Caption
    readonly property int body_02_size:  12   // Inter/Body 02
    readonly property int body_01_size:  14   // Inter/Body 01

    // ── Button label — Figma-verified per size ────────────────────────────────
    // Large  → Inter/Section-headings/H5: SemiBold 600, 14 px
    // Medium → Inter/Button/Medium:       Bold 700,     12 px
    // Small  → Inter/Button/Small:        Bold 700,     10 px
    readonly property int button_label_small_size:   10
    readonly property int button_label_medium_size:  12
    readonly property int button_label_large_size:   14

    readonly property int button_label_small_weight:  bold      // 700
    readonly property int button_label_medium_weight: bold      // 700
    readonly property int button_label_large_weight:  semi_bold  // 600

    // ── Label — Figma: Inter/Label/M ──────────────────────────────────────────
    readonly property int label_m_size:          12   // Inter/Label/M-Default
    readonly property int label_m_default_weight: medium    // 500 — default / placeholder
    readonly property int label_m_active_weight:  semi_bold  // 600 — selected / active state
}
