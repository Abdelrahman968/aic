# Mock Ollama: an in-process HttpListener on 127.0.0.1:<random port>. No real Ollama is ever needed.
# Endpoints: GET /api/tags, POST /api/show, POST /api/chat (scripted, streamed NDJSON), POST /api/generate (unload).
# Chat responses come from $mock.State.Chat (a list of scripted entries). When the list is exhausted the LAST entry repeats.
#   entry = @{ Status = 200; Lines = @('<ndjson>', ...); DelayMs = 0; Body = '<raw body for non-200>'; AbortAfterLines = 0 }

function Start-MockOllama {
    param([object[]]$Models = @('qwen2.5-coder:7b'), [string[]]$Capabilities = @('completion'))
    $tcp = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0); $tcp.Start()
    $port = $tcp.LocalEndpoint.Port; $tcp.Stop()
    $state = [hashtable]::Synchronized(@{
        Port = $port; Models = $Models; Capabilities = $Capabilities; Stop = $false; Ready = $false; Error = $null; ChatIndex = 0; ContextLength = 0; ClientGone = $false
        Chat     = [System.Collections.ArrayList]::Synchronized([System.Collections.ArrayList]::new())
        Requests = [System.Collections.ArrayList]::Synchronized([System.Collections.ArrayList]::new())
    })
    $rs = [runspacefactory]::CreateRunspace(); $rs.Open()
    $rs.SessionStateProxy.SetVariable('state', $state)
    $ps = [powershell]::Create(); $ps.Runspace = $rs
    [void]$ps.AddScript({
        $l = $null
        try {
            $l = [System.Net.HttpListener]::new()
            $l.Prefixes.Add("http://127.0.0.1:$($state.Port)/")
            $l.Start(); $state.Ready = $true
            while (-not $state.Stop) {
                $t = $l.GetContextAsync()
                while (-not $t.Wait(100)) { if ($state.Stop) { break } }
                if ($state.Stop -or -not $t.IsCompleted) { break }
                $c = $t.Result; $req = $c.Request; $res = $c.Response
                $body = ''
                if ($req.HasEntityBody) { $sr = [IO.StreamReader]::new($req.InputStream, [Text.Encoding]::UTF8); $body = $sr.ReadToEnd(); $sr.Dispose() }
                $path = $req.Url.AbsolutePath
                [void]$state.Requests.Add([pscustomobject]@{ Method = $req.HttpMethod; Path = $path; Body = $body; Auth = [string]$req.Headers['Authorization'] })
                try {
                    $write = {
                        param($text, $status, $ctype)
                        $res.StatusCode = $status; $res.ContentType = $ctype
                        $b = [Text.Encoding]::UTF8.GetBytes($text); $res.ContentLength64 = $b.Length
                        $res.OutputStream.Write($b, 0, $b.Length)
                    }
                    if ($path -eq '/api/tags') {
                        $models = @($state.Models | ForEach-Object { if ($_ -is [hashtable]) { @{ name = $_['name']; size = $_['size'] } } else { @{ name = $_; size = 4700000000 } } })
                        & $write (@{ models = $models } | ConvertTo-Json -Depth 5 -Compress) 200 'application/json'
                    }
                    elseif ($path -eq '/v1/models') {
                        $data = @($state.Models | ForEach-Object { @{ id = $(if ($_ -is [hashtable]) { $_['name'] } else { $_ }); object = 'model' } })
                        & $write (@{ object = 'list'; data = $data } | ConvertTo-Json -Depth 5 -Compress) 200 'application/json'
                    }
                    elseif ($path -eq '/api/show') {
                        $show = @{ capabilities = @($state.Capabilities) }
                        if ($state.ContextLength -gt 0) { $show['model_info'] = @{ 'general.architecture' = 'llama'; 'llama.context_length' = [int]$state.ContextLength } }
                        & $write ($show | ConvertTo-Json -Depth 4 -Compress) 200 'application/json'
                    }
                    elseif ($path -eq '/api/generate') { & $write '{}' 200 'application/json' }
                    elseif ($path -eq '/api/chat' -or $path -eq '/v1/chat/completions') {
                        $n = $state.Chat.Count
                        if ($n -eq 0) {
                            $entry = @{ Status = 200; Lines = @(
                                '{"message":{"role":"assistant","content":"feat: add thing"},"done":false}',
                                '{"done":true,"done_reason":"stop","eval_count":5,"eval_duration":1000000000}') }
                        } else {
                            $entry = $state.Chat[[Math]::Min($state.ChatIndex, $n - 1)]; $state.ChatIndex = $state.ChatIndex + 1
                        }
                        $status = if ($entry['Status']) { [int]$entry['Status'] } else { 200 }
                        if ($status -ne 200) { & $write ([string]$entry['Body']) $status 'application/json' }
                        elseif ($entry['AbortImmediately']) { $res.Abort() }                         # connection dies before the first byte
                        else {
                            $res.StatusCode = 200; $res.ContentType = $(if ($path -like '/v1/*') { 'text/event-stream' } else { 'application/x-ndjson' }); $res.SendChunked = $true
                            $out = $res.OutputStream; $sent = 0
                            foreach ($line in @($entry['Lines'])) {
                                if ($entry['DelayMs']) { Start-Sleep -Milliseconds ([int]$entry['DelayMs']) }
                                try { $b = [Text.Encoding]::UTF8.GetBytes([string]$line + "`n"); $out.Write($b, 0, $b.Length); $out.Flush(); $sent++ }
                                catch { $state.ClientGone = $true; break }                              # the client closed the connection: nothing is left orphaned
                                if ($entry['AbortAfterLines'] -and $sent -ge [int]$entry['AbortAfterLines']) { $res.Abort(); break }
                            }
                        }
                    }
                    else { & $write '{"error":"not found"}' 404 'application/json' }
                } catch { $state.Error = "$_" }
                finally { try { $res.Close() } catch { } }
            }
        } catch { $state.Error = "listener: $_"; $state.Ready = $true }
        finally { if ($l) { try { $l.Stop(); $l.Close() } catch { } } }
    })
    $handle = $ps.BeginInvoke()
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while (-not $state.Ready -and $sw.Elapsed.TotalSeconds -lt 10) { Start-Sleep -Milliseconds 25 }
    if ($state.Error) { throw "mock ollama failed to start: $($state.Error)" }
    [pscustomobject]@{ Url = "http://127.0.0.1:$port"; State = $state; PS = $ps; Runspace = $rs; Handle = $handle }
}

