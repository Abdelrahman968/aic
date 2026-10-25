<div align="center">

# ✦ aic

**AI Commit — Conventional Commit messages written by a _local_ Ollama model.**

Stage → `aic` → review with one key → commit. Nothing leaves your machine.

![PowerShell](https://img.shields.io/badge/PowerShell-7%2B-5391FE?logo=powershell&logoColor=white)
![Ollama](https://img.shields.io/badge/Ollama-local%20LLM-000000?logo=ollama&logoColor=white)
![Conventional Commits](https://img.shields.io/badge/Conventional%20Commits-1.0.0-FE5196?logo=conventionalcommits&logoColor=white)
![Privacy](https://img.shields.io/badge/100%25-local%20%26%20private-2ea44f)

[Install](#-install) · [Quick start](#-quick-start) · [AI files](#-ai-files-staging) · [Review keys](#-review-keys) · [Config](#-configuration) · [Parameters](#-parameters)

</div>

<!-- Add a screenshot or GIF here: ![aic demo](docs/demo.gif) -->

---

## ✨ Features

- **Local & private** — your diff goes to an Ollama server on your own machine, nowhere else.
- **Conventional Commits** — output is validated (`type(scope): subject`, max 72 chars) with automatic retry when the format is wrong.
- **One-key review** — commit, edit, retry, pick a model, change type/scope, copy, push, all without leaving the prompt.
- **AI-file staging** — `git add` only the prompts, agent rules and AI configs you changed (`CLAUDE.md`, `.cursorrules`, `prompts/`, …).
- **File checklist** — nothing staged? Pick exactly which files go into the commit.
- **Message variants** — generate several alternatives and choose with the arrow keys.
- **Live UI** — spinner, token progress bar, colour-coded diffstat, subject-length gauge, type pills.
- **Secret scan** — warns about `.env` files, private keys, tokens and database URLs before you commit.
- **Customisable** — 10 themes, 8 spinners, 4 border styles, 3 banners, per-repo and global settings.
- **Extras** — `-Undo`, `-Amend`, `-Push`, `-Doctor`, `-Log`, gitmoji, Arabic/any-language messages.

---

## 📦 Requirements

| Tool | Notes |
|---|---|
| [PowerShell 7+](https://github.com/PowerShell/PowerShell) | Windows Terminal / VS Code terminal recommended |
| [Git](https://git-scm.com/) | any recent version |
| [Ollama](https://ollama.com/) | running locally (or reachable via `-OllamaUrl`) |
| A model | e.g. `ollama pull qwen2.5-coder:7b` (default) or a lighter `qwen2.5-coder:3b` |

---

## 🚀 Install

```powershell
# 1. Get the script
git clone https://github.com/abdelrahman968/aic.git "$HOME\aic"

# 2. Load it from your profile
notepad $PROFILE
```

Add this line to your `$PROFILE`:

```powershell
. "$HOME\aic\aic.ps1"
```

Reload the profile (or open a new terminal) and check everything:

```powershell
. $PROFILE
aic -Doctor
```

> **Tip:** you can also paste the `aic` function directly into `$PROFILE` instead of dot-sourcing the file.

Optional defaults, also in `$PROFILE`:

```powershell
$PSDefaultParameterValues['aic:Model'] = 'qwen2.5-coder:3b'
$PSDefaultParameterValues['aic:Theme'] = 'dracula'
```

---

## ⚡ Quick start

```powershell
aic                    # pick files if nothing is staged → generate → review → commit
aic -AiFiles           # stage changed AI files, then generate
aic -All -Push         # git add -A, commit, push
aic -DryRun            # preview only, commit nothing
aic -Undo              # soft-undo the last commit (changes stay staged)
aic -Log 12            # pretty history with type pills
aic -Doctor            # health check
```

---

## 🤖 AI files staging

Stage only the files that configure or steer AI tools — without touching the rest.

| Command | What it does |
|---|---|
| `aic -AiFiles` | `git add` every changed AI-related file, then generate → review → commit |
| `aic -AiOnly` | commit **only** AI files (other staged files are unstaged after confirmation; your working tree is untouched) |
| `aic -ListAi` | list changed AI files and whether they are `staged`, `partial` or `unstaged` |
| `aic -AiPattern 'agents/*','*.skill.md'` | add your own globs |

**Detected automatically**

```text
.aic.json                    CLAUDE.md  AGENTS.md  GEMINI.md  COPILOT.md  QWEN.md  CODEX.md
.cursorrules  .windsurfrules  .clinerules  .aider*
.claude/  .cursor/  .continue/  .windsurf/  .roo/  .cline/  .codex/  .gemini/  .ollama/  .tabby/  .agents/
.github/copilot-instructions.md  .github/{instructions,prompts,chatmodes,agents}/
mcp.json  .mcp.json  .vscode/mcp.json
Modelfile  llms.txt  llms-full.txt
prompts/  *.prompt.md  *.prompty  *.mdc  skills/*/SKILL.md
```

aider's scratch files (`.aider.chat.history.md`, `.aider.input.history`, `.aider.tags.cache`) are intentionally ignored.

In the checklist AI files carry a purple `AI` tag and the **`i`** key ticks them all. When every staged file is AI-related, the model is nudged towards `chore(ai): …`.

Make it automatic per repo with `"autoStageAi": true` in `.aic.json`.

---

## ⌨️ Review keys

| Key | Action |
|---|---|
| `Enter` | commit |
| `e` | commit, but edit the message in your git editor first |
| `r` | retry (new message, same settings) |
| `v` | generate variants and pick one |
| `h` | retry with a hint you type |
| `m` | pick another model |
| `t` | pick the commit type |
| `s` | set / pick the scope |
| `b` | toggle breaking-change `!` |
| `x` | toggle gitmoji |
| `a` | stage AI files and regenerate |
| `f` | re-pick files and regenerate |
| `c` | copy message to clipboard |
| `p` | commit and push |
| `d` | view the staged diff |
| `q` / `Esc` | quit without committing |

`Esc` during generation cancels it (the previous message is kept).
In pickers: `↑`/`↓` or `j`/`k`, `Home`/`End`, `Enter`, `Esc`. In the checklist: `Space` toggle, `a` all, `n` none, `i` AI files.

---

## 🛠 Configuration

Create a starter file for the current repo:

```powershell
aic -Init
```

`.aic.json` (repo root) and `~/.aic.json` (personal defaults) support:

```json
{
  "model": "qwen2.5-coder:7b",
  "language": "English",
  "bullets": 3,
  "history": 3,
  "emoji": false,
  "theme": "ocean",
  "spinner": "dots",
  "border": "rounded",
  "banner": "mini",
  "width": 78,
  "scopes": ["auth", "ui", "api", "ai"],
  "exclude": ["*.svg"],
  "aiFiles": ["prompts/*", "*.prompt.md"],
  "autoStageAi": false
}
```

**Precedence** (highest first):

1. flag you type
2. `$PSDefaultParameterValues`
3. `.aic.json` in the repo
4. `~/.aic.json`
5. built-in default

If `scopes` is set, the model is restricted to them and anything else shows up as a note on the message card.

---

## 🎛 Parameters

<details>
<summary><b>Model & generation</b></summary>

| Parameter | Default | Description |
|---|---|---|
| `-Model` | `qwen2.5-coder:7b` | Ollama model (tab-completes installed models) |
| `-OllamaUrl` | `$env:OLLAMA_HOST` / `http://localhost:11434` | server address |
| `-MaxChars` | `6000` | diff cap, shared fairly between files |
| `-NumCtx` | `4096` | context window (auto-raised when needed) |
| `-NumPredict` | `256` | max answer tokens |
| `-Temperature` | `0.2` | rises a little on every retry |
| `-KeepAlive` | `10m` | how long Ollama keeps the model loaded |
| `-TimeoutSec` | `180` | whole-generation timeout |
| `-StartOllama` | off | start `ollama serve` automatically |
| `-Unload` | off | free the model from (V)RAM when done |

</details>

<details>
<summary><b>Message shape</b></summary>

| Parameter | Description |
|---|---|
| `-Type` | force the type (`feat`, `fix`, `refactor`, `perf`, `docs`, `style`, `test`, `build`, `ci`, `chore`, `revert`) |
| `-Scope` | force the scope |
| `-Breaking` | mark as breaking: `type(scope)!:` |
| `-Emoji` | gitmoji after the colon |
| `-Hint` | extra context for the model |
| `-Language` | language of subject + bullets (type/scope stay English) |
| `-Bullets` | max body bullets, `0`–`6` (`0` = subject only) |
| `-History` | recent commit subjects shown as style reference, `0`–`20` |
| `-Ref '#42'` | adds a `Refs: #42` footer |
| `-Exclude` | extra pathspecs hidden from the model |
| `-Retries` | automatic retries on format failure, `0`–`5` |
| `-Variants` | alternatives generated by `v`, `2`–`6` |
| `-NoScan` | skip the secret scan |

</details>

<details>
<summary><b>Staging</b></summary>

| Parameter | Description |
|---|---|
| `-All` | `git add -A` first |
| `-AiFiles` | `git add` every changed AI-related file |
| `-AiOnly` | commit only AI-related files |
| `-AiPattern` | extra globs counted as AI-related |
| `-ListAi` | list changed AI files and exit |
| `-Pick` | show the file checklist even if something is staged |

</details>

<details>
<summary><b>Actions & output</b></summary>

| Parameter | Description |
|---|---|
| `-Amend` | rewrite the last commit's message |
| `-Push` | push after committing (sets upstream on new branches) |
| `-NoVerify` | skip git hooks |
| `-Signoff` | add `Signed-off-by` |
| `-Undo` | soft-undo the last commit and exit |
| `-Init` | write a starter `.aic.json` and exit |
| `-Doctor` | health check and exit |
| `-Log N` | last `N` commits as coloured pills and exit |
| `-ListThemes` | preview all themes and exit |
| `-Yes` | commit without asking (refuses on secret warnings or format problems) |
| `-DryRun` | show the message, commit nothing |
| `-Copy` | copy the message, commit nothing |
| `-PassThru` | also return the message as a string |

</details>

<details>
<summary><b>Look & feel</b></summary>

| Parameter | Values |
|---|---|
| `-Theme` | `ocean` `sunset` `forest` `neon` `mono` `aurora` `rose` `gold` `dracula` `candy` |
| `-Spinner` | `dots` `arc` `bounce` `pulse` `grow` `line` `star` `orbit` |
| `-Border` | `rounded` `square` `double` `heavy` |
| `-Banner` | `mini` `big` `none` |
| `-Width` | `50`–`140` (default `78`) |
| `-Bell` | ring the terminal bell after a successful commit |
| `-NoAnim` | keep colours, drop animations |
| `-Plain` | ASCII only, no colour, no animation (automatic when output is redirected or `NO_COLOR` is set) |

</details>

---

## 🧪 Examples

```powershell
aic -DryRun -Type fix -Scope auth          # force "fix(auth): ..."
aic -Model qwen2.5-coder:3b -Yes           # lighter model, no questions asked
aic -Amend -Hint "mention the retry logic" # reword the last commit
aic -Language Arabic                       # Arabic subject + bullets
aic -Theme dracula -Border double -Banner big -Spinner star
$msg = aic -DryRun -PassThru               # use the message in your own scripts
```

---

## 🔐 Privacy

- The diff is sent only to the Ollama address you configure (default `localhost`).
- The secret scan runs locally and only **warns**; with `-Yes` it refuses to commit when something suspicious is staged.
- Lockfiles and minified/generated files (`package-lock.json`, `yarn.lock`, `*.min.js`, `*.map`, …) are never sent to the model.

---

## ❓ Troubleshooting

| Problem | Fix |
|---|---|
| `Can't reach Ollama` | open the Ollama app, run `ollama serve`, or use `-StartOllama` / `-OllamaUrl` |
| `Model '…' is not installed` | `ollama pull <model>` or pick one in the prompt |
| Garbled colours / glyphs | use Windows Terminal and PowerShell 7+, or run with `-Plain` |
| Pickers don't appear | they need an interactive terminal; run `aic -Doctor` to see which capabilities are detected |
| Model "thinks" forever | raise `-NumPredict` or use a non-reasoning model |

---

## 🤝 Contributing

Issues and pull requests are welcome. If you add a new AI-tool file pattern, put it in the `$aiRx` list inside `aic.ps1` and mention it in this README.

## 📄 License

Add a `LICENSE` file of your choice (MIT is a common default).

---

<div align="center">

Made by [**@abdelrahman968**](https://github.com/abdelrahman968)

</div>
