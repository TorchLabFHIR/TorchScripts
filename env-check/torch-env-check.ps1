#Requires -Version 5.1
# ──────────────────────────────────────────────────────────────
#  Torch  ·  FHIR Dev Environment Check  ·  torchlab.dev
#  Windows PowerShell / PowerShell 7+
# ──────────────────────────────────────────────────────────────

$ErrorActionPreference = 'Continue'
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
function Write-HR    { Write-Dim "  ────────────────────────────────────────────────────────"; Write-Nl }

# ── Result store ──────────────────────────────────────────────
$script:Results  = [System.Collections.Generic.List[PSObject]]::new()
$script:Patches  = [System.Collections.Generic.List[PSObject]]::new()
$script:CorpHints = @()

function Add-Result {
  param(
    [string]$Tool,
    [string]$Status,   # pass | warn | fail
    [string]$Version = '',
    [string]$Note    = '',
    [string[]]$Install = @(),
    [string]$Url     = ''
  )
  $script:Results.Add([PSCustomObject]@{
    Tool    = $Tool
    Status  = $Status
    Version = $Version
    Note    = $Note
    Install = $Install
    Url     = $Url
  })
}

# ── Utilities ─────────────────────────────────────────────────
function Test-CommandExists([string]$cmd) {
  return $null -ne (Get-Command $cmd -ErrorAction SilentlyContinue)
}

function Get-CmdVersion([string]$cmd, [string]$flag = '--version') {
  try {
    $out = & $cmd $flag 2>&1 | Out-String
    # Strip trailing dots/spaces from version string
    if ($out -match '(\d+\.\d+[\.\d]*)') { return $Matches[1].TrimEnd('.') }
  } catch {}
  return $null
}

function Compare-Version([string]$current, [string]$minimum) {
  try {
    $c = [System.Version]::Parse(($current -replace '[^0-9.]','').TrimEnd('.'))
    $m = [System.Version]::Parse(($minimum  -replace '[^0-9.]','').TrimEnd('.'))
    return $c -ge $m
  } catch { return $false }
}

function Add-SessionPath([string]$dir, [string]$label) {
  if ((Test-Path $dir) -and ($env:Path -notlike "*$dir*")) {
    $env:Path = "$dir;$env:Path"
    $script:Patches.Add([PSCustomObject]@{ Dir = $dir; Label = $label })
    return $true
  }
  return $false
}

# Pull fresh Machine + User PATH from registry after a winget install
function Refresh-EnvPath {
  try {
    $mp = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
    $up = [System.Environment]::GetEnvironmentVariable('Path', 'User')
    $combined = (@($mp, $up) | Where-Object { $_ }) -join ';'
    if ($combined) { $env:Path = $combined }
  } catch {}
}

# Scan a list of glob-capable candidate paths; patch session PATH for the first one found
function Find-AndPatchCandidates([string[]]$candidates, [string]$label) {
  foreach ($pattern in $candidates) {
    $resolved = Resolve-Path $pattern -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($resolved) {
      Add-SessionPath $resolved.Path $label | Out-Null
      return $resolved.Path
    }
  }
  return $null
}

# ── Corporate detection ───────────────────────────────────────
function Detect-Corporate {
  if ($env:HTTP_PROXY -or $env:HTTPS_PROXY) {
    $script:CorpHints += "System proxy: $($env:HTTP_PROXY)$($env:HTTPS_PROXY)"
  }
  try {
    $p = npm config get proxy 2>$null
    if ($p -and $p -ne 'null') { $script:CorpHints += "npm proxy: $p" }
  } catch {}
  try {
    $p = git config --global http.proxy 2>$null
    if ($p) { $script:CorpHints += "Git proxy: $p" }
  } catch {}
  $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  if (-not $isAdmin) { $script:CorpHints += "no-admin" }
}

# ── Tool checks ───────────────────────────────────────────────

function Check-Git {
  if (-not (Test-CommandExists 'git')) {
    Add-Result 'Git' 'fail' '' '' @('winget install Git.Git') 'https://git-scm.com'
    return
  }
  $ver = Get-CmdVersion 'git' '--version'
  if (Compare-Version $ver '2.0.0') {
    Add-Result 'Git' 'pass' $ver
  } else {
    Add-Result 'Git' 'warn' $ver 'update recommended' @('winget upgrade Git.Git')
  }
}

