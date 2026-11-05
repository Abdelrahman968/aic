# B16: the "Refs:" footer is derived from the branch name with patterns that match years and CVE ids.
# B21: a commit that only touches lockfiles / generated files is refused as "nothing staged".
BeforeAll { . (Join-Path $PSScriptRoot '..' 'Helpers' 'All.ps1'); $script:mock = Start-MockOllama }
AfterAll  { Stop-MockOllama $script:mock }

Describe 'C6: auto-ref and lockfile-only commits' -Tag 'Regression', 'C06' {
    BeforeEach {
        $script:sb = New-AicSandbox; Enter-AicSandbox $script:sb
        Set-MockChat $script:mock @{ Lines = (New-ChatLines -Text 'feat: add thing') }
        $script:repo = New-TestRepo $script:sb @{ 'a.txt' = "one`n"; 'package-lock.json' = "{}`n" }
    }
    AfterEach { Exit-AicSandbox $script:sb; Remove-AicSandbox $script:sb }
    function script:RunOn([string]$branch) {
        [void](G $script:repo switch -q -c $branch)
        Set-TestFile $script:repo 'a.txt' "two`n"; [void](G $script:repo add -- a.txt)
        Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ DryRun = $true }
    }

    It 'a year-like branch prefix (2024-refactor) is not an issue number' { (RunOn '2024-refactor').Stdout | Should -Not -Match 'from the branch name' }
    It 'a date-like branch prefix (12-05-cleanup) is not an issue number'  { (RunOn '12-05-cleanup').Stdout | Should -Not -Match 'from the branch name' }
    It 'a CVE id (fix/CVE-2024-1234) is not cut into a bogus ticket key'   { (RunOn 'fix/CVE-2024-1234').Stdout | Should -Not -Match 'ref CVE-2024 ' }
    It 'CONTROL: feat/ABC-123-login still gives Refs ABC-123' -Tag 'Control' { (RunOn 'feat/ABC-123-login').Stdout | Should -Match 'ref ABC-123 \(from the branch name\)' }
    It 'CONTROL: 42-fix-header still gives #42' -Tag 'Control'               { (RunOn '42-fix-header').Stdout | Should -Match 'ref #42 \(from the branch name\)' }
    It 'CONTROL: issue-42 still gives #42' -Tag 'Control'                    { (RunOn 'issue-42').Stdout | Should -Match 'ref #42 \(from the branch name\)' }

    It 'a commit that only changes a lockfile can still be written' {
        Set-TestFile $script:repo 'package-lock.json' "{ `"lockfileVersion`": 3 }`n"; [void](G $script:repo add -- package-lock.json)
        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ DryRun = $true }
        $e.Stdout | Should -Match 'dry run' -Because $e.Stdout
        $e.Code | Should -Be 0
    }
    It 'an empty index is still "nothing to commit" (exit 5), the lockfile fallback does not invent a commit' {
        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ DryRun = $true }
        $e.Code | Should -Be 5
    }
}