function Stop-MockOllama($Mock) {
    if (-not $Mock) { return }
    $Mock.State.Stop = $true
    try { [void]$Mock.PS.EndInvoke($Mock.Handle) } catch { }
    try { $Mock.PS.Dispose(); $Mock.Runspace.Dispose() } catch { }
}

# build the NDJSON lines Ollama would stream for $Text (split into $Chunks pieces)
function New-ChatLines {
    param([string]$Text, [string]$DoneReason = 'stop', [bool]$SendDone = $true, [int]$Chunks = 3)
    $lines = [System.Collections.Generic.List[string]]::new()
    $len = $Text.Length; $size = [Math]::Max(1, [int][Math]::Ceiling($len / [double]$Chunks))
    for ($i = 0; $i -lt $len; $i += $size) {
        $piece = $Text.Substring($i, [Math]::Min($size, $len - $i))
        $lines.Add((@{ message = @{ role = 'assistant'; content = $piece }; done = $false } | ConvertTo-Json -Compress))
    }
    if ($SendDone) { $lines.Add((@{ done = $true; done_reason = $DoneReason; eval_count = $Chunks; eval_duration = 1000000000 } | ConvertTo-Json -Compress)) }
    , $lines.ToArray()
}

# Set-MockChat $mock @{ Lines = ... }, @{ Status = 500; Body = '{"error":"x"}' }   (replaces the script, clears the request log)
function Set-MockChat($Mock, [hashtable[]]$Entries) {
    $Mock.State.Chat.Clear(); $Mock.State.Requests.Clear(); $Mock.State.ChatIndex = 0; $Mock.State.ClientGone = $false
    foreach ($e in $Entries) { [void]$Mock.State.Chat.Add($e) }
}
function Get-MockRequests($Mock, [string]$Path) { @($Mock.State.Requests | Where-Object { -not $Path -or $_.Path -eq $Path }) }

# the same answer as an OpenAI-compatible server (LM Studio, llama.cpp server ...) would stream it: SSE "data:" events
function New-SseLines {
    param([string]$Text, [string]$FinishReason = 'stop', [bool]$SendDone = $true, [int]$Chunks = 3)
    $lines = [System.Collections.Generic.List[string]]::new()
    $len = $Text.Length; $size = [Math]::Max(1, [int][Math]::Ceiling($len / [double]$Chunks))
    for ($i = 0; $i -lt $len; $i += $size) {
        $piece = $Text.Substring($i, [Math]::Min($size, $len - $i))
        $lines.Add('data: ' + (@{ choices = @(@{ index = 0; delta = @{ content = $piece }; finish_reason = $null }) } | ConvertTo-Json -Depth 5 -Compress)); $lines.Add('')
    }
    $lines.Add('data: ' + (@{ choices = @(@{ index = 0; delta = @{}; finish_reason = $FinishReason }) } | ConvertTo-Json -Depth 5 -Compress)); $lines.Add('')
    if ($SendDone) { $lines.Add('data: [DONE]'); $lines.Add('') }
    , $lines.ToArray()
}
