# Security and privacy

This describes what aic does and, just as important, what it does not. Each behaviour below has an automated test (`tests/Regression`), except where noted.

## What leaves your machine

* aic sends HTTP requests **only** to the model server you configure (`-OllamaUrl`, `OLLAMA_HOST`, or the default `localhost`). There is no telemetry, no update check, no analytics.
* The prompt contains your staged diff (limited to `-MaxChars`), the file list, the branch name, up to `-History` recent commit subjects, and your `-Hint`.
* If the server is **not on this machine**, aic prints a warning at start-up (and says "unencrypted" for plain http) and stops claiming that "zero tokens left the building". Nothing prevents you from using a remote server: the warning is the control.

## What the model is not allowed to see

Before the prompt is built (commit message, `-Review`, `-NewBranch`, `-Pr`, `-ReviewDiff`):

* **Credential files** (`.env` and `.env.*` except `.example/.sample/.template/.dist`; `*.pem *.p12 *.pfx *.jks *.keystore`; `id_rsa`, `id_dsa`, `id_ecdsa`, `id_ed25519`; `service-account*.json`) are reduced to their name; their content is omitted.
* **Secret values** matching the patterns below are replaced by `[REDACTED]` (several per line are handled).
* **Lockfiles, minified files and source maps**, and anything you list in `-Exclude` / `"exclude"`, are hidden from the model.

Redaction is always on, also with `-NoScan` (which only silences the warning).

## Secret scan

The scan covers **everything that is staged**, including files hidden from the model by `-Exclude`, `"exclude"` or the default lockfile filter. It reports file name and rule, never the value. Patterns: AWS access key id, private key blocks, GitHub tokens, Slack tokens, Stripe live keys, Google API keys, JWTs, database URLs with a password, and hard-coded `api_key / secret / token / password` assignments (obvious placeholders are skipped). `-Yes` refuses to commit when anything is found (exit 3); interactively aic asks first.

**Limits:** pattern-based. Secrets that look like ordinary text (a short password, a custom token format) are not detected and may be sent to the model. Scanning stops at 3 MB of diff without notice.

## Repository content is untrusted

Diffs, file names, commit subjects and AI instruction files are data, never instructions:

* Terminal escape sequences and control characters (including bidirectional overrides) are removed from model output and shown as `?` in file names, log subjects and findings, so they cannot drive your terminal or reach git history.
* A model cannot add commit trailers: `Signed-off-by`, `Co-authored-by`, `Closes` and `Fixes` lines it writes are dropped. Only your flags (`-Signoff`, `-CoAuthor`, `-Ref`) and the branch-derived reference add them; `BREAKING CHANGE` and `Refs` footers from the model are kept.
* The prompts tell the model that the diff is untrusted and must not be obeyed. This reduces, but cannot eliminate, prompt-injection risk with a local model.
* Review findings are verified against the diff: a finding about a file not in the diff is dropped; a line number is shown only when derived from the diff; findings whose quoted code is not found are labelled **unverified**. This checks that the code exists, not that the model's judgement of it is right.

## Your Git index and working tree

* aic stages into a **private copy of the index** (`.git/aic-shadow-<pid>.index`, in the same directory so split indexes work). The real index is replaced only immediately before `git commit`, using git's own `index.lock` and rename, and **only if HEAD and your staging are unchanged since aic started**. Otherwise aic refuses, modifies nothing and exits 3.
* A run that does not end in a commit leaves your index byte-for-byte equivalent: `-DryRun`, `-Review`, `-Copy`, errors, quitting.
* A file you staged partially (`git add -p`) keeps exactly the staged hunks; aic never re-adds an already-staged file.
* Conflicted (unmerged) files are never staged by aic, and `-All`, `-AiFiles`, `-AiOnly` refuse while a merge is unresolved.
* The original index file is kept in memory for the run. After a **failed commit** (for example a hook), an interactive run offers to put your original staging back; it does so only if the index is still exactly what aic left.
* The only commands that change index or history are: `git add` of paths you selected, `git reset -q -- <paths>` (index only, working tree untouched), `git commit`, `git commit --amend` (with a warning if the commit is already on the remote), `git reset --soft HEAD~1` for `-Undo` (asks first), `git tag -a` and `git push`. aic never runs `reset --hard`, `clean`, `checkout -- <file>`, force pushes, or branch/tag deletion.
* `-Push` pushes to the upstream, or the configured push remote, or the only remote, or `origin`; with several remotes and no way to tell, it pushes nothing and names them. A release tag is pushed only after confirmation (or `-Yes`), and the remote is checked first so a tag is never created locally for nothing.
* If pwsh is killed hard, a leftover `.git/aic-shadow-<pid>.index` can remain. It is harmless and can be deleted.

## Files and secrets on disk

* The commit message is written to a temporary file for `git commit -F` and deleted afterwards.
* `AIC_API_KEY` is read from the environment only and is never printed or stored.
* aic writes `.aic.json` only with `-Init`, and never overwrites an existing one.

## Not covered by tests

Windows and macOS, the interactive keyboard paths, and behaviour against real (non-mock) model servers.
