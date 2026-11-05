# Provider layer (Ollama stays the default; an OpenAI-compatible local server such as LM Studio / llama.cpp is optional) and
# model profiles (fast / balanced / quality) with recommendations that do not equate "largest" with "best".
BeforeAll { . (Join-Path $PSScriptRoot '..' 'Helpers' 'All.ps1'); $script:mock = Start-MockOllama }
AfterAll  { Stop-MockOllama $script:mock }

Describe 'C9: providers' -Tag 'Regression', 'C09' {
    BeforeEach {
        $script:sb = New-AicSandbox; Enter-AicSandbox $script:sb
        $script:mock.State.Models = @('local-model'); $script:mock.State.Capabilities = @('completion'); $script:mock.State.ContextLength = 0
        Set-MockChat $script:mock @{ Lines = (New-SseLines -Text 'feat: add thing') }
        $script:repo = New-TestRepo $script:sb @{ 'a.txt' = "one`n" }
        Set-TestFile $script:repo 'a.txt' "two`n"; [void](G $script:repo add -- a.txt)
        function script:Paths { @(Get-MockRequests $script:mock | ForEach-Object Path | Select-Object -Unique) }
        $script:oai = @{ Provider = 'openai-compatible' }
    }
    AfterEach { Exit-AicSandbox $script:sb; Remove-AicSandbox $script:sb }

    It 'an OpenAI-compatible server works: models from /v1/models, answer streamed over /v1/chat/completions, no Ollama endpoints touched' {
        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params ($script:oai + @{ DryRun = $true })
        $e.Stdout | Should -Match 'feat: add thing' -Because $e.Stdout
        Paths | Should -Contain '/v1/models'; Paths | Should -Contain '/v1/chat/completions'
        Paths | Should -Not -Contain '/api/tags'; Paths | Should -Not -Contain '/api/show'; Paths | Should -Not -Contain '/api/chat'
        $j = (Get-MockRequests $script:mock '/v1/chat/completions' | Select-Object -Last 1).Body | ConvertFrom-Json
        $j.model | Should -Be 'local-model' -Because 'with no model chosen, the one the server offers is used'
        $j.stream | Should -BeTrue; $j.max_tokens | Should -BeGreaterThan 0
        $j.PSObject.Properties.Name | Should -Not -Contain 'options'
    }
    It 'an answer cut off by the server (finish_reason length) is not auto-committed' {
        Set-MockChat $script:mock @{ Lines = (New-SseLines -Text 'feat: add thing' -FinishReason 'length') }
        $head = Get-HeadSha $script:repo
        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params ($script:oai + @{ Yes = $true })
        Get-HeadSha $script:repo | Should -Be $head; $e.Code | Should -Be 3
    }
    It 'a stream that never reaches [DONE] is not auto-committed' {
        Set-MockChat $script:mock @{ Lines = (New-SseLines -Text 'feat: add thing' -SendDone $false) }
        $head = Get-HeadSha $script:repo
        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params ($script:oai + @{ Yes = $true })
        Get-HeadSha $script:repo | Should -Be $head; $e.Code | Should -Be 3
    }
    It 'a model the server does not offer is reported (exit 4)' {
        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params ($script:oai + @{ DryRun = $true; Model = 'nope' })
        $e.Code | Should -Be 4
    }
    It 'an error object from the server is shown as text' {
        Set-MockChat $script:mock @{ Status = 400; Body = '{"error":{"message":"the context is too long for this model"}}' }
        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params ($script:oai + @{ DryRun = $true })
        $e.Stdout | Should -Match 'context is too long'
    }
    It 'AIC_API_KEY is sent as a Bearer token and never printed' {
        $script:sb.Env['AIC_API_KEY'] = 'test-key-123'
        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params ($script:oai + @{ DryRun = $true })
        (Get-MockRequests $script:mock '/v1/chat/completions' | Select-Object -Last 1).Auth | Should -Be 'Bearer test-key-123'
        ($e.Stdout + $e.Stderr) | Should -Not -Match 'test-key-123'
    }
    It 'no key configured: no Authorization header is sent' {
        [void](Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params ($script:oai + @{ DryRun = $true }))
        @(Get-MockRequests $script:mock '/v1/chat/completions').Count | Should -BeGreaterThan 0 -Because 'precondition: the request was made'
        (Get-MockRequests $script:mock '/v1/chat/completions' | Select-Object -Last 1).Auth | Should -BeNullOrEmpty
    }
    It '"provider" in .aic.json selects the provider; an unknown provider is reported by -ConfigValidate' {
        Set-TestFile $script:sb.Home '.aic.json' '{ "provider": "openai-compatible" }'
        [void](Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ DryRun = $true })
        Paths | Should -Contain '/v1/chat/completions'
        Set-TestFile $script:sb.Home '.aic.json' '{ "provider": "azure" }'
        $v = Invoke-Aic -Sandbox $script:sb -Params @{ ConfigValidate = $true }
        $v.Code | Should -Be 1; $v.Stdout | Should -Match 'provider'
    }
    It 'CONTROL: Ollama is still the default provider' -Tag 'Control' {
        $script:mock.State.Models = @('qwen2.5-coder:7b'); Set-MockChat $script:mock @{ Lines = (New-ChatLines -Text 'feat: add thing') }
        [void](Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ DryRun = $true })
        Paths | Should -Contain '/api/tags'; Paths | Should -Contain '/api/chat'; Paths | Should -Not -Contain '/v1/models'
    }
}

