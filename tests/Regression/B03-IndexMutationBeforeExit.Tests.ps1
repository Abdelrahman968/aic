# B3 (High): aic mutates the index (-All, -AiFiles, -AiOnly) BEFORE it knows the run will end in a commit.
# -DryRun promises "nothing was committed" / preview only; a run that ends without a commit must not leave the index changed.
BeforeAll {
    . (Join-Path $PSScriptRoot '..' 'Helpers' 'All.ps1')
    $script:mock = Start-MockOllama
}
AfterAll { Stop-MockOllama $script:mock }

Describe 'B3: runs that end without a commit leave the index as they found it' -Tag 'Regression', 'B03' {
    BeforeEach {
        $script:sb = New-AicSandbox; Enter-AicSandbox $script:sb
        Set-MockChat $script:mock @{ Lines = (New-ChatLines -Text 'feat: add thing') }
    }
    AfterEach { Exit-AicSandbox $script:sb; Remove-AicSandbox $script:sb }

    It '<Flag> -DryRun does not change the index or the working tree' -ForEach @(
        @{ Flag = '-All';     P = @{ All = $true;     DryRun = $true } }
        @{ Flag = '-AiFiles'; P = @{ AiFiles = $true; DryRun = $true } }
        @{ Flag = '-AiOnly';  P = @{ AiOnly = $true;  DryRun = $true } }
    ) {
        $repo   = New-MixedRepo $script:sb
        $before = Get-IndexFingerprint $repo
        $wt     = Get-WorktreeFingerprint $repo
        $head   = Get-HeadSha $repo

        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params $P

        $e.TimedOut | Should -BeFalse
        $e.Stdout | Should -Match 'dry run' -Because 'precondition: the run must have reached the dry-run stop'
        Get-HeadSha $repo | Should -Be $head
        Get-WorktreeFingerprint $repo | Should -Be $wt
        Get-IndexFingerprint $repo | Should -Be $before -Because 'a preview must not stage or unstage anything'
    }

    # SPEC (derived from the audit proposal, not from the original behaviour): a non-interactive run that fails before
    # committing should hand the index back as it found it.
    It '-All followed by a generation failure leaves the index as found' -Tag 'Spec' {
        $repo = New-MixedRepo $script:sb
        Set-MockChat $script:mock @{ Status = 500; Body = '{"error":"model exploded"}' }
        $before = Get-IndexFingerprint $repo

        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ All = $true; Yes = $true }

        $e.TimedOut | Should -BeFalse
        $e.Stdout | Should -Match 'Generation failed' -Because 'precondition: the failure path was taken'
        Get-IndexFingerprint $repo | Should -Be $before
    }

    It '-All -DryRun in an unborn repository leaves the index as found' {
        $repo = $script:sb.Repo
        [void](G $repo init -q -b main .)
        Set-TestFile $repo 'a.txt' "one`n"; Set-TestFile $repo 'b.txt' "two`n"; [void](G $repo add -- a.txt)
        $before = Get-IndexFingerprint $repo
        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ All = $true; DryRun = $true }
        $e.TimedOut | Should -BeFalse
        Get-IndexFingerprint $repo | Should -Be $before
    }
}
