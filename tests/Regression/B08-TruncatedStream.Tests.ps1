# B8 (Medium): the NDJSON stream is not validated. done_reason "length" (cut at num_predict), a stream that ends without
# done:true (connection dropped) and malformed lines all produce a message that LOOKS fine.  With -Yes it is committed unattended.
# Expected behaviour (from the audit): such a message must not be auto-committed.
BeforeAll {
    . (Join-Path $PSScriptRoot '..' 'Helpers' 'All.ps1')
    $script:mock = Start-MockOllama
}
AfterAll { Stop-MockOllama $script:mock }

Describe 'B8: an incomplete model stream is never auto-committed' -Tag 'Regression', 'B08' {
    BeforeEach {
        $script:sb = New-AicSandbox; Enter-AicSandbox $script:sb
        $script:repo = New-TestRepo $script:sb
        Set-TestFile $script:repo 'a.txt' "two`n"; [void](G $script:repo add -- a.txt)
        $script:head = Get-HeadSha $script:repo
    }
    AfterEach { Exit-AicSandbox $script:sb; Remove-AicSandbox $script:sb }

    It 'done_reason "length" (output cut at -NumPredict) is not committed with -Yes' {
        Set-MockChat $script:mock @{ Lines = (New-ChatLines -Text 'feat(auth): add login validation for' -DoneReason 'length') }
        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ Yes = $true }
        $e.TimedOut | Should -BeFalse
        Get-HeadSha $script:repo | Should -Be $script:head -Because "a message cut off mid-sentence was committed: '$((GTry $script:repo log -1 --format=%s).Out -join '')'"
    }

    It 'a stream that ends without a final done:true is not committed with -Yes' {
        Set-MockChat $script:mock @{ Lines = (New-ChatLines -Text 'feat(auth): add login validation' -SendDone $false) }
        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ Yes = $true }
        $e.TimedOut | Should -BeFalse
        Get-HeadSha $script:repo | Should -Be $script:head
    }

    It 'a malformed NDJSON line in the middle of the stream is not silently dropped into a committed message' -Tag 'Spec' {
        $lines = @(
            '{"message":{"role":"assistant","content":"feat: add "},"done":false}',
            'this is not json {{{',
            '{"message":{"role":"assistant","content":"parser"},"done":false}',
            '{"done":true,"done_reason":"stop","eval_count":3,"eval_duration":1000000000}')
        Set-MockChat $script:mock @{ Lines = $lines }
        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ Yes = $true }
        $e.TimedOut | Should -BeFalse
        Get-HeadSha $script:repo | Should -Be $script:head
    }

    It 'CONTROL: a complete stream (done:true, done_reason stop) is committed with -Yes' -Tag 'Control' {
        Set-MockChat $script:mock @{ Lines = (New-ChatLines -Text 'feat: add thing') }
        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ Yes = $true }
        $e.TimedOut | Should -BeFalse
        Get-HeadSha $script:repo | Should -Not -Be $script:head
        (G $script:repo log -1 --format=%s) | Should -Be 'feat: add thing'
    }
}
