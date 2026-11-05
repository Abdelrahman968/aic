# Characterization of GIT behaviour (not of aic): what is, and is not, a complete backup of the index?
# These tests PASS today by design: they document facts the Step 2 design relies on.
# The "prototype" section proves the restore-safety rules (never overwrite an index that changed since aic touched it).
BeforeAll {
    . (Join-Path $PSScriptRoot '..' 'Helpers' 'All.ps1')

    # ---- PROTOTYPE (test-side only; not part of aic.ps1) -------------------------------------------------------
    function New-IndexSnapshot([string]$Repo) {
        $p = Get-IndexPath $Repo
        @{ Path = $p; Bytes = $(if (Test-Path -LiteralPath $p) { [IO.File]::ReadAllBytes($p) } else { $null })
           Fingerprint = (Get-IndexFingerprint $Repo); Head = (Get-HeadSha $Repo) }
    }
    # Restores the raw index bytes ONLY if (a) nobody else holds index.lock, (b) HEAD did not move and
    # (c) the index is still exactly what aic left behind ($ExpectedNow). Uses git's own lock+rename protocol.
    function Restore-IndexSnapshot([string]$Repo, $Snap, [string]$ExpectedNow) {
        $lock = "$($Snap.Path).lock"
        try { $fs = [IO.File]::Open($lock, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None) }
        catch { return @{ Restored = $false; Reason = 'index.lock exists' } }
        $moved = $false
        try {
            if ((Get-HeadSha $Repo) -ne $Snap.Head)               { return @{ Restored = $false; Reason = 'HEAD moved' } }
            if ((Get-IndexFingerprint $Repo) -ne $ExpectedNow)    { return @{ Restored = $false; Reason = 'index changed since aic modified it' } }
            if ($null -eq $Snap.Bytes) { $fs.Dispose(); Remove-Item -LiteralPath $lock -Force; if (Test-Path -LiteralPath $Snap.Path) { Remove-Item -LiteralPath $Snap.Path -Force }; return @{ Restored = $true; Reason = '' } }
            $fs.Write($Snap.Bytes, 0, $Snap.Bytes.Length); $fs.Flush(); $fs.Dispose()
            Move-Item -LiteralPath $lock -Destination $Snap.Path -Force; $moved = $true
            @{ Restored = $true; Reason = '' }
        } finally { try { $fs.Dispose() } catch { }; if (-not $moved -and (Test-Path -LiteralPath $lock)) { Remove-Item -LiteralPath $lock -Force -ErrorAction SilentlyContinue } }
    }
}

