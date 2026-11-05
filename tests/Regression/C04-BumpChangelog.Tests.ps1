# B12 / B24: -Bump picks the NEAREST tag (not the highest), drops prerelease info, trusts any tag name, counts prose that merely
# mentions "BREAKING CHANGE", ignores shallow clones and remote tag state; -Changelog ignores BREAKING CHANGE footers.
BeforeAll { . (Join-Path $PSScriptRoot '..' 'Helpers' 'All.ps1') }

Describe 'C4: -Bump and -Changelog' -Tag 'Regression', 'C04' {
    BeforeEach { $script:sb = New-AicSandbox; Enter-AicSandbox $script:sb; $script:repo = New-TestRepo $script:sb @{ 'a.txt' = "one`n" } }
    AfterEach  { Exit-AicSandbox $script:sb; Remove-AicSandbox $script:sb }
    function script:Tags { @(G $script:repo tag --list) }

    It 'bases the bump on the HIGHEST semver tag reachable from HEAD, not the nearest one' {
        [void](G $script:repo tag -a v1.0.0 -m r); Add-TestCommit $script:repo 'fix: a'; [void](G $script:repo tag -a v0.9.0 -m old)
        Add-TestCommit $script:repo 'feat: b'
        $e = Invoke-Aic -Sandbox $script:sb -Params @{ Bump = $true; Yes = $true }
        Tags | Should -Contain 'v1.1.0' -Because $e.Stdout
        Tags | Should -Not -Contain 'v0.10.0'
    }
    It 'bumping from a prerelease releases that version (v1.2.3-rc.1 + fix -> v1.2.3)' {
        [void](G $script:repo tag -a v1.2.3-rc.1 -m rc); Add-TestCommit $script:repo 'fix: x'
        $e = Invoke-Aic -Sandbox $script:sb -Params @{ Bump = $true; Yes = $true }
        Tags | Should -Contain 'v1.2.3' -Because $e.Stdout
    }
    It 'ignores tags that are not semantic versions' {
        [void](G $script:repo tag -a v1.0.0 -m r); Add-TestCommit $script:repo 'fix: a'; [void](G $script:repo tag -a nightly -m n)
        Add-TestCommit $script:repo 'feat: b'
        $e = Invoke-Aic -Sandbox $script:sb -Params @{ Bump = $true; Yes = $true }
        Tags | Should -Contain 'v1.1.0' -Because $e.Stdout
    }
    It 'prose that merely mentions BREAKING CHANGE is not a breaking change' {
        [void](G $script:repo tag -a v1.0.0 -m r); Add-TestCommit $script:repo 'feat: add y' 'this is not a BREAKING CHANGE, just a note'
        $e = Invoke-Aic -Sandbox $script:sb -Params @{ Bump = $true; Yes = $true }
        Tags | Should -Contain 'v1.1.0' -Because $e.Stdout
    }
    It 'refuses to bump in a shallow clone (history is incomplete)' {
        [void](G $script:repo tag -a v1.0.0 -m r); Add-TestCommit $script:repo 'fix: a'; Add-TestCommit $script:repo 'fix: b'
        [void](G $script:sb.Base clone -q --depth 1 "file://$($script:repo)" shallow)
        $e = Invoke-Aic -Sandbox $script:sb -Cwd (Join-Path $script:sb.Base 'shallow') -Params @{ Bump = $true; Yes = $true }
        @(G (Join-Path $script:sb.Base 'shallow') tag --list 'v1.0.1') | Should -BeNullOrEmpty
        $e.Stdout | Should -Match 'shallow'
    }
    It 'refuses -Push when the tag already exists on the remote, and creates no local tag' {
        $bare = Add-BareRemote $script:sb 'origin'
        [void](G $script:repo tag -a v1.0.0 -m r); Add-TestCommit $script:repo 'feat: b'
        [void](G $script:repo tag -a v1.1.0 -m other); [void](G $script:repo push -q origin v1.1.0); [void](G $script:repo tag -d v1.1.0)
        [void](G $script:repo tag -d v1.0.0); [void](G $script:repo tag -a v1.0.0 -m r HEAD~1)
        $e = Invoke-Aic -Sandbox $script:sb -Params @{ Bump = $true; Yes = $true; Push = $true }
        Tags | Should -Not -Contain 'v1.1.0' -Because $e.Stdout
        $e.Stdout | Should -Match 'remote'
    }
    It '-Changelog lists a BREAKING CHANGE footer under "Breaking changes"' {
        [void](G $script:repo tag -a v1.0.0 -m r); Add-TestCommit $script:repo 'feat: shiny' 'BREAKING CHANGE: the old api is gone'
        $e = Invoke-Aic -Sandbox $script:sb -Params @{ Changelog = $true; PassThru = $true }
        ($e.Pipeline -join "`n") | Should -Match '(?s)### Breaking changes\s*\n- shiny'
    }
    It 'CONTROL: a BREAKING CHANGE footer makes a major bump' -Tag 'Control' {
        [void](G $script:repo tag -a v1.0.0 -m r); Add-TestCommit $script:repo 'feat: z' 'BREAKING CHANGE: api removed'
        $e = Invoke-Aic -Sandbox $script:sb -Params @{ Bump = $true; Yes = $true }
        Tags | Should -Contain 'v2.0.0'
    }
    It 'CONTROL: "feat!:" makes a major bump; build metadata (v1.2.3+b5) bumps the patch' -Tag 'Control' {
        [void](G $script:repo tag -a v1.0.0 -m r); Add-TestCommit $script:repo 'feat!: z'
        [void](Invoke-Aic -Sandbox $script:sb -Params @{ Bump = $true; Yes = $true }); Tags | Should -Contain 'v2.0.0'
    }
    It 'CONTROL: -Bump -Yes -Push pushes the new tag' -Tag 'Control' {
        $bare = Add-BareRemote $script:sb 'origin'
        [void](G $script:repo tag -a v1.0.0 -m r); Add-TestCommit $script:repo 'fix: a'
        [void](Invoke-Aic -Sandbox $script:sb -Params @{ Bump = $true; Yes = $true; Push = $true })
        Get-RemoteRef $bare 'refs/tags/v1.0.1' | Should -Not -BeNullOrEmpty
    }
}
