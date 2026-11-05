# CONTROLS: behaviour that works today and must keep working after every fix (backward compatibility).
# They also prove the harness itself is sound: if these fail, a regression-test failure elsewhere may be a harness problem.
BeforeAll {
    . (Join-Path $PSScriptRoot '..' 'Helpers' 'All.ps1')
    $script:mock = Start-MockOllama
}
AfterAll { Stop-MockOllama $script:mock }

Describe 'Baseline: end to end' -Tag 'Control' {
    BeforeEach {
        $script:sb = New-AicSandbox; Enter-AicSandbox $script:sb
        Set-MockChat $script:mock @{ Lines = (New-ChatLines -Text 'feat: add thing') }
        $script:repo = New-TestRepo $script:sb @{ 'a.txt' = "one`n" }
        Set-TestFile $script:repo 'a.txt' "two`n"; [void](G $script:repo add -- a.txt)
    }
    AfterEach { Exit-AicSandbox $script:sb; Remove-AicSandbox $script:sb }

    It 'harness sanity: -DryRun reaches the preview, talks to the mock only, commits nothing' {
        $head = Get-HeadSha $script:repo
        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ DryRun = $true }
        $e.TimedOut | Should -BeFalse
        $e.Error | Should -BeNullOrEmpty
        $e.Stdout | Should -Match 'feat: add thing'
        $e.Stdout | Should -Match 'dry run'
        (Get-MockRequests $script:mock | ForEach-Object Path | Select-Object -Unique) | Should -Be @('/api/tags', '/api/show', '/api/chat')
        Get-HeadSha $script:repo | Should -Be $head
    }

    It '-Yes commits the staged change with the generated message' {
        $head = Get-HeadSha $script:repo
        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ Yes = $true }
        $e.TimedOut | Should -BeFalse
        Get-HeadSha $script:repo | Should -Not -Be $head
        (G $script:repo log -1 --format=%s) | Should -Be 'feat: add thing'
        (G $script:repo status --porcelain) | Should -BeNullOrEmpty
    }

    It '-Yes -Type fix -Scope api forces the header' {
        Set-MockChat $script:mock @{ Lines = (New-ChatLines -Text 'feat: add thing') }
        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ Yes = $true; Type = 'fix'; Scope = 'api' }
        (G $script:repo log -1 --format=%s) | Should -Be 'fix(api): add thing'
    }

    It '-All -Yes stages everything and commits it' {
        Set-TestFile $script:repo 'new.txt' "n`n"
        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ All = $true; Yes = $true }
        (G $script:repo ls-tree -r --name-only HEAD) | Should -Contain 'new.txt'
    }

    It '-DryRun -PassThru returns the message on the pipeline' {
        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ DryRun = $true; PassThru = $true }
        @($e.Pipeline) | Should -Contain 'feat: add thing'
    }

    It '-Undo -Yes soft-undoes the last commit and keeps the changes staged' {
        [void](G $script:repo commit -q -m 'feat: second')
        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ Undo = $true; Yes = $true }
        (G $script:repo log -1 --format=%s) | Should -Be 'chore: initial'
        (G $script:repo diff --cached --name-only) | Should -Contain 'a.txt'
    }

    It 'a repo-level .aic.json overrides ~/.aic.json, and a typed flag overrides both' {
        Set-TestFile $script:sb.Home '.aic.json' '{ "language": "French", "bullets": 1 }'
        Set-TestFile $script:repo '.aic.json' '{ "bullets": 2 }'
        $r = Invoke-AicHarness -Sandbox $script:sb -Script { [pscustomobject]@{ Language = $Language; Bullets = $Bullets } }
        $r.Output.Language | Should -Be 'French'
        $r.Output.Bullets  | Should -Be 2
        $r2 = Invoke-AicHarness -Sandbox $script:sb -AicParams @{ Bullets = 5 } -Script { [pscustomobject]@{ Bullets = $Bullets } }
        $r2.Output.Bullets | Should -Be 5
    }
}

