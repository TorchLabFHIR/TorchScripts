#Requires -Version 5.1
# ──────────────────────────────────────────────────────────────
#  Torch  ·  Interactive FHIR IG Scaffold  ·  torchlab.dev
#  Windows PowerShell / PowerShell 7+
# ──────────────────────────────────────────────────────────────

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

# ── Colour helpers ────────────────────────────────────────────
function Write-Brand { param([string]$t) Write-Host $t -ForegroundColor DarkYellow -NoNewline }
function Write-Ok    { param([string]$t) Write-Host $t -ForegroundColor Green    -NoNewline }
function Write-Err   { param([string]$t) Write-Host $t -ForegroundColor Red      -NoNewline }
function Write-Warn  { param([string]$t) Write-Host $t -ForegroundColor Yellow   -NoNewline }
function Write-Hi    { param([string]$t) Write-Host $t -ForegroundColor Cyan     -NoNewline }
function Write-Dim   { param([string]$t) Write-Host $t -ForegroundColor DarkGray -NoNewline }
function Write-Bold  { param([string]$t) Write-Host $t -ForegroundColor White    -NoNewline }
function Write-Nl    { Write-Host "" }

function Write-HR {
  Write-Dim "  ────────────────────────────────────────────────────────"
  Write-Nl
}

function Write-Section([string]$title) {
  Write-Nl
  Write-Brand "  $title"
  Write-Nl
  Write-HR
}

function Write-Header {
  Clear-Host
  Write-Nl
  Write-Brand "  ████████╗ ██████╗ ██████╗  ██████╗██╗  ██╗"
  Write-Nl
  Write-Brand "     ██╔══╝██╔═══██╗██╔══██╗██╔════╝██║  ██║"
  Write-Nl
  Write-Brand "     ██║   ██║   ██║██████╔╝██║     ███████║"
  Write-Nl
  Write-Brand "     ██║   ██║   ██║██╔══██╗██║     ██╔══██║"
  Write-Nl
  Write-Brand "     ██║   ╚██████╔╝██║  ██║╚██████╗██║  ██║"
  Write-Nl
  Write-Brand "     ╚═╝    ╚═════╝ ╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝"
  Write-Nl
  Write-Nl
  Write-Dim   "  Interactive FHIR IG Scaffold  ·  v1.0  ·  torchlab.dev"
  Write-Nl
  Write-Nl
  Write-HR
}

# ── Prompt helpers ────────────────────────────────────────────
function Ask-Value([string]$prompt, [string]$default = '') {
  if ($default) {
    Write-Host "  " -NoNewline
    Write-Hi   "? "
    Write-Bold $prompt
    Write-Dim  " [$default]"
    Write-Host ": " -NoNewline
  } else {
    Write-Host "  " -NoNewline
    Write-Hi   "? "
    Write-Bold "$prompt`: "
  }
  $val = Read-Host
  if ([string]::IsNullOrWhiteSpace($val)) { return $default }
  return $val.Trim()
}

function Ask-Required([string]$prompt) {
  while ($true) {
    Write-Host "  " -NoNewline
    Write-Hi   "? "
    Write-Bold "$prompt`: "
    $val = Read-Host
    if (-not [string]::IsNullOrWhiteSpace($val)) { return $val.Trim() }
    Write-Host "  " -NoNewline
    Write-Err  "This field is required."
    Write-Nl
  }
}

function Ask-Choice([string]$prompt, [string[]]$options) {
  Write-Host "  " -NoNewline
  Write-Hi   "? "
  Write-Bold $prompt
  Write-Nl
  $i = 1
  foreach ($o in $options) {
    Write-Host "    " -NoNewline
    Write-Dim  "$i) "
    Write-Host $o
    $i++
  }
  while ($true) {
    Write-Host "  " -NoNewline
    Write-Hi   "Enter choice [1-$($options.Count)]: "
    $in = Read-Host
    if ($in -match '^\d+$') {
      $idx = [int]$in - 1
      if ($idx -ge 0 -and $idx -lt $options.Count) {
        return $options[$idx] -replace '\s+.*$', ''   # first word only
      }
    }
    Write-Host "  " -NoNewline
    Write-Err  "Please enter a number between 1 and $($options.Count)."
    Write-Nl
  }
}

function Ask-Confirm([string]$prompt, [bool]$default = $true) {
  $hint = if ($default) { "[Y/n]" } else { "[y/N]" }
  Write-Host "  " -NoNewline
  Write-Hi   "? "
  Write-Bold $prompt
  Write-Dim  " $hint"
  Write-Host ": " -NoNewline
  $val = Read-Host
  if ([string]::IsNullOrWhiteSpace($val)) { return $default }
  return $val -match '^[Yy]'
}