function Check-Java {
  if (-not (Test-CommandExists 'java')) {
    $candidates = @(
      "$env:JAVA_HOME\bin",
      "C:\Program Files\Eclipse Adoptium\jdk-21*\bin",
      "C:\Program Files\Microsoft\jdk-21*\bin",
      "C:\Program Files\Java\jdk-21*\bin",
      "C:\Program Files\Eclipse Adoptium\jdk-17*\bin"
    )
    foreach ($pattern in $candidates) {
      $r = Resolve-Path $pattern -ErrorAction SilentlyContinue | Select-Object -First 1
      if ($r) { Add-SessionPath $r.Path 'Java bin' | Out-Null; break }
    }
  }
  if (-not (Test-CommandExists 'java')) {
    Add-Result 'Java' 'fail' '' 'required for HL7 Publisher + Validator' `
      @('winget install EclipseAdoptium.Temurin.21.JDK') 'https://adoptium.net'
    return
  }
  $raw = (java -version 2>&1 | Out-String)
  $major = 0
  if ($raw -match '"(\d+)\.(\d+)\.') {
    $major = [int]$Matches[1]; if ($major -eq 1) { $major = [int]$Matches[2] }
  } elseif ($raw -match '"(\d+)') { $major = [int]$Matches[1] }
  $ver = if ($major -gt 0) { "Java $major" } else { 'unknown' }
  if ($major -ge 21)     { Add-Result 'Java' 'pass' $ver }
  elseif ($major -ge 17) { Add-Result 'Java' 'warn' $ver 'Java 21 recommended for Publisher 1.6+' @('winget install EclipseAdoptium.Temurin.21.JDK') }
  else                   { Add-Result 'Java' 'fail' $ver 'Java 17+ required' @('winget install EclipseAdoptium.Temurin.21.JDK') 'https://adoptium.net' }
  if (-not $env:JAVA_HOME) {
    $r = ($script:Results | Where-Object Tool -eq 'Java')
    if ($r -and -not $r.Note) { $r.Note = 'set JAVA_HOME for tools that need it' }
  }
}

function Check-Node {
  if (-not (Test-CommandExists 'node')) {
    foreach ($p in @("$env:APPDATA\nvm\current", "C:\Program Files\nodejs")) {
      $r = Resolve-Path $p -ErrorAction SilentlyContinue | Select-Object -First 1
      if ($r) { Add-SessionPath $r.Path 'node' | Out-Null; break }
    }
  }
  if (-not (Test-CommandExists 'node')) {
    Add-Result 'Node.js' 'fail' '' 'required for SUSHI' `
      @('winget install OpenJS.NodeJS.LTS') 'https://nodejs.org'
    return
  }
  $ver = (node --version 2>$null) -replace '^v',''
  if (Compare-Version $ver '18.0.0') { Add-Result 'Node.js' 'pass' "v$ver" }
  else { Add-Result 'Node.js' 'warn' "v$ver" 'v18 LTS minimum' @('winget install OpenJS.NodeJS.LTS') }
}

function Check-Npm {
  if (-not (Test-CommandExists 'npm')) {
    Add-Result 'npm' 'fail' '' 'should ship with Node.js'
    return
  }
  $ver = Get-CmdVersion 'npm'
  if (Compare-Version $ver '9.0.0') { Add-Result 'npm' 'pass' $ver }
  else { Add-Result 'npm' 'warn' $ver 'v9+ recommended' @('npm install -g npm@latest') }
}

function Check-Sushi {
  if (-not (Test-CommandExists 'sushi') -and (Test-CommandExists 'npm')) {
    $prefix = npm config get prefix 2>$null
    if ($prefix) { Add-SessionPath $prefix 'npm global' | Out-Null }
  }
  if (-not (Test-CommandExists 'sushi')) {
    Add-Result 'SUSHI' 'fail' '' 'FSH compiler for FHIR IGs' @('npm install -g fsh-sushi') 'https://fshschool.org'
    return
  }
  $ver = Get-CmdVersion 'sushi'
  if (Compare-Version $ver '3.0.0') { Add-Result 'SUSHI' 'pass' $ver }
  else { Add-Result 'SUSHI' 'warn' $ver 'v3+ recommended' @('npm install -g fsh-sushi@latest') }
}

