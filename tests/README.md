# aic test-suite (Phase B, Step 1)

Pester 5 tests for `aic.ps1`. **No Ollama server is needed** (a mock is started in-process) and **no test touches your real
repositories**: every test runs in a throw-away temp sandbox with its own `HOME`, `GIT_CONFIG_GLOBAL`, `GIT_CONFIG_NOSYSTEM=1`
and `GIT_CEILING_DIRECTORIES`; the git helper refuses to run outside that sandbox.

    pwsh -File tests/Invoke-AicTests.ps1                      # tests ../aic.ps1
    pwsh -File tests/Invoke-AicTests.ps1 -AicPath C:\tools\aic.ps1     # test YOUR real file
    pwsh -File tests/Invoke-AicTests.ps1 -Tag Regression      # or Control / Characterization / Spec / B01 .. B13
    pwsh -File tests/Invoke-AicTests.ps1 -ResultJson out.json

## Layout
| Path | Purpose |
|---|---|
| `Regression/B*.Tests.ps1`, `C01..C10` | One file per audit finding or feature (B = stabilisation, C = configuration, exit codes, push/amend, bump, prompt safety, Ollama reliability, providers, structured review). Written to FAIL on the original code and pass once fixed. |
| `Docs/Docs.Tests.ps1` | The documentation is checked against the code: generated references are current, every parameter and config key is documented, every `aic -Flag` in the docs exists, JSON examples validate, exit codes and links are right. Regenerate with `pwsh tools/Update-Docs.ps1`. |
| `Controls/Baseline.Tests.ps1` | Behaviour that works today and must keep working (backward compatibility, harness sanity). |
| `Investigation/IndexBackup.Characterization.Tests.ps1` | Facts about git (why `write-tree` is not an index backup) + a test-side prototype of the restore-safety rules. |
| `Helpers/Sandbox.ps1` | Sandbox, guarded `G`/`GTry` git wrappers, scenario builders, index/worktree fingerprints. |
| `Helpers/MockOllama.ps1` | `HttpListener` mock: `/api/tags`, `/api/show`, scripted streaming `/api/chat`, `/api/generate`. |
| `Helpers/AicRun.ps1` | `Invoke-Aic` (end to end, child process) and `Invoke-AicHarness` (function level, see below). |

## How function-level tests reach aic's nested functions
`aic` defines ~70 nested helpers inside one function, so they cannot be called directly. The harness parses `aic.ps1`
with the PowerShell AST, slices the source text of everything before the main `try{}` (parameter block + all nested
functions + state), and wraps it into `aic_harness`, which then runs the test's scriptblock **in that same scope**.
`aic.ps1` is never modified. A test can define a function such as `Pick-Many` inside its block to shadow the interactive
original (this is how "user pressed Enter on the checklist" is simulated). If a future refactor removes the final
`try/finally` of `aic`, `ConvertTo-AicHarnessSource` fails loudly instead of silently testing the wrong thing.

## Tags
* `Regression` - reproduces a bug from the audit. * `Spec` - encodes a behaviour *proposed* in the audit (not an existing contract); reviewed in Step 2.
* `Control` - must pass before and after. * `Characterization` - documents git behaviour. * `Docs` - documentation drift.

A full run takes roughly 10 minutes (each test starts a child `pwsh`). Some sandboxes limit a single command to a few minutes: run the files in groups, e.g. `-Path tests/Regression/C01-Config.Tests.ps1`.

## Index fingerprint (why not hash `.git/index`?)
`git status` / `git diff` rewrite `.git/index` to refresh stat data, so a byte hash changes without the user changing anything.
`Get-IndexFingerprint` compares mode/oid/stage/tag per path, the extended flags (intent-to-add, skip-worktree) and the
resolve-undo extension, with `GIT_OPTIONAL_LOCKS=0` so the check itself does not write.

## Last results (this repository, Linux, PowerShell 7.4.6, Git 2.43)

`last-run-original.json` / `last-run-new.json` hold per-test results against the original script (62 of 176 pass; the 114 that fail are the bugs and missing features) and the current script (184 of 184 including the 8 docs tests). All 58 control tests pass on both.
