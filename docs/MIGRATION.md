# Migrating from the original script

Existing parameters, aliases, `.aic.json` keys and the single-file distribution keep working. Behaviour changed in the places below, all of them to remove silent data loss, unsafe defaults or misleading results.

## Behaviour changes

| Area | Before | Now |
|---|---|---|
| Partial staging | ticking a partially staged file in the checklist (or `-AiFiles`) staged the rest of the file too | already-staged files are never re-added; the checklist marks them "(partially staged)"; use `git add <file>` for the rest |
| Index | `-All`, `-AiFiles`, `-AiOnly` changed your index even for `-DryRun`/`-Review`/errors | all staging happens in a private copy; your index changes only when a commit is made |
| Merges | `-All`/`-AiFiles` marked conflicts resolved | refuse (exit 3) while a merge is unresolved; conflicted files are never staged |
| Renames | rename paths appeared as `dir/{old => new}`; `-AiOnly` left the old path's deletion staged | real paths; both sides of a rename are judged |
| Secret scan | skipped files hidden by `-Exclude`, `"exclude"` and lockfiles | scans everything staged; the model never sees secret values or credential files |
| Incomplete answers | a cut-off or unfinished model reply could be committed with `-Yes` | blocked (exit 3) |
| Model footers | `Signed-off-by`, `Co-authored-by`, `Closes`, `Fixes` from the model were committed | dropped; only your flags add them |
| Exit codes | none (whatever git returned last) | `$LASTEXITCODE` is set: 0, 1, 2, 3, 4, 5, 130 |
| Pipeline | git's commit/push output leaked into the pipeline unless `-PassThru` | never; git output no longer carries colour; the editor (`e`) and diff viewer (`d`) still use the terminal directly |
| `-Push` | always `origin HEAD` | upstream / push remote / only remote / origin; several remotes and no choice: refuses and names them; detached HEAD refused |
| `-Amend` | silent | warns when the commit is already on the remote (asks interactively) |
| `-Bump` | nearest tag of any name, prerelease dropped, any text mentioning "BREAKING CHANGE" counted | highest SemVer tag reachable from HEAD, non-semver tags ignored, prerelease promotes (`1.2.3-rc.1` to `1.2.3`), only `!` or a real footer is breaking; refuses shallow clones; checks the remote before creating the tag; asks before pushing the tag unless `-Yes` |
| `-Changelog` | nearest tag, ignored footers | same base tag rule; `BREAKING CHANGE:` footers listed under "Breaking changes" |
| Config | a wrong type crashed aic; unknown keys and bad values were silently ignored; scope check ignored case | validated, reported, never crashes; scopes are case-sensitive; `-ConfigValidate` |
| `-Review` | a few free-text bullets | structured, verified findings; see the README (old bullet output is still shown when a model ignores the format) |
| `-Pr` | the model wrote the "Testing" section | the model does not; aic lists changed test files and says it ran nothing |
| Lockfile-only commit | refused as "nothing staged" | allowed |
| Auto `Refs:` | matched years (`2024-x`), dates and CVE ids | no longer |
| Ollama calls | only generation bypassed a proxy; one failure = give up | all local calls bypass the proxy; transient failures are retried twice; `num_ctx` is clamped to the model |

## New parameters

`-ConfigValidate`, `-Provider`, `-Profile` (parameter `-ModelProfile`), `-ListModels`, `-ReviewJson`, `-ReviewMarkdown`, `-ReviewSeverity`, `-ReviewDiff`. New `.aic.json` keys: `provider`, `profile`. New environment variable: `AIC_API_KEY`.

## If you relied on the old behaviour

* Scripts that read `$LASTEXITCODE` after `aic` now see aic's code, not git's.
* Scripts that captured git's output from `aic` must use `-PassThru` for the message.
* `-Amend -Yes` on a pushed commit still proceeds, with a warning.
