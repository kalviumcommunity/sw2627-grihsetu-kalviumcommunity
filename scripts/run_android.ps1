param(
  [string]$AvdName = 'grihsetu_api35',
  [int]$BootTimeoutSeconds = 240,
  [switch]$RunApp
)

$ErrorActionPreference = 'Stop'

$sdkRoot = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
$adb = Join-Path $sdkRoot 'platform-tools\adb.exe'
$emulator = Join-Path $sdkRoot 'emulator\emulator.exe'

if (-not (Test-Path -LiteralPath $adb)) {
  throw "ADB was not found at $adb. Install Android SDK Platform-Tools."
}
if (-not (Test-Path -LiteralPath $emulator)) {
  throw "Android Emulator was not found at $emulator. Install it from Android Studio SDK Manager."
}

$env:Path = "$(Split-Path -Parent $adb);$(Split-Path -Parent $emulator);$env:Path"

function Get-AndroidEmulator {
  param([string]$RequiredState)

  $lines = & $adb devices 2>$null
  foreach ($line in $lines) {
    if ($line -match "^(emulator-\d+)\s+$RequiredState(?:\s|$)") {
      return $Matches[1]
    }
  }
  return $null
}

function Show-FirebaseTarget {
  $googleServicesPath = Join-Path $PSScriptRoot '..\android\app\google-services.json'
  $firebaseRcPath = Join-Path $PSScriptRoot '..\.firebaserc'
  if (-not (Test-Path -LiteralPath $googleServicesPath)) { return }

  $androidProject = (Get-Content -Raw -LiteralPath $googleServicesPath | ConvertFrom-Json).project_info.project_id
  Write-Host "Android Firebase project: $androidProject" -ForegroundColor Cyan

  if (Test-Path -LiteralPath $firebaseRcPath) {
    $cliProject = (Get-Content -Raw -LiteralPath $firebaseRcPath | ConvertFrom-Json).projects.default
    if ($cliProject -and $cliProject -ne $androidProject) {
      Write-Warning "Firebase CLI targets '$cliProject', but Android targets '$androidProject'. Check the '$androidProject' console for app data."
    }
  }
}

Show-FirebaseTarget

# Remove dead ADB transports left behind by failed emulator attempts. This
# does not stop a healthy connected device.
& $adb reconnect offline | Out-Null

$serial = Get-AndroidEmulator -RequiredState 'device'
if (-not $serial) {
  $offlineSerial = Get-AndroidEmulator -RequiredState 'offline'
  if ($offlineSerial) {
    Write-Host "Removing stale offline emulator $offlineSerial..." -ForegroundColor Yellow
    $escapedAvd = [regex]::Escape($AvdName)
    Get-CimInstance Win32_Process |
      Where-Object {
        $_.Name -in @('emulator.exe', 'qemu-system-x86_64.exe', 'qemu-system-x86_64-headless.exe') -and
        $_.CommandLine -match "-avd\s+$escapedAvd(?:\s|$)"
      } |
      ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Seconds 2
  }

  & $adb kill-server | Out-Null
  & $adb start-server | Out-Null

  Write-Host "Starting $AvdName as a detached emulator..." -ForegroundColor Cyan
  $process = Start-Process -FilePath $emulator -ArgumentList @(
    '-avd', $AvdName,
    '-no-snapshot-load'
  ) -PassThru

  $deadline = (Get-Date).AddSeconds($BootTimeoutSeconds)
  do {
    Start-Sleep -Seconds 3
    if ($process.HasExited) {
      throw "The Android emulator exited during startup. Run: & '$emulator' -avd $AvdName -no-snapshot-load -verbose"
    }

    $serial = Get-AndroidEmulator -RequiredState 'device'
    if ($serial) {
      $bootCompleted = (& $adb -s $serial shell getprop sys.boot_completed 2>$null).Trim()
      if ($bootCompleted -eq '1') { break }
    }
    Write-Host 'Waiting for Android to finish booting...'
  } while ((Get-Date) -lt $deadline)

  if (-not $serial -or $bootCompleted -ne '1') {
    throw "Android did not finish booting within $BootTimeoutSeconds seconds."
  }
}

Write-Host "Android is ready: $serial" -ForegroundColor Green

if ($RunApp) {
  Push-Location (Join-Path $PSScriptRoot '..')
  try {
    & flutter run -d $serial
    exit $LASTEXITCODE
  } finally {
    Pop-Location
  }
}

