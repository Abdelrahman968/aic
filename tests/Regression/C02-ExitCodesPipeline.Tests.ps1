# B15: aic has no exit codes (it leaves whatever git returned last in $LASTEXITCODE) and git's own output leaks into the pipeline.
# Convention under test: 0 ok | 1 error | 3 blocked by a safety check | 4 Ollama / model unavailable | 5 nothing to commit | 130 cancelled
BeforeAll { . (Join-Path $PSScriptRoot '..' 'Helpers' 'All.ps1'); $script:mock = Start-MockOllama }
AfterAll  { Stop-MockOllama $script:mock }

Describe 'C2: exit codes and a clean pipeline' -Tag 'Regression', 'C02' {
    BeforeEach {
        $script:sb = New-AicSandbox; Enter-AicSandbox $script:sb
        Set-MockChat $script:mock @{ Lines = (New-ChatLines -Text 'feat: add thing') }
        $script:repo = New-TestRepo $script:sb @{ 'a.txt' = "one`n" }
        Set-TestFile $script:repo 'a.txt' "two`n"; [void](G $script:repo add -- a.txt)
    }
    AfterEach { Exit-AicSandbox $script:sb; Remove-AicSandbox $script:sb }

    It '-DryRun: exit 0 and nothing on the pipeline' {
        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ DryRun = $true }
        $e.Code | Should -Be 0; @($e.Pipeline).Count | Should -Be 0
    }
    It '-Yes commit: exit 0 and git''s commit summary does not leak into the pipeline' {
        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ Yes = $true }
        (G $script:repo log -1 --format=%s) | Should -Be 'feat: add thing'
        $e.Code | Should -Be 0
        @($e.Pipeline) | Should -BeNullOrEmpty -Because "leaked: $($e.Pipeline -join ' | ')"
    }
    It '-Yes -PassThru: the pipeline is exactly the commit message' {
        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ Yes = $true; PassThru = $true }
        @($e.Pipeline) | Should -Be @('feat: add thing')
    }
    It 'blocked by the secret scan: exit 3' {
        Set-TestFile $script:repo 'c.txt' "k = AKIAIOSFODNN7EXAMPLE`n"; [void](G $script:repo add -- c.txt)
        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ Yes = $true }
        $e.Code | Should -Be 3
    }
    It 'incomplete model stream under -Yes: exit 3' {
        Set-MockChat $script:mock @{ Lines = (New-ChatLines -Text 'feat: add thing' -SendDone $false) }
        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ Yes = $true }
        $e.Code | Should -Be 3
    }
    It 'Ollama not reachable: exit 4' {
        $e = Invoke-Aic -Sandbox $script:sb -Params @{ DryRun = $true; OllamaUrl = 'http://127.0.0.1:1' }
        $e.Code | Should -Be 4
    }
    It 'model not installed: exit 4' {
        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ DryRun = $true; Model = 'does-not-exist:1b' }
        $e.Code | Should -Be 4
    }
    It 'generation failure (HTTP 500): exit 1' {
        Set-MockChat $script:mock @{ Status = 500; Body = '{"error":"boom"}' }
        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ DryRun = $true }
        $e.Code | Should -Be 1
    }
    It 'not inside a git repository: exit 1' {
        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Cwd $script:sb.Home -Params @{ DryRun = $true }
        $e.Code | Should -Be 1
    }
    It 'nothing staged: exit 5' {
        [void](G $script:repo reset -q)
        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ DryRun = $true }
        $e.Code | Should -Be 5
    }
}