Describe 'C9b: model profiles and recommendations' -Tag 'Regression', 'C09' {
    BeforeEach { $script:sb = New-AicSandbox; Enter-AicSandbox $script:sb; [void](New-TestRepo $script:sb) }
    AfterEach  { Exit-AicSandbox $script:sb; Remove-AicSandbox $script:sb }

    It 'fast = small, balanced = about 7B, quality = the largest model that is still practical (not the 70B)' {
        $r = Invoke-AicHarness -Sandbox $script:sb -Script {
            function M($n, $s) { [pscustomobject]@{ name = $n; size = $s } }
            $x = Get-ModelRecommendation @((M 'qwen2.5-coder:3b' 1.9e9), (M 'qwen2.5-coder:7b' 4.7e9), (M 'qwen2.5-coder:32b' 19e9), (M 'llama3.1:70b' 40e9), (M 'nomic-embed-text:latest' 0.3e9))
            [pscustomobject]@{ Fast = $x.fast; Balanced = $x.balanced; Quality = $x.quality }
        }
        $r.Error | Should -BeNullOrEmpty
        $r.Output.Fast | Should -Be 'qwen2.5-coder:3b'; $r.Output.Balanced | Should -Be 'qwen2.5-coder:7b'; $r.Output.Quality | Should -Be 'qwen2.5-coder:32b'
    }
    It 'a single installed model is every profile; embedding models are never recommended' {
        $r = Invoke-AicHarness -Sandbox $script:sb -Script {
            function M($n, $s) { [pscustomobject]@{ name = $n; size = $s } }
            $one = Get-ModelRecommendation @((M 'only:latest' 4e9), (M 'bge-embed:latest' 0.2e9))
            $none = Get-ModelRecommendation @((M 'bge-embed:latest' 0.2e9))
            [pscustomobject]@{ F = $one.fast; B = $one.balanced; Q = $one.quality; NoneF = [string]$none.fast }
        }
        $r.Output.F | Should -Be 'only:latest'; $r.Output.B | Should -Be 'only:latest'; $r.Output.Q | Should -Be 'only:latest'
        $r.Output.NoneF | Should -BeNullOrEmpty
    }
    It 'balanced picks the model closest to 7B, prefers a coder model on a tie, and estimates parameters from the size when the name has none' {
        $r = Invoke-AicHarness -Sandbox $script:sb -Script {
            function M($n, $s) { [pscustomobject]@{ name = $n; size = $s } }
            $a = Get-ModelRecommendation @((M 'llama3.2:3b' 2e9), (M 'llama3.1:8b' 4.9e9), (M 'mistral:7b' 4.1e9))
            $b = Get-ModelRecommendation @((M 'llama3.1:7b' 4.4e9), (M 'qwen2.5-coder:7b' 4.7e9))
            $c = Get-ModelRecommendation @((M 'tiny:latest' 0.9e9), (M 'custom-model:latest' 4.4e9), (M 'huge:latest' 38e9))
            [pscustomobject]@{ A = $a.balanced; AFast = $a.fast; B = $b.balanced; C = $c.balanced }
        }
        $r.Output.A | Should -Be 'mistral:7b'; $r.Output.AFast | Should -Be 'llama3.2:3b'
        $r.Output.B | Should -Be 'qwen2.5-coder:7b'
        $r.Output.C | Should -Be 'custom-model:latest'
    }

    Context 'end to end' {
        BeforeEach {
            $script:mock = Start-MockOllama -Models @(@{ name = 'qwen2.5-coder:3b'; size = 1.9e9 }, @{ name = 'qwen2.5-coder:7b'; size = 4.7e9 }, @{ name = 'qwen2.5-coder:32b'; size = 19e9 })
            Set-MockChat $script:mock @{ Lines = (New-ChatLines -Text 'feat: add thing') }
            Set-TestFile $script:sb.Repo 'a.txt' "x`n"; [void](G $script:sb.Repo add -- a.txt)
            function script:UsedModel { ((Get-MockRequests $script:mock '/api/chat' | Select-Object -Last 1).Body | ConvertFrom-Json).model }
        }
        AfterEach { Stop-MockOllama $script:mock }
        It '-Profile fast / balanced / quality choose the model' -ForEach @(@{ P = 'fast'; M = 'qwen2.5-coder:3b' }, @{ P = 'balanced'; M = 'qwen2.5-coder:7b' }, @{ P = 'quality'; M = 'qwen2.5-coder:32b' }) {
            [void](Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ DryRun = $true; Profile = $P })
            UsedModel | Should -Be $M
        }
        It 'an explicit -Model beats -Profile' {
            [void](Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ DryRun = $true; Profile = 'fast'; Model = 'qwen2.5-coder:32b' })
            UsedModel | Should -Be 'qwen2.5-coder:32b'
        }
        It '"profile" in .aic.json is used when no model is configured, and "model" wins when both are' {
            Set-TestFile $script:sb.Home '.aic.json' '{ "profile": "fast" }'
            [void](Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ DryRun = $true }); UsedModel | Should -Be 'qwen2.5-coder:3b'
            Set-TestFile $script:sb.Home '.aic.json' '{ "profile": "fast", "model": "qwen2.5-coder:32b" }'
            [void](Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ DryRun = $true }); UsedModel | Should -Be 'qwen2.5-coder:32b'
        }
        It '-ListModels shows size, estimated parameters and which profile each model is recommended for, without generating anything' {
            $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ ListModels = $true }
            $e.Code | Should -Be 0
            ($e.Stdout -split "`n" | Where-Object { $_ -match 'coder:3b' }) | Should -Match 'fast'
            ($e.Stdout -split "`n" | Where-Object { $_ -match 'coder:7b' }) | Should -Match 'balanced'
            ($e.Stdout -split "`n" | Where-Object { $_ -match 'coder:32b' }) | Should -Match 'quality'
            (Get-MockRequests $script:mock '/api/chat').Count | Should -Be 0
        }
    }
}
