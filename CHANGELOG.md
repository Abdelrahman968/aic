# Changelog

Format: [Keep a Changelog](https://keepachangelog.com), versions follow [Semantic Versioning](https://semver.org).

## [Unreleased] - proposed 2.0.0

The version is a recommendation: behaviour changed in ways scripts can notice (exit codes, pipeline output, `-Push` target, `-Bump` rules, staging semantics), which is a major version under SemVer. See [docs/MIGRATION.md](docs/MIGRATION.md). This is a release candidate: tested on Linux / PowerShell 7.4 only.

### Added
- Private index session: aic stages into a private copy of the index and replaces the real one only when committing (guarded against concurrent changes).
- Exit codes in `$LASTEXITCODE` (0, 1, 2, 3, 4, 5, 130).
- `-ConfigValidate`, validated configuration with "did you mean" hints.
- Provider layer: `-Provider openai-compatible` (LM Studio, llama.cpp server), `AIC_API_KEY`.
- Model profiles: `-Profile fast|balanced|quality`, `-ListModels`.
- Structured review with verified findings, `-ReviewJson`, `-ReviewMarkdown`, `-ReviewSeverity`, `-ReviewDiff`.
- Retry of transient server failures, first-token latency, context-window clamping and diff shortening.
- Endpoint warning for servers that are not on this machine.
- Test suite (Pester 5, mock servers, temporary repositories) and generated parameter/configuration reference.

### Changed
- `-Bump`, `-Changelog`, `-Push`, `-Amend`, checklist and AI-file staging, `-Pr` "Testing" section: see the migration guide.

### Fixed
- Partial staging destroyed by the checklist and `-AiFiles` (data loss).
- Index modified by runs that never commit; conflicted files marked resolved.
- Renames mishandled by `-AiOnly`, unticking and AI detection.
- Secret scan blind to excluded files; secrets sent to the model.
- Terminal-escape and forged-trailer injection through model output and file names.
- Incomplete model streams committed under `-Yes`.
- Markdown headings flagged as merge conflicts; false auto-refs; lockfile-only commits refused.
- Proxy breaking local Ollama; connection loss crashing a run.
