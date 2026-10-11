$ErrorActionPreference = 'Stop'

$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

$packageArgs = @{
    packageName    = $env:ChocolateyPackageName
    unzipLocation  = $toolsDir
    url64bit       = '{{ZIP_URL}}'
    checksum64     = '{{ZIP_SHA256}}'
    checksumType64 = 'sha256'
}
Install-ChocolateyZipPackage @packageArgs

# Chocolatey shims every executable in the package. Only the mo.exe launcher
# belongs on PATH; the TUI tools are started by Mole itself.
foreach ($tool in @('analyze.exe', 'status.exe')) {
    $exe = Join-Path $toolsDir "bin\$tool"
    if (Test-Path $exe) {
        New-Item -ItemType File -Path "$exe.ignore" -Force | Out-Null
    }
}

# `mole` is the long name for the same launcher.
Install-BinFile -Name 'mole' -Path (Join-Path $toolsDir 'mo.exe')