function Ask-Names([string]$label, [int]$count) {
  $names = @()
  for ($i = 1; $i -le $count; $i++) {
    $n = Ask-Value "$label $i name (PascalCase)" ""
    if ($n) { $names += $n }
  }
  return $names
}

function To-KebabCase([string]$s) {
  ($s.ToLower() -replace '\s+', '-') -replace '[^a-z0-9\-]', ''
}

function To-DotCase([string]$s) {
  ($s.ToLower() -replace '\s+', '.') -replace '[^a-z0-9\.]', ''
}

function To-PascalNoSpaces([string]$s) {
  $s -replace '[^A-Za-z0-9]', ''
}

# ── Scaffold generators ───────────────────────────────────────

function Write-GitIgnore([string]$dir) {
  @"
# HL7 FHIR IG Publisher
output/
input-cache/
temp/
template/
.fhir/

# SUSHI
fsh-generated/

# OS
.DS_Store
Thumbs.db

# Editor
.vscode/
.idea/
*.swp
"@ | Set-Content (Join-Path $dir '.gitignore') -Encoding UTF8
}

function Get-FhirVersionNum([string]$ver) {
  switch ($ver) {
    'R4'  { '4.0.1' }
    'R4B' { '4.3.0' }
    'R5'  { '5.0.0' }
    default { '4.0.1' }
  }
}

function Write-SushiConfig([string]$dir, [hashtable]$cfg) {
  $fv = Get-FhirVersionNum $cfg.FhirVersion
  $fvLower = $cfg.FhirVersion.ToLower()
  $nameNoSpaces = To-PascalNoSpaces $cfg.IgName
  $year = (Get-Date).Year

  $ghBlock = if ($cfg.GithubUrl) {
    "`ncontact:`n  - name: $($cfg.PubName)`n    telecom:`n      - system: url`n        value: $($cfg.GithubUrl)"
  } else { '' }

  $profMenu  = if ($cfg.ProfileNames.Count -gt 0)  { "`n  Profiles: artifacts.html#structures-resource-profiles" } else { '' }
  $extMenu   = if ($cfg.ExtNames.Count -gt 0)       { "`n  Extensions: artifacts.html#structures-extension-definitions" } else { '' }
  $vsMenu    = if ($cfg.VsNames.Count -gt 0)        { "`n  Terminology: artifacts.html#terminology-value-sets" } else { '' }
  $capMenu   = if ($cfg.HasCapStmt)                 { "`n  Capability Statements: artifacts.html#behavior-capability-statements" } else { '' }

  @"
id: $($cfg.IgId)
canonical: $($cfg.Canonical)
name: $nameNoSpaces
title: "$($cfg.IgTitle)"
description: "$($cfg.Description)"
status: $($cfg.Status)
version: $($cfg.Version)
fhirVersion: $fv
copyrightYear: ${year}+
releaseLabel: ci-build
publisher:
  name: $($cfg.PubName)
  url: $($cfg.PubUrl)
  email: $($cfg.PubEmail)${ghBlock}
dependencies:
  hl7.fhir.${fvLower}.core:
    version: $fv
    uri: http://hl7.org/fhir/$($cfg.FhirVersion)
parameters:
  apply-wg: true
  show-inherited-invariants: false

pages:
  index.md:
    title: Home

menu:
  Home: index.html${profMenu}${extMenu}${vsMenu}${capMenu}
  Artifacts: artifacts.html
"@ | Set-Content (Join-Path $dir 'sushi-config.yaml') -Encoding UTF8
}

function Write-IgIni([string]$dir, [hashtable]$cfg) {
  $ext = if ($cfg.Format -eq 'JSON') { 'json' } else { 'xml' }
  @"
[IG]
ig = input/ImplementationGuide-$($cfg.IgId).${ext}
template = hl7.base.template
"@ | Set-Content (Join-Path $dir 'ig.ini') -Encoding UTF8
}

function Write-IgResourceJson([string]$dir, [hashtable]$cfg) {
  $fv = Get-FhirVersionNum $cfg.FhirVersion
  $idDashes = $cfg.IgId -replace '\.', '-'
  $nameNoSpaces = To-PascalNoSpaces $cfg.IgName

  @"
{
  "resourceType": "ImplementationGuide",
  "id": "$idDashes",
  "url": "$($cfg.Canonical)/ImplementationGuide/$($cfg.IgId)",
  "version": "$($cfg.Version)",
  "name": "$nameNoSpaces",
  "title": "$($cfg.IgTitle)",
  "status": "$($cfg.Status)",
  "description": "$($cfg.Description)",
  "fhirVersion": ["$fv"],
  "packageId": "$($cfg.IgId)",
  "publisher": "$($cfg.PubName)",
  "contact": [
    {
      "name": "$($cfg.PubName)",
      "telecom": [
        { "system": "url", "value": "$($cfg.PubUrl)" },
        { "system": "email", "value": "$($cfg.PubEmail)" }
      ]
    }
  ],
  "definition": {
    "resource": [],
    "page": {
      "nameUrl": "toc.html",
      "title": "Table of Contents",
      "generation": "html",
      "page": [
        { "nameUrl": "index.html", "title": "Home", "generation": "markdown" }
      ]
    }
  }
}
"@ | Set-Content (Join-Path $dir "input\ImplementationGuide-$($cfg.IgId).json") -Encoding UTF8
}

