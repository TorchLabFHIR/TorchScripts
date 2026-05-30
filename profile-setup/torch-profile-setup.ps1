#Requires -Version 5.1
# ──────────────────────────────────────────────────────────────
#  Torch  ·  PowerShell Profile Setup  ·  torchlab.dev
#  Windows PowerShell / PowerShell 7+
#
#  Installs Torch scripts to %USERPROFILE%\.torch\scripts\ and
#  adds functions to your $PROFILE so they work in every terminal.
#  Run once from the root of the cloned torch-scripts repo.
# ──────────────────────────────────────────────────────────────

$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'

# ── Colour helpers ────────────────────────────────────────────
function Write-Brand { param([string]$t) Write-Host $t -ForegroundColor DarkYellow -NoNewline }
function Write-Ok    { param([string]$t) Write-Host $t -ForegroundColor Green    -NoNewline }
function Write-Fail  { param([string]$t) Write-Host $t -ForegroundColor Red      -NoNewline }
function Write-Warn  { param([string]$t) Write-Host $t -ForegroundColor Yellow   -NoNewline }
function Write-Hi    { param([string]$t) Write-Host $t -ForegroundColor Cyan     -NoNewline }
function Write-Dim   { param([string]$t) Write-Host $t -ForegroundColor DarkGray -NoNewline }
function Write-Nl    { Write-Host "" }
function Write-HR    { Write-Dim "  ────────────────────────────────────────────────────────"; Write-Nl }

function Write-Section([string]$title) {
  Write-Nl; Write-Brand "  $title"; Write-Nl; Write-HR
}
function Write-Ok-Line([string]$msg)   { Write-Host "  " -NoNewline; Write-Ok "✔  "; Write-Host $msg }
function Write-Info-Line([string]$msg) { Write-Host "  " -NoNewline; Write-Hi "→  "; Write-Dim $msg; Write-Nl }
function Write-Warn-Line([string]$msg) { Write-Host "  " -NoNewline; Write-Warn "⚠  "; Write-Host $msg -ForegroundColor Yellow }

$TorchDir   = "$env:USERPROFILE\.torch"
$ScriptsDir = "$TorchDir\scripts"
$PS1File    = "$TorchDir\torch.ps1"
$Marker     = "# Torch FHIR Developer Tools — torchlab.dev"
$RepoRoot   = Split-Path $PSScriptRoot -Parent

function Write-Header {
  Clear-Host
  Write-Nl
  Write-Brand "  ████████╗ ██████╗ ██████╗  ██████╗██╗  ██╗"; Write-Nl
  Write-Brand "     ██╔══╝██╔═══██╗██╔══██╗██╔════╝██║  ██║"; Write-Nl
  Write-Brand "     ██║   ██║   ██║██████╔╝██║     ███████║"; Write-Nl
  Write-Brand "     ██║   ██║   ██║██╔══██╗██║     ██╔══██║"; Write-Nl
  Write-Brand "     ██║   ╚██████╔╝██║  ██║╚██████╗██║  ██║"; Write-Nl
  Write-Brand "     ╚═╝    ╚═════╝ ╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝"; Write-Nl
  Write-Nl
  Write-Dim "  PowerShell Profile Setup  ·  v1.0  ·  torchlab.dev"; Write-Nl
  Write-Nl; Write-HR
}

# ── Install scripts ───────────────────────────────────────────
function Install-Scripts {
  Write-Section "Installing scripts to $ScriptsDir"
  New-Item -ItemType Directory -Force $ScriptsDir | Out-Null

  $files = @(
    'env-check\torch-env-check.ps1',
    'ig-scaffold\torch-ig-scaffold.ps1',
    'validator\torch-validate.ps1'
  )
  foreach ($rel in $files) {
    $src = Join-Path $RepoRoot $rel
    $dst = Join-Path $ScriptsDir (Split-Path $rel -Leaf)
    if (Test-Path $src) {
      Copy-Item $src $dst -Force
      Write-Ok-Line (Split-Path $rel -Leaf)
    } else {
      Write-Warn-Line "Not found: $src (skipped)"
    }
  }
}

