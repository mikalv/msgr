<# 
.SYNOPSIS
  Bootstrap the Android SDK + emulator on Windows for reverse-engineering.

.USAGE
  .\setup_android_sdk.ps1 [-InstallDir C:\Android\sdk]

.NOTES
  - Requires PowerShell 5+.
  - Downloads command line tools revision 9477386.
  - Installs platform-tools, emulator, Android 13 (API 33) platform & system image.
#>

[CmdletBinding()]
param(
  [string]$InstallDir = $env:ANDROID_SDK_ROOT
)

if (-not $InstallDir) {
  $InstallDir = "$env:USERPROFILE\Android\sdk"
}

if (Test-Path $InstallDir) {
  $InstallDir = (Resolve-Path -Path $InstallDir).Path
} else {
  $InstallDir = (New-Item -ItemType Directory -Path $InstallDir -Force).FullName
}

Write-Host "[Setup] Installing Android SDK into $InstallDir"

$sdkRevision = "9477386"
$zipUrl = "https://dl.google.com/android/repository/commandlinetools-win-$sdkRevision`_latest.zip"
$tempDir = New-Item -ItemType Directory -Path ([System.IO.Path]::GetTempPath()) -Name ("android-sdk-" + [System.Guid]::NewGuid()) -Force
$zipPath = Join-Path $tempDir "cmdline-tools.zip"

try {
  Write-Host "[Setup] Downloading command line tools $zipUrl"
  Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath

  Write-Host "[Setup] Extracting command line tools"
  $extractDir = Join-Path $tempDir "cmdline-tools"
  Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force

  $cmdlineToolsRoot = Join-Path $InstallDir "cmdline-tools"
  New-Item -ItemType Directory -Path $cmdlineToolsRoot -Force | Out-Null
  $targetDir = Join-Path $cmdlineToolsRoot "latest"
  if (Test-Path $targetDir) {
    Remove-Item -Recurse -Force $targetDir
  }
  Move-Item -Path (Join-Path $extractDir "cmdline-tools") -Destination $targetDir

  $sdkManager = Join-Path $targetDir "bin\sdkmanager.bat"

  Write-Host "[Setup] Accepting licenses"
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = $sdkManager
  $psi.Arguments = "--sdk_root=$InstallDir --licenses"
  $psi.RedirectStandardInput = $true
  $psi.RedirectStandardOutput = $false
  $psi.RedirectStandardError = $false
  $psi.UseShellExecute = $false
  $licenseProcess = [System.Diagnostics.Process]::Start($psi)
  for ($i = 0; $i -lt 20; $i++) {
    $licenseProcess.StandardInput.WriteLine("y")
    Start-Sleep -Milliseconds 100
  }
  $licenseProcess.StandardInput.Close()
  $licenseProcess.WaitForExit()

  $packages = @(
    "platform-tools",
    "emulator",
    "platforms;android-33",
    "build-tools;33.0.2",
    "system-images;android-33;google_apis;x86_64"
  )

  Write-Host "[Setup] Installing core packages"
  & $sdkManager --sdk_root=$InstallDir $packages

  Write-Host ""
  Write-Host "[Setup] Android SDK installation complete!"
  Write-Host ""
  Write-Host "Add to your environment (PowerShell profile or system variables):"
  Write-Host "  setx ANDROID_SDK_ROOT `"$InstallDir`""
  Write-Host "  setx ANDROID_HOME `"$InstallDir`""
  Write-Host "  setx PATH (`$env:PATH + ';$InstallDir\platform-tools;$InstallDir\emulator;$InstallDir\cmdline-tools\latest\bin'`)"
  Write-Host ""
  Write-Host "Create a Pixel 6 emulator:"
  Write-Host "  $InstallDir\cmdline-tools\latest\bin\avdmanager.bat create avd `"
  Write-Host "    --name Pixel_6_API_33 `"
  Write-Host "    --package `"system-images;android-33;google_apis;x86_64`" `"
  Write-Host "    --device `"pixel_6`""
  Write-Host ""
  Write-Host "Start the emulator:"
  Write-Host "  $InstallDir\emulator\emulator.exe -avd Pixel_6_API_33 -writable-system -no-snapshot"
  Write-Host ""
}
finally {
  if (Test-Path $tempDir) {
    Remove-Item -Recurse -Force $tempDir
  }
}