function Write-IgResourceXml([string]$dir, [hashtable]$cfg) {
  $fv = Get-FhirVersionNum $cfg.FhirVersion
  $idDashes = $cfg.IgId -replace '\.', '-'
  $nameNoSpaces = To-PascalNoSpaces $cfg.IgName

  @"
<?xml version="1.0" encoding="UTF-8"?>
<ImplementationGuide xmlns="http://hl7.org/fhir">
  <id value="$idDashes"/>
  <url value="$($cfg.Canonical)/ImplementationGuide/$($cfg.IgId)"/>
  <version value="$($cfg.Version)"/>
  <name value="$nameNoSpaces"/>
  <title value="$($cfg.IgTitle)"/>
  <status value="$($cfg.Status)"/>
  <description value="$($cfg.Description)"/>
  <packageId value="$($cfg.IgId)"/>
  <fhirVersion value="$fv"/>
  <definition>
    <page>
      <nameUrl value="toc.html"/>
      <title value="Table of Contents"/>
      <generation value="html"/>
      <page>
        <nameUrl value="index.html"/>
        <title value="Home"/>
        <generation value="markdown"/>
      </page>
    </page>
  </definition>
</ImplementationGuide>
"@ | Set-Content (Join-Path $dir "input\ImplementationGuide-$($cfg.IgId).xml") -Encoding UTF8
}

function Write-IndexPage([string]$dir, [hashtable]$cfg) {
  $profLine = if ($cfg.ProfileNames.Count -gt 0) { "- Profiles: $($cfg.ProfileNames -join ', ')`n" } else { '' }
  $extLine  = if ($cfg.ExtNames.Count -gt 0)     { "- Extensions: $($cfg.ExtNames -join ', ')`n"  } else { '' }
  $vsLine   = if ($cfg.VsNames.Count -gt 0)      { "- Value Sets: $($cfg.VsNames -join ', ')`n"   } else { '' }

  @"
### Introduction

$($cfg.Description)

### Scope

This implementation guide covers:
${profLine}${extLine}${vsLine}
### Authors

| Role | Name |
|------|------|
| Author | $($cfg.PubName) |

### Contact

$($cfg.PubEmail)
"@ | Set-Content (Join-Path $dir 'input\pagecontent\index.md') -Encoding UTF8
}

function Write-FshProfile([string]$name, [string]$path, [hashtable]$cfg) {
  $id = To-KebabCase $name
  @"
Profile:     $name
Parent:      Patient
Id:          $id
Title:       "$name"
Description: "Profile description for $name."

* name 1..* MS
* name ^short = "Patient name"

// TODO: Add further constraints
"@ | Set-Content $path -Encoding UTF8
}

function Write-FshExtension([string]$name, [string]$path) {
  $id = To-KebabCase $name
  @"
Extension:   $name
Id:          $id
Title:       "$name"
Description: "Extension description for $name."
Context:     Patient

* value[x] only string
* value[x] ^short = "Extension value"
"@ | Set-Content $path -Encoding UTF8
}

function Write-FshValueSet([string]$name, [string]$path) {
  $id = To-KebabCase $name
  @"
ValueSet:    ${name}VS
Id:          $id-vs
Title:       "$name Value Set"
Description: "Value set for $name."

* include codes from system http://snomed.info/sct
  where concept is-a #404684003
"@ | Set-Content $path -Encoding UTF8
}

function Write-FshCodeSystem([string]$name, [string]$path) {
  $id = To-KebabCase $name
  @"
CodeSystem:  ${name}CS
Id:          $id-cs
Title:       "$name Code System"
Description: "Code system for $name."

* #example "Example Code" "An example code"
"@ | Set-Content $path -Encoding UTF8
}

function Write-FshExample([string]$path) {
  @"
Instance:    PatientExample
InstanceOf:  Patient
Title:       "Example Patient"
Description: "An example patient resource."

* name.family = "Example"
* name.given = "Test"
* gender = #male
* birthDate = "1990-01-01"
"@ | Set-Content $path -Encoding UTF8
}