# ── Write ~/.torch/torch.ps1 ──────────────────────────────────
function Write-PS1File {
  Write-Section "Writing function definitions to $PS1File"
  New-Item -ItemType Directory -Force $TorchDir | Out-Null

  @"
$Marker

`$TorchScripts = "`$env:USERPROFILE\.torch\scripts"
`$TorchDir     = "`$env:USERPROFILE\.torch"

# ── Torch tool functions ──────────────────────────────────────
function torch-check    { & "`$TorchScripts\torch-env-check.ps1"    @args }
function torch-scaffold { & "`$TorchScripts\torch-ig-scaffold.ps1"  @args }
function fhir-validate  { & "`$TorchScripts\torch-validate.ps1"     @args }
function fv             { & "`$TorchScripts\torch-validate.ps1"     @args }

# ── IG workflow (run from within an IG project directory) ─────
function ig-run    { & ".\\_genonce.bat"       @args }
function ig-watch  { & ".\\_gencontinuous.bat" @args }
function ig-update { & ".\\_updatePublisher.bat" }
function ig-sushi  { sushi . }
function ig-build  { sushi .; & ".\\_genonce.bat" }

# Run publisher directly from anywhere
function fhir-pub  { java -jar "`$TorchDir\publisher.jar" -ig . @args }

# Open IG output in default browser
function ig-open {
  param([string]`$Path = "output\index.html")
  if (Test-Path `$Path) { Start-Process `$Path }
  else { Write-Host "IG output not found at `$Path - run ig-run first" -ForegroundColor Yellow }
}

# Update shared publisher.jar
function torch-update-publisher {
  `$url = "https://github.com/HL7/fhir-ig-publisher/releases/latest/download/publisher.jar"
  `$jar = "`$TorchDir\publisher.jar"
  Write-Host "Downloading latest HL7 IG Publisher..." -ForegroundColor Cyan
  New-Item -ItemType Directory -Force `$TorchDir | Out-Null
  Invoke-WebRequest -Uri `$url -OutFile `$jar -UseBasicParsing
  Write-Host "Saved to `$jar" -ForegroundColor Green
}

# Pull latest Torch scripts from GitHub
function torch-update {
  `$repo = "https://github.com/torchlab-dev/fhir-scripts"
  `$tmp  = Join-Path `$env:TEMP "torch-update-`$([System.IO.Path]::GetRandomFileName())"
  Write-Host "Fetching latest Torch scripts..." -ForegroundColor Cyan
  try {
    git clone --depth 1 `$repo `$tmp 2>`$null
    & "`$tmp\profile-setup\torch-profile-setup.ps1" -UpdateOnly
    Remove-Item `$tmp -Recurse -Force -ErrorAction SilentlyContinue
  } catch {
    Write-Host "Could not reach `$repo - check connection" -ForegroundColor Yellow
    Remove-Item `$tmp -Recurse -Force -ErrorAction SilentlyContinue
  }
}

# Create a starter FHIR resource file and open it
function fhir-new {
  param([string]`$ResourceType = "Patient", [string]`$FileName = "")
  if (-not `$FileName) { `$FileName = "`$ResourceType-example.json" }
  @"
{
  "resourceType": "`$ResourceType",
  "id": "example",
  "meta": { "profile": [] }
}
"@ | Set-Content `$FileName -Encoding UTF8
  Write-Host "Created `$FileName" -ForegroundColor Green
  if (Get-Command code -ErrorAction SilentlyContinue) { code `$FileName }
  else { Start-Process notepad `$FileName }
}

Write-Host ""
"@ | Set-Content $PS1File -Encoding UTF8

  Write-Ok-Line "torch.ps1 written"
}

# ── Add dot-source line to $PROFILE ───────────────────────────
function Add-ToProfile {
  Write-Section "PowerShell profile setup"
  Write-Info-Line "Profile file: $PROFILE"
  Write-Nl

  # Check if already installed
  $alreadyInstalled = $false
  if (Test-Path $PROFILE) {
    $content = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
    if ($content -and $content.Contains($Marker)) { $alreadyInstalled = $true }
  }

  if ($alreadyInstalled) {
    Write-Ok-Line "Torch functions already in `$PROFILE — skipping"
    return
  }

  $sourceBlock = @"

$Marker
if (Test-Path "`$env:USERPROFILE\.torch\torch.ps1") {
  . "`$env:USERPROFILE\.torch\torch.ps1"
}
"@

  Write-Host "  " -NoNewline
  Write-Hi   "Add Torch functions to your PowerShell profile? "
  Write-Dim  "[Y/n]: "
  $ans = Read-Host

  if ($ans -notmatch '^[Nn]') {
    # Ensure profile directory exists
    $profileDir = Split-Path $PROFILE
    if (-not (Test-Path $profileDir)) {
      New-Item -ItemType Directory -Force $profileDir | Out-Null
    }
    if (-not (Test-Path $PROFILE)) {
      New-Item -ItemType File -Force $PROFILE | Out-Null
    }
    Add-Content $PROFILE $sourceBlock -Encoding UTF8
    Write-Ok-Line "Added to $PROFILE"
    Write-Nl
    Write-Info-Line "Reload now:  . `$PROFILE    (or open a new terminal)"
  } else {
    Write-Warn-Line "Skipped. To add manually, append to $PROFILE`:"
    Write-Nl
    Write-Dim "  $Marker"; Write-Nl
    Write-Dim '  if (Test-Path "$env:USERPROFILE\.torch\torch.ps1") {'; Write-Nl
    Write-Dim '    . "$env:USERPROFILE\.torch\torch.ps1"'; Write-Nl
    Write-Dim "  }"; Write-Nl
    Write-Nl
  }
}

# ── VS Code extensions ────────────────────────────────────────
function Setup-VSCode {
  Write-Section "VS Code integration"

  if (-not (Get-Command code -ErrorAction SilentlyContinue)) {
    Write-Info-Line "VS Code CLI (code) not found — skipping"
    Write-Info-Line "Enable it: VS Code -> Cmd+Shift+P -> 'Shell Command: Install code command'"
    return
  }

  Write-Host "  " -NoNewline
  Write-Hi   "Install recommended FHIR VS Code extensions? "
  Write-Dim  "[Y/n]: "
  $ans = Read-Host

  if ($ans -notmatch '^[Nn]') {
    $extensions = @(
      'Yannick-Lagger.vscode-fhir-tools',
      'kmahalingam.vscode-language-fsh',
      'redhat.vscode-xml',
      'redhat.vscode-yaml',
      'humao.rest-client'
    )
    foreach ($ext in $extensions) {
      Write-Host "  Installing $ext..." -NoNewline
      code --install-extension $ext --force 2>$null
      if ($LASTEXITCODE -eq 0) { Write-Ok "  ok"; Write-Nl }
      else                     { Write-Warn "  failed"; Write-Nl }
    }
  }
}

# ── Execution policy check ────────────────────────────────────
function Check-ExecutionPolicy {
  $policy = Get-ExecutionPolicy -Scope CurrentUser
  if ($policy -eq 'Restricted' -or $policy -eq 'AllSigned') {
    Write-Section "Execution Policy"
    Write-Warn-Line "Current policy '$policy' may block Torch scripts."
    Write-Nl
    Write-Info-Line "Fix with:  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser"
    Write-Nl
    Write-Host "  " -NoNewline
    Write-Hi   "Set RemoteSigned now? "
    Write-Dim  "[Y/n]: "
    $ans = Read-Host
    if ($ans -notmatch '^[Nn]') {
      Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
      Write-Ok-Line "Execution policy set to RemoteSigned (current user)"
    }
  }
}

# ── Summary ───────────────────────────────────────────────────
function Write-FinalSummary {
  Write-Section "Done"
  Write-Ok "  Torch is ready."; Write-Host "  Open a new terminal or run:"; Write-Nl
  Write-Nl
  Write-Dim "  . `$PROFILE"; Write-Nl
  Write-Nl
  Write-Brand "  Available commands:"; Write-Nl
  Write-Nl
  $cmds = @(
    @("torch-check",             "Check your FHIR dev environment"),
    @("torch-scaffold",          "Create a new FHIR IG project"),
    @("fhir-validate <file>",    "Validate a FHIR resource  (alias: fv)"),
    @("ig-run",                  "Build IG once (run from IG root)"),
    @("ig-watch",                "Build IG + watch for changes"),
    @("ig-update",               "Update shared publisher.jar"),
    @("ig-sushi",                "Run SUSHI (FSH compile only)"),
    @("ig-build",                "SUSHI + build (FSH projects)"),
    @("ig-open",                 "Open IG output in browser"),
    @("fhir-new <type>",         "Create a starter FHIR resource file"),
    @("torch-update-publisher",  "Download latest publisher.jar"),
    @("torch-update",            "Pull latest Torch scripts from GitHub")
  )
  foreach ($row in $cmds) {
    Write-Dim ("  " + $row[0].PadRight(28))
    Write-Host $row[1] -ForegroundColor DarkGray
  }
  Write-Nl
  Write-Dim "  torchlab.dev  ·  FHIR learning & tooling"; Write-Nl
  Write-Nl
}

# ── Main ──────────────────────────────────────────────────────
param([switch]$UpdateOnly)

# When invoked via 'torch setup' from the npm package, TORCH_NPM_MANAGED=1 is set.
# In that case skip script copying and shell alias setup — npm already provides the commands.
$NpmManaged = ($env:TORCH_NPM_MANAGED -eq '1')

if (-not $UpdateOnly) { Write-Header }

if ($NpmManaged) {
  Write-Section "npm-managed install"
  Write-Ok-Line "@torchlab/fhir is installed via npm"
  Write-Nl
  Write-Info-Line "Skipping script installation and PowerShell function setup."
  Write-Info-Line "Commands (torch, torch-check, fhir-validate, etc.) are already in your PATH."
  Write-Nl
  Setup-VSCode
  Write-Section "Done"
  Write-Ok "  Torch is ready."; Write-Host "  All commands are available via npm."; Write-Nl
  Write-Nl
  Write-Dim "  torch check    torch scaffold    fhir-validate"; Write-Nl
  Write-Dim "  ig-run         ig-watch          torch --help"; Write-Nl
  Write-Nl
  Write-Dim "  torchlab.dev"; Write-Nl
  Write-Nl
} else {
  Check-ExecutionPolicy
  Install-Scripts
  Write-PS1File
  Add-ToProfile
  if (-not $UpdateOnly) { Setup-VSCode }
  Write-FinalSummary
}
