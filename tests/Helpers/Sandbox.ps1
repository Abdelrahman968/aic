# Sandbox + git helpers for the aic test-suite.
# Everything happens under a throw-away temp directory with an isolated HOME and git config.
# Nothing here ever runs git against a directory outside that sandbox (see Assert-InSandbox).

$script:SandboxRoots = [System.Collections.Generic.List[string]]::new()

function New-AicSandbox {
    $base = Join-Path ([IO.Path]::GetTempPath()) ('aic-t-' + [guid]::NewGuid().ToString('N').Substring(0, 10))
    foreach ($d in 'repo', 'home', 'xdg') { New-Item -ItemType Directory -Path (Join-Path $base $d) -Force | Out-Null }
    $base = (Resolve-Path -LiteralPath $base).Path
    $gc = Join-Path $base 'gitconfig'
    $cfgText = @(
        '[user]', '    name = Aic Test', '    email = aic-test@example.invalid',
        '[init]', '    defaultBranch = main',
        '[commit]', '    gpgsign = false',
        '[tag]', '    gpgsign = false',
        '[core]', '    autocrlf = false', '    safecrlf = false', '    editor = true',
        '[advice]', '    detachedHead = false',
        '[merge]', '    conflictStyle = merge'
    ) -join "`n"
    [IO.File]::WriteAllText($gc, $cfgText + "`n", [Text.UTF8Encoding]::new($false))
    $script:SandboxRoots.Add($base)
    $envMap = [ordered]@{
        HOME = (Join-Path $base 'home'); USERPROFILE = (Join-Path $base 'home'); XDG_CONFIG_HOME = (Join-Path $base 'xdg')
        GIT_CONFIG_GLOBAL = $gc; GIT_CONFIG_NOSYSTEM = '1'; GIT_TERMINAL_PROMPT = '0'; GIT_EDITOR = 'true'
        GIT_CEILING_DIRECTORIES = $base          # git can never discover a repo above the sandbox
    }
    [pscustomobject]@{ Base = $base; Repo = (Join-Path $base 'repo'); Home = (Join-Path $base 'home'); Env = $envMap; Saved = @{} }
}