function Write-FshCapStmt([string]$path) {
  @"
Instance:    CapabilityStatementServer
InstanceOf:  CapabilityStatement
Title:       "Server Capability Statement"
Description: "Describes the capabilities of the server."

* status = #draft
* kind = #requirements
* fhirVersion = #4.0.1
* format = #json
* rest[0].mode = #server
* rest[0].resource[0].type = #Patient
* rest[0].resource[0].interaction[0].code = #read
* rest[0].resource[0].interaction[1].code = #search-type
"@ | Set-Content $path -Encoding UTF8
}

function Write-SdProfileJson([string]$name, [string]$path, [hashtable]$cfg) {
  $id = To-KebabCase $name
  $fv = Get-FhirVersionNum $cfg.FhirVersion
  @"
{
  "resourceType": "StructureDefinition",
  "id": "$id",
  "url": "$($cfg.Canonical)/StructureDefinition/$id",
  "version": "$($cfg.Version)",
  "name": "$name",
  "title": "$name",
  "status": "$($cfg.Status)",
  "kind": "resource",
  "abstract": false,
  "type": "Patient",
  "baseDefinition": "http://hl7.org/fhir/StructureDefinition/Patient",
  "derivation": "constraint",
  "differential": {
    "element": [
      {
        "id": "Patient.name",
        "path": "Patient.name",
        "min": 1,
        "mustSupport": true
      }
    ]
  }
}
"@ | Set-Content $path -Encoding UTF8
}

function Write-Success([string]$msg) {
  Write-Host "  " -NoNewline
  Write-Ok "✔  "
  Write-Host $msg
}

# ── Main ──────────────────────────────────────────────────────

Write-Header
Write-Host "  " -NoNewline
Write-Dim "This wizard scaffolds a FHIR Implementation Guide project."
Write-Nl
Write-Host "  " -NoNewline
Write-Dim "Answer each question - press Enter to accept [defaults]."
Write-Nl

# ── Step 1: Format ─────────────────────────────────────────
Write-Section "Step 1 of 6  ·  Format"
$Format = Ask-Choice "Authoring format" @(
  "FSH/SUSHI  (recommended - human-readable shorthand)",
  "JSON       (raw FHIR resources)",
  "XML        (raw FHIR resources)"
)

# ── Step 2: FHIR version ───────────────────────────────────
Write-Section "Step 2 of 6  ·  FHIR Version"
$FhirVersion = Ask-Choice "FHIR version" @("R4", "R4B", "R5")

# ── Step 3: IG identity ────────────────────────────────────
Write-Section "Step 3 of 6  ·  IG Identity"
$IgTitle    = Ask-Required "IG title (e.g. 'My Country Patient IG')"
$suggestName = To-PascalNoSpaces $IgTitle
$IgName     = Ask-Value "IG name (no spaces, PascalCase)" $suggestName
$suggestId   = To-DotCase $IgTitle
$IgId       = Ask-Value "Package ID (reverse-domain, e.g. my.country.ig)" $suggestId
$Canonical  = Ask-Required "Canonical URL (e.g. http://example.org/fhir/my-ig)"
$Version    = Ask-Value "Version" "0.1.0"
$Description = Ask-Value "Short description" "A FHIR Implementation Guide."
$Status     = Ask-Choice "Publication status" @("draft", "active", "retired", "unknown")

# ── Step 4: Publisher ──────────────────────────────────────
Write-Section "Step 4 of 6  ·  Publisher Details"
$PubName    = Ask-Required "Publisher / organisation name"
$PubEmail   = Ask-Value "Publisher email" ""
$PubUrl     = Ask-Value "Publisher URL" ""
$GithubUrl  = Ask-Value "GitHub repository URL (for CI/CD)" ""

# ── Step 5: Components ─────────────────────────────────────
Write-Section "Step 5 of 6  ·  IG Components"

$ProfileCount = [int](Ask-Value "Number of Profiles" "0")
$ProfileNames = if ($ProfileCount -gt 0) { Ask-Names "Profile" $ProfileCount } else { @() }

$ExtCount   = [int](Ask-Value "Number of Extensions" "0")
$ExtNames   = if ($ExtCount -gt 0)     { Ask-Names "Extension" $ExtCount }   else { @() }

$VsCount    = [int](Ask-Value "Number of Value Sets" "0")
$VsNames    = if ($VsCount -gt 0)      { Ask-Names "ValueSet"  $VsCount }    else { @() }

$CsCount    = [int](Ask-Value "Number of Code Systems" "0")
$CsNames    = if ($CsCount -gt 0)      { Ask-Names "CodeSystem" $CsCount }   else { @() }

$HasExamples = Ask-Confirm "Include example resources?" $true
$HasCapStmt  = Ask-Confirm "Include a Capability Statement?" $false

