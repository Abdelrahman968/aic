# B6: the secret scan only WARNS; the unredacted diff, including .env content, still goes into the model prompt.
# With a remote Ollama endpoint that means the secret leaves the machine, while the success line still brags about zero tokens leaving.
# All "secrets" here are synthetic placeholders (AWS' documented example key, repeated letters), never real credentials.
BeforeAll { . (Join-Path $PSScriptRoot '..' 'Helpers' 'All.ps1'); $script:mock = Start-MockOllama; $script:aws = 'AKIAIOSFODNN7EXAMPLE'; $script:aws2 = 'AKIAIOSFODNN7EXAMPL2' }
AfterAll  { Stop-MockOllama $script:mock }

Describe 'C5: secrets never reach the model prompt' -Tag 'Regression', 'C05' {
    BeforeEach {
        $script:sb = New-AicSandbox; Enter-AicSandbox $script:sb
        Set-MockChat $script:mock @{ Lines = (New-ChatLines -Text 'feat: add thing') }
        $script:repo = New-TestRepo $script:sb @{ 'src/a.js' = "let a = 1;`n" }
        Set-TestFile $script:repo 'src/a.js' "let a = 2;`n"; [void](G $script:repo add -- src/a.js)
        function script:ChatBody { (Get-MockRequests $script:mock '/api/chat' | ForEach-Object Body) -join "`n" }
    }
    AfterEach { Exit-AicSandbox $script:sb; Remove-AicSandbox $script:sb }

    It 'a secret value inside a diff is replaced by a marker before the prompt is built (and still reported)' {
        Set-TestFile $script:repo 'config.txt' "aws_access_key_id = $($script:aws)`n"; [void](G $script:repo add -- config.txt)
        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ DryRun = $true }
        ChatBody | Should -Not -Match $script:aws
        ChatBody | Should -Match 'REDACTED'
        $e.Stdout | Should -Match 'possible secret'
        $e.Stdout | Should -Not -Match $script:aws -Because 'values are never printed either'
    }
    It 'two secrets on one line are both redacted' {
        Set-TestFile $script:repo 'config.txt' "pair = $($script:aws) / $($script:aws2)`n"; [void](G $script:repo add -- config.txt)
        [void](Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ DryRun = $true })
        ChatBody | Should -Not -Match 'AKIAIOSFODNN7EXAMPL'
    }
    It 'the content of a credential file (.env) is omitted, only its name is sent' {
        Set-TestFile $script:repo '.env' "DB_PASSWORD=hunter2hunter2hunter2`n"; [void](G $script:repo add -- .env)
        [void](Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ DryRun = $true })
        ChatBody | Should -Not -Match 'hunter2'
        ChatBody | Should -Match '\.env'
    }
    It '-Review redacts as well' {
        Set-TestFile $script:repo 'config.txt' "aws_access_key_id = $($script:aws)`n"; [void](G $script:repo add -- config.txt)
        [void](Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ Review = $true })
        ChatBody | Should -Not -Match $script:aws
    }
    It '-Pr redacts the branch diff' {
        [void](G $script:repo reset -q); [void](G $script:repo checkout -q -- .)
        [void](G $script:repo switch -q -c feat/x)
        Set-TestFile $script:repo 'config.txt' "aws_access_key_id = $($script:aws)`n"; [void](G $script:repo add -- config.txt); [void](G $script:repo commit -q -m 'feat: add config')
        [void](Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ Pr = $true; Into = 'main' })
        (Get-MockRequests $script:mock '/api/chat').Count | Should -BeGreaterThan 0 -Because 'precondition: the PR request was made'
        ChatBody | Should -Not -Match $script:aws
    }
    It 'CONTROL: a lockfile token is not in the prompt (lockfiles are hidden from the model)' -Tag 'Control' {
        Set-TestFile $script:repo 'package-lock.json' "{ `"t`": `"ghp_$('a' * 36)`" }`n"; [void](G $script:repo add -- package-lock.json)
        [void](Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ DryRun = $true })
        ChatBody | Should -Not -Match 'ghp_a{36}'
    }
    It 'warns when the endpoint is not on this machine (plain http AND https)' {
        $r = Invoke-AicHarness -Sandbox $script:sb -Script {
            [pscustomobject]@{ Local = [string](Get-EndpointWarning ([Uri]'http://127.0.0.1:11434')); Lan = [string](Get-EndpointWarning ([Uri]'http://192.168.1.50:11434')); Tls = [string](Get-EndpointWarning ([Uri]'https://ollama.example.com')) }
        }
        $r.Error | Should -BeNullOrEmpty
        $r.Output.Local | Should -BeNullOrEmpty
        $r.Output.Lan | Should -Match 'not on this machine'; $r.Output.Lan | Should -Match 'unencrypted'
        $r.Output.Tls | Should -Match 'not on this machine'
    }
    It 'does not claim "zero tokens left the building" for a remote endpoint' {
        $r = Invoke-AicHarness -Sandbox $script:sb -Script {
            $uri = [Uri]'http://10.0.0.5:11434'; $remote = (Get-QuipPool) -join '|'
            $uri = [Uri]'http://127.0.0.1:11434'; $local = (Get-QuipPool) -join '|'
            [pscustomobject]@{ Remote = $remote; Local = $local }
        }
        $r.Error | Should -BeNullOrEmpty
        $r.Output.Remote | Should -Not -Match 'left the building'; $r.Output.Remote | Should -Not -Match 'fully local'
        $r.Output.Local  | Should -Match 'left the building'
    }
}
