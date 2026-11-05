# B3 (continued): behaviour of the private-index session itself: publish, guarded restore, refusals, cleanup.
BeforeAll {
    . (Join-Path $PSScriptRoot '..' 'Helpers' 'All.ps1')
    $script:mock = Start-MockOllama
}
AfterAll { Stop-MockOllama $script:mock }

Describe 'B3b: index session (private index copy, guarded publish and restore)' -Tag 'Regression', 'B03' {
    BeforeEach {
        $script:sb = New-AicSandbox; Enter-AicSandbox $script:sb
        Set-MockChat $script:mock @{ Lines = (New-ChatLines -Text 'feat: add thing') }
    }
    AfterEach { Exit-AicSandbox $script:sb; Remove-AicSandbox $script:sb }

    # an index with every awkward state at once: partial staging, intent-to-add, skip-worktree, plus untracked files
    function script:New-AwkwardRepo($sb) {
        $r = New-PartialStaging $sb
        Set-TestFile $r 'ita.txt' "i`n"; [void](G $r add -N ita.txt)
        [void](G $r update-index --skip-worktree other.txt)
        Set-TestFile $r 'extra.txt' "e`n"; Set-TestFile $r 'user.txt' "u`n"
        $r
    }

    It 'publish + restore puts the ORIGINAL index back exactly (partial staging, intent-to-add, skip-worktree)' {
        $repo = New-AwkwardRepo $script:sb
        $orig = Get-IndexFingerprint $repo; $wt = Get-WorktreeFingerprint $repo
        $r = Invoke-AicHarness -Sandbox $script:sb -Script {
            Start-IndexSession
            git @gitC add -A 2>&1 | Out-Null
            $ok  = Publish-IndexSession
            $mid = (git @gitC diff --cached --name-only) -join ','
            $rs  = Restore-IndexSession
            Stop-IndexSession
            [pscustomobject]@{ Published = $ok; Mid = $mid; Restore = $rs }
        }
        $r.Error | Should -BeNullOrEmpty
        $r.Output.Published | Should -BeTrue
        $r.Output.Mid | Should -Match 'extra\.txt' -Because 'precondition: the published index really held aic''s staging'
        $r.Output.Restore | Should -Be 'restored'
        Get-IndexFingerprint $repo | Should -Be $orig
        Get-WorktreeFingerprint $repo | Should -Be $wt
    }

    It 'restore REFUSES when the user staged something after aic published, and leaves the user''s index alone' {
        $repo = New-AwkwardRepo $script:sb
        $r = Invoke-AicHarness -Sandbox $script:sb -Script {
            Start-IndexSession
            git @gitC add -- extra.txt 2>&1 | Out-Null
            [void](Publish-IndexSession)
            git @gitC add -- user.txt 2>&1 | Out-Null                       # the user acts after aic
            $rs = Restore-IndexSession
            Stop-IndexSession
            [pscustomobject]@{ Restore = $rs }
        }
        $r.Error | Should -BeNullOrEmpty
        $r.Output.Restore | Should -Be 'index-changed'
        @(G $repo diff --cached --name-only) | Should -Contain 'user.txt'
        @(G $repo diff --cached --name-only) | Should -Contain 'extra.txt'
    }

    It 'publish REFUSES (and modifies nothing) when the user changed the index while aic was running' {
        $repo = New-AwkwardRepo $script:sb
        $r = Invoke-AicHarness -Sandbox $script:sb -Script {
            Start-IndexSession
            git @gitC add -- extra.txt 2>&1 | Out-Null                       # aic stages into its private copy
            $env:GIT_INDEX_FILE = $null; git @gitC add -- user.txt 2>&1 | Out-Null; $env:GIT_INDEX_FILE = $idx.Shadow   # the user stages in another terminal
            $ok = Publish-IndexSession
            Stop-IndexSession
            [pscustomobject]@{ Published = $ok }
        }
        $r.Error | Should -BeNullOrEmpty
        $r.Output.Published | Should -BeFalse
        $staged = @(G $repo diff --cached --name-only)
        $staged | Should -Contain 'user.txt' -Because "the user's own change must survive"
        $staged | Should -Not -Contain 'extra.txt' -Because 'aic must not have written its private staging into the real index'
    }

    It 'publish REFUSES while another git process holds index.lock, and does not delete that lock' {
        $repo = New-AwkwardRepo $script:sb
        $lock = Join-Path $repo '.git' 'index.lock'; [IO.File]::WriteAllText($lock, '')
        $before = Get-IndexFingerprint $repo
        try {
            $r = Invoke-AicHarness -Sandbox $script:sb -Script {
                Start-IndexSession; git @gitC add -- extra.txt 2>&1 | Out-Null
                $ok = Publish-IndexSession; Stop-IndexSession
                [pscustomobject]@{ Published = $ok }
            }
            $r.Error | Should -BeNullOrEmpty
            $r.Output.Published | Should -BeFalse
            Test-Path -LiteralPath $lock | Should -BeTrue
            Get-IndexFingerprint $repo | Should -Be $before
        } finally { Remove-Item -LiteralPath $lock -Force -ErrorAction SilentlyContinue }
    }

    It 'publish REFUSES when HEAD moved while aic was running' {
        $repo = New-AwkwardRepo $script:sb
        $r = Invoke-AicHarness -Sandbox $script:sb -Script {
            Start-IndexSession; git @gitC add -- extra.txt 2>&1 | Out-Null
            $env:GIT_INDEX_FILE = $null; git @gitC commit -q --allow-empty -m 'chore: elsewhere' 2>&1 | Out-Null; $env:GIT_INDEX_FILE = $idx.Shadow
            $ok = Publish-IndexSession; Stop-IndexSession
            [pscustomobject]@{ Published = $ok }
        }
        $r.Error | Should -BeNullOrEmpty
        $r.Output.Published | Should -BeFalse
        @(G $repo diff --cached --name-only) | Should -Not -Contain 'extra.txt'
    }

    It 'leaves no private index file behind (after a dry run, and after a refused -Yes)' {
        $repo = New-MixedRepo $script:sb
        [void](Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ All = $true; DryRun = $true })
        Set-TestFile $repo 'cfg.txt' "aws_access_key_id = AKIAIOSFODNN7EXAMPLE`n"
        [void](Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ All = $true; Yes = $true })        # refused: secret
        @(Get-ChildItem -LiteralPath (Join-Path $repo '.git') -Filter 'aic-shadow-*' -Force) | Should -BeNullOrEmpty
        Test-Path -LiteralPath (Join-Path $repo '.git' 'index.lock') | Should -BeFalse
    }

    It 'a failing pre-commit hook: nothing is committed, no crash, no leftover private index' -Skip:($IsWindows) {
        $repo = New-MixedRepo $script:sb
        $hook = Join-Path $repo '.git' 'hooks' 'pre-commit'
        [IO.File]::WriteAllText($hook, "#!/bin/sh`nexit 1`n"); & chmod +x $hook
        $head = Get-HeadSha $repo
        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ All = $true; Yes = $true }
        $e.TimedOut | Should -BeFalse
        $e.Stdout | Should -Match 'did not complete'
        Get-HeadSha $repo | Should -Be $head
        @(Get-ChildItem -LiteralPath (Join-Path $repo '.git') -Filter 'aic-shadow-*' -Force) | Should -BeNullOrEmpty
    }
}