# ── Step 6: Output directory ───────────────────────────────
Write-Section "Step 6 of 6  ·  Output"
$suggestDir = ".\$(To-KebabCase $IgTitle)"
$IgDir      = Ask-Value "Output directory" $suggestDir

# ── Confirm ────────────────────────────────────────────────
Write-Nl
Write-Nl
Write-Host "  " -NoNewline; Write-Brand "Ready to scaffold:"
Write-Nl
Write-HR
Write-Dim "  Directory:   "; Write-Host $IgDir; Write-Dim "  Format:      "; Write-Host $Format
Write-Nl; Write-Dim "  FHIR:        "; Write-Host $FhirVersion
Write-Nl; Write-Dim "  ID:          "; Write-Host $IgId
Write-Nl; Write-Dim "  Canonical:   "; Write-Host $Canonical
Write-Nl; Write-Dim "  Version:     "; Write-Host $Version
Write-Nl; Write-Dim "  Publisher:   "; Write-Host $PubName
if ($ProfileNames.Count -gt 0) { Write-Nl; Write-Dim "  Profiles:    "; Write-Host ($ProfileNames -join ', ') }
if ($ExtNames.Count -gt 0)     { Write-Nl; Write-Dim "  Extensions:  "; Write-Host ($ExtNames -join ', ') }
if ($VsNames.Count -gt 0)      { Write-Nl; Write-Dim "  ValueSets:   "; Write-Host ($VsNames -join ', ') }
if ($CsNames.Count -gt 0)      { Write-Nl; Write-Dim "  CodeSystems: "; Write-Host ($CsNames -join ', ') }
Write-Nl
Write-HR

if (-not (Ask-Confirm "Generate scaffold?" $true)) {
  Write-Warn "  Cancelled."
  Write-Nl
  exit 0
}

# Build config hashtable passed to generators
$cfg = @{
  Format       = $Format
  FhirVersion  = $FhirVersion
  IgTitle      = $IgTitle
  IgName       = $IgName
  IgId         = $IgId
  Canonical    = $Canonical
  Version      = $Version
  Description  = $Description
  Status       = $Status
  PubName      = $PubName
  PubEmail     = $PubEmail
  PubUrl       = $PubUrl
  GithubUrl    = $GithubUrl
  ProfileNames = $ProfileNames
  ExtNames     = $ExtNames
  VsNames      = $VsNames
  CsNames      = $CsNames
  HasExamples  = $HasExamples
  HasCapStmt   = $HasCapStmt
}

Write-Nl
Write-Brand "  Generating..."
Write-Nl
Write-Nl

# Create directory structure
New-Item -ItemType Directory -Force -Path "$IgDir\input\pagecontent" | Out-Null
New-Item -ItemType Directory -Force -Path "$IgDir\input\images"      | Out-Null

switch ($Format) {
  'FSH' {
    New-Item -ItemType Directory -Force -Path "$IgDir\input\fsh\profiles"    | Out-Null
    New-Item -ItemType Directory -Force -Path "$IgDir\input\fsh\extensions"  | Out-Null
    New-Item -ItemType Directory -Force -Path "$IgDir\input\fsh\vocabulary"  | Out-Null
    New-Item -ItemType Directory -Force -Path "$IgDir\input\fsh\examples"    | Out-Null
  }
  default {
    New-Item -ItemType Directory -Force -Path "$IgDir\input\resources" | Out-Null
    New-Item -ItemType Directory -Force -Path "$IgDir\input\examples"  | Out-Null
  }
}

Write-GitIgnore $IgDir
Write-Success ".gitignore"

switch ($Format) {
  'FSH'  { Write-SushiConfig $IgDir $cfg; Write-Success "sushi-config.yaml" }
  'JSON' { Write-IgIni $IgDir $cfg; Write-Success "ig.ini"; Write-IgResourceJson $IgDir $cfg; Write-Success "input\ImplementationGuide-$IgId.json" }
  'XML'  { Write-IgIni $IgDir $cfg; Write-Success "ig.ini"; Write-IgResourceXml  $IgDir $cfg; Write-Success "input\ImplementationGuide-$IgId.xml" }
}

Write-IndexPage $IgDir $cfg
Write-Success "input\pagecontent\index.md"

foreach ($name in $ProfileNames) {
  switch ($Format) {
    'FSH'  { Write-FshProfile $name "$IgDir\input\fsh\profiles\$name.fsh" $cfg }
    'JSON' { Write-SdProfileJson $name "$IgDir\input\resources\StructureDefinition-$(To-KebabCase $name).json" $cfg }
    'XML'  { Write-SdProfileJson $name "$IgDir\input\resources\StructureDefinition-$(To-KebabCase $name).json" $cfg }
  }
  Write-Success "Profile: $name"
}

