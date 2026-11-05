# B7 (High): model output (and file names) are untrusted. Prompt injection through a diff / file name / commit history can make the
# model emit forged trailers (Signed-off-by, Closes ...) or terminal escape sequences. aic must not pass either through.
BeforeAll {
    . (Join-Path $PSScriptRoot '..' 'Helpers' 'All.ps1')
    $script:mock = Start-MockOllama
}
AfterAll { Stop-MockOllama $script:mock }

Describe 'B7: model output and file names are treated as untrusted' -Tag 'Regression', 'B07' {
    BeforeEach { $script:sb = New-AicSandbox; Enter-AicSandbox $script:sb }
    AfterEach  { Exit-AicSandbox $script:sb; Remove-AicSandbox $script:sb }

    Context 'forged trailers' {
        It 'drops model-supplied Signed-off-by / Co-authored-by / Closes / Fixes lines' {
            $repo = New-TestRepo $script:sb
            $r = Invoke-AicHarness -Sandbox $script:sb -Script {
                $raw = "feat(x): add y`n`n- did a thing`n`nSigned-off-by: Evil <e@evil.test>`nCo-authored-by: Bot <b@evil.test>`nCloses #1`nFixes #2"
                [pscustomobject]@{ Msg = (Normalize-Message $raw) }
            }
            $r.Error | Should -BeNullOrEmpty
            $r.Output.Msg | Should -Not -Match 'Signed-off-by'
            $r.Output.Msg | Should -Not -Match 'Co-authored-by'
            $r.Output.Msg | Should -Not -Match '(?m)^Closes'
            $r.Output.Msg | Should -Not -Match '(?m)^Fixes'
        }

        It 'CONTROL: BREAKING CHANGE and Refs footers from the model are kept' -Tag 'Control' {
            $repo = New-TestRepo $script:sb
            $r = Invoke-AicHarness -Sandbox $script:sb -Script {
                [pscustomobject]@{ Msg = (Normalize-Message "feat(x)!: drop v1 api`n`n- removed the endpoint`n`nBREAKING CHANGE: v1 is gone`nRefs: #7") }
            }
            $r.Output.Msg | Should -Match 'BREAKING CHANGE: v1 is gone'
            $r.Output.Msg | Should -Match 'Refs: #7'
        }

        It 'CONTROL: the user-supplied -CoAuthor still produces exactly one Co-authored-by footer' -Tag 'Control' {
            $repo = New-TestRepo $script:sb
            $r = Invoke-AicHarness -Sandbox $script:sb -AicParams @{ CoAuthor = 'Jane Doe <jane@example.com>' } -Script {
                [pscustomobject]@{ Msg = (Normalize-Message 'feat: add y') }
            }
            ([regex]::Matches($r.Output.Msg, 'Co-authored-by: Jane Doe <jane@example.com>')).Count | Should -Be 1
        }
    }

    Context 'terminal escape sequences and control characters' {
        It 'Normalize-Message strips ESC / BEL / C1 control characters from subject and bullets' {
            $repo = New-TestRepo $script:sb
            $r = Invoke-AicHarness -Sandbox $script:sb -Script {
                $e = [string][char]27; $bel = [string][char]7; $c1 = [string][char]0x9B
                $raw = "feat: add $e]0;pwned$bel thing $e[31mred$c1`n`n- bullet $e[2Jgone"
                $m = Normalize-Message $raw
                $ctrl = @($m.ToCharArray() | Where-Object { [char]::IsControl($_) -and $_ -ne "`n" }).Count
                [pscustomobject]@{ Msg = $m; ControlChars = $ctrl }
            }
            $r.Error | Should -BeNullOrEmpty
            $r.Output.ControlChars | Should -Be 0 -Because 'control characters would be rendered by the terminal and written to git history'
        }

        It 'a model reply containing escape sequences never reaches the commit (end to end, -Yes)' {
            $repo = New-TestRepo $script:sb
            Set-TestFile $repo 'a.txt' "two`n"; [void](G $repo add -- a.txt)
            $evil = "feat: add " + [char]27 + "]0;pwned" + [char]7 + " thing"
            Set-MockChat $script:mock @{ Lines = (New-ChatLines -Text $evil) }
            $head = Get-HeadSha $repo

            $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ Yes = $true }

            $e.TimedOut | Should -BeFalse
            $subject = ((GTry $repo log -1 --format=%B).Out -join "`n")
            $subject.Contains([string][char]27) | Should -BeFalse -Because "HEAD message was: $subject"
            $subject.Contains([string][char]7)  | Should -BeFalse
        }

        It '-ListAi does not print raw escape sequences found in file names' -Skip:($IsWindows) {
            $repo = New-TestRepo $script:sb
            Set-TestFile $repo ("prompts/a" + [char]27 + "[31mred.md") "x`n"      # a hostile (but legal on Linux/macOS) file name

            $e = Invoke-Aic -Sandbox $script:sb -Params @{ ListAi = $true }

            $e.TimedOut | Should -BeFalse
            $e.Stdout | Should -Match 'red\.md' -Because 'precondition: the file was listed'
            $e.Stdout.Contains([string][char]27) | Should -BeFalse -Because 'a file name must not be able to drive the terminal'
        }
    }
}
