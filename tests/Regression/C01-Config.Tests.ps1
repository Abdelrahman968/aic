# B14: configuration. Wrong types crash aic with a raw exception, typos and bad values are silently ignored,
# there is no way to validate a config without running the AI engine, and scope checks are case-insensitive.
BeforeAll { . (Join-Path $PSScriptRoot '..' 'Helpers' 'All.ps1'); $script:mock = Start-MockOllama }
AfterAll  { Stop-MockOllama $script:mock }

Describe 'C1: configuration is validated, never crashes, never silently ignored' -Tag 'Regression', 'C01' {
    BeforeEach {
        $script:sb = New-AicSandbox; Enter-AicSandbox $script:sb
        Set-MockChat $script:mock @{ Lines = (New-ChatLines -Text 'feat: add thing') }
        $script:repo = New-TestRepo $script:sb @{ 'a.txt' = "one`n" }
        Set-TestFile $script:repo 'a.txt' "two`n"; [void](G $script:repo add -- a.txt)
    }
    AfterEach { Exit-AicSandbox $script:sb; Remove-AicSandbox $script:sb }

    It 'a value of the wrong type is reported and ignored, aic keeps running' {
        Set-TestFile $script:sb.Home '.aic.json' '{ "bullets": "many" }'
        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ DryRun = $true }
        $e.Error | Should -BeNullOrEmpty -Because 'a bad config value must not surface as a raw exception'
        $e.Stdout | Should -Match 'bullets'
        $e.Stdout | Should -Match 'dry run'
    }
    It 'a misspelled key is reported with a suggestion' {
        Set-TestFile $script:sb.Home '.aic.json' '{ "theem": "dracula" }'
        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ DryRun = $true }
        $e.Stdout | Should -Match "unknown.*theem.*theme"
        $e.Stdout | Should -Match 'dry run'
    }
    It 'an invalid value for an enum key is reported' {
        Set-TestFile $script:sb.Home '.aic.json' '{ "theme": "nope" }'
        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ DryRun = $true }
        $e.Stdout | Should -Match 'theme.*nope'
    }
    It 'an out-of-range number is reported (and still clamped, as before)' {
        Set-TestFile $script:sb.Home '.aic.json' '{ "bullets": 99 }'
        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ DryRun = $true }
        $e.Stdout | Should -Match 'bullets.*99'
    }
    It '-ConfigValidate on a good config says so, exits 0 and never contacts Ollama' {
        Set-TestFile $script:sb.Home '.aic.json' '{ "model": "qwen2.5-coder:3b", "bullets": 2, "scopes": ["api", "ui"], "theme": "dracula" }'
        $e = Invoke-Aic -Sandbox $script:sb -Params @{ ConfigValidate = $true }
        $e.Error | Should -BeNullOrEmpty
        $e.Code | Should -Be 0
        $e.Stdout | Should -Match 'valid'
    }
    It '-ConfigValidate on a bad config lists every problem and exits 1' {
        Set-TestFile $script:sb.Home '.aic.json' '{ "bullets": "x", "theem": 1, "banner": "huge" }'
        $e = Invoke-Aic -Sandbox $script:sb -Params @{ ConfigValidate = $true }
        $e.Error | Should -BeNullOrEmpty
        $e.Code | Should -Be 1
        $e.Stdout | Should -Match 'bullets'; $e.Stdout | Should -Match 'theem'; $e.Stdout | Should -Match 'banner'
    }
    It 'scope enforcement is case-sensitive ("Auth" is not "auth")' {
        Set-TestFile $script:sb.Home '.aic.json' '{ "scopes": ["auth"] }'
        $r = Invoke-AicHarness -Sandbox $script:sb -Script { $p = Test-Message 'feat(Auth): add x'; [pscustomobject]@{ N = $p.Count } }
        $r.Error | Should -BeNullOrEmpty
        $r.Output.N | Should -BeGreaterThan 0
    }
    It 'CONTROL: unreadable JSON is a warning, aic still runs' -Tag 'Control' {
        Set-TestFile $script:sb.Home '.aic.json' '{ not json'
        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ DryRun = $true }
        $e.Stdout | Should -Match 'could not be read'
        $e.Stdout | Should -Match 'dry run'
    }
}
