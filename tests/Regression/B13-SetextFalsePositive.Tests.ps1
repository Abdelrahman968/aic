# B13 (Medium): a bare "=======" line (Markdown / reStructuredText heading underline) is treated as a merge-conflict marker,
# which makes -Yes refuse and a normal commit ask for confirmation.
BeforeAll { . (Join-Path $PSScriptRoot '..' 'Helpers' 'All.ps1') }

Describe 'B13: conflict-marker detection' -Tag 'Regression', 'B13' {
    BeforeEach { $script:sb = New-AicSandbox; Enter-AicSandbox $script:sb }
    AfterEach  { Exit-AicSandbox $script:sb; Remove-AicSandbox $script:sb }

    It 'a setext heading underline (=======) in Markdown is not a conflict marker' {
        $repo = New-TestRepo $script:sb
        Set-TestFile $repo 'docs/guide.md' "Install`n=======`n`nRun the installer.`n"
        [void](G $repo add -- docs/guide.md)
        $r = Invoke-AicHarness -Sandbox $script:sb -Script {
            $d = (git @gitC diff --staged --no-color) -join "`n"
            $x = Find-Leftovers $d
            [pscustomobject]@{ Blocking = [bool]$x.Blocking; Notes = @($x.Notes) }
        }
        $r.Error | Should -BeNullOrEmpty
        $r.Output.Blocking | Should -BeFalse -Because 'documentation headings must not block -Yes'
    }

    It 'CONTROL: a real conflict block with all three marker lines is still detected' -Tag 'Control' {
        $repo = New-TestRepo $script:sb
        Set-TestFile $repo 'src/a.js' "<<<<<<< HEAD`nlet a = 1;`n=======`nlet a = 2;`n>>>>>>> feature`n"
        [void](G $repo add -- src/a.js)
        $r = Invoke-AicHarness -Sandbox $script:sb -Script {
            $d = (git @gitC diff --staged --no-color) -join "`n"
            $x = Find-Leftovers $d
            [pscustomobject]@{ Blocking = [bool]$x.Blocking }
        }
        $r.Error | Should -BeNullOrEmpty
        $r.Output.Blocking | Should -BeTrue
    }
}
