<#
  LaptopCheck - hardware facts collector (read-only)

  Collects hardware and health facts from this PC and writes them to data.js,
  which LaptopCheck.html reads to show the results.

  * Read-only: it changes no settings, installs nothing and deletes nothing
    (a temporary battery report is written to %TEMP% and removed right away).
  * Offline: it sends nothing over the network.
  * All judging rules (OK / check / problem) live in LaptopCheck.html,
    so this script stays language-neutral and model-neutral.

  Usage:  double-click START.bat
          powershell -ExecutionPolicy Bypass -File check.ps1 [-NoElevate] [-NoOpen] [-OutDir <path>]
#>
param(
  [switch]$NoElevate,
  [switch]$NoOpen,
  [string]$OutDir
)

$Version = '1.0.0'

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin -and -not $NoElevate) {
  try {
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-NoElevate')
    if ($NoOpen) { $argList += '-NoOpen' }
    if ($OutDir) { $argList += @('-OutDir', "`"$OutDir`"") }
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -ErrorAction Stop -ArgumentList $argList
    exit
  } catch {
    Write-Host ''
    Write-Host '  Running without admin rights: SSD health details and drive encryption will be skipped.' -ForegroundColor Yellow
  }
}

$ErrorActionPreference = 'SilentlyContinue'
try { $Host.UI.RawUI.WindowTitle = 'LaptopCheck' } catch {}

function Step($msg) { Write-Host "  > $msg" }
function ToNum($v) {
  $n = 0.0
  if ($null -ne $v -and [double]::TryParse("$v", [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$n)) { return $n }
  return $null
}
function Clean($v) { if ($null -eq $v) { return '' } return ("$v").Trim() }
function Names($list) { @($list | ForEach-Object { Clean $_.Name } | Where-Object { $_ } | Select-Object -Unique) }

Write-Host ''
Write-Host "  LaptopCheck $Version - read-only hardware check" -ForegroundColor Cyan
Write-Host '  Nothing on this PC is changed. Nothing is sent anywhere.' -ForegroundColor DarkGray
Write-Host ''

# ---------------------------------------------------------------- system
Step 'System'
$cs   = Get-CimInstance Win32_ComputerSystem
$csp  = Get-CimInstance Win32_ComputerSystemProduct
$bios = Get-CimInstance Win32_BIOS
$os   = Get-CimInstance Win32_OperatingSystem
$encl = Get-CimInstance Win32_SystemEnclosure | Select-Object -First 1

# SMBIOS chassis types that are portable: laptop, notebook, sub-notebook, tablet, convertible, detachable ...
$portableTypes = @(8, 9, 10, 11, 12, 14, 18, 21, 30, 31, 32)
$portableChassis = @($encl.ChassisTypes | Where-Object { $portableTypes -contains [int]$_ }).Count -gt 0

$system = [ordered]@{
  manufacturer = Clean $cs.Manufacturer
  model        = Clean $cs.Model
  family       = Clean $cs.SystemFamily
  product      = Clean $csp.Version
  serial       = Clean $bios.SerialNumber
  bios         = Clean $bios.SMBIOSBIOSVersion
  os           = Clean $os.Caption
  build        = Clean $os.BuildNumber
  installDate  = $(if ($os.InstallDate) { $os.InstallDate.ToString('yyyy-MM-dd') } else { $null })
  isLaptop     = $false
}

# ---------------------------------------------------------------- cpu / ram
Step 'CPU / memory'
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$cpuInfo = [ordered]@{
  name    = Clean $cpu.Name
  cores   = $cpu.NumberOfCores
  threads = $cpu.NumberOfLogicalProcessors
  maxMHz  = $cpu.MaxClockSpeed
}

$mem = @(Get-CimInstance Win32_PhysicalMemory)
$memBytes = ($mem | Measure-Object -Property Capacity -Sum).Sum
if (-not $memBytes) { $memBytes = $cs.TotalPhysicalMemory }
$modules = @($mem | ForEach-Object {
  [ordered]@{ gb = [math]::Round($_.Capacity / 1GB, 1); slot = Clean $_.DeviceLocator; speed = $_.ConfiguredClockSpeed; maker = Clean $_.Manufacturer }
})
$ram = [ordered]@{
  totalGB = [math]::Round($memBytes / 1GB, 1)
  speed   = ($mem | Select-Object -First 1).ConfiguredClockSpeed
  modules = $modules
}

# ---------------------------------------------------------------- storage
Step 'Storage'
$disks = New-Object System.Collections.ArrayList
foreach ($d in @(Get-PhysicalDisk | Where-Object { "$($_.BusType)" -ne 'USB' })) {
  $o = [ordered]@{
    name         = Clean $d.FriendlyName
    sizeGB       = [math]::Round($d.Size / 1e9)
    bus          = Clean $d.BusType
    media        = Clean $d.MediaType
    health       = Clean $d.HealthStatus
    wear         = $null
    powerOnHours = $null
    temperature  = $null
    readErrors   = $null
  }
  if ($isAdmin) {
    $rc = $d | Get-StorageReliabilityCounter
    if ($rc) {
      $o.wear         = ToNum $rc.Wear
      $o.powerOnHours = ToNum $rc.PowerOnHours
      $o.temperature  = ToNum $rc.Temperature
      $o.readErrors   = ToNum $rc.ReadErrorsUncorrected
    }
  }
  [void]$disks.Add($o)
}
$cd = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
$cdrive = $null
if ($cd) { $cdrive = [ordered]@{ freeGB = [math]::Round($cd.FreeSpace / 1e9); sizeGB = [math]::Round($cd.Size / 1e9) } }

# ---------------------------------------------------------------- battery
Step 'Battery'
$battery = $null
$wbs = @(Get-CimInstance Win32_Battery)
$xmlPath = Join-Path $env:TEMP ("lc_battery_{0}.xml" -f $PID)
powercfg /batteryreport /xml /output "$xmlPath" | Out-Null
if (Test-Path $xmlPath) {
  try {
    $bx = New-Object xml
    $bx.Load($xmlPath)
    $b = @($bx.BatteryReport.Batteries.Battery)[0]
    if ($b) {
      $design = ToNum $b.DesignCapacity
      $full   = ToNum $b.FullChargeCapacity
      $health = $null
      if ($design -and $full) { $health = [math]::Round($full / $design * 100, 1) }
      $battery = [ordered]@{ design = $design; full = $full; health = $health; cycles = ToNum $b.CycleCount; chargePct = $null; onAC = $null }
    }
  } catch {}
  Remove-Item $xmlPath -Force
}
if (-not $battery -and $wbs.Count -gt 0) {
  $battery = [ordered]@{ design = $null; full = $null; health = $null; cycles = $null; chargePct = $null; onAC = $null }
}
if ($battery -and $wbs.Count -gt 0) {
  $battery.chargePct = ToNum $wbs[0].EstimatedChargeRemaining
  $battery.onAC = ($wbs[0].BatteryStatus -eq 2)
}
$system.isLaptop = [bool]($portableChassis -or $cs.PCSystemType -eq 2 -or $battery)

# ---------------------------------------------------------------- display
Step 'Display / graphics'
$gpus = @(Get-CimInstance Win32_VideoController | ForEach-Object {
  [ordered]@{
    name = Clean $_.Name; driver = Clean $_.DriverVersion; status = Clean $_.Status
    width = $_.CurrentHorizontalResolution; height = $_.CurrentVerticalResolution
    refresh = $_.CurrentRefreshRate; maxRefresh = $_.MaxRefreshRate
  }
})
$monitors = @(Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorBasicDisplayParams | ForEach-Object {
  $h = ToNum $_.MaxHorizontalImageSize; $v = ToNum $_.MaxVerticalImageSize
  [ordered]@{ inches = $(if ($h -and $v) { [math]::Round([math]::Sqrt($h * $h + $v * $v) / 2.54, 1) } else { $null }) }
})

# ---------------------------------------------------------------- devices
Step 'Devices / drivers'
$pnp = @(Get-CimInstance Win32_PnPEntity)
$errDevices = @($pnp | Where-Object { $_.ConfigManagerErrorCode -and $_.ConfigManagerErrorCode -ne 45 } | Select-Object -First 15 | ForEach-Object {
  [ordered]@{ name = Clean $_.Name; code = [int]$_.ConfigManagerErrorCode }
})
function Has-HidUsage($usage) {
  @($pnp | Where-Object { (($_.CompatibleID -join ';') + ';' + ($_.HardwareID -join ';')) -like "*$usage*" }).Count -gt 0
}
$wifiAdapter = @(Get-NetAdapter -Physical | Where-Object { $_.NdisPhysicalMedium -eq 9 -or $_.InterfaceDescription -match 'Wi-?Fi|Wireless|WLAN|802\.11' }) | Select-Object -First 1
$devices = [ordered]@{
  errors      = $errDevices
  touchscreen = Has-HidUsage 'UP:000D_U:0004'
  touchpad    = Has-HidUsage 'UP:000D_U:0005'
  cameras     = Names ($pnp | Where-Object { $_.PNPClass -in @('Camera', 'Image') })
  audio       = Names ($pnp | Where-Object { $_.PNPClass -eq 'AudioEndpoint' })
  bluetooth   = @($pnp | Where-Object { $_.PNPClass -eq 'Bluetooth' }).Count -gt 0
  wifi        = $(if ($wifiAdapter) { [ordered]@{ name = Clean $wifiAdapter.InterfaceDescription; status = Clean $wifiAdapter.Status } } else { $null })
}

# ---------------------------------------------------------------- stability
Step 'Error history (last 90 days)'
$since = (Get-Date).AddDays(-90)
$kp   = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-Kernel-Power'; Id = 41; StartTime = $since })
$bsod = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-WER-SystemErrorReporting'; Id = 1001; StartTime = $since })
$whea = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-WHEA-Logger'; StartTime = $since })
$oldest = Get-WinEvent -LogName System -MaxEvents 1 -Oldest
$events = [ordered]@{
  days        = 90
  kernelPower = $kp.Count
  bugcheck    = $bsod.Count
  whea        = $whea.Count
  logStart    = $(if ($oldest) { $oldest.TimeCreated.ToString('yyyy-MM-dd') } else { $null })
}

# ---------------------------------------------------------------- windows
Step 'Windows license / accounts'
$lic = Get-CimInstance -ClassName SoftwareLicensingProduct -Filter "Name LIKE 'Windows%' AND PartialProductKey IS NOT NULL" | Select-Object -First 1
$bitlocker = $null
if ($isAdmin) {
  $bl = Get-BitLockerVolume -MountPoint 'C:'
  if ($bl) { $bitlocker = Clean $bl.ProtectionStatus }
}
$windows = [ordered]@{
  activated     = $(if ($lic) { [bool]($lic.LicenseStatus -eq 1) } else { $null })
  licenseStatus = $(if ($lic) { [int]$lic.LicenseStatus } else { $null })
  bitlocker     = $bitlocker
  msAccounts    = @(Get-LocalUser | Where-Object { $_.Enabled -and "$($_.PrincipalSource)" -eq 'MicrosoftAccount' }).Count
}

# ---------------------------------------------------------------- write
Step 'Saving results'
$data = [ordered]@{
  schema    = 1
  tool      = 'LaptopCheck'
  version   = $Version
  generated = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss')
  admin     = [bool]$isAdmin
  system    = $system
  cpu       = $cpuInfo
  ram       = $ram
  disks     = @($disks)
  cdrive    = $cdrive
  battery   = $battery
  gpus      = $gpus
  monitors  = $monitors
  devices   = $devices
  events    = $events
  windows   = $windows
}
$json = ConvertTo-Json -InputObject $data -Depth 8 -Compress
$payload = "window.AUTO = $json;"
$utf8 = New-Object System.Text.UTF8Encoding($false)

$here = Split-Path -Parent $PSCommandPath
$html = Join-Path $here 'LaptopCheck.html'
$target = $(if ($OutDir) { $OutDir } else { $here })
try {
  if (-not (Test-Path $target)) { New-Item -ItemType Directory -Force -Path $target -ErrorAction Stop | Out-Null }
  [IO.File]::WriteAllText((Join-Path $target 'data.js'), $payload, $utf8)
  if ($target -ne $here) { Copy-Item $html (Join-Path $target 'LaptopCheck.html') -Force; $html = Join-Path $target 'LaptopCheck.html' }
} catch {
  # read-only location (e.g. write-protected USB): fall back to %TEMP%
  $tmp = Join-Path $env:TEMP 'LaptopCheck'
  New-Item -ItemType Directory -Force -Path $tmp | Out-Null
  Copy-Item $html (Join-Path $tmp 'LaptopCheck.html') -Force
  [IO.File]::WriteAllText((Join-Path $tmp 'data.js'), $payload, $utf8)
  $html = Join-Path $tmp 'LaptopCheck.html'
}

Write-Host ''
Write-Host '  Done. Continue in the browser window (screen, keyboard, touch, speakers ...).' -ForegroundColor Green
if (-not $NoOpen) {
  # explorer.exe hands the file to the default browser without admin rights
  Start-Process -FilePath 'explorer.exe' -ArgumentList "`"$html`""
  Start-Sleep -Seconds 4
}
