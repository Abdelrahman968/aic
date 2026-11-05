# Child-process runner: dot-sources aic.ps1 and calls `aic` with the splatted parameters from a JSON file.
# Running in a child gives real "redirected stdout / redirected stdin" behaviour (CI-like) and full isolation.
param([string]$AicPath, [string]$ArgsFile, [string]$ResultFile)
$res = [ordered]@{ Pipeline = @(); Error = $null; Code = $null }
try {
    . $AicPath
    $p = Get-Content -LiteralPath $ArgsFile -Raw | ConvertFrom-Json -AsHashtable
    $global:LASTEXITCODE = $null
    $res.Pipeline = @(& aic @p | ForEach-Object { "$_" })
    $res.Code = $global:LASTEXITCODE
} catch { $res.Error = ($_ | Out-String) }
$res | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $ResultFile -Encoding utf8
