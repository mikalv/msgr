<#
.SYNOPSIS
  Install Frida CLI tools and download the matching frida-server binary on Windows.

.USAGE
  .\setup_frida_env.ps1 [-Arch android-arm64] [-OutputDir .\reverse\frida\bin]
#>

[CmdletBinding()]
param(
  [string]$Arch,
  [string]$OutputDir = ".\reverse\frida\bin"
)

if (-not (Get-Command python -ErrorAction SilentlyContinue) -and -not (Get-Command python3 -ErrorAction SilentlyContinue)) {
  Write-Error "Python 3 is required. Install it first."
  exit 1
}

$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) {
  $python = Get-Command python3 -ErrorAction SilentlyContinue
}

Write-Host "[Frida] Installing Python packages (frida, frida-tools)"
& $python.Source -m pip install --user --upgrade frida frida-tools

$fridaVersion = & $python.Source - <<'PY'
import frida, sys
sys.stdout.write(frida.__version__)
PY

if (-not $fridaVersion) {
  Write-Error "Failed to detect Frida version."
  exit 1
}

if (-not $Arch) {
  Write-Host "[Frida] Detecting device ABI via adb (fallback to android-arm64)"
  if (Get-Command adb -ErrorAction SilentlyContinue) {
    $deviceAbi = (& adb shell getprop ro.product.cpu.abi 2>$null).Trim()
    if ($deviceAbi -like "*x86_64*") {
      $Arch = "android-x86_64"
    } elseif ($deviceAbi -like "*x86*") {
      $Arch = "android-x86"
    } else {
      $Arch = "android-arm64"
    }
  } else {
    $Arch = "android-arm64"
  }
}

if (Test-Path $OutputDir) {
  $OutputDir = (Resolve-Path -Path $OutputDir).Path
} else {
  $OutputDir = (New-Item -ItemType Directory -Path $OutputDir -Force).FullName
}

Write-Host "[Frida] Targeting frida-server for $Arch"
$serverName = "frida-server-$fridaVersion-$Arch"
$downloadUrl = "https://github.com/frida/frida/releases/download/$fridaVersion/$serverName.xz"
$tempFile = [System.IO.Path]::GetTempFileName()

try {
  Write-Host "[Frida] Downloading $downloadUrl"
  Invoke-WebRequest -Uri $downloadUrl -OutFile $tempFile

  $targetPath = Join-Path $OutputDir $serverName

  Write-Host "[Frida] Decompressing to $targetPath"
  $pythonArgs = @(
    "-c",
    "import lzma, pathlib, sys; data = lzma.open(sys.argv[1], 'rb').read(); pathlib.Path(sys.argv[2]).write_bytes(data)",
    $tempFile,
    $targetPath
  )
  & $python.Source $pythonArgs

  Write-Host ""
  Write-Host "[Frida] Setup complete!"
  Write-Host " - python -m pip install --user frida frida-tools"
  Write-Host " - frida-server stored at: $targetPath"
  Write-Host ""
  Write-Host "Deploy to emulator/device:"
  Write-Host "  adb push `"$targetPath`" /data/local/tmp/frida-server"
  Write-Host "  adb shell `"chmod 755 /data/local/tmp/frida-server`""
  Write-Host "  adb shell `/data/local/tmp/frida-server`"
}
finally {
  if (Test-Path $tempFile) {
    Remove-Item -Force $tempFile
  }
}
