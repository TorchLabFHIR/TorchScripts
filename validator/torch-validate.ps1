#Requires -Version 5.1
# ──────────────────────────────────────────────────────────────
#  Torch  ·  FHIR Validator Wrapper  ·  torchlab.dev
#  Windows PowerShell / PowerShell 7+
#
#  Wraps the HL7 FHIR Validator CLI (validator_cli.jar).
#  Downloads the jar automatically on first use.
#
#  Usage:
#    .\torch-validate.ps1 [options] <file|directory>
#
#  Options:
#    -FhirVersion <ver>    R4 | R4B | R5  [default: R4]
#    -Ig <pkg>             IG package (repeat for multiple)
#    -Profile <url>        Profile canonical URL (repeat for multiple)
#    -TxServer <url>       Terminology server URL
#    -NoTx                 Offline mode
#    -Output <fmt>         text | json | xml  [default: text]
#    -Recurse              Validate directory recursively
#    -Download             Download / update validator_cli.jar
#    -Help                 Show usage
# ──────────────────────────────────────────────────────────────

[CmdletBinding()]
param(
  [string[]]$Target,
  [string]  $FhirVersion = 'R4',
  [string[]]$Ig          = @(),
  [string[]]$Profile     = @(),
  [string]  $TxServer    = 'https://tx.fhir.org/r4',
  [switch]  $NoTx,
  [string]  $Output      = 'text',
  [switch]  $Recurse,
  [switch]  $Download,
  [switch]  $Help
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

# ── Colour helpers ────────────────────────────────────────────
function Write-Brand { param([string]$t) Write-Host $t -ForegroundColor DarkYellow -NoNewline }
function Write-Ok    { param([string]$t) Write-Host $t -ForegroundColor Green    -NoNewline }
function Write-Fail  { param([string]$t) Write-Host $t -ForegroundColor Red      -NoNewline }
function Write-Warn  { param([string]$t) Write-Host $t -ForegroundColor Yellow   -NoNewline }
function Write-Hi    { param([string]$t) Write-Host $t -ForegroundColor Cyan     -NoNewline }
function Write-Dim   { param([string]$t) Write-Host $t -ForegroundColor DarkGray -NoNewline }
function Write-Nl    { Write-Host "" }

function Write-HR  { Write-Dim "  ────────────────────────────────────────────────────────"; Write-Nl }
function Write-Ok-Line([string]$msg)   { Write-Host "  " -NoNewline; Write-Ok "✔  "; Write-Host $msg }
function Write-Warn-Line([string]$msg) { Write-Host "  " -NoNewline; Write-Warn "⚠  "; Write-Host $msg -ForegroundColor Yellow }
function Write-Err-Line([string]$msg)  { Write-Host "  " -NoNewline; Write-Fail "✘  "; Write-Host $msg -ForegroundColor Red }
function Write-Info-Line([string]$msg) { Write-Host "  " -NoNewline; Write-Hi "→  "; Write-Dim $msg; Write-Nl }

$JarDir  = Join-Path $env:USERPROFILE '.torch'
$JarPath = Join-Path $JarDir 'validator_cli.jar'
$JarUrl  = 'https://github.com/hapifhir/org.hl7.fhir.core/releases/latest/download/validator_cli.jar'

function Write-Banner {
  Write-Nl
  Write-Brand "  ████████╗ ██████╗ ██████╗  ██████╗██╗  ██╗"
  Write-Nl
  Write-Dim   "  FHIR Validator Wrapper  ·  v1.0  ·  torchlab.dev"
  Write-Nl
  Write-Nl
  Write-HR
}

function Show-Usage {
  Write-Nl
  Write-Brand "Torch FHIR Validator"
  Write-Host "  torchlab.dev"
  Write-Nl
  Write-Host "Usage:" -ForegroundColor White
  Write-Dim  "  .\torch-validate.ps1 [options] <file|directory>"
  Write-Nl
  Write-Host "Options:" -ForegroundColor White
  Write-Dim  "  -FhirVersion R4|R4B|R5      FHIR version [default: R4]"
  Write-Nl
  Write-Dim  "  -Ig <pkg>                   IG package (e.g. hl7.fhir.us.core#6.1.0)"
  Write-Nl
  Write-Dim  "  -Profile <url>              Profile canonical URL"
  Write-Nl
  Write-Dim  "  -TxServer <url>             Terminology server URL"
  Write-Nl
  Write-Dim  "  -NoTx                       Offline mode (no terminology validation)"
  Write-Nl
  Write-Dim  "  -Output text|json|xml       Output format [default: text]"
  Write-Nl
  Write-Dim  "  -Recurse                    Recursively validate directory"
  Write-Nl
  Write-Dim  "  -Download                   Download/update validator_cli.jar"
  Write-Nl
  Write-Nl
  Write-Host "Examples:" -ForegroundColor White
  Write-Dim  "  .\torch-validate.ps1 Patient-example.json"
  Write-Nl
  Write-Dim  "  .\torch-validate.ps1 -FhirVersion R4 -Ig hl7.fhir.us.core#6.1.0 .\input\resources\"
  Write-Nl
  Write-Dim  "  .\torch-validate.ps1 -NoTx Patient.json"
  Write-Nl
  Write-Dim  "  .\torch-validate.ps1 -Download"
  Write-Nl
  Write-Nl
  Write-Dim  "Requires Java 17+. Jar cached at $JarPath"
  Write-Nl
}

function Get-FhirVersionNum([string]$ver) {
  switch ($ver.ToUpper()) {
    'R4'    { return '4.0.1' }
    'R4B'   { return '4.3.0' }
    'R5'    { return '5.0.0' }
    '4.0.1' { return '4.0.1' }
    '4.3.0' { return '4.3.0' }
    '5.0.0' { return '5.0.0' }
    default { Write-Err-Line "Unknown FHIR version: $ver"; exit 1 }
  }
}

function Test-Java {
  $java = Get-Command java -ErrorAction SilentlyContinue
  if (-not $java) {
    Write-Err-Line "Java not found. Install Java 17+: https://adoptium.net"
    Write-Info-Line "winget install EclipseAdoptium.Temurin.21.JDK"
    exit 1
  }
  $rawVer = (java -version 2>&1 | Out-String)
  if ($rawVer -match '"(\d+)(?:\.(\d+))?') {
    $major = [int]$Matches[1]
    if ($major -eq 1 -and $Matches[2]) { $major = [int]$Matches[2] }
    if ($major -lt 17) {
      Write-Err-Line "Java $major found - Java 17+ required."
      Write-Info-Line "Upgrade: winget install EclipseAdoptium.Temurin.21.JDK"
      exit 1
    }
    Write-Ok-Line "Java $major"
  }
}

function Get-Jar {
  if (-not (Test-Path $JarDir)) { New-Item -ItemType Directory -Force $JarDir | Out-Null }
  Write-Info-Line "Downloading FHIR Validator (latest)..."
  Write-Info-Line $JarUrl
  try {
    Invoke-WebRequest -Uri $JarUrl -OutFile $JarPath -UseBasicParsing
    Write-Ok-Line "Saved to $JarPath"
  } catch {
    Write-Err-Line "Download failed: $_"
    Write-Info-Line "Download manually from: $JarUrl"
    exit 1
  }
}

function Get-Files([string[]]$targets) {
  $files = @()
  foreach ($t in $targets) {
    if (Test-Path $t -PathType Leaf) {
      $files += (Resolve-Path $t).Path
    } elseif (Test-Path $t -PathType Container) {
      $depth = if ($Recurse) { } else { 1 }
      $found = if ($Recurse) {
        Get-ChildItem -Path $t -Recurse -Include '*.json','*.xml' |
          Where-Object { $_.FullName -notmatch '\\(output|input-cache|fsh-generated)\\' -and $_.Name -ne 'package.json' }
      } else {
        Get-ChildItem -Path $t -Include '*.json','*.xml' |
          Where-Object { $_.Name -ne 'package.json' }
      }
      $files += $found | Select-Object -ExpandProperty FullName
    } else {
      Write-Warn-Line "Not found: $t"
    }
  }
  return $files
}

# ── Entry ─────────────────────────────────────────────────────

Write-Banner

if ($Help) { Show-Usage; exit 0 }

if ($Download) {
  Test-Java
  Get-Jar
  Write-Nl
  Write-Ok-Line "Validator ready at $JarPath"
  Write-Nl
  exit 0
}

if (-not $Target -or $Target.Count -eq 0) {
  Write-Err-Line "No target file or directory specified."
  Show-Usage
  exit 1
}

Test-Java

if (-not (Test-Path $JarPath)) {
  Write-Warn-Line "validator_cli.jar not found - downloading now..."
  Write-Nl
  Get-Jar
  Write-Nl
}

$fhirNum = Get-FhirVersionNum $FhirVersion
$files   = Get-Files $Target

if ($files.Count -eq 0) {
  Write-Err-Line "No FHIR JSON/XML files found in specified target(s)."
  exit 1
}

# Build Java argument list
$javaArgs = @('-jar', $JarPath, '-version', $fhirNum)

foreach ($pkg in $Ig)      { $javaArgs += @('-ig', $pkg) }
foreach ($prof in $Profile) { $javaArgs += @('-profile', $prof) }

if ($NoTx) {
  $javaArgs += @('-tx', 'n/a')
} else {
  $javaArgs += @('-tx', $TxServer)
}

switch ($Output.ToLower()) {
  'json' { $javaArgs += @('-output-style', 'json') }
  'xml'  { $javaArgs += @('-output-style', 'xml')  }
}

$javaArgs += $files

# Run
Write-Nl
Write-Host "  " -NoNewline
Write-Brand "Validating $($files.Count) file(s) against FHIR $fhirNum"
Write-Nl
if ($Ig.Count -gt 0)      { Write-Info-Line "IGs:      $($Ig -join ', ')" }
if ($Profile.Count -gt 0) { Write-Info-Line "Profiles: $($Profile -join ', ')" }
if ($NoTx) { Write-Info-Line "Mode:     offline (terminology disabled)" } else { Write-Info-Line "Tx:       $TxServer" }
Write-Nl
Write-HR
Write-Nl

& java @javaArgs
$exitCode = $LASTEXITCODE

Write-Nl
Write-HR

if ($exitCode -eq 0) {
  Write-Ok-Line "Validation completed. Review output above."
} else {
  Write-Warn-Line "Validation completed with issues (exit $exitCode). Review output above."
}

Write-Nl
Write-Dim "  Learn FHIR validation at torchlab.dev"
Write-Nl
exit $exitCode
