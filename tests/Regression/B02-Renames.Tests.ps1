# B2 (High): renames. `diff --name-only`, `numstat` and `status` all present renames differently from what aic assumes.
BeforeAll { . (Join-Path $PSScriptRoot '..' 'Helpers' 'All.ps1') }

Describe 'B2: renames are handled as old-path + new-path' -Tag 'Regression', 'B02' {
    BeforeEach { $script:sb = New-AicSandbox; Enter-AicSandbox $script:sb }
    AfterEach  { Exit-AicSandbox $script:sb; Remove-AicSandbox $script:sb }

    It 'Limit-ToAi (-AiOnly): a rename from a non-AI path into an AI path must not leave the old-path deletion staged' {
        $repo = New-TestRepo $script:sb @{ 'notes/guide.txt' = "guide line 1`nguide line 2`nguide line 3`nguide line 4`n"; 'README.md' = "r`n" }
        New-Item -ItemType Directory -Path (Join-Path $repo 'prompts') -Force | Out-Null
        [void](G $repo mv notes/guide.txt prompts/guide.txt)
        (G $repo diff --cached --name-status --no-renames) | Should -Contain "D`tnotes/guide.txt"   # precondition
        $wt = Get-WorktreeFingerprint $repo

        $r = Invoke-AicHarness -Sandbox $script:sb -AicParams @{ Yes = $true } -Script {
            Limit-ToAi
            [pscustomobject]@{ Done = $true }
        }

        $r.Error | Should -BeNullOrEmpty
        @(G $repo diff --cached --name-status --no-renames) | Should -Be @("A`tprompts/guide.txt") `
            -Because 'an AI-only commit may contain AI paths only: the deletion of notes/guide.txt is not an AI change'
        Get-WorktreeFingerprint $repo | Should -Be $wt
    }

    It 'Load-Changes: a renamed file is reported under its real new path, not as "dir/{old => new}"' {
        $repo = New-TestRepo $script:sb @{ 'docs/old-name.md' = "# Title`nline a`nline b`nline c`nline d`n" }
        [void](G $repo mv docs/old-name.md docs/new-name.md)

        $r = Invoke-AicHarness -Sandbox $script:sb -Script {
            $n = Load-Changes
            [pscustomobject]@{ N = $n; Paths = @($ctx.Files | ForEach-Object { $_.Path }) }
        }

        $r.Error | Should -BeNullOrEmpty
        @($r.Output.Paths) | Should -Be @('docs/new-name.md')
    }

    It 'Load-Changes: renaming AGENTS.md to CLAUDE.md is recognised as an all-AI change' {
        $repo = New-TestRepo $script:sb @{ 'AGENTS.md' = "rule 1`nrule 2`nrule 3`nrule 4`n" }
        [void](G $repo mv AGENTS.md CLAUDE.md)

        $r = Invoke-AicHarness -Sandbox $script:sb -Script {
            [void](Load-Changes)
            [pscustomobject]@{ AllAi = [bool]$ctx.Repo.AllAi; AiPaths = @($ctx.Repo.AiPaths) }
        }

        $r.Error | Should -BeNullOrEmpty
        $r.Output.AllAi | Should -BeTrue -Because 'both sides of the rename are AI instruction files'
    }

    It 'Select-Files: unticking a renamed file unstages the whole rename (new path AND old-path deletion)' {
        $repo = New-TestRepo $script:sb @{ 'a.txt' = "alpha 1`nalpha 2`nalpha 3`nalpha 4`n" }
        [void](G $repo mv a.txt b.txt)

        $r = Invoke-AicHarness -Sandbox $script:sb -Script {
            function Pick-Many { param($title, $labels, $checked, $ai) return , [bool[]]@($checked | ForEach-Object { $false }) }   # untick everything
            Select-Files
            [pscustomobject]@{ Done = $true }
        }

        $r.Error | Should -BeNullOrEmpty
        (GTry $repo diff --cached --quiet).Rc | Should -Be 0 -Because 'with everything unticked the index must equal HEAD again (no half-rename left behind)'
    }
}
