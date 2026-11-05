# CONTROLS (end to end): flows that touch the index and must behave identically before and after the Step 2 fixes.
BeforeAll {
    . (Join-Path $PSScriptRoot '..' 'Helpers' 'All.ps1')
    $script:mock = Start-MockOllama
}
AfterAll { Stop-MockOllama $script:mock }

Describe 'Compat: index-touching flows' -Tag 'Control' {
    BeforeEach {
        $script:sb = New-AicSandbox; Enter-AicSandbox $script:sb
        Set-MockChat $script:mock @{ Lines = (New-ChatLines -Text 'feat: add thing') }
    }
    AfterEach { Exit-AicSandbox $script:sb; Remove-AicSandbox $script:sb }

    It 'a commit keeps the skip-worktree flag of an unrelated file' {
        $repo = New-TestRepo $script:sb @{ 'skip.txt' = "s`n"; 'a.txt' = "one`n" }
        [void](G $repo update-index --skip-worktree skip.txt)
        Set-TestFile $repo 'a.txt' "two`n"; [void](G $repo add -- a.txt)
        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ Yes = $true }
        (G $repo log -1 --format=%s) | Should -Be 'feat: add thing'
        ((G $repo ls-files -t) | Where-Object { $_ -match 'skip\.txt' }) | Should -Match '^S '
    }

    It 'committing a partially staged file commits only the staged hunk and keeps the rest in the working tree' {
        $repo = New-PartialStaging $script:sb
        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ Yes = $true }
        (G $repo show HEAD:partial.txt) -join "`n" | Should -Be "line1`nSTAGED`nline3"
        (Get-TestFile $repo 'partial.txt') | Should -Be "line1`nSTAGED`nUNSTAGED`n"
        (GTry $repo diff --quiet -- partial.txt).Rc | Should -Be 1 -Because 'the unstaged line is still an unstaged change'
    }

    It '-Amend -Yes rewrites the message of the last commit without adding a commit' {
        $repo = New-TestRepo $script:sb @{ 'a.txt' = "one`n" }
        Set-TestFile $repo 'a.txt' "two`n"; [void](G $repo add -- a.txt); [void](G $repo commit -q -m 'feat: first')
        $n = @(G $repo rev-list --count HEAD)[0]
        Set-MockChat $script:mock @{ Lines = (New-ChatLines -Text 'fix: better message') }
        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ Amend = $true; Yes = $true }
        @(G $repo rev-list --count HEAD)[0] | Should -Be $n
        (G $repo log -1 --format=%s) | Should -Be 'fix: better message'
    }

    It '-AiOnly -Yes commits only the AI file and leaves the other change in the working tree' {
        $repo = New-MixedRepo $script:sb
        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ AiOnly = $true; Yes = $true }
        @(G $repo show --name-only --format= HEAD) | Should -Be @('prompts/p.md')
        (G $repo status --porcelain) | Should -Contain ' M src/app.js'
    }

    It 'works inside a linked worktree (its own index lives under .git/worktrees)' {
        $repo = New-TestRepo $script:sb @{ 'a.txt' = "one`n" }
        $wt = Join-Path $script:sb.Base 'wt'
        [void](G $repo worktree add -q $wt -b wtb)
        Set-TestFile $wt 'a.txt' "wt change`n"; Set-TestFile $wt 'new.txt' "n`n"
        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Cwd $wt -Params @{ All = $true; Yes = $true }
        (G $wt log -1 --format=%s) | Should -Be 'feat: add thing'
        (G $wt ls-tree -r --name-only HEAD) | Should -Contain 'new.txt'
        (G $repo log -1 --format=%s) | Should -Be 'chore: initial' -Because 'the main worktree branch must not move'
    }

    It 'the very first commit of an unborn repository works (no HEAD, no index file before staging)' {
        $repo = $script:sb.Repo
        [void](G $repo init -q -b main .)
        Set-TestFile $repo 'a.txt' "one`n"; [void](G $repo add -- a.txt)
        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ Yes = $true }
        $e.TimedOut | Should -BeFalse
        (G $repo log -1 --format=%s) | Should -Be 'feat: add thing'
        (G $repo ls-tree -r --name-only HEAD) | Should -Contain 'a.txt'
    }
}
