# B23: the PR "Testing" section is written by the model (invented evidence). B10: -Review covers only the first MaxChars of the diff
# and never says so. B8 (extended): -Review / -Pr ignore truncated or incomplete model streams.
BeforeAll { . (Join-Path $PSScriptRoot '..' 'Helpers' 'All.ps1'); $script:mock = Start-MockOllama }
AfterAll  { Stop-MockOllama $script:mock }

Describe 'C7: -Pr and -Review report only what is verified' -Tag 'Regression', 'C07' {
    BeforeEach {
        $script:sb = New-AicSandbox; Enter-AicSandbox $script:sb
        $script:repo = New-TestRepo $script:sb @{ 'a.txt' = "one`n" }
        [void](G $script:repo switch -q -c feat/x)
        $script:prText = "feat(x): add the thing`n`n## Summary`nAdds the thing.`n`n## Changes`n- adds b.txt`n`n## Testing`n- all tests pass on CI`n- manually verified"
    }
    AfterEach { Exit-AicSandbox $script:sb; Remove-AicSandbox $script:sb }

    It '-Pr never repeats testing claims made by the model' {
        Set-TestFile $script:repo 'b.txt' "b`n"; [void](G $script:repo add -A); [void](G $script:repo commit -q -m 'feat: add b')
        Set-MockChat $script:mock @{ Lines = (New-ChatLines -Text $script:prText) }
        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ Pr = $true; Into = 'main'; PassThru = $true }
        $out = ($e.Pipeline -join "`n")
        $out | Should -Match '## Summary' -Because 'precondition: a PR text was produced'
        $out | Should -Not -Match 'all tests pass'; $out | Should -Not -Match 'manually verified'
    }
    It '-Pr states which test files changed (evidence) and that aic did not run them' {
        Set-TestFile $script:repo 'src/b.js' "b`n"; Set-TestFile $script:repo 'src/b.test.js' "t`n"; [void](G $script:repo add -A); [void](G $script:repo commit -q -m 'feat: add b')
        Set-MockChat $script:mock @{ Lines = (New-ChatLines -Text $script:prText) }
        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ Pr = $true; Into = 'main'; PassThru = $true }
        $out = ($e.Pipeline -join "`n")
        $out | Should -Match '(?s)## Testing.*src/b\.test\.js'
        $out | Should -Match 'did not run'
    }
    It '-Pr says plainly when no test file changed' {
        Set-TestFile $script:repo 'b.txt' "b`n"; [void](G $script:repo add -A); [void](G $script:repo commit -q -m 'feat: add b')
        Set-MockChat $script:mock @{ Lines = (New-ChatLines -Text $script:prText) }
        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ Pr = $true; Into = 'main'; PassThru = $true }
        ($e.Pipeline -join "`n") | Should -Match 'No test files changed'
    }
    It '-Pr warns when the model stream was cut off' {
        Set-TestFile $script:repo 'b.txt' "b`n"; [void](G $script:repo add -A); [void](G $script:repo commit -q -m 'feat: add b')
        Set-MockChat $script:mock @{ Lines = (New-ChatLines -Text "feat(x): add the thing`n`n## Summary`nAdds" -DoneReason 'length') }
        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ Pr = $true; Into = 'main' }
        $e.Stdout | Should -Match 'cut off'
    }

    Context '-Review' {
        BeforeEach { Set-TestFile $script:repo 'big.txt' ((1..400 | ForEach-Object { "line number $_ of a long file" }) -join "`n"); [void](G $script:repo add -- big.txt) }
        It 'discloses that only part of a large diff was reviewed, and never claims a clean bill of health for all of it' {
            Set-MockChat $script:mock @{ Lines = (New-ChatLines -Text '- no problems found') }
            $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ Review = $true; MaxChars = 500 }
            $e.Stdout | Should -Match 'only part of the diff'
            $e.Stdout | Should -Match '-MaxChars'
        }
        It 'warns when the review stream ended before the model finished' {
            Set-MockChat $script:mock @{ Lines = (New-ChatLines -Text '- big.txt: something' -SendDone $false) }
            $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ Review = $true }
            $e.Stdout | Should -Match 'ended before'
        }
        It 'CONTROL: a small diff is reviewed without any coverage warning' -Tag 'Control' {
            [void](G $script:repo reset -q); Set-TestFile $script:repo 'big.txt' "x`n"; [void](G $script:repo add -- big.txt)
            Set-MockChat $script:mock @{ Lines = (New-ChatLines -Text '- no problems found') }
            $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ Review = $true }
            $e.Stdout | Should -Match 'no problems found'
            $e.Stdout | Should -Not -Match 'only part of the diff'
        }
    }
}