foreach ($name in $ExtNames) {
  if ($Format -eq 'FSH') {
    Write-FshExtension $name "$IgDir\input\fsh\extensions\$name.fsh"
    Write-Success "Extension: $name"
  }
}

foreach ($name in $VsNames) {
  if ($Format -eq 'FSH') {
    Write-FshValueSet $name "$IgDir\input\fsh\vocabulary\${name}VS.fsh"
    Write-Success "ValueSet: $name"
  }
}

foreach ($name in $CsNames) {
  if ($Format -eq 'FSH') {
    Write-FshCodeSystem $name "$IgDir\input\fsh\vocabulary\${name}CS.fsh"
    Write-Success "CodeSystem: $name"
  }
}

if ($HasExamples) {
  if ($Format -eq 'FSH') {
    Write-FshExample "$IgDir\input\fsh\examples\PatientExample.fsh"
    Write-Success "Example: PatientExample.fsh"
  } else {
    @'
{
  "resourceType": "Patient",
  "id": "example",
  "name": [{ "family": "Example", "given": ["Test"] }],
  "gender": "male",
  "birthDate": "1990-01-01"
}
'@ | Set-Content "$IgDir\input\examples\Patient-example.json" -Encoding UTF8
    Write-Success "Example: Patient-example.json"
  }
}

if ($HasCapStmt -and $Format -eq 'FSH') {
  Write-FshCapStmt "$IgDir\input\fsh\examples\CapabilityStatement-server.fsh"
  Write-Success "CapabilityStatement: server"
}

# ── VS Code tasks + JetBrains configs ─────────────────────────
New-Item -ItemType Directory -Force "$IgDir\.vscode"           | Out-Null
New-Item -ItemType Directory -Force "$IgDir\.idea\runConfigurations" | Out-Null

@'
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "FHIR: Build IG",
      "type": "shell",
      "command": "./_genonce.sh",
      "windows": { "command": ".\\_genonce.bat" },
      "group": { "kind": "build", "isDefault": true },
      "presentation": { "reveal": "always", "panel": "shared", "clear": true },
      "problemMatcher": []
    },
    {
      "label": "FHIR: Watch mode",
      "type": "shell",
      "command": "./_gencontinuous.sh",
      "windows": { "command": ".\\_gencontinuous.bat" },
      "group": "build",
      "isBackground": true,
      "presentation": { "reveal": "always", "panel": "dedicated", "clear": true },
      "problemMatcher": []
    },
    {
      "label": "FHIR: Run SUSHI",
      "type": "shell",
      "command": "sushi .",
      "group": "build",
      "presentation": { "reveal": "always", "panel": "shared", "clear": true },
      "problemMatcher": []
    },
    {
      "label": "FHIR: SUSHI + Build",
      "type": "shell",
      "command": "sushi . && ./_genonce.sh",
      "windows": { "command": "sushi . && .\\_genonce.bat" },
      "group": "build",
      "presentation": { "reveal": "always", "panel": "shared", "clear": true },
      "problemMatcher": []
    },
    {
      "label": "FHIR: Update Publisher",
      "type": "shell",
      "command": "./_updatePublisher.sh",
      "windows": { "command": ".\\_updatePublisher.bat" },
      "group": "none",
      "presentation": { "reveal": "always", "panel": "shared" },
      "problemMatcher": []
    },
    {
      "label": "FHIR: Validate current file",
      "type": "shell",
      "command": "fv '${file}'",
      "group": "test",
      "presentation": { "reveal": "always", "panel": "shared" },
      "problemMatcher": []
    },
    {
      "label": "FHIR: Open output in browser",
      "type": "shell",
      "command": "open output/index.html",
      "linux": { "command": "xdg-open output/index.html" },
      "windows": { "command": "Start-Process output\\index.html" },
      "group": "none",
      "presentation": { "reveal": "silent", "panel": "shared" },
      "problemMatcher": []
    }
  ]
}
'@ | Set-Content "$IgDir\.vscode\tasks.json" -Encoding UTF8
Write-Success ".vscode\tasks.json"

# JetBrains run configs
$jbConfigs = @{
  'FHIR_Build_IG'        = @{ Name = 'FHIR: Build IG';        Script = '_genonce.sh' }
  'FHIR_Watch_Mode'      = @{ Name = 'FHIR: Watch Mode';       Script = '_gencontinuous.sh' }
  'FHIR_Update_Publisher'= @{ Name = 'FHIR: Update Publisher'; Script = '_updatePublisher.sh' }
}
foreach ($key in $jbConfigs.Keys) {
  $cfg = $jbConfigs[$key]
@"
<component name="ProjectRunConfigurationManager">
  <configuration default="false" name="$($cfg.Name)" type="ShConfigurationType" singleton="true">
    <option name="SCRIPT_PATH" value="`$PROJECT_DIR`$/$($cfg.Script)" />
    <option name="SCRIPT_WORKING_DIRECTORY" value="`$PROJECT_DIR`$" />
    <option name="INTERPRETER_PATH" value="/bin/bash" />
    <option name="EXECUTE_IN_TERMINAL" value="true" />
    <option name="RUN_WITH_PTY" value="true" />
    <method v="2" />
  </configuration>
</component>
"@ | Set-Content "$IgDir\.idea\runConfigurations\$key.xml" -Encoding UTF8
}
Write-Success ".idea\runConfigurations\ (JetBrains)"

