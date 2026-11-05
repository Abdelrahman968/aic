# aic: AI commit messages from a local model

`aic` is a PowerShell 7+ command that reads your staged changes and writes a **Conventional Commit** message with a model that runs on **your own machine** (Ollama by default). You review the message with a single key, then commit. No cloud service, no API key, no telemetry: the only network traffic goes to the model server address you configure.

It also reviews diffs, writes pull-request text, changelogs, release tags and commit statistics, and has guard rails around your Git index (see [Security and privacy](docs/SECURITY.md)).

> **Status: release candidate, not "production-ready".** The automated suite (Pester 5, mock model servers, temporary Git repositories) passes completely on Linux with PowerShell 7.4. Windows and macOS, the interactive key handling, and real LM Studio / llama.cpp servers have **not** been tested. See [Known limitations](#known-limitations).

## Requirements

* PowerShell 7 or newer, `git` in `PATH`
* [Ollama](https://ollama.com) with at least one chat model, e.g. `ollama pull qwen2.5-coder:7b` (or an OpenAI-compatible local server, see [docs/OLLAMA.md](docs/OLLAMA.md))

## Install

`aic.ps1` defines one function, `aic`. Load it from your profile:

```powershell
# in $PROFILE
. C:\tools\aic\aic.ps1
```

Defaults once, in `$PROFILE` (any parameter works this way):

```powershell
$PSDefaultParameterValues['aic:Model'] = 'qwen2.5-coder:3b'
$PSDefaultParameterValues['aic:Theme'] = 'dracula'
```

Run `aic -Doctor` to check PowerShell, git, the server, the model and your settings.

## Quick start

```powershell
git add -p                  # stage what you want in this commit
aic                         # generate, review with one key, commit
```

Nothing staged? In an interactive terminal `aic` shows a checklist. A few more:

```powershell
aic -DryRun                       # preview only, commit nothing
aic -All -Yes                     # git add -A, commit without asking
aic -Model qwen2.5-coder:3b -Hint "mention the retry logic"
aic -Profile fast                 # pick the installed model that fits: fast | balanced | quality
aic -ListModels                   # installed models, size, which profile each fits
aic -Amend                        # rewrite the message of the last commit
aic -Undo                         # soft-undo the last commit (changes stay staged)
aic -AiFiles                      # stage changed AI-tooling files (prompts, agent rules ...)
aic -NewBranch                    # the model names a branch for the staged changes
```

Review, PR, release and history tools:

```powershell
aic -Review                       # advisory review of the staged diff
aic -ReviewDiff main              # review everything on this branch against main
aic -ReviewSeverity high          # only findings at or above a level
aic -Pr -Into main                # PR title + description from this branch
aic -Changelog -Since v1.2.0      # changelog grouped by commit type
aic -Bump -Push                   # next SemVer from your commits, tag it, push the tag
aic -Log 12                       # last 12 commits as type pills
aic -Stats -Days 60               # commit statistics
```

For scripts (the interface goes to stderr, the document is the only output):

```powershell
$review = aic -ReviewJson | ConvertFrom-Json
$msg    = aic -DryRun -PassThru
aic -ReviewMarkdown > review.md
```

Keys at the review prompt: see [docs/KEYBOARD.md](docs/KEYBOARD.md).

## Exit codes

aic leaves its result in `$LASTEXITCODE` when it finishes:

| Code | Meaning |
|---|---|
| 0 | success |
| 1 | error (not a repository, generation failed, commit or push failed ...) |
| 2 | usage error (`-ReviewJson` together with `-ReviewMarkdown`) |
| 3 | blocked by a safety check (secrets, conflict markers, incomplete model output under `-Yes`, unresolved merge, the index changed while aic was running) |
| 4 | the model server or the model is unavailable |
| 5 | nothing to commit / nothing to release |
| 130 | cancelled |

## What it protects you from

* **Your staging is never rewritten behind your back.** aic works on a private copy of the index and only replaces the real one right before committing, and only if nothing changed in the meantime. A run that ends without a commit (`-DryRun`, `-Review`, an error, `q`) leaves your index exactly as it was.
* **Secrets** in staged content are detected (including in files you excluded from the model), `-Yes` refuses to commit them, and secret values and credential files are redacted from what the model sees.
* **Repository content is untrusted**: terminal escape sequences are stripped, forged commit trailers are dropped, and review findings are checked against the diff before they are shown.
* No hard resets, cleans, force pushes or branch deletions, ever. Details and limits: [docs/SECURITY.md](docs/SECURITY.md).

## Documentation

| | |
|---|---|
| [docs/PARAMETERS.md](docs/PARAMETERS.md) | every parameter (generated from the code) |
| [docs/CONFIGURATION.md](docs/CONFIGURATION.md) | `.aic.json` keys, environment variables |
| [docs/OLLAMA.md](docs/OLLAMA.md) | Ollama and OpenAI-compatible servers, model profiles, retries, context |
| [docs/KEYBOARD.md](docs/KEYBOARD.md) | keyboard reference |
| [docs/SECURITY.md](docs/SECURITY.md) | security and privacy |
| [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | messages and what to do |
| [docs/MIGRATION.md](docs/MIGRATION.md) | what changed compared with the original script |
| [CHANGELOG.md](CHANGELOG.md) | release notes |
| [tests/README.md](tests/README.md) | how to run the test suite |

## Known limitations

* Tested on Linux, PowerShell 7.4, Git 2.43, against in-process mock servers. **Not tested** on Windows or macOS, with a real terminal's key handling, or against real LM Studio / llama.cpp servers.
* Secret detection is pattern-based. It will miss secrets that look like ordinary text; do not treat it as a guarantee.
* A "verified" review finding means the quoted code is in the diff. It does not mean the model's claim about that code is right.
* The `-Model` tab-completer queries the server directly and is not covered by the proxy bypass.
* Large repositories: every run starts several git processes; performance on very large repositories has not been measured.