function Check-Ruby {
  if (-not (Test-CommandExists 'ruby')) {
    foreach ($p in @('C:\Ruby33-x64\bin','C:\Ruby32-x64\bin','C:\Ruby31-x64\bin','C:\Ruby30-x64\bin')) {
      if (Add-SessionPath $p 'RubyInstaller') { break }
    }
  }
  if (-not (Test-CommandExists 'ruby')) {
    Add-Result 'Ruby' 'fail' '' 'required for Jekyll (IG site generation)' `
      @('winget install RubyInstallerTeam.RubyWithDevKit.3.3') 'https://rubyinstaller.org'
    return
  }
  $ver = Get-CmdVersion 'ruby'
  if (Compare-Version $ver '3.0.0') { Add-Result 'Ruby' 'pass' $ver }
  else { Add-Result 'Ruby' 'warn' $ver 'v3+ required' @('winget install RubyInstallerTeam.RubyWithDevKit.3.3') }

  # Gem bin
  try {
    $gemHome = gem environment gemdir 2>$null
    if ($gemHome) { Add-SessionPath "$gemHome\bin" 'gem bin' | Out-Null }
  } catch {}
}

function Check-Bundler {
  if (-not (Test-CommandExists 'bundle')) {
    Add-Result 'Bundler' 'fail' '' 'required by Jekyll' @('gem install bundler')
    return
  }
  $ver = Get-CmdVersion 'bundle'
  if (Compare-Version $ver '2.0.0') { Add-Result 'Bundler' 'pass' $ver }
  else { Add-Result 'Bundler' 'warn' $ver 'v2+ required' @('gem update bundler') }
}

function Check-Jekyll {
  if (-not (Test-CommandExists 'jekyll')) {
    Add-Result 'Jekyll' 'fail' '' 'IG site generation' @('gem install jekyll') 'https://jekyllrb.com'
    return
  }
  $ver = Get-CmdVersion 'jekyll'
  if (Compare-Version $ver '4.0.0') { Add-Result 'Jekyll' 'pass' $ver }
  else { Add-Result 'Jekyll' 'warn' $ver 'v4+ required' @('gem update jekyll') }
}

function Check-Dotnet {
  if (-not (Test-CommandExists 'dotnet')) {
    # Broad candidate scan - winget installs to Program Files, user installs vary
    Find-AndPatchCandidates @(
      "$env:ProgramFiles\dotnet",
      'C:\Program Files\dotnet',
      "$env:LOCALAPPDATA\Microsoft\dotnet",
      "$env:USERPROFILE\.dotnet"
    ) 'dotnet' | Out-Null
  }
  if (-not (Test-CommandExists 'dotnet')) {
    Add-Result '.NET SDK' 'fail' '' 'required for Firely Terminal' `
      @('winget install Microsoft.DotNet.SDK.8') 'https://dotnet.microsoft.com/download'
    return
  }

  # Always patch dotnet tools dir regardless of whether dotnet was already in PATH
  Add-SessionPath "$env:USERPROFILE\.dotnet\tools" '.NET tools' | Out-Null

  # Try --version first; fall back to --list-sdks for tricky installs
  $ver = Get-CmdVersion 'dotnet' '--version'
  if (-not $ver) {
    $sdks = (& dotnet --list-sdks 2>&1 | Out-String)
    if ($sdks -match '(\d+\.\d+[\.\d]*)') { $ver = $Matches[1].TrimEnd('.') }
  }
  if (-not $ver) {
    $info = (& dotnet --info 2>&1 | Out-String)
    if ($info -match 'Version:\s*(\d+\.\d+[\.\d]*)') { $ver = $Matches[1].TrimEnd('.') }
  }

  if (-not $ver) {
    Add-Result '.NET SDK' 'warn' '' 'found in PATH but version unreadable - run: dotnet --version'
    return
  }

  # Distinguish runtime-only from full SDK installs
  $sdkList = (& dotnet --list-sdks 2>&1 | Out-String).Trim()
  $hasSdk  = $sdkList -and $sdkList.Length -gt 0

  if (-not $hasSdk) {
    Add-Result '.NET SDK' 'warn' "$ver (runtime only)" `
      'SDK required for dotnet tool installs - install SDK separately' `
      @('winget install Microsoft.DotNet.SDK.8')
    return
  }

  if (Compare-Version $ver '8.0.0') { Add-Result '.NET SDK' 'pass' $ver }
  else { Add-Result '.NET SDK' 'warn' $ver 'v8+ required' @('winget install Microsoft.DotNet.SDK.8') }
}