# ── Publisher scripts ──────────────────────────────────────────
Write-Nl
Write-Hi "  Generating publisher scripts (shared cache at `$env:USERPROFILE\.torch\)..."
Write-Nl

$PubUrl   = 'https://github.com/HL7/fhir-ig-publisher/releases/latest/download/publisher.jar'
$TorchVar = '%USERPROFILE%\.torch'

# _genonce.bat
@"
@ECHO OFF
REM _genonce.bat -- generated by Torch . torchlab.dev
REM Enhanced with shared publisher.jar via %USERPROFILE%\.torch\
REM Note: the publisher automatically shares its terminology cache at %USERPROFILE%\fhircache

SET TORCH_DIR=%USERPROFILE%\.torch
SET JAVA_TOOL_OPTIONS=-Dfile.encoding=UTF-8

ECHO Checking internet connection...
powershell -Command "try{`$r=[System.Net.WebRequest]::Create('https://tx.fhir.org/r4/metadata');`$r.Timeout=4000;`$r.GetResponse().Close();exit 0}catch{exit 1}"
IF %ERRORLEVEL% EQU 0 (SET TX_OPT=) ELSE (
  ECHO Offline - terminology validation disabled
  SET TX_OPT=-tx n/a
)

IF EXIST "%TORCH_DIR%\publisher.jar" (
  SET JAR=%TORCH_DIR%\publisher.jar
) ELSE IF EXIST "%CD%\input-cache\publisher.jar" (
  SET JAR=%CD%\input-cache\publisher.jar
) ELSE IF EXIST "..\publisher.jar" (
  SET JAR=..\publisher.jar
) ELSE (
  ECHO publisher.jar not found. Run _updatePublisher.bat first.
  PAUSE & EXIT /B 1
)

ECHO Publisher : %JAR%
JAVA -jar "%JAR%" -ig . %TX_OPT% %*
PAUSE
"@ | Set-Content "$IgDir\_genonce.bat" -Encoding UTF8
Write-Success "_genonce.bat"

# _gencontinuous.bat
@"
@ECHO OFF
REM _gencontinuous.bat -- generated by Torch . torchlab.dev
CALL _genonce.bat -watch %*
"@ | Set-Content "$IgDir\_gencontinuous.bat" -Encoding UTF8
Write-Success "_gencontinuous.bat"

# _updatePublisher.bat
@"
@ECHO OFF
REM _updatePublisher.bat -- generated by Torch . torchlab.dev
REM Downloads publisher.jar to %USERPROFILE%\.torch\ (shared across all IGs).
REM A copy is placed in .\input-cache\ for compatibility with standard tooling.

SET TORCH_DIR=%USERPROFILE%\.torch
SET SHARED_JAR=%TORCH_DIR%\publisher.jar
SET LOCAL_CACHE=%CD%\input-cache
SET LOCAL_JAR=%LOCAL_CACHE%\publisher.jar
SET DLURL=$PubUrl

ECHO Checking internet connection...
powershell -Command "try{`$r=[System.Net.WebRequest]::Create('https://tx.fhir.org/r4/metadata');`$r.Timeout=4000;`$r.GetResponse().Close();exit 0}catch{exit 1}"
IF %ERRORLEVEL% NEQ 0 (ECHO Offline - cannot update. & PAUSE & EXIT /B 1)

IF NOT EXIST "%TORCH_DIR%"   MKDIR "%TORCH_DIR%"
IF NOT EXIST "%LOCAL_CACHE%" MKDIR "%LOCAL_CACHE%"

ECHO Downloading IG Publisher to shared location (~100 MB)...
powershell -Command "if('System.Net.WebClient' -as [type]){(new-object System.Net.WebClient).DownloadFile('%DLURL%','%SHARED_JAR%')}else{Invoke-WebRequest -Uri '%DLURL%' -Outfile '%SHARED_JAR%'}"

IF EXIST "%SHARED_JAR%" (
  ECHO Saved : %SHARED_JAR%
  COPY /Y "%SHARED_JAR%" "%LOCAL_JAR%" >NUL
  ECHO Copied: %LOCAL_JAR%
) ELSE (ECHO Download failed. & PAUSE & EXIT /B 1)
PAUSE
"@ | Set-Content "$IgDir\_updatePublisher.bat" -Encoding UTF8
Write-Success "_updatePublisher.bat"

