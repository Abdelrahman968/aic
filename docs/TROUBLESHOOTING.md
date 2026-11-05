# Troubleshooting

Start with `aic -Doctor` (PowerShell, git, repository, identity, settings, server, model, clipboard) and `aic -ConfigValidate`.

| You see | What it means | What to do |
|---|---|---|
| `Can't reach Ollama at ...` (exit 4) | the server is not running or the address is wrong | start Ollama, use `-StartOllama`, or pass `-OllamaUrl`. A proxy in the environment is not used for a local server |
| `Model '...' is not installed` (exit 4) | the model is not on the server | `ollama pull <model>`, or `-Model`, or `-Profile`; `aic -ListModels` shows what is installed |
| `Generation failed` after `retrying (1/2)` | the server kept failing (503, dropped connection) | check the server log; the generation was retried twice |
| `timed out after N s` | no complete answer within `-TimeoutSec` (the first call includes model loading) | raise `-TimeoutSec`, or use a smaller model |
| `the answer was cut off at -NumPredict` / `the stream ended before the model reported it was finished` | an incomplete answer; `-Yes` will not commit it (exit 3) | raise `-NumPredict`, press `r`, or use another model |
| `the diff was shortened to fit the model's N-token context` | the model's context is small | use a model with a larger context, or commit less at a time |
| `possible secret: file - rule` | the scan matched a pattern; `-Yes` refuses (exit 3) | remove the secret; if it is a false alarm, commit interactively or re-run with `-NoScan` |
| `N path(s) still have unresolved merge conflicts` (exit 3) | `-All/-AiFiles/-AiOnly` would mark conflicts resolved | resolve the conflicts first |
| `Your index changed while aic was running` / `HEAD moved ...` (exit 3) | something else changed your staging; aic refused and modified nothing | run aic again |
| `Another git process holds index.lock` | a git process is running, or a crashed one left `.git/index.lock` | wait, or remove the stale lock yourself if no git process is running |
| `Nothing staged.` (exit 5) | the index is empty | `git add`, or `-All`, `-AiFiles`, or the file checklist in an interactive terminal |
| `git commit did not complete` | a hook failed or the editor was closed empty | fix the cause and press Enter again; interactively you can restore your original staging |
| `Not pushed` + `several remotes` | no upstream and several remotes | `git push -u <remote> <branch>` once |
| `This is a shallow clone` (`-Bump`) | tags and history are incomplete | `git fetch --unshallow --tags` |
| `Tag vX already exists on the remote` | someone released it already | `git fetch --tags`, then `-Bump` again |
| config warnings at start-up | an unknown key, a wrong type or an invalid value in `.aic.json` | `aic -ConfigValidate` lists each one |
| `only part of the diff was reviewed` | the diff is larger than `-MaxChars` | raise `-MaxChars` for a fuller review |
| output looks garbled | the terminal does not do colour/Unicode | `-Plain`, or set `NO_COLOR` |

Debugging: `-Verbose` and `-Debug` are the standard PowerShell common parameters; aic itself writes no log file. For a script, check `$LASTEXITCODE` (see the exit codes in the README).
