# The documentation is checked against the code: it cannot silently drift.
BeforeAll {
    . (Join-Path $PSScriptRoot '..' 'Helpers' 'All.ps1')
    $script:root = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
    $script:aic  = Get-AicPath
    $script:src  = Get-Content -LiteralPath $script:aic -Raw
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($script:aic, [ref]$null, [ref]$null)
    $fn  = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'aic' }, $true)
    $script:params  = @($fn.Body.ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath })
    $script:aliases = @($fn.Body.ParamBlock.Parameters | ForEach-Object { $_.Attributes | Where-Object { $_.TypeName.Name -eq 'Alias' } | ForEach-Object { $_.PositionalArguments | ForEach-Object { $_.Value } } })
    $script:docs    = @(Get-Item (Join-Path $script:root 'README.md'), (Join-Path $script:root 'CHANGELOG.md')) + @(Get-ChildItem (Join-Path $script:root 'docs') -Filter *.md)
    $script:schemaKeys = @([regex]::Matches([regex]::Match($script:src, '(?s)\$cfgSchema = @\{(.*?)\n    \}').Groups[1].Value, '(\w+) = ') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
}

Describe 'Docs: the documentation matches the implementation' -Tag 'Docs' {
    It 'docs/PARAMETERS.md and docs/CONFIGURATION.md are exactly what tools/Update-Docs.ps1 generates from the code' {
        $pwsh = (Get-Process -Id $PID).Path
        $out = & $pwsh -NoProfile -File (Join-Path $script:root 'tools' 'Update-Docs.ps1') -Check -AicPath $script:aic -OutDir (Join-Path $script:root 'docs') 2>&1
        $LASTEXITCODE | Should -Be 0 -Because "$out (run: pwsh tools/Update-Docs.ps1)"
    }
    It 'every parameter has help text in aic.ps1 and appears in the parameter reference' {
        $ref  = Get-Content (Join-Path $script:root 'docs' 'PARAMETERS.md') -Raw
        $help = @([regex]::Matches($script:src, '(?m)^\.PARAMETER (\w+)') | ForEach-Object { $_.Groups[1].Value })
        @($script:params | Where-Object { $help -notcontains $_ }) | Should -BeNullOrEmpty -Because 'missing .PARAMETER help'
        @($script:params | Where-Object { $ref -notmatch ('`-' + $_ + '`') }) | Should -BeNullOrEmpty -Because 'missing from docs/PARAMETERS.md'
    }
    It 'every .aic.json key of the schema is documented, and nothing else is' {
        $cfg  = Get-Content (Join-Path $script:root 'docs' 'CONFIGURATION.md') -Raw
        $docKeys = @([regex]::Matches($cfg, '(?m)^\| `(\w+)` \| (?:text|whole number|true / false|list of text) ') | ForEach-Object { $_.Groups[1].Value })
        @($script:schemaKeys | Where-Object { $docKeys -notcontains $_ }) | Should -BeNullOrEmpty
        @($docKeys | Where-Object { $script:schemaKeys -notcontains $_ }) | Should -BeNullOrEmpty
    }
    It 'every "aic -Flag" used in the documents is a real parameter or alias' {
        $ok = $script:params + $script:aliases + @('Verbose', 'Debug', 'ErrorAction')
        $bad = foreach ($f in $script:docs) {
            foreach ($line in (Get-Content $f.FullName)) {
                $code = ($line -replace 'Get-Help aic -Full', '') -replace '\s#.*$', ''          # shell comments and Get-Help's own switch are not aic flags
                if ($code -notmatch '\baic\s+-') { continue }
                foreach ($m in [regex]::Matches(($code -replace '^.*?\baic\b', ''), '(?<![\w-])-([A-Za-z]\w*)')) { if ($ok -notcontains $m.Groups[1].Value) { "$($f.Name): -$($m.Groups[1].Value)  in  $line" } }
            }
        }
        @($bad) | Should -BeNullOrEmpty
    }
    It 'every JSON example in the documents is a valid configuration (checked by aic -ConfigValidate)' {
        $sb = New-AicSandbox; Enter-AicSandbox $sb
        try {
            $n = 0
            foreach ($f in $script:docs) {
                foreach ($m in [regex]::Matches((Get-Content $f.FullName -Raw), '(?s)```json\r?\n(.*?)```')) {
                    $n++; Set-TestFile $sb.Home '.aic.json' $m.Groups[1].Value
                    $e = Invoke-Aic -Sandbox $sb -Params @{ ConfigValidate = $true }
                    $e.Code | Should -Be 0 -Because "$($f.Name) example #$n : $($e.Stdout)"
                }
            }
            $n | Should -BeGreaterThan 0
        } finally { Exit-AicSandbox $sb; Remove-AicSandbox $sb }
    }
    It 'the exit codes in the README are the ones aic documents in its own help' {
        $readme = Get-Content (Join-Path $script:root 'README.md') -Raw
        $table  = @([regex]::Matches($readme, '(?m)^\| (\d+) \|') | ForEach-Object { [int]$_.Groups[1].Value })
        $help   = [regex]::Match($script:src, 'EXIT CODES[^\n]*\n\s*([^\n]+)').Groups[1].Value
        $helpCodes = @([regex]::Matches($help, '(\d+) ') | ForEach-Object { [int]$_.Groups[1].Value })
        ($table | Sort-Object) -join ',' | Should -Be (($helpCodes | Sort-Object) -join ',')
        ($table | Sort-Object) -join ',' | Should -Be '0,1,2,3,4,5,130'
    }
    It 'the keyboard reference lists every key of the review prompt' {
        $kb = Get-Content (Join-Path $script:root 'docs' 'KEYBOARD.md') -Raw
        foreach ($k in 'Enter', 'e', 'r', 'v', 'h', 'm', 't', 's', 'b', 'x', 'a', 'f', 'w', 'c', 'p', 'd', 'q') { $kb | Should -Match ("(?m)^\| " + [regex]::Escape($k) + "( or [^|]*)? \|") -Because "key $k" }
    }
    It 'relative links in the documents point to files that exist' {
        $bad = foreach ($f in $script:docs) { foreach ($m in [regex]::Matches((Get-Content $f.FullName -Raw), '\]\(([^)#\s]+)\)')) {
            $t = $m.Groups[1].Value; if ($t -match '^(https?:|mailto:)') { continue }
            if (-not (Test-Path -LiteralPath (Join-Path $f.DirectoryName $t))) { "$($f.Name) -> $t" } } }
        @($bad) | Should -BeNullOrEmpty
    }
}
