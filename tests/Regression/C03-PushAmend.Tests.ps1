# B11: -Push hard-codes "origin" and HEAD; -Amend rewrites a commit that is already on the remote without a word.
BeforeAll { . (Join-Path $PSScriptRoot '..' 'Helpers' 'All.ps1'); $script:mock = Start-MockOllama }
AfterAll  { Stop-MockOllama $script:mock }

Describe 'C3: push and amend guards' -Tag 'Regression', 'C03' {
    BeforeEach {
        $script:sb = New-AicSandbox; Enter-AicSandbox $script:sb
        Set-MockChat $script:mock @{ Lines = (New-ChatLines -Text 'feat: add thing') }
        $script:repo = New-TestRepo $script:sb @{ 'a.txt' = "one`n" }
        Set-TestFile $script:repo 'a.txt' "two`n"; [void](G $script:repo add -- a.txt)
    }
    AfterEach { Exit-AicSandbox $script:sb; Remove-AicSandbox $script:sb }

    It '-Push with a single remote that is not called origin pushes to it and sets the upstream' {
        $bare = Add-BareRemote $script:sb 'up'
        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ Yes = $true; Push = $true }
        Get-RemoteRef $bare 'refs/heads/main' | Should -Be (Get-HeadSha $script:repo) -Because $e.Stdout
        $e.Code | Should -Be 0
    }
    It '-Push with several remotes and no upstream does not guess: it names the remotes and pushes nowhere' {
        $b1 = Add-BareRemote $script:sb 'up1'; $b2 = Add-BareRemote $script:sb 'up2'
        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ Yes = $true; Push = $true }
        Get-RemoteRef $b1 'refs/heads/main' | Should -BeNullOrEmpty
        Get-RemoteRef $b2 'refs/heads/main' | Should -BeNullOrEmpty
        $e.Stdout | Should -Match 'up1'; $e.Stdout | Should -Match 'up2'
        $e.Code | Should -Be 1
    }
    It '-Amend on a commit that is already on the remote warns that history is being rewritten' {
        [void](Add-BareRemote $script:sb 'origin')
        [void](G $script:repo commit -q -m 'feat: first'); [void](G $script:repo push -q -u origin main)
        Set-TestFile $script:repo 'a.txt' "three`n"; [void](G $script:repo add -- a.txt)
        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ Amend = $true; Yes = $true }
        $e.Stdout | Should -Match 'already on the remote'
    }
    It 'CONTROL: -Amend on a local-only commit does not warn' -Tag 'Control' {
        [void](Add-BareRemote $script:sb 'origin')
        [void](G $script:repo commit -q -m 'feat: first')
        Set-TestFile $script:repo 'a.txt' "three`n"; [void](G $script:repo add -- a.txt)
        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ Amend = $true; Yes = $true }
        $e.Stdout | Should -Not -Match 'already on the remote'
    }
    It 'CONTROL: -Push to origin with an upstream already set keeps working' -Tag 'Control' {
        $bare = Add-BareRemote $script:sb 'origin'
        [void](G $script:repo commit -q -m 'feat: first'); [void](G $script:repo push -q -u origin main)
        Set-TestFile $script:repo 'a.txt' "three`n"; [void](G $script:repo add -- a.txt)
        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ Yes = $true; Push = $true }
        Get-RemoteRef $bare 'refs/heads/main' | Should -Be (Get-HeadSha $script:repo)
    }
}
