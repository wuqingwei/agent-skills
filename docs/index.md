---
hide:
  - navigation
  - toc
---

<div class="qt-hero" markdown>

# Qt5 Agentic Tools

Agentic skills — portable, version-controlled knowledge
packages that AI agents load on demand — adapted for **Qt 5**
(5.15 LTS) development. Designed for AI coding tools.

Tested with frontier LLMs from the Claude, Gemini, and GPT model
families. Ported from the official Qt AI Skills with every skill
name preserved.

[Get started →](getting-started.md){ .md-button .md-button--primary } &nbsp;
[Browse skills →](skills/index.md){ .md-button }

</div>

## Why Qt5-specific tools { #why-qt5-official }

Generic AI coding assistants treat Qt like any other C++ or
JavaScript codebase — and most of their training material is
Qt 6. Ask them to touch a Qt 5 project and they reach for
`qt_add_qml_module`, drop import version numbers, and write
`pragma ComponentBehavior`. These skills exist because Qt 5
deserves better than Qt 6 guesses.

<div class="qt-cards">

<a class="qt-card">
<strong>Qt5-aware by design</strong>
Ported against the Qt 5.15 API surface. Skills encode Qt 5
CMake conventions (`AUTOMOC`, `.qrc`, `qt5_*` macros), versioned
QML imports, `qmlRegisterType`-based type registration, and
parent-ownership rules — the things LLMs get systematically
wrong for Qt 5.
</a>

<a class="qt-card">
<strong>Same skill names as upstream</strong>
Every skill keeps its original name, so mixed toolchains and
documentation written against the official Qt AI Skills keep
working; only the guidance is Qt 5.
</a>

<a class="qt-card">
<strong>Cross-tool, no lock-in</strong>
One source format (`SKILL.md`) runs natively in Claude Code,
Codex CLI, Gemini CLI, and GitHub Copilot. Skills are
open-source under BSD-3-Clause — installable from this repo
or as a CLI plugin.
</a>

<a class="qt-card">
<strong>Tested across frontier LLMs</strong>
Validated against Claude, Gemini, and GPT model families.
Triggering descriptions, references, and progressive disclosure
are tuned so the skill activates when it should and stays out
of the way when it shouldn't.
</a>

</div>

## What's Here { #whats-here }

<div class="qt-cards">

<a class="qt-card" href="skills/">
<strong>Skills</strong>
Agentic skills for QML and C++ authoring, review, and
documentation — packaged so they work natively in Claude Code,
Codex CLI, and Gemini CLI.
</a>

<a class="qt-card" href="contributing/">
<strong>Contributing</strong>
Packaging conventions and the cross-platform story for
publishing a new skill in this repo.
</a>

</div>

!!! warning "AI output requires review"
    These tools and skills depend on LLMs, which can make mistakes.
    Always double-check the output carefully.

    Before using the skills under Qt commercial licensing, make sure
    you have understood and agree to the
    [Qt AI Services Terms & Conditions](https://www.qt.io/terms-conditions/ai-services-2025-06).