function Check-Firely {
  if (-not (Test-CommandExists 'fhir')) {
    Add-Result 'Firely Terminal' 'fail' '' 'FHIR package manager + validator' `
      @('dotnet tool install -g Firely.Terminal') 'https://docs.fire.ly/projects/Firely-Terminal'
    return
  }
  $ver = Get-CmdVersion 'fhir'
  Add-Result 'Firely Terminal' 'pass' (if ($ver) { $ver } else { 'installed' })
}

# ── Display ───────────────────────────────────────────────────

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
  Write-Dim "  FHIR Dev Environment Check  ·  v1.0  ·  torchlab.dev"; Write-Nl
  Write-Nl
  Write-HR
  Write-Dim "  Scanning your system..."; Write-Nl
  Write-Nl
}

function Write-ResultsTable {
  # PS5.1-compatible column width calculation (Measure-Object script blocks require PS7)
  $toolW = 0; $verW = 0
  foreach ($r in $script:Results) {
    if ($r.Tool.Length    -gt $toolW) { $toolW = $r.Tool.Length }
    if ($r.Version.Length -gt $verW)  { $verW  = $r.Version.Length }
  }
  $toolW += 2
  $verW   = [Math]::Max($verW + 2, 14)

  Write-HR

  foreach ($r in $script:Results) {
    Write-Host "  " -NoNewline

    switch ($r.Status) {
      'pass' { Write-Ok  "✔ " }
      'warn' { Write-Warn "⚠ " }
      'fail' { Write-Err  "✘ " }
    }

    Write-Bold $r.Tool.PadRight($toolW)

    if ($r.Version) {
      switch ($r.Status) {
        'pass' { Write-Ok   $r.Version.PadRight($verW) }
        'warn' { Write-Warn $r.Version.PadRight($verW) }
        'fail' { Write-Err  $r.Version.PadRight($verW) }
      }
    } else {
      $label = switch ($r.Status) {
        'fail' { 'not installed' }
        'warn' { 'check required' }
        default { '' }
      }
      Write-Dim $label.PadRight($verW)
    }

    if ($r.Note) {
      Write-Dim "  $($r.Note)"
    }

    Write-Nl
  }

  Write-Nl
}

function Write-InstallGuide {
  $failing = $script:Results | Where-Object { $_.Status -eq 'fail' -and $_.Install.Count -gt 0 }
  $warning = $script:Results | Where-Object { $_.Status -eq 'warn' -and $_.Install.Count -gt 0 }

  if (-not $failing -and -not $warning) { return }

  Write-HR
  Write-Bold "  What to install or update:"; Write-Nl
  Write-Nl

  # Group Ruby/Bundler/Jekyll together since they're a chain
  $rubyGroup    = @('Ruby','Bundler','Jekyll')
  $rubyPrinted  = $false

  foreach ($r in (@($failing) + @($warning))) {
    if ($r.Tool -in $rubyGroup) {
      if ($rubyPrinted) { continue }
      $rubyPrinted = $true
      Write-Hi "  Ruby + Bundler + Jekyll"; Write-Dim "  (IG site generation)"; Write-Nl
      Write-Dim "    winget install RubyInstallerTeam.RubyWithDevKit.3.3"; Write-Nl
      Write-Dim "    gem install bundler jekyll"; Write-Nl
    } else {
      Write-Hi "  $($r.Tool)"; if ($r.Note) { Write-Dim "  ($($r.Note))" }; Write-Nl
      foreach ($cmd in $r.Install) {
        Write-Dim "    $cmd"; Write-Nl
      }
    }
    Write-Nl
  }
}

function Write-PathPatches {
  if ($script:Patches.Count -eq 0) { return }

  Write-HR
  Write-Warn "  These tools were found on your system but were not in PATH."; Write-Nl
  Write-Dim  "  They have been added for this session only:"; Write-Nl
  Write-Nl
  foreach ($p in $script:Patches) {
    Write-Ok  "    + "; Write-Bold $p.Dir; Write-Dim "  ($($p.Label))"; Write-Nl
  }
  Write-Nl

  Write-Bold "  How to make PATH permanent:"; Write-Nl
  Write-Nl

  # Option 1 - PowerShell profile
  Write-Hi   "  Option 1 - PowerShell profile (recommended, user-level):"; Write-Nl
  Write-Dim  "  Open your profile:  notepad `$PROFILE"; Write-Nl
  Write-Dim  "  Add these lines:"; Write-Nl
  foreach ($p in $script:Patches) {
    Write-Dim '    $env:Path = "' + $p.Dir + ';$env:Path"'; Write-Nl
  }
  Write-Nl

  # Option 2 - GUI
  Write-Hi   "  Option 2 - Windows Environment Variables (GUI):"; Write-Nl
  Write-Dim  "  1. Press Win+R, type: SystemPropertiesAdvanced, press Enter"; Write-Nl
  Write-Dim  "  2. Click 'Environment Variables'"; Write-Nl
  Write-Dim  "  3. Under 'User variables', select 'Path' and click Edit"; Write-Nl
  Write-Dim  "  4. Add each of these as a new entry:"; Write-Nl
  foreach ($p in $script:Patches) {
    Write-Dim "       $($p.Dir)"; Write-Nl
  }
  Write-Nl

  # Corporate IT block
  $isCorpMachine = $script:CorpHints -contains 'no-admin'
  if ($isCorpMachine) {
    Write-HR
    Write-Hi   "  On a managed machine? Send IT this PATH request:"; Write-Nl
    Write-Nl
    Write-Dim  "  Subject: PATH update request for FHIR development toolchain"; Write-Nl
    Write-Nl
    Write-Dim  "  Please add the following directories to the user PATH for $env:USERNAME`:"; Write-Nl
    foreach ($p in $script:Patches) {
      Write-Dim "    - $($p.Dir)  [$($p.Label)]"; Write-Nl
    }
    Write-Nl
    Write-Dim  "  Reference: https://torchlab.dev/resources"; Write-Nl
  }
}

function Write-Summary {
  # @() wrapping ensures .Count works correctly for 0 or 1 result in PS5.1
  $pass    = @($script:Results | Where-Object { $_.Status -eq 'pass' }).Count
  $warn    = @($script:Results | Where-Object { $_.Status -eq 'warn' }).Count
  $fail    = @($script:Results | Where-Object { $_.Status -eq 'fail' }).Count
  $missing = (@($script:Results | Where-Object { $_.Status -eq 'fail' }) | Select-Object -ExpandProperty Tool) -join ', '

  Write-HR

  if ($fail -eq 0 -and $warn -eq 0) {
    Write-Ok "  All $pass checks passed"; Write-Dim " - your environment is FHIR-ready."; Write-Nl
  } elseif ($fail -eq 0) {
    Write-Warn "  $pass passed  ·  $warn need attention"; Write-Dim "  - review notes above."; Write-Nl
  } else {
    Write-Ok   "  $pass passed  "; Write-Dim "·  "
    Write-Warn "$warn warnings  "; Write-Dim "·  "
    Write-Err  "$fail not installed"; Write-Nl
    if ($missing) {
      Write-Nl
      Write-Dim "  Not installed: "; Write-Err $missing; Write-Nl
    }
  }

  if ($script:CorpHints -contains 'no-admin' -or $script:CorpHints.Count -gt 1) {
    Write-Nl
    Write-HR
    Write-Hi "  On a managed or corporate machine?"; Write-Nl
    Write-Dim "  You may need IT to install the missing tools above."; Write-Nl
    Write-Dim "  Send them this output and reference:  https://torchlab.dev/resources"; Write-Nl
    if ($missing) {
      Write-Nl
      Write-Dim "  Required tools: "; Write-Warn $missing; Write-Nl
    }
  }

  Write-HR
  Write-Dim "  torchlab.dev  ·  FHIR learning & tooling"; Write-Nl
  Write-Nl
}

# ── Auto-install ──────────────────────────────────────────────

function Invoke-AutoInstall {
  $toInstall = @($script:Results | Where-Object { $_.Status -eq 'fail' -and $_.Install.Count -gt 0 })
  if ($toInstall.Count -eq 0) { return }

  Write-HR
  Write-Host "  " -NoNewline
  Write-Hi   "Install missing tools now? "
  Write-Dim  "[Y/n]: "
  $ans = Read-Host
  if ($ans -match '^[Nn]') { Write-Nl; return }
  Write-Nl

  $wingetOk    = Test-CommandExists 'winget'
  $installed   = [System.Collections.Generic.List[string]]::new()
  $needsAdmin  = [System.Collections.Generic.List[string]]::new()
  $skipped     = [System.Collections.Generic.List[string]]::new()

  # Ordered so dependencies install before dependents
  $installOrder = @('Git','Java','Node.js','npm','.NET SDK','Ruby','SUSHI','Bundler','Jekyll','Firely Terminal')

  $sorted = foreach ($name in $installOrder) {
    $toInstall | Where-Object { $_.Tool -eq $name }
  }

  $rubyJekyllDone = $false

  foreach ($r in $sorted) {
    if ($null -eq $r) { continue }

    # Dependency gates
    if ($r.Tool -in @('Bundler','Jekyll')) {
      if ($rubyJekyllDone) { continue }    # handled in the Ruby block below
      if (-not (Test-CommandExists 'ruby')) {
        Write-Dim "  Skipping $($r.Tool) - Ruby must install first"; Write-Nl
        $skipped.Add($r.Tool) | Out-Null; continue
      }
    }
    if ($r.Tool -eq 'SUSHI' -and -not (Test-CommandExists 'node')) {
      Write-Dim "  Skipping SUSHI - Node.js must install first"; Write-Nl
      $skipped.Add('SUSHI') | Out-Null; continue
    }
    if ($r.Tool -eq 'Firely Terminal') {
      if (-not (Test-CommandExists 'dotnet')) {
        Write-Dim "  Skipping Firely Terminal - .NET SDK must install first"; Write-Nl
        $skipped.Add('Firely Terminal') | Out-Null; continue
      }
      # dotnet runtime can be present without the SDK; 'dotnet tool' requires the SDK
      $sdkList = (& dotnet --list-sdks 2>&1 | Out-String).Trim()
      if (-not $sdkList -or $sdkList.Length -eq 0) {
        Write-Warn "  .NET runtime is installed but the SDK is missing."; Write-Nl
        Write-Dim  "  'dotnet tool install' requires the .NET SDK, not just the runtime."; Write-Nl
        Write-Dim  "  Install it first:  winget install Microsoft.DotNet.SDK.8"; Write-Nl
        $needsAdmin.Add('Firely Terminal (.NET SDK required first)') | Out-Null
        Write-Nl; continue
      }
    }

    Write-Host "  " -NoNewline
    Write-Hi   "Installing $($r.Tool)..."; Write-Nl

    $cmdStr = $r.Install[0]
    $parts  = $cmdStr -split '\s+', 2
    $exe    = $parts[0]
    $xArgs  = if ($parts.Count -gt 1) { $parts[1] -split '\s+' } else { @() }

    if ($exe -eq 'winget') {
      if (-not $wingetOk) {
        Write-Warn "  winget not available - see aka.ms/getwinget"; Write-Nl
        $skipped.Add($r.Tool) | Out-Null; Write-Nl; continue
      }
      # --disable-interactivity keeps winget output visible but prevents prompts
      $xArgs += @('--accept-source-agreements', '--accept-package-agreements', '--disable-interactivity')
    }

    # Stream output live so the user sees progress
    Write-Dim "  "; Write-Dim "  "; Write-Nl
    try {
      & $exe @xArgs
      $ok = $LASTEXITCODE -eq 0
    } catch {
      Write-Warn "  Error: $($_.Exception.Message)"; Write-Nl
      $ok = $false
    }
    Write-Nl

    if ($ok) {
      # After winget installs, pull fresh system PATH so newly installed tools are visible
      if ($exe -eq 'winget') { Refresh-EnvPath }

      Write-Ok "  Done: $($r.Tool)"; Write-Nl
      $installed.Add($r.Tool) | Out-Null

      # After Ruby: refresh PATH from common RubyInstaller locations, then chain Bundler + Jekyll
      if ($r.Tool -eq 'Ruby') {
        Refresh-EnvPath
        Find-AndPatchCandidates @(
          'C:\Ruby33-x64\bin','C:\Ruby32-x64\bin','C:\Ruby31-x64\bin','C:\Ruby30-x64\bin'
        ) 'Ruby (fresh install)' | Out-Null

        if (Test-CommandExists 'gem') {
          Write-Nl
          Write-Hi "  Installing Bundler + Jekyll..."; Write-Nl
          gem install bundler jekyll
          if ($LASTEXITCODE -eq 0) {
            Write-Ok "  Done: Bundler + Jekyll"; Write-Nl
            $installed.Add('Bundler') | Out-Null
            $installed.Add('Jekyll')  | Out-Null
            $rubyJekyllDone = $true
          } else {
            Write-Warn "  gem install failed - check Ruby is in PATH and try manually"; Write-Nl
          }
        } else {
          Write-Warn "  gem not found after Ruby install - open a new terminal and run: gem install bundler jekyll"; Write-Nl
        }
      }

      # After .NET: patch dotnet tools dir
      if ($r.Tool -eq '.NET SDK') {
        Refresh-EnvPath
        Find-AndPatchCandidates @("$env:ProgramFiles\dotnet", 'C:\Program Files\dotnet') 'dotnet (fresh install)' | Out-Null
        Add-SessionPath "$env:USERPROFILE\.dotnet\tools" '.NET tools' | Out-Null
      }

    } else {
      if ($exe -eq 'winget') {
        Write-Warn "  Could not install $($r.Tool) - may need Administrator rights"; Write-Nl
        $needsAdmin.Add($r.Tool) | Out-Null
      } else {
        Write-Warn "  Install failed for $($r.Tool) - see output above"; Write-Nl
        $skipped.Add($r.Tool) | Out-Null
      }
    }
    Write-Nl
  }

  # Re-scan if anything changed
  if ($installed.Count -gt 0) {
    Write-HR
    Write-Hi "  Re-checking your environment..."; Write-Nl
    Write-Nl
    $script:Results.Clear()
    $script:Patches.Clear()
    Check-Git; Check-Java; Check-Node; Check-Npm; Check-Sushi
    Check-Ruby; Check-Bundler; Check-Jekyll; Check-Dotnet; Check-Firely
    Write-ResultsTable
  }

  if ($needsAdmin.Count -gt 0) {
    Write-HR
    Write-Warn "  These tools need Administrator rights to install:"; Write-Nl
    foreach ($t in $needsAdmin) { Write-Dim "    - $t"; Write-Nl }
    Write-Nl
    Write-Dim "  Right-click PowerShell > 'Run as Administrator' and re-run this script,"; Write-Nl
    Write-Dim "  or ask your IT team to install them."; Write-Nl
  }
}

# ── Main ──────────────────────────────────────────────────────

Write-Header
Detect-Corporate

Check-Git
Check-Java
Check-Node
Check-Npm
Check-Sushi
Check-Ruby
Check-Bundler
Check-Jekyll
Check-Dotnet
Check-Firely

Write-ResultsTable
Write-InstallGuide
Invoke-AutoInstall
Write-PathPatches
Write-Summary