Describe 'Baseline: pure logic' -Tag 'Control' {
    BeforeEach { $script:sb = New-AicSandbox; Enter-AicSandbox $script:sb; [void](New-TestRepo $script:sb) }
    AfterEach  { Exit-AicSandbox $script:sb; Remove-AicSandbox $script:sb }

    It 'Normalize-Message strips fences, think-blocks and preamble, lower-cases the subject, drops the trailing dot' {
        $r = Invoke-AicHarness -Sandbox $script:sb -Script {
            $a = Normalize-Message "<think>hmm</think>`n``````text`nfeat(api): Add login endpoint.`n``````"
            [pscustomobject]@{ A = $a }
        }
        $r.Output.A | Should -Be 'feat(api): add login endpoint'
    }

    It 'Test-Message accepts a valid header and rejects bad / over-long ones' {
        $r = Invoke-AicHarness -Sandbox $script:sb -Script {
            $ok = Test-Message 'feat(api): add x'; $bad = Test-Message 'Added some stuff'; $long = Test-Message ('fix: ' + ('x' * 80))
            [pscustomobject]@{ Ok = $ok.Count; Bad = $bad.Count; Long = $long.Count }
        }
        $r.Output.Ok | Should -Be 0; $r.Output.Bad | Should -BeGreaterThan 0; $r.Output.Long | Should -BeGreaterThan 0
    }

    It 'Test-AiPath recognises AI tooling files and ignores ordinary source' {
        $r = Invoke-AicHarness -Sandbox $script:sb -Script {
            [pscustomobject]@{
                Yes = @('.cursorrules', 'CLAUDE.md', 'prompts/a.md', '.claude/settings.json', '.github/copilot-instructions.md', 'x/y.prompt.md', 'skills/foo/SKILL.md') | ForEach-Object { Test-AiPath $_ }
                No  = @('src/app.js', 'README.md', '.aider.chat.history.md') | ForEach-Object { Test-AiPath $_ }
            }
        }
        @($r.Output.Yes) | Should -Not -Contain $false
        @($r.Output.No)  | Should -Not -Contain $true
    }

    It 'Find-Secrets flags an AWS key, a private-key file and .env, but not .env.example or placeholders' {
        $r = Invoke-AicHarness -Sandbox $script:sb -Script {
            $d = "diff --git a/c.txt b/c.txt`n+++ b/c.txt`n+aws = AKIAIOSFODNN7EXAMPLE`n"
            $hit = Find-Secrets @('c.txt', '.env', 'deploy.pem', '.env.example') $d
            $d2 = "diff --git a/c.txt b/c.txt`n+++ b/c.txt`n+password = `"your-password-here-please`"`n"
            $ph = Find-Secrets @('c.txt') $d2
            [pscustomobject]@{ Hits = @($hit); Placeholder = $ph.Count }
        }
        ($r.Output.Hits -join "`n") | Should -Match 'c\.txt - AWS access key id'
        ($r.Output.Hits -join "`n") | Should -Match '\.env - environment file'
        ($r.Output.Hits -join "`n") | Should -Match 'deploy\.pem - key'
        ($r.Output.Hits -join "`n") | Should -Not -Match '\.env\.example'
        $r.Output.Placeholder | Should -Be 0
    }

    It 'Get-Changes reports a partially staged file as Staged AND Dirty, and untracked files as unstaged' {
        $repo = $script:sb.Repo
        Set-TestFile $repo 'p.txt' "1`n2`n3`n"; [void](G $repo add -A); [void](G $repo commit -q -m 'chore: p')
        Set-TestFile $repo 'p.txt' "1`nS`n3`n"; [void](G $repo add p.txt); Set-TestFile $repo 'p.txt' "1`nS`nU`n"
        Set-TestFile $repo 'new.txt' "n`n"
        $r = Invoke-AicHarness -Sandbox $script:sb -Script { , @(Get-Changes | ForEach-Object { [pscustomobject]@{ P = $_.Path; S = $_.Staged; D = $_.Dirty } }) }
        $p = @($r.Output) | Where-Object P -eq 'p.txt';   $p.S | Should -BeTrue;  $p.D | Should -BeTrue
        $n = @($r.Output) | Where-Object P -eq 'new.txt'; $n.S | Should -BeFalse
    }

    It 'Find-Leftovers reports console.log in JS and a TODO, without blocking' {
        $repo = $script:sb.Repo
        Set-TestFile $repo 'src/a.js' "console.log('x');`n// TODO fix`n"; [void](G $repo add -- src/a.js)
        $r = Invoke-AicHarness -Sandbox $script:sb -Script {
            $x = Find-Leftovers ((git @gitC diff --staged --no-color) -join "`n")
            [pscustomobject]@{ Notes = @($x.Notes); Blocking = [bool]$x.Blocking }
        }
        ($r.Output.Notes -join '|') | Should -Match 'console.log'
        ($r.Output.Notes -join '|') | Should -Match 'TODO'
        $r.Output.Blocking | Should -BeFalse
    }
}

Describe 'Baseline: AI-file staging' -Tag 'Control' {
    BeforeEach { $script:sb = New-AicSandbox; Enter-AicSandbox $script:sb }
    AfterEach  { Exit-AicSandbox $script:sb; Remove-AicSandbox $script:sb }

    It 'Stage-AiFiles stages an untracked AI file and leaves a non-AI file alone' {
        $repo = New-TestRepo $script:sb
        Set-TestFile $repo 'CLAUDE.md' "rules`n"; Set-TestFile $repo 'src/x.js' "x`n"
        $r = Invoke-AicHarness -Sandbox $script:sb -Script { [pscustomobject]@{ N = (Stage-AiFiles) } }
        $r.Output.N | Should -Be 1
        @(G $repo diff --cached --name-only) | Should -Be @('CLAUDE.md')
    }

    It 'Limit-ToAi (-AiOnly) unstages a plain non-AI file and keeps it in the working tree' {
        $repo = New-TestRepo $script:sb @{ 'src/x.js' = "x`n"; 'prompts/p.md' = "p`n" }
        Set-TestFile $repo 'src/x.js' "y`n"; Set-TestFile $repo 'prompts/p.md' "q`n"; [void](G $repo add -A)
        $r = Invoke-AicHarness -Sandbox $script:sb -AicParams @{ Yes = $true } -Script { Limit-ToAi; [pscustomobject]@{ Done = $true } }
        @(G $repo diff --cached --name-only) | Should -Be @('prompts/p.md')
        (Get-TestFile $repo 'src/x.js') | Should -Be "y`n"
    }

    It 'Select-Files stages a newly ticked unstaged file' {
        $repo = New-TestRepo $script:sb @{ 'a.txt' = "one`n" }
        Set-TestFile $repo 'a.txt' "two`n"
        $r = Invoke-AicHarness -Sandbox $script:sb -Script {
            function Pick-Many { param($title, $labels, $checked, $ai) return , [bool[]]@($checked | ForEach-Object { $true }) }
            Select-Files; [pscustomobject]@{ Done = $true }
        }
        @(G $repo diff --cached --name-only) | Should -Be @('a.txt')
    }
}
