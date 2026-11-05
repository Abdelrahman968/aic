# Ollama integration: proxy handling (B17), transient-failure retry, timeouts without orphaned requests, first-token latency,
# context-window clamping (B9), thinking models and empty responses. Everything runs against the in-process mock.
BeforeAll { . (Join-Path $PSScriptRoot '..' 'Helpers' 'All.ps1'); $script:mock = Start-MockOllama }
AfterAll  { Stop-MockOllama $script:mock }

Describe 'C8: Ollama reliability' -Tag 'Regression', 'C08' {
    BeforeEach {
        $script:sb = New-AicSandbox; Enter-AicSandbox $script:sb
        $script:mock.State.Capabilities = @('completion'); $script:mock.State.ContextLength = 0
        Set-MockChat $script:mock @{ Lines = (New-ChatLines -Text 'feat: add thing') }
        $script:repo = New-TestRepo $script:sb @{ 'a.txt' = "one`n" }
        Set-TestFile $script:repo 'a.txt' "two`n"; [void](G $script:repo add -- a.txt)
        function script:ChatCount { (Get-MockRequests $script:mock '/api/chat').Count }
    }
    AfterEach { Exit-AicSandbox $script:sb; Remove-AicSandbox $script:sb }

    Context 'proxy' {
        It 'a proxy in the environment does not break calls to a local Ollama (tags, show and chat all bypass it)' {
            foreach ($k in 'HTTP_PROXY', 'http_proxy', 'HTTPS_PROXY', 'https_proxy', 'ALL_PROXY') { $script:sb.Env[$k] = 'http://127.0.0.1:9' }   # a dead proxy
            $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ DryRun = $true }
            $e.Stdout | Should -Match 'dry run' -Because $e.Stdout
            $e.Code | Should -Be 0
        }
    }

    Context 'transient failures are retried, everything else is not' {
        It 'HTTP 503 followed by success: one retry, the commit is made exactly once' {
            Set-MockChat $script:mock @{ Status = 503; Body = '{"error":"server busy"}' }, @{ Lines = (New-ChatLines -Text 'feat: add thing') }
            $n = [int]@(G $script:repo rev-list --count HEAD)[0]
            $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ Yes = $true }
            ChatCount | Should -Be 2
            [int]@(G $script:repo rev-list --count HEAD)[0] | Should -Be ($n + 1) -Because 'a retry of the generation must never repeat the git operation'
            $e.Code | Should -Be 0
        }
        It 'a connection that dies before the first byte is retried' {
            Set-MockChat $script:mock @{ AbortImmediately = $true }, @{ Lines = (New-ChatLines -Text 'feat: add thing') }
            $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ DryRun = $true }
            ChatCount | Should -Be 2
            $e.Stdout | Should -Match 'dry run'
        }
        It 'gives up after 2 retries (3 requests in total) and reports the failure' {
            Set-MockChat $script:mock @{ Status = 503; Body = '{"error":"server busy"}' }
            $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ DryRun = $true }
            ChatCount | Should -Be 3
            $e.Stdout | Should -Match 'Generation failed'
            $e.Code | Should -Be 1
        }
        It 'CONTROL: "model not found" (404) is not retried and tells you what to pull' -Tag 'Control' {
            Set-MockChat $script:mock @{ Status = 404; Body = '{"error":"model ''x'' not found"}' }
            $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ DryRun = $true }
            ChatCount | Should -Be 1
            $e.Stdout | Should -Match 'ollama pull'
        }
        It 'CONTROL: a client error (400) is not retried' -Tag 'Control' {
            Set-MockChat $script:mock @{ Status = 400; Body = '{"error":"bad request"}' }
            [void](Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ DryRun = $true })
            ChatCount | Should -Be 1
        }
    }

    Context 'timeout and cancellation' {
        It 'a stalled stream times out, is not retried, commits nothing and leaves no connection open' {
            Set-MockChat $script:mock @{ DelayMs = 800; Lines = (New-ChatLines -Text 'feat: add a very slow thing indeed' -Chunks 6) }
            $head = Get-HeadSha $script:repo
            $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ Yes = $true; TimeoutSec = 1 }
            $e.TimedOut | Should -BeFalse
            $e.Stdout | Should -Match 'timed out'
            $e.Code | Should -Be 1
            ChatCount | Should -Be 1
            Get-HeadSha $script:repo | Should -Be $head
            $sw = [Diagnostics.Stopwatch]::StartNew(); while (-not $script:mock.State.ClientGone -and $sw.Elapsed.TotalSeconds -lt 6) { Start-Sleep -Milliseconds 100 }
            $script:mock.State.ClientGone | Should -BeTrue -Because 'aic must close the HTTP request when it gives up'
        }
    }

    Context 'reporting' {
        It 'reports first-token latency next to the speed' {
            $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ DryRun = $true }
            $e.Stdout | Should -Match 'first token \d'
        }
    }

    Context 'context window' {
        BeforeEach { Set-TestFile $script:repo 'big.txt' ((1..400 | ForEach-Object { "line number $_ of a long file" }) -join "`n"); [void](G $script:repo add -- big.txt) }
        It 'never asks for more context than the model has, and shortens the diff to fit' {
            $script:mock.State.ContextLength = 2048
            $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ DryRun = $true; MaxChars = 12000 }
            $j = (Get-MockRequests $script:mock '/api/chat' | Select-Object -Last 1).Body | ConvertFrom-Json
            $j.options.num_ctx | Should -BeLessOrEqual 2048
            $chars = ($j.messages | ForEach-Object { $_.content.Length } | Measure-Object -Sum).Sum
            (($chars / 2.8) + 256 + 64) | Should -BeLessOrEqual (2048 * 1.05) -Because "the prompt was $chars characters"
            $e.Stdout | Should -Match 'shortened'
        }
        It 'CONTROL: without a known context length nothing is clamped or shortened' -Tag 'Control' {
            $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ DryRun = $true; MaxChars = 12000 }
            $j = (Get-MockRequests $script:mock '/api/chat' | Select-Object -Last 1).Body | ConvertFrom-Json
            $j.options.num_ctx | Should -BeGreaterThan 4000
            $e.Stdout | Should -Not -Match 'shortened'
        }
    }

    Context 'thinking models and empty answers (existing behaviour)' {
        It 'CONTROL: a thinking-capable model is called with think:false' -Tag 'Control' {
            $script:mock.State.Capabilities = @('completion', 'thinking')
            [void](Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ DryRun = $true })
            (Get-MockRequests $script:mock '/api/chat' | Select-Object -Last 1).Body | Should -Match '"think":false'
        }
        It 'CONTROL: a model that only thinks is reported, not committed' -Tag 'Control' {
            Set-MockChat $script:mock @{ Lines = @('{"message":{"role":"assistant","thinking":"hmm"},"done":false}', '{"message":{"role":"assistant","thinking":"hmm2"},"done":false}', '{"done":true,"done_reason":"length"}') }
            $head = Get-HeadSha $script:repo
            $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ Yes = $true }
            $e.Stdout | Should -Match 'whole token budget'
            Get-HeadSha $script:repo | Should -Be $head
        }
        It 'CONTROL: an empty answer is reported, not committed' -Tag 'Control' {
            Set-MockChat $script:mock @{ Lines = @('{"done":true,"done_reason":"stop"}') }
            $head = Get-HeadSha $script:repo
            $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ Yes = $true }
            $e.Stdout | Should -Match 'empty message'
            Get-HeadSha $script:repo | Should -Be $head
        }
    }
}
