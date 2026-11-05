# Child-process runner for function-level tests. The harness function (generated from aic.ps1 by AST) defines every
# nested helper of `aic` exactly as the original does, then runs the test block in that same scope.
param([string]$FnFile, [string]$BlockFile, [string]$VarsFile, [string]$ParamsFile, [string]$ResultFile)
$res = [ordered]@{ Output = $null; Leaked = 0; Error = $null }
try {
    . $FnFile
    $global:AicHarnessBlock = [scriptblock]::Create([IO.File]::ReadAllText($BlockFile))
    $global:AicVars = Get-Content -LiteralPath $VarsFile -Raw | ConvertFrom-Json -AsHashtable
    $p = Get-Content -LiteralPath $ParamsFile -Raw | ConvertFrom-Json -AsHashtable
    $out = @(aic_harness @p)
    if ($out.Count -gt 0) { $res.Output = $out[$out.Count - 1]; $res.Leaked = $out.Count - 1 }   # last object = the block's result
} catch { $res.Error = ($_ | Out-String) }
$res | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ResultFile -Encoding utf8
