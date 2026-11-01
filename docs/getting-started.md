# Getting started


This article explains how to install the Qt5 skills into your AI tool of
choice, invoke the skills, and verify that the skills are actually used.

## 1. Install

To install agent skills to your AI tool:

=== "Claude Code"

    ```
    /plugin marketplace add wuqingwei/agent-skills
    /plugin install qt5-development-skills
    ```

    Claude Code automatically discovers the skills, so no restart needed.

=== "Codex CLI"

    ```bash
    npx skills add wuqingwei/agent-skills
    ```

    Restart Codex after installation.

=== "Gemini CLI"

    ```bash
    gemini extensions install https://github.com/wuqingwei/agent-skills
    ```

=== "GitHub Copilot CLI"

    ```
    copilot plugin marketplace add wuqingwei/agent-skills
    copilot plugin install qt5-development-skills@qt-skills-and-tools
    ```

See the project
[README](https://github.com/wuqingwei/agent-skills#installation)
for manual install, VSCode agents setup, and per-skill symlinking options.

## 2. Invoke your first skill

Open a project containing Qt code, then ask the agent to do
something a skill is designed for. Trigger phrases are
defined in each skill's `description` — the agent matches your
request against them.

Examples to try (substitute a real file path):

> "Review my QML changes in `Main.qml` before I commit."

> "Document this class — `src/network/RequestQueue.h`."

> "Profile this app and find what's making the UI feel laggy:
> `build/myapp.exe`"

The agent will load the matching skill, follow its workflow, and
report back.

## 3. Verify it actually fired

Skills load on demand. A request that *sounds* relevant doesn't
guarantee activation. Look for these signals:

- **Claude Code** — a `Skill` tool invocation appears in the
  transcript with the skill name, for example
  `qt5-development-skills:qt-qml-review`. Without it, the model
  answered from general knowledge.
- **Codex CLI** — the skill appears in the loaded-skills list at
  session start, and the agent quotes its workflow steps.
- **Gemini CLI** — the extension is listed under
  `gemini extensions list` and the agent references `@SKILL.md`
  context.

If the right skill didn't fire, see
[Why a skill didn't activate](skills/concepts.md#troubleshooting).

## Next steps

- [How skills are triggered and what they look like inside](skills/concepts.md)
- [Requirements and platform support per skill](skills/requirements.md)
