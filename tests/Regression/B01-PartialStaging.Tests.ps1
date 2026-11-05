# B1 (Critical): partial staging (`git add -p`) is destroyed by the file checklist and by AI-file staging.
# Expected to FAIL against the original implementation; they pin the behaviour Step 2 must deliver.
BeforeAll { . (Join-Path $PSScriptRoot '..' 'Helpers' 'All.ps1') }

Describe 'B1: partial staging must survive file selection and AI-file staging' -Tag 'Regression', 'B01' {
    BeforeEach { $script:sb = New-AicSandbox; Enter-AicSandbox $script:sb }
    AfterEach  { Exit-AicSandbox $script:sb; Remove-AicSandbox $script:sb }

    It 'Select-Files: pressing Enter on the untouched checklist keeps a partially staged file (MM) exactly as staged' {
        $repo   = New-PartialStaging $script:sb
        $before = Get-IndexFingerprint $repo
        $blob   = Get-StagedBlob $repo 'partial.txt'
        $wt     = Get-WorktreeFingerprint $repo

        $r = Invoke-AicHarness -Sandbox $script:sb -Script {
            function Pick-Many { param($title, $labels, $checked, $ai) return , [bool[]]@($checked) }   # user just presses Enter
            Select-Files
            [pscustomobject]@{ Done = $true }
        }

        $r.Error | Should -BeNullOrEmpty
        Get-StagedBlob $repo 'partial.txt' | Should -Be $blob -Because 'only the STAGED line was staged; the UNSTAGED line must not have been added'
        Get-IndexFingerprint $repo | Should -Be $before
        Get-WorktreeFingerprint $repo | Should -Be $wt -Because 'nothing on disk may change'
    }

    It 'Stage-AiFiles: a partially staged AI file keeps its staged content (the unstaged hunk is not silently added)' {
        $repo = New-PartialStaging $script:sb 'prompts/system.md'
        $blob = Get-StagedBlob $repo 'prompts/system.md'
        $wt   = Get-WorktreeFingerprint $repo

        $r = Invoke-AicHarness -Sandbox $script:sb -Script {
            $n = Stage-AiFiles
            [pscustomobject]@{ Added = $n }
        }

        $r.Error | Should -BeNullOrEmpty
        Get-StagedBlob $repo 'prompts/system.md' | Should -Be $blob -Because '-AiFiles / autoStageAi must not overwrite a hand-built partial staging'
        Get-WorktreeFingerprint $repo | Should -Be $wt
    }
}
