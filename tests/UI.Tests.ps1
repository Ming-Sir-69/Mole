BeforeAll {
    . "$PSScriptRoot\..\lib\core\ui.ps1"
    if (-not (Get-Command Test-MoleInteractiveOutput -ErrorAction SilentlyContinue)) {
        function Test-MoleInteractiveOutput { $false }
    }
}

Describe 'Terminal presentation' {
    BeforeEach {
        Mock Write-Host {}
        Mock Test-MoleInteractiveOutput { $false }
    }

    It 'accepts the native progress parameter contract used by both scanners' {
        Mock Update-Spinner {}
        Mock Stop-Spinner {}
        Write-Progress -Activity 'Scanning apps' -Status 'Registry' -PercentComplete 50
        Should -Invoke Update-Spinner -Times 1 -Exactly -ParameterFilter { $Message -eq 'Scanning apps, Registry' }
        Write-Progress -Activity 'Scanning apps' -Completed
        Should -Invoke Stop-Spinner -Times 1 -Exactly
    }

    It 'does not emit animation or cursor escapes to redirected output' {
        Start-Spinner 'Scanning'
        Update-Spinner 'Measuring'
        Stop-Spinner
        Should -Invoke Write-Host -Times 0 -Exactly
    }

    It 'uses the Mac summary frame and keeps a narrow terminal within its width' {
        Mock Get-TerminalSize { @{ Width = 40; Height = 24 } }
        Show-SummaryBlock -Heading 'Cleanup complete' -Details @('Space freed: 128 MB')
        Should -Invoke Write-Host -Times 2 -Exactly -ParameterFilter { $Object -eq ('=' * 40) }
        Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { $Object -match 'Space freed: 128 MB' }
    }

    It 'caps the summary divider at the Mac width' {
        Mock Get-TerminalSize { @{ Width = 120; Height = 24 } }
        Show-SummaryBlock -Heading 'Preview' -Details @()
        Should -Invoke Write-Host -Times 2 -Exactly -ParameterFilter { $Object -eq ('=' * 70) }
    }

    It 'stops loading before printing a result and resumes only an active section' {
        Mock Stop-Spinner {}
        Mock Start-Spinner {}
        $script:CurrentSection.Active = $true
        Write-Success 'Cache cleaned'
        Should -Invoke Stop-Spinner -Times 1 -Exactly
        Should -Invoke Start-Spinner -Times 1 -Exactly
        $script:CurrentSection.Active = $false
    }
}

Describe 'Background loading lifecycle' {
    It 'animates while the calling thread waits and stops before returning' {
        Initialize-MoleSpinner
        $original = [Console]::Out
        $capture = New-Object System.IO.StringWriter
        try {
            [Console]::SetOut($capture)
            [Mole.TerminalSpinner]::Start('Scanning')
            Start-Sleep -Milliseconds 350
            [Mole.TerminalSpinner]::Stop()
            $finished = $capture.ToString()
            $finished | Should -Match ([string][char]0x2816)
            $finished | Should -Match ([string][char]0x2832)
            Start-Sleep -Milliseconds 180
            $capture.ToString() | Should -BeExactly $finished
        }
        finally {
            [Mole.TerminalSpinner]::Stop()
            [Console]::SetOut($original)
            $capture.Dispose()
        }
    }
}

Describe 'Display-cell list columns' {
    It 'aligns ASCII, Chinese, mixed and truncated names at one right edge' {
        Mock Get-TerminalSize { @{ Width = 60; Height = 24 } }
        foreach ($name in @('Clash Party', '微信输入法', 'UU远程', ('中文应用' * 20), 'éditor')) {
            $row = Format-SizeListEntry -Name $name -Size '443.4MB'
            (Get-TerminalTextWidth $row) | Should -Be 53
            $row.EndsWith('443.4MB') | Should -BeTrue
        }
        (Format-SizeListEntry -Name ('中文应用' * 20) -Size '1MB') | Should -Match '\.\.\.'
    }

    It 'fits both list callers in a narrow terminal including a suffix' {
        Mock Get-TerminalSize { @{ Width = 40; Height = 24 } }
        $row = Format-SizeListEntry -Name ('中文项目' * 20) -Size '12MB' -Suffix ' (3 items)' -NameWidth 32
        (Get-TerminalTextWidth $row) | Should -Be 33
    }

    It 'settles interactive results once without delaying redirected output' {
        Mock Write-Host {}
        Mock Stop-Spinner {}
        Mock Start-Sleep {}
        Mock Test-MoleInteractiveOutput { $false }
        Show-SummaryBlock -Heading 'Done'
        Should -Invoke Start-Sleep -Times 0 -Exactly
        Mock Test-MoleInteractiveOutput { $true }
        Show-SummaryBlock -Heading 'Done'
        Should -Invoke Start-Sleep -Times 1 -Exactly -ParameterFilter { $Milliseconds -eq 180 }
    }
}