Describe 'git facts: why `git write-tree` is NOT a complete index backup' -Tag 'Characterization' {
    BeforeEach { $script:sb = New-AicSandbox; Enter-AicSandbox $script:sb }
    AfterEach  { Exit-AicSandbox $script:sb; Remove-AicSandbox $script:sb }

    It 'write-tree refuses to run while the index has unmerged entries' {
        $repo = New-ConflictRepo $script:sb
        (GTry $repo write-tree).Rc | Should -Not -Be 0
    }

    It 'write-tree + read-tree loses intent-to-add (git add -N) entries' {
        $repo = New-TestRepo $script:sb
        Set-TestFile $repo 'ita.txt' "new`n"; [void](G $repo add -N ita.txt)
        (G $repo ls-files) | Should -Contain 'ita.txt'
        $t = @(G $repo write-tree)[0]; [void](G $repo read-tree $t)
        (G $repo ls-files) | Should -Not -Contain 'ita.txt'
    }

    It 'write-tree + read-tree resets skip-worktree and assume-unchanged flags' {
        $repo = New-TestRepo $script:sb @{ 'skip.txt' = "s`n"; 'assume.txt' = "a`n" }
        [void](G $repo update-index --skip-worktree skip.txt); [void](G $repo update-index --assume-unchanged assume.txt)
        $before = Get-IndexFingerprint $repo
        $t = @(G $repo write-tree)[0]; [void](G $repo read-tree $t)
        Get-IndexFingerprint $repo | Should -Not -Be $before
    }

    It 'write-tree + read-tree discards the resolve-undo extension (git checkout -m / update-index --unresolve)' {
        $repo = New-ConflictRepo $script:sb
        Set-TestFile $repo 'conf.txt' "resolved`n"; Set-TestFile $repo 'prompts/p.md' "resolved`n"; [void](G $repo add conf.txt prompts/p.md)
        (G $repo ls-files --resolve-undo) | Should -Not -BeNullOrEmpty
        $t = @(G $repo write-tree)[0]; [void](GTry $repo read-tree $t)
        (G $repo ls-files --resolve-undo) | Should -BeNullOrEmpty
    }

    It 'a byte copy of the index file restores ALL of those states exactly' {
        $repo = New-ConflictRepo $script:sb
        Set-TestFile $repo 'ita.txt' "n`n"; [void](G $repo add -N ita.txt)
        [void](G $repo update-index --skip-worktree ok.txt)
        $snap = New-IndexSnapshot $repo; $before = Get-IndexFingerprint $repo
        [void](G $repo add -A)                                                    # destroy the state
        Get-IndexFingerprint $repo | Should -Not -Be $before
        [IO.File]::WriteAllBytes($snap.Path, $snap.Bytes)
        Get-IndexFingerprint $repo | Should -Be $before
    }

    It 'git status rewrites the index file (stat refresh): raw hashes cannot detect user changes, the semantic fingerprint can' {
        $repo = New-TestRepo $script:sb @{ 'f.txt' = "a`n" }
        $p = Get-IndexPath $repo
        [IO.File]::SetLastWriteTimeUtc((Join-Path $repo 'f.txt'), [DateTime]::UtcNow.AddMinutes(-30))   # make the cached stat data stale
        $h1 = (Get-FileHash -LiteralPath $p).Hash; $f1 = Get-IndexFingerprint $repo
        [void](G $repo status --porcelain)
        (Get-FileHash -LiteralPath $p).Hash | Should -Not -Be $h1 -Because 'plain `git status` refreshed and rewrote the index'
        Get-IndexFingerprint $repo | Should -Be $f1
    }

    It 'a linked worktree has its own index outside the main .git directory (use rev-parse --git-path index)' {
        $repo = New-TestRepo $script:sb
        $wt = Join-Path $script:sb.Base 'wt'
        [void](G $repo worktree add -q $wt -b wtb)
        $p = Get-IndexPath $wt
        ($p -replace '\\', '/') | Should -Match '/\.git/worktrees/wt/index$'
        Test-Path -LiteralPath $p | Should -BeTrue
    }
}

Describe 'prototype: restore-safety rules for an index snapshot' -Tag 'Characterization' {
    BeforeEach {
        $script:sb = New-AicSandbox; Enter-AicSandbox $script:sb
        $script:repo = New-PartialStaging $script:sb
        Set-TestFile $script:repo 'extra.txt' "e`n"
        [void](G $script:repo update-index --skip-worktree other.txt)
        $script:snap = New-IndexSnapshot $script:repo
        $script:orig = Get-IndexFingerprint $script:repo
        [void](G $script:repo add -A)                                      # what `aic -All` does
        $script:after = Get-IndexFingerprint $script:repo                  # = what aic left behind
    }
    AfterEach { Exit-AicSandbox $script:sb; Remove-AicSandbox $script:sb }

    It 'restores partial staging, skip-worktree flags and untracked state when the index is still what aic left' {
        (Restore-IndexSnapshot $script:repo $script:snap $script:after).Restored | Should -BeTrue
        Get-IndexFingerprint $script:repo | Should -Be $script:orig
    }

    It 'REFUSES to restore when the user changed the index after aic did' {
        Set-TestFile $script:repo 'user-added.txt' "u`n"; [void](G $script:repo add -- user-added.txt)   # the user acts meanwhile
        $changed = Get-IndexFingerprint $script:repo
        $r = Restore-IndexSnapshot $script:repo $script:snap $script:after
        $r.Restored | Should -BeFalse
        $r.Reason | Should -Match 'changed'
        Get-IndexFingerprint $script:repo | Should -Be $changed -Because "the user's staging must survive"
    }

    It 'REFUSES to restore while another git process holds index.lock, and leaves that lock alone' {
        $lock = "$($script:snap.Path).lock"; [IO.File]::WriteAllText($lock, '')
        try {
            (Restore-IndexSnapshot $script:repo $script:snap $script:after).Restored | Should -BeFalse
            Test-Path -LiteralPath $lock | Should -BeTrue
        } finally { Remove-Item -LiteralPath $lock -Force -ErrorAction SilentlyContinue }
    }

    It 'REFUSES to restore when HEAD moved (e.g. a commit happened in between)' {
        [void](G $script:repo commit -q -m 'chore: user commit')
        (Restore-IndexSnapshot $script:repo $script:snap $script:after).Restored | Should -BeFalse
    }
}
