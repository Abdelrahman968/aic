# B4 (High): unmerged (conflicted) paths look "staged + dirty" to aic, so staging helpers `git add` them,
# which silently marks the conflict as resolved while the conflict markers are still in the file.
BeforeAll {
    . (Join-Path $PSScriptRoot '..' 'Helpers' 'All.ps1')
    $script:mock = Start-MockOllama
}
AfterAll { Stop-MockOllama $script:mock }

Describe 'B4: conflicted files are never marked resolved by aic' -Tag 'Regression', 'B04' {
    BeforeEach {
        $script:sb = New-AicSandbox; Enter-AicSandbox $script:sb
        Set-MockChat $script:mock @{ Lines = (New-ChatLines -Text 'feat: add thing') }
    }
    AfterEach { Exit-AicSandbox $script:sb; Remove-AicSandbox $script:sb }

    It 'Stage-AiFiles does not `git add` a conflicted AI file' {
        $repo = New-ConflictRepo $script:sb
        $un = Get-UnmergedFingerprint $repo
        $wt = Get-WorktreeFingerprint $repo

        $r = Invoke-AicHarness -Sandbox $script:sb -Script { [pscustomobject]@{ Added = (Stage-AiFiles) } }

        $r.Error | Should -BeNullOrEmpty
        Get-UnmergedFingerprint $repo | Should -Be $un -Because 'prompts/p.md still contains conflict markers and must stay unmerged'
        Get-WorktreeFingerprint $repo | Should -Be $wt
    }

    It 'Select-Files: accepting the untouched checklist does not resolve conflicted paths' {
        $repo = New-ConflictRepo $script:sb
        $un = Get-UnmergedFingerprint $repo

        $r = Invoke-AicHarness -Sandbox $script:sb -Script {
            function Pick-Many { param($title, $labels, $checked, $ai) return , [bool[]]@($checked) }
            Select-Files
            [pscustomobject]@{ Done = $true }
        }

        $r.Error | Should -BeNullOrEmpty
        Get-UnmergedFingerprint $repo | Should -Be $un
    }

    It '-All -DryRun does not resolve conflicted paths (end to end)' {
        $repo = New-ConflictRepo $script:sb
        $un = Get-UnmergedFingerprint $repo

        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ All = $true; DryRun = $true }

        $e.TimedOut | Should -BeFalse
        Get-UnmergedFingerprint $repo | Should -Be $un -Because '`git add -A` during a merge silently stages the conflict markers'
    }

    It 'CONTROL: a plain -DryRun during a merge does not change the unmerged state' -Tag 'Control' {
        $repo = New-ConflictRepo $script:sb
        $un = Get-UnmergedFingerprint $repo

        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ DryRun = $true }

        $e.TimedOut | Should -BeFalse
        Get-UnmergedFingerprint $repo | Should -Be $un
    }
}