function Enter-AicSandbox($Sandbox) {
    foreach ($k in $Sandbox.Env.Keys) {
        $Sandbox.Saved[$k] = [Environment]::GetEnvironmentVariable($k)
        [Environment]::SetEnvironmentVariable($k, [string]$Sandbox.Env[$k])
    }
}
function Exit-AicSandbox($Sandbox) {
    foreach ($k in @($Sandbox.Saved.Keys)) { [Environment]::SetEnvironmentVariable($k, $Sandbox.Saved[$k]) }
    $Sandbox.Saved.Clear()
}
function Remove-AicSandbox($Sandbox) {
    if ($Sandbox -and $Sandbox.Base -and (Test-Path -LiteralPath $Sandbox.Base) -and $Sandbox.Base.StartsWith([IO.Path]::GetTempPath().TrimEnd('/', '\'))) {
        Remove-Item -LiteralPath $Sandbox.Base -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Assert-InSandbox([string]$Dir) {
    $full = [IO.Path]::GetFullPath($Dir)
    $ok = $false
    foreach ($r in $script:SandboxRoots) { if ($full.StartsWith($r)) { $ok = $true } }
    if (-not $ok) { throw "SAFETY: refusing to run git outside a test sandbox: $full" }
}

# G <dir> <git args...>   (uses $args on purpose: dash-tokens like -d / -A must reach git untouched)
function G {
    $dir = $args[0]; $rest = @($args | Select-Object -Skip 1)
    Assert-InSandbox $dir
    $out = & git -C $dir @rest 2>&1
    $rc = $LASTEXITCODE
    $txt = @($out | ForEach-Object { "$_" })
    if ($rc -ne 0) { throw "git $($rest -join ' ') failed ($rc): $($txt -join ' | ')" }
    $txt
}
# GTry: never throws; returns @{ Rc; Out }
function GTry {
    $dir = $args[0]; $rest = @($args | Select-Object -Skip 1)
    Assert-InSandbox $dir
    $out = & git -C $dir @rest 2>&1
    @{ Rc = $LASTEXITCODE; Out = @($out | ForEach-Object { "$_" }) }
}

function Set-TestFile([string]$Repo, [string]$Rel, [string]$Content) {
    $p = Join-Path $Repo $Rel
    $dir = Split-Path $p -Parent
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [IO.File]::WriteAllText($p, $Content, [Text.UTF8Encoding]::new($false))
}
function Get-TestFile([string]$Repo, [string]$Rel) { [IO.File]::ReadAllText((Join-Path $Repo $Rel)) }

# repo with one initial commit holding $Files (hashtable path -> content)
function New-TestRepo($Sandbox, [hashtable]$Files = @{ 'README.md' = "# demo`n" }) {
    $r = $Sandbox.Repo
    [void](G $r init -q -b main .)
    foreach ($k in $Files.Keys) { Set-TestFile $r $k $Files[$k] }
    [void](G $r add -A)
    [void](G $r commit -q -m 'chore: initial')
    $r
}

function Get-HeadSha([string]$Repo) { $x = GTry $Repo rev-parse -q --verify HEAD; if ($x.Rc -eq 0) { $x.Out[0] } else { '' } }
function Get-StagedBlob([string]$Repo, [string]$Path) { (G $Repo show ":$Path") -join "`n" }

# --- index fingerprint -------------------------------------------------------------------------------
# Semantic, NOT byte-level: `git status`/`git diff` legitimately rewrite .git/index to refresh stat data,
# so hashing the raw file would report false changes. This captures what a user would call "my staging":
# mode / object id / stage (0..3 = unmerged) / tag (H, M, S=skip-worktree, h=assume-unchanged, ...) per path,
# the extended flags (intent-to-add, skip-worktree) and the resolve-undo extension.
function Get-IndexFingerprint([string]$Repo) {
    $old = $env:GIT_OPTIONAL_LOCKS; $env:GIT_OPTIONAL_LOCKS = '0'
    try {
        $entries = (G $Repo -c core.quotepath=false ls-files -s -t -v) -join "`n"
        $flags = ((G $Repo ls-files --debug) | Where-Object { $_ -match '^\s+flags:' }) -join "`n"
        $reuc = (G $Repo ls-files --resolve-undo) -join "`n"
        "ENTRIES`n$entries`nFLAGS`n$flags`nRESOLVE-UNDO`n$reuc"
    } finally { $env:GIT_OPTIONAL_LOCKS = $old }
}
function Get-UnmergedFingerprint([string]$Repo) { (G $Repo ls-files -u) -join "`n" }

# every working-tree file (outside .git) as "relpath:sha256": proves nothing on disk was altered
function Get-WorktreeFingerprint([string]$Repo) {
    $gitDir = Join-Path $Repo '.git'
    Get-ChildItem -LiteralPath $Repo -Recurse -File -Force |
        Where-Object { $_.FullName -ne $gitDir -and -not $_.FullName.StartsWith($gitDir + [IO.Path]::DirectorySeparatorChar) } |
        Sort-Object FullName |
        ForEach-Object { $_.FullName.Substring($Repo.Length + 1) + ':' + (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash } |
        Out-String
}

# raw index bytes (location is worktree-aware via rev-parse --git-path)
function Get-IndexPath([string]$Repo) {
    $p = @(G $Repo rev-parse --git-path index)[0]
    if ([IO.Path]::IsPathRooted($p)) { $p } else { Join-Path $Repo $p }
}

# --- scenario builders ---------------------------------------------------------------------------------
# MM: one line staged, a different line still unstaged
function New-PartialStaging($Sandbox, [string]$Path = 'partial.txt') {
    $r = New-TestRepo $Sandbox @{ $Path = "line1`nline2`nline3`n"; 'other.txt' = "o`n" }
    Set-TestFile $r $Path "line1`nSTAGED`nline3`n";   [void](G $r add -- $Path)
    Set-TestFile $r $Path "line1`nSTAGED`nUNSTAGED`n"
    $r
}
# real merge conflict: conf.txt and prompts/p.md are unmerged (UU)
function New-ConflictRepo($Sandbox) {
    $r = New-TestRepo $Sandbox @{ 'conf.txt' = "l1`nbase`nl3`n"; 'prompts/p.md' = "p1`nbase`np3`n"; 'ok.txt' = "ok`n" }
    [void](G $r switch -q -c side)
    Set-TestFile $r 'conf.txt' "l1`nSIDE`nl3`n"; Set-TestFile $r 'prompts/p.md' "p1`nSIDE`np3`n"
    [void](G $r commit -q -am 'side')
    [void](G $r switch -q main)
    Set-TestFile $r 'conf.txt' "l1`nMAIN`nl3`n"; Set-TestFile $r 'prompts/p.md' "p1`nMAIN`np3`n"
    [void](G $r commit -q -am 'main')
    [void](GTry $r merge side)                   # exits 1 on conflict: expected
    if (-not (Get-UnmergedFingerprint $r)) { throw 'scenario error: no unmerged entries were produced' }
    $r
}

# staged non-AI change + unstaged modification + untracked AI file + untracked plain file
function New-MixedRepo($Sandbox) {
    $r = New-TestRepo $Sandbox @{ 'README.md' = "# demo`n"; 'src/app.js' = "let a = 1;`n" }
    Set-TestFile $r 'src/app.js' "let a = 2;`n"; [void](G $r add -- src/app.js)
    Set-TestFile $r 'README.md' "# demo v2`n"
    Set-TestFile $r 'prompts/p.md' "be nice`n"
    Set-TestFile $r 'notes.txt' "n`n"
    $r
}

# bare repository inside the sandbox, registered as a remote of $Repo
function Add-BareRemote($Sandbox, [string]$Name = 'origin') {
    $bare = Join-Path $Sandbox.Base "$Name.git"
    [void](G $Sandbox.Base init -q --bare -b main "$Name.git")
    [void](G $Sandbox.Repo remote add $Name $bare)
    $bare
}
function Add-TestCommit([string]$Repo, [string]$Subject, [string]$Body = '') {
    $a = @('commit', '-q', '--allow-empty', '-m', $Subject); if ($Body) { $a += @('-m', $Body) }
    [void](G $Repo @a)
}
function Get-RemoteRef([string]$Bare, [string]$Ref) { $x = GTry $Bare rev-parse -q --verify $Ref; if ($x.Rc -eq 0) { $x.Out[0] } else { '' } }