# _genonce.sh
@"
#!/usr/bin/env bash
# _genonce.sh -- generated by Torch . torchlab.dev
# Enhanced with shared publisher.jar via ~/.torch/
# Note: the publisher automatically shares its terminology cache at ~/fhircache

TORCH_DIR="`$HOME/.torch"

export JAVA_TOOL_OPTIONS=-Dfile.encoding=UTF-8

echo "Checking internet connection..."
if curl -s --max-time 4 https://tx.fhir.org/r4/metadata -o /dev/null 2>&1; then
  TX_OPT=""
else
  echo "Offline -- terminology validation disabled"
  TX_OPT="-tx n/a"
fi

if   [ -f "`$TORCH_DIR/publisher.jar"  ]; then JAR="`$TORCH_DIR/publisher.jar"
elif [ -f "input-cache/publisher.jar"  ]; then JAR="input-cache/publisher.jar"
elif [ -f "../publisher.jar"           ]; then JAR="../publisher.jar"
else
  echo "publisher.jar not found. Run ./_updatePublisher.sh first."
  exit 1
fi

echo "Publisher : `$JAR"
java -jar "`$JAR" -ig . `$TX_OPT "`$@"
"@ | Set-Content "$IgDir\_genonce.sh" -Encoding UTF8
Write-Success "_genonce.sh"

# _gencontinuous.sh
@"
#!/usr/bin/env bash
# _gencontinuous.sh -- generated by Torch . torchlab.dev
./_genonce.sh -watch "`$@"
"@ | Set-Content "$IgDir\_gencontinuous.sh" -Encoding UTF8
Write-Success "_gencontinuous.sh"

# _updatePublisher.sh
@"
#!/usr/bin/env bash
# _updatePublisher.sh -- generated by Torch . torchlab.dev
# Downloads publisher.jar to ~/.torch/ (shared across all IGs).
# A copy is placed in ./input-cache/ for compatibility with standard tooling.

TORCH_DIR="`$HOME/.torch"
SHARED_JAR="`$TORCH_DIR/publisher.jar"
LOCAL_CACHE="input-cache"
LOCAL_JAR="`$LOCAL_CACHE/publisher.jar"
DLURL="$PubUrl"

echo "Checking internet connection..."
if ! curl -s --max-time 4 https://tx.fhir.org/r4/metadata -o /dev/null 2>&1; then
  echo "Offline -- cannot update publisher."
  exit 1
fi

mkdir -p "`$TORCH_DIR" "`$LOCAL_CACHE"

echo "Downloading IG Publisher to shared location (~100 MB)..."
if curl -L --progress-bar "`$DLURL" -o "`$SHARED_JAR"; then
  echo "Saved : `$SHARED_JAR"
  ln -sf "`$SHARED_JAR" "`$LOCAL_JAR" 2>/dev/null || cp "`$SHARED_JAR" "`$LOCAL_JAR"
  echo "Linked: `$LOCAL_JAR"
else
  echo "Download failed."
  exit 1
fi
"@ | Set-Content "$IgDir\_updatePublisher.sh" -Encoding UTF8
Write-Success "_updatePublisher.sh"

Write-Nl
Write-HR
Write-Ok "  Scaffold complete!"
Write-Nl
Write-Nl
Write-Dim "  Location:  "; Write-Host $IgDir
Write-Nl
Write-Nl
Write-Brand "  Next steps:"
Write-Nl
if ($Format -eq 'FSH') {
  Write-Dim "  1.  cd $IgDir"; Write-Nl
  Write-Dim "  2.  .\_updatePublisher.bat        "; Write-Dim "# downloads to ~\.torch\ (shared)"; Write-Nl
  Write-Dim "  3.  sushi . && .\_genonce.bat"; Write-Nl
} else {
  Write-Dim "  1.  cd $IgDir"; Write-Nl
  Write-Dim "  2.  .\_updatePublisher.bat        "; Write-Dim "# downloads to ~\.torch\ (shared)"; Write-Nl
  Write-Dim "  3.  .\_genonce.bat"; Write-Nl
}
Write-Nl
Write-Dim "  Use _gencontinuous.bat to watch for changes during authoring."
Write-Nl
Write-Dim "  publisher.jar is shared across all your IGs via %USERPROFILE%\.torch\"
Write-Nl
Write-Dim "  Terminology cache is shared automatically by the publisher at %USERPROFILE%\fhircache\"
Write-Nl
Write-Nl
Write-Dim "  Learn more at torchlab.dev"
Write-Nl
