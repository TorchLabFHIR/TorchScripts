#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
#  Torch  ·  Interactive FHIR IG Scaffold  ·  torchlab.dev
#  macOS / Linux
# ──────────────────────────────────────────────────────────────

set -euo pipefail

# ── Colours ───────────────────────────────────────────────────
if [ -t 1 ]; then
  O='\033[38;5;214m'  G='\033[0;32m'  R='\033[0;31m'
  Y='\033[1;33m'  C='\033[0;36m'  B='\033[1m'  D='\033[2m'  NC='\033[0m'
else
  O='' G='' R='' Y='' C='' B='' D='' NC=''
fi

# ── Helpers ───────────────────────────────────────────────────
hr()      { echo -e "${D}────────────────────────────────────────────────────────${NC}"; }
section() { echo ""; echo -e "${O}${B}  $1${NC}"; hr; }
info()    { echo -e "  ${C}→${NC}  ${D}$1${NC}"; }
success() { echo -e "  ${G}✔${NC}  $1"; }
err()     { echo -e "  ${R}✘${NC}  $1" >&2; }

header() {
  clear 2>/dev/null || true
  echo ""
  echo -e "${O}${B}"
  echo "  ████████╗ ██████╗ ██████╗  ██████╗██╗  ██╗"
  echo "     ██╔══╝██╔═══██╗██╔══██╗██╔════╝██║  ██║"
  echo "     ██║   ██║   ██║██████╔╝██║     ███████║"
  echo "     ██║   ██║   ██║██╔══██╗██║     ██╔══██║"
  echo "     ██║   ╚██████╔╝██║  ██║╚██████╗██║  ██║"
  echo "     ╚═╝    ╚═════╝ ╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝"
  echo -e "${NC}"
  echo -e "  ${D}Interactive FHIR IG Scaffold  ·  v1.0  ·  torchlab.dev${NC}"
  echo ""
  hr
}

ask() {
  # ask <var_name> <prompt> [default]
  local var="$1" prompt="$2" default="${3:-}"
  local val
  if [ -n "$default" ]; then
    printf "  ${C}?${NC} ${B}${prompt}${NC} ${D}[${default}]${NC}: "
  else
    printf "  ${C}?${NC} ${B}${prompt}${NC}: "
  fi
  IFS= read -r val
  [ -z "$val" ] && val="$default"
  printf -v "$var" '%s' "$val"
}

ask_required() {
  # ask_required <var_name> <prompt>
  local var="$1" prompt="$2" val
  while true; do
    printf "  ${C}?${NC} ${B}${prompt}${NC}: "
    IFS= read -r val
    [ -n "$val" ] && break
    echo -e "  ${R}This field is required.${NC}"
  done
  printf -v "$var" '%s' "$val"
}

choose() {
  # choose <var_name> <prompt> <opt1> <opt2> ...
  local var="$1" prompt="$2"
  shift 2
  local opts=("$@")
  echo -e "  ${C}?${NC} ${B}${prompt}${NC}"
  local i=1
  for o in "${opts[@]}"; do
    echo -e "    ${D}$i)${NC} $o"
    ((i++))
  done
  local choice
  while true; do
    printf "  ${C}Enter choice [1-$((i-1))]:${NC} "
    read -r choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice < i )); then
      printf -v "$var" '%s' "${opts[$((choice-1))]}"
      return
    fi
    echo -e "  ${R}Please enter a number between 1 and $((i-1)).${NC}"
  done
}

confirm() {
  # confirm <prompt> [default: y|n]  → returns 0/1
  local prompt="$1" default="${2:-y}" yn
  local hint="[Y/n]"; [ "$default" = "n" ] && hint="[y/N]"
  printf "  ${C}?${NC} ${B}${prompt}${NC} ${D}${hint}${NC}: "
  read -r yn
  yn="${yn:-$default}"
  [[ "$yn" =~ ^[Yy] ]] && return 0 || return 1
}

ask_names() {
  # ask_names <var_array_name> <label> <count>
  local arr_name="$1" label="$2" count="$3"
  local -n arr_ref=$arr_name
  arr_ref=()
  for ((i=1; i<=count; i++)); do
    local nm
    ask nm "$label $i name (PascalCase)" ""
    [ -n "$nm" ] && arr_ref+=("$nm")
  done
}

to_kebab() { echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/ /-/g' | sed 's/[^a-z0-9-]//g'; }
to_id()    { echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/ /./g'  | sed 's/[^a-z0-9.]//g'; }

# ── Scaffold generators ───────────────────────────────────────

write_gitignore() {
  cat > "$IG_DIR/.gitignore" <<'EOF'
# HL7 FHIR IG Publisher output
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
EOF
}

write_readme() {
  cat > "$IG_DIR/README.md" <<EOF
# ${IG_TITLE}

${IG_DESCRIPTION}

- **Canonical:** ${IG_CANONICAL}
- **FHIR Version:** ${FHIR_VERSION}
- **Status:** ${IG_STATUS}

## Building

$([ "$FORMAT" = "FSH/SUSHI" ] && echo "### Prerequisites
- Node.js 18+ and SUSHI: \`npm install -g fsh-sushi\`
- Java 17+ (for HL7 Publisher)

### Run
\`\`\`bash
sushi .
java -jar input-cache/publisher.jar -ig .
\`\`\`" || echo "### Prerequisites
- Java 17+ (for HL7 Publisher)

### Run
\`\`\`bash
java -jar input-cache/publisher.jar -ig .
\`\`\`")

## Resources

- [Torch FHIR Dev Toolkit](https://torchlab.dev)
- [FHIR R4 Specification](https://hl7.org/fhir/R4)
EOF
}

write_sushi_config() {
  local fhir_ver_num
  case "$FHIR_VERSION" in
    R4)  fhir_ver_num="4.0.1" ;;
    R4B) fhir_ver_num="4.3.0" ;;
    R5)  fhir_ver_num="5.0.0" ;;
  esac

  cat > "$IG_DIR/sushi-config.yaml" <<EOF
id: ${IG_ID}
canonical: ${IG_CANONICAL}
name: $(echo "${IG_NAME}" | sed 's/ //g')
title: "${IG_TITLE}"
description: "${IG_DESCRIPTION}"
status: ${IG_STATUS}
version: ${IG_VERSION}
fhirVersion: ${fhir_ver_num}
copyrightYear: $(date +%Y)+
releaseLabel: ci-build
publisher:
  name: ${PUB_NAME}
  url: ${PUB_URL}
  email: ${PUB_EMAIL}
$([ -n "$GITHUB_URL" ] && echo "
contact:
  - name: ${PUB_NAME}
    telecom:
      - system: url
        value: ${GITHUB_URL}")
dependencies:
  hl7.fhir.$(echo "$FHIR_VERSION" | tr '[:upper:]' '[:lower:]').core:
    version: ${fhir_ver_num}
    uri: http://hl7.org/fhir/$(echo "$FHIR_VERSION" | tr '[:upper:]' '[:lower:]')
parameters:
  apply-wg: true
  show-inherited-invariants: false

pages:
  index.md:
    title: Home

menu:
  Home: index.html
$([ "${#PROFILE_NAMES[@]}" -gt 0 ] && echo "  Profiles: artifacts.html#structures-resource-profiles")
$([ "${#EXT_NAMES[@]}" -gt 0 ] && echo "  Extensions: artifacts.html#structures-extension-definitions")
$([ "${#VS_NAMES[@]}" -gt 0 ] && echo "  Terminology: artifacts.html#terminology-value-sets")
$([ -n "$HAS_CAPSTMT" ] && echo "  Capability Statements: artifacts.html#behavior-capability-statements")
  Artifacts: artifacts.html
EOF
}

write_ig_ini() {
  cat > "$IG_DIR/ig.ini" <<EOF
[IG]
ig = input/ImplementationGuide-${IG_ID}.$(echo "$FORMAT" | tr '[:upper:]' '[:lower:]' | sed 's/fsh\/sushi/json/')
template = hl7.base.template
EOF
}

write_ig_resource_json() {
  local fhir_ver_num
  case "$FHIR_VERSION" in
    R4)  fhir_ver_num="4.0.1" ;;
    R4B) fhir_ver_num="4.3.0" ;;
    R5)  fhir_ver_num="5.0.0" ;;
  esac

  cat > "$IG_DIR/input/ImplementationGuide-${IG_ID}.json" <<EOF
{
  "resourceType": "ImplementationGuide",
  "id": "$(echo "$IG_ID" | sed 's/\./-/g')",
  "url": "${IG_CANONICAL}/ImplementationGuide/${IG_ID}",
  "version": "${IG_VERSION}",
  "name": "$(echo "${IG_NAME}" | sed 's/ //g')",
  "title": "${IG_TITLE}",
  "status": "${IG_STATUS}",
  "description": "${IG_DESCRIPTION}",
  "fhirVersion": ["${fhir_ver_num}"],
  "packageId": "${IG_ID}",
  "publisher": "${PUB_NAME}",
  "contact": [
    {
      "name": "${PUB_NAME}",
      "telecom": [
        { "system": "url", "value": "${PUB_URL}" },
        { "system": "email", "value": "${PUB_EMAIL}" }
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
        {
          "nameUrl": "index.html",
          "title": "Home",
          "generation": "markdown"
        }
      ]
    }
  }
}
EOF
}

write_ig_resource_xml() {
  local fhir_ver_num
  case "$FHIR_VERSION" in
    R4)  fhir_ver_num="4.0.1" ;;
    R4B) fhir_ver_num="4.3.0" ;;
    R5)  fhir_ver_num="5.0.0" ;;
  esac
  local ig_name_no_spaces
  ig_name_no_spaces=$(echo "${IG_NAME}" | sed 's/ //g')

  cat > "$IG_DIR/input/ImplementationGuide-${IG_ID}.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<ImplementationGuide xmlns="http://hl7.org/fhir">
  <id value="$(echo "$IG_ID" | sed 's/\./-/g')"/>
  <url value="${IG_CANONICAL}/ImplementationGuide/${IG_ID}"/>
  <version value="${IG_VERSION}"/>
  <name value="${ig_name_no_spaces}"/>
  <title value="${IG_TITLE}"/>
  <status value="${IG_STATUS}"/>
  <description value="${IG_DESCRIPTION}"/>
  <packageId value="${IG_ID}"/>
  <fhirVersion value="${fhir_ver_num}"/>
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
EOF
}

write_index_page() {
  cat > "$IG_DIR/input/pagecontent/index.md" <<EOF
### Introduction

${IG_DESCRIPTION}

### Scope

This implementation guide covers:
$([ "${#PROFILE_NAMES[@]}" -gt 0 ] && printf '- Profiles for %s\n' "${PROFILE_NAMES[*]}")
$([ "${#EXT_NAMES[@]}" -gt 0 ] && printf '- Extensions: %s\n' "${EXT_NAMES[*]}")
$([ "${#VS_NAMES[@]}" -gt 0 ] && printf '- Value sets: %s\n' "${VS_NAMES[*]}")

### Authors

| Role | Name |
|------|------|
| Author | ${PUB_NAME} |

### Contact

${PUB_EMAIL}
EOF
}

write_fsh_profile() {
  local name="$1" file="$2"
  local id
  id=$(to_kebab "$name")
  cat > "$file" <<EOF
Profile:     ${name}
Parent:      Patient
Id:          ${id}
Title:       "${name}"
Description: "Profile description for ${name}."

* name 1..* MS
* name ^short = "Patient name"

// TODO: Add further constraints
EOF
}

write_fsh_extension() {
  local name="$1" file="$2"
  local id
  id=$(to_kebab "$name")
  cat > "$file" <<EOF
Extension:   ${name}
Id:          ${id}
Title:       "${name}"
Description: "Extension description for ${name}."
Context:     Patient

* value[x] only string
* value[x] ^short = "Extension value"
EOF
}

write_fsh_valueset() {
  local name="$1" file="$2"
  local id
  id=$(to_kebab "$name")
  cat > "$file" <<EOF
ValueSet:    ${name}
Id:          ${id}
Title:       "${name}"
Description: "Value set description for ${name}."

* include codes from system http://snomed.info/sct
  where concept is-a #404684003  // Clinical finding
EOF
}

write_fsh_codesystem() {
  local name="$1" file="$2"
  local id
  id=$(to_kebab "$name")
  cat > "$file" <<EOF
CodeSystem:  ${name}
Id:          ${id}
Title:       "${name}"
Description: "Code system for ${name}."

* #example "Example Code" "An example code"
EOF
}

write_fsh_example() {
  local file="$1"
  cat > "$file" <<EOF
Instance:    PatientExample
InstanceOf:  Patient
Title:       "Example Patient"
Description: "An example patient resource."

* name.family = "Example"
* name.given = "Test"
* gender = #male
* birthDate = "1990-01-01"
EOF
}

write_fsh_capstmt() {
  local file="$1"
  cat > "$file" <<EOF
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
EOF
}

write_sd_profile_json() {
  local name="$1" file="$2"
  local id
  id=$(to_kebab "$name")
  cat > "$file" <<EOF
{
  "resourceType": "StructureDefinition",
  "id": "${id}",
  "url": "${IG_CANONICAL}/StructureDefinition/${id}",
  "version": "${IG_VERSION}",
  "name": "${name}",
  "title": "${name}",
  "status": "${IG_STATUS}",
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
EOF
}

write_sd_profile_xml() {
  local name="$1" file="$2"
  local id
  id=$(to_kebab "$name")
  cat > "$file" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<StructureDefinition xmlns="http://hl7.org/fhir">
  <id value="${id}"/>
  <url value="${IG_CANONICAL}/StructureDefinition/${id}"/>
  <version value="${IG_VERSION}"/>
  <name value="${name}"/>
  <title value="${name}"/>
  <status value="${IG_STATUS}"/>
  <kind value="resource"/>
  <abstract value="false"/>
  <type value="Patient"/>
  <baseDefinition value="http://hl7.org/fhir/StructureDefinition/Patient"/>
  <derivation value="constraint"/>
  <differential>
    <element id="Patient.name">
      <path value="Patient.name"/>
      <min value="1"/>
      <mustSupport value="true"/>
    </element>
  </differential>
</StructureDefinition>
EOF
}

# ── Publisher scripts generator ───────────────────────────────
# Generates enhanced _genonce / _gencontinuous / _updatePublisher scripts
# that use ~/.torch/ as a shared publisher + tx cache location, with
# fallback to ./input-cache/ so standard HL7 tooling still works.

write_publisher_scripts() {
  local TORCH="~/.torch"
  local PUB_URL="https://github.com/HL7/fhir-ig-publisher/releases/latest/download/publisher.jar"

  # ── _genonce.sh ─────────────────────────────────────────
  cat > "$IG_DIR/_genonce.sh" <<'GENONCE_SH'
#!/usr/bin/env bash
# _genonce.sh — generated by Torch · torchlab.dev
# Based on HL7 ig-publisher-scripts; enhanced with shared publisher.jar via ~/.torch/
# Note: the publisher automatically shares its terminology cache at ~/fhircache

TORCH_DIR="$HOME/.torch"

export JAVA_TOOL_OPTIONS=-Dfile.encoding=UTF-8

echo "Checking internet connection..."
if curl -s --max-time 4 https://tx.fhir.org/r4/metadata -o /dev/null 2>&1; then
  echo "Online"
  TX_OPT=""
else
  echo "Offline — terminology validation disabled"
  TX_OPT="-tx n/a"
fi

# Resolve publisher — shared first, then local, then parent
if   [ -f "$TORCH_DIR/publisher.jar" ]; then JAR="$TORCH_DIR/publisher.jar"
elif [ -f "input-cache/publisher.jar"  ]; then JAR="input-cache/publisher.jar"
elif [ -f "../publisher.jar"            ]; then JAR="../publisher.jar"
else
  echo "publisher.jar not found. Run ./_updatePublisher.sh first."
  exit 1
fi

echo "Publisher : $JAR"

java -jar "$JAR" -ig . $TX_OPT "$@"
GENONCE_SH
  chmod +x "$IG_DIR/_genonce.sh"

  # ── _gencontinuous.sh ───────────────────────────────────
  cat > "$IG_DIR/_gencontinuous.sh" <<'GENCONT_SH'
#!/usr/bin/env bash
# _gencontinuous.sh — generated by Torch · torchlab.dev
./_genonce.sh -watch "$@"
GENCONT_SH
  chmod +x "$IG_DIR/_gencontinuous.sh"

  # ── _updatePublisher.sh ─────────────────────────────────
  cat > "$IG_DIR/_updatePublisher.sh" <<UPDATEPUB_SH
#!/usr/bin/env bash
# _updatePublisher.sh — generated by Torch · torchlab.dev
# Downloads publisher.jar to ~/.torch/ (shared across all IGs).
# A copy is placed in ./input-cache/ for compatibility with standard tooling.

TORCH_DIR="\$HOME/.torch"
SHARED_JAR="\$TORCH_DIR/publisher.jar"
LOCAL_CACHE="input-cache"
LOCAL_JAR="\$LOCAL_CACHE/publisher.jar"
DLURL="${PUB_URL}"

echo "Checking internet connection..."
if ! curl -s --max-time 4 https://tx.fhir.org/r4/metadata -o /dev/null 2>&1; then
  echo "Offline — cannot update publisher."
  exit 1
fi

mkdir -p "\$TORCH_DIR" "\$LOCAL_CACHE"

echo "Downloading IG Publisher (~100 MB) to shared location..."
if curl -L --progress-bar "\$DLURL" -o "\$SHARED_JAR"; then
  echo "Saved : \$SHARED_JAR"
  # Symlink into input-cache so _genonce fallback and standard tools work
  ln -sf "\$SHARED_JAR" "\$LOCAL_JAR" 2>/dev/null || cp "\$SHARED_JAR" "\$LOCAL_JAR"
  echo "Linked: \$LOCAL_JAR"
else
  echo "Download failed."
  exit 1
fi
UPDATEPUB_SH
  chmod +x "$IG_DIR/_updatePublisher.sh"

  # ── _genonce.bat ────────────────────────────────────────
  cat > "$IG_DIR/_genonce.bat" <<'GENONCE_BAT'
@ECHO OFF
REM _genonce.bat — generated by Torch · torchlab.dev
REM Enhanced with shared publisher.jar via %USERPROFILE%\.torch\
REM Note: the publisher automatically shares its terminology cache at %USERPROFILE%\fhircache

SET TORCH_DIR=%USERPROFILE%\.torch
SET JAVA_TOOL_OPTIONS=-Dfile.encoding=UTF-8

ECHO Checking internet connection...
powershell -Command "try{$r=[System.Net.WebRequest]::Create('https://tx.fhir.org/r4/metadata');$r.Timeout=4000;$r.GetResponse().Close();exit 0}catch{exit 1}"
IF %ERRORLEVEL% EQU 0 (
  ECHO Online
  SET TX_OPT=
) ELSE (
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
  PAUSE
  EXIT /B 1
)

ECHO Publisher : %JAR%

JAVA -jar "%JAR%" -ig . %TX_OPT% %*
PAUSE
GENONCE_BAT

  # ── _gencontinuous.bat ──────────────────────────────────
  cat > "$IG_DIR/_gencontinuous.bat" <<'GENCONT_BAT'
@ECHO OFF
REM _gencontinuous.bat — generated by Torch · torchlab.dev
CALL _genonce.bat -watch %*
GENCONT_BAT

  # ── _updatePublisher.bat ────────────────────────────────
  cat > "$IG_DIR/_updatePublisher.bat" <<UPDATEPUB_BAT
@ECHO OFF
REM _updatePublisher.bat — generated by Torch · torchlab.dev
REM Downloads publisher.jar to %USERPROFILE%\.torch\ (shared across all IGs).
REM A copy is placed in .\input-cache\ for compatibility with standard tooling.

SET TORCH_DIR=%USERPROFILE%\.torch
SET SHARED_JAR=%TORCH_DIR%\publisher.jar
SET LOCAL_CACHE=%CD%\input-cache
SET LOCAL_JAR=%LOCAL_CACHE%\publisher.jar
SET DLURL=${PUB_URL}

ECHO Checking internet connection...
powershell -Command "try{$r=[System.Net.WebRequest]::Create('https://tx.fhir.org/r4/metadata');$r.Timeout=4000;$r.GetResponse().Close();exit 0}catch{exit 1}"
IF %ERRORLEVEL% NEQ 0 (
  ECHO Offline - cannot update publisher.
  PAUSE & EXIT /B 1
)

IF NOT EXIST "%TORCH_DIR%"    MKDIR "%TORCH_DIR%"
IF NOT EXIST "%LOCAL_CACHE%"  MKDIR "%LOCAL_CACHE%"

ECHO Downloading IG Publisher to shared location (~100 MB)...
powershell -Command "if('System.Net.WebClient' -as [type]){(new-object System.Net.WebClient).DownloadFile('%DLURL%','%SHARED_JAR%')}else{Invoke-WebRequest -Uri '%DLURL%' -Outfile '%SHARED_JAR%'}"

IF EXIST "%SHARED_JAR%" (
  ECHO Saved : %SHARED_JAR%
  COPY /Y "%SHARED_JAR%" "%LOCAL_JAR%" >NUL
  ECHO Copied: %LOCAL_JAR%
) ELSE (
  ECHO Download failed.
  PAUSE & EXIT /B 1
)
PAUSE
UPDATEPUB_BAT
}

# ── Main ──────────────────────────────────────────────────────

main() {
  header

  echo -e "  ${D}This wizard scaffolds a FHIR Implementation Guide project.${NC}"
  echo -e "  ${D}Answer each question — press Enter to accept [defaults].${NC}"
  echo ""

  # ── Step 1: Format ─────────────────────────────────────────
  section "Step 1 of 6  ·  Format"
  choose FORMAT "Authoring format" \
    "FSH/SUSHI  (recommended — human-readable shorthand)" \
    "JSON       (raw FHIR resources)" \
    "XML        (raw FHIR resources)"
  FORMAT=$(echo "$FORMAT" | awk '{print $1}')   # just the short key

  # ── Step 2: FHIR version ───────────────────────────────────
  section "Step 2 of 6  ·  FHIR Version"
  choose FHIR_VERSION "FHIR version" "R4" "R4B" "R5"

  # ── Step 3: IG identity ────────────────────────────────────
  section "Step 3 of 6  ·  IG Identity"

  ask_required IG_TITLE "IG title (e.g. 'My Country Patient IG')"
  local suggested_name
  suggested_name=$(echo "$IG_TITLE" | sed 's/[^A-Za-z0-9 ]//g' | sed 's/ //g')
  ask IG_NAME "IG name (no spaces, PascalCase)" "$suggested_name"

  local suggested_id
  suggested_id=$(echo "$IG_TITLE" | tr '[:upper:]' '[:lower:]' | sed 's/ /./g' | sed 's/[^a-z0-9.]//g')
  ask IG_ID "Package ID (reverse-domain, e.g. my.country.ig)" "$suggested_id"

  ask_required IG_CANONICAL "Canonical URL (e.g. http://example.org/fhir/my-ig)"
  ask IG_VERSION "Version" "0.1.0"
  ask IG_DESCRIPTION "Short description" "A FHIR Implementation Guide."
  choose IG_STATUS "Publication status" "draft" "active" "retired" "unknown"

  # ── Step 4: Publisher ──────────────────────────────────────
  section "Step 4 of 6  ·  Publisher Details"
  ask_required PUB_NAME "Publisher / organisation name"
  ask PUB_EMAIL "Publisher email" ""
  ask PUB_URL "Publisher URL" ""
  ask GITHUB_URL "GitHub repository URL (for CI/CD)" ""

  # ── Step 5: Components ─────────────────────────────────────
  section "Step 5 of 6  ·  IG Components"

  PROFILE_COUNT=0; EXT_COUNT=0; VS_COUNT=0; CS_COUNT=0
  HAS_EXAMPLES=""; HAS_CAPSTMT=""

  local pc
  ask pc "Number of Profiles" "0"
  PROFILE_COUNT=$pc
  PROFILE_NAMES=()
  if (( PROFILE_COUNT > 0 )); then
    ask_names PROFILE_NAMES "Profile" "$PROFILE_COUNT"
  fi

  local ec
  ask ec "Number of Extensions" "0"
  EXT_COUNT=$ec
  EXT_NAMES=()
  if (( EXT_COUNT > 0 )); then
    ask_names EXT_NAMES "Extension" "$EXT_COUNT"
  fi

  local vc
  ask vc "Number of Value Sets" "0"
  VS_COUNT=$vc
  VS_NAMES=()
  if (( VS_COUNT > 0 )); then
    ask_names VS_NAMES "ValueSet" "$VS_COUNT"
  fi

  local cc
  ask cc "Number of Code Systems" "0"
  CS_COUNT=$cc
  CS_NAMES=()
  if (( CS_COUNT > 0 )); then
    ask_names CS_NAMES "CodeSystem" "$CS_COUNT"
  fi

  confirm "Include example resources?" "y" && HAS_EXAMPLES="yes"
  confirm "Include a Capability Statement?" "n" && HAS_CAPSTMT="yes"

  # ── Step 6: Output directory ───────────────────────────────
  section "Step 6 of 6  ·  Output"
  local suggested_dir
  suggested_dir=$(to_kebab "$IG_TITLE")
  ask IG_DIR "Output directory" "./${suggested_dir}"

  # ── Confirm ────────────────────────────────────────────────
  echo ""
  echo -e "  ${O}${B}Ready to scaffold:${NC}"
  echo -e "  ${D}──────────────────────────────────────────${NC}"
  echo -e "  ${D}Directory:${NC}  $IG_DIR"
  echo -e "  ${D}Format:${NC}     $FORMAT"
  echo -e "  ${D}FHIR:${NC}       $FHIR_VERSION"
  echo -e "  ${D}ID:${NC}         $IG_ID"
  echo -e "  ${D}Canonical:${NC}  $IG_CANONICAL"
  echo -e "  ${D}Version:${NC}    $IG_VERSION"
  echo -e "  ${D}Publisher:${NC}  $PUB_NAME"
  [ ${#PROFILE_NAMES[@]} -gt 0 ] && echo -e "  ${D}Profiles:${NC}   ${PROFILE_NAMES[*]}"
  [ ${#EXT_NAMES[@]} -gt 0 ]     && echo -e "  ${D}Extensions:${NC} ${EXT_NAMES[*]}"
  [ ${#VS_NAMES[@]} -gt 0 ]      && echo -e "  ${D}ValueSets:${NC}  ${VS_NAMES[*]}"
  [ ${#CS_NAMES[@]} -gt 0 ]      && echo -e "  ${D}CodeSystems:${NC}${CS_NAMES[*]}"
  [ -n "$HAS_EXAMPLES" ]         && echo -e "  ${D}Examples:${NC}   yes"
  [ -n "$HAS_CAPSTMT" ]          && echo -e "  ${D}CapStmt:${NC}    yes"
  echo -e "  ${D}──────────────────────────────────────────${NC}"
  echo ""

  if ! confirm "Generate scaffold?" "y"; then
    echo -e "  ${Y}Cancelled.${NC}"; exit 0
  fi

  # ── Generate ───────────────────────────────────────────────
  echo ""
  echo -e "  ${O}Generating...${NC}"
  echo ""

  # Directory structure
  mkdir -p "$IG_DIR/input/pagecontent"
  mkdir -p "$IG_DIR/input/images"

  case "$FORMAT" in
    FSH)
      mkdir -p "$IG_DIR/input/fsh/profiles"
      mkdir -p "$IG_DIR/input/fsh/extensions"
      mkdir -p "$IG_DIR/input/fsh/vocabulary"
      mkdir -p "$IG_DIR/input/fsh/examples"
      ;;
    JSON|XML)
      mkdir -p "$IG_DIR/input/resources"
      mkdir -p "$IG_DIR/input/examples"
      ;;
  esac

  # Core config files
  write_gitignore
  success ".gitignore"

  write_readme
  success "README.md"

  case "$FORMAT" in
    FSH)
      write_sushi_config
      success "sushi-config.yaml"
      ;;
    JSON)
      write_ig_ini
      success "ig.ini"
      write_ig_resource_json
      success "input/ImplementationGuide-${IG_ID}.json"
      ;;
    XML)
      write_ig_ini
      success "ig.ini"
      write_ig_resource_xml
      success "input/ImplementationGuide-${IG_ID}.xml"
      ;;
  esac

  write_index_page
  success "input/pagecontent/index.md"

  # Profiles
  for name in "${PROFILE_NAMES[@]}"; do
    case "$FORMAT" in
      FSH)
        f="$IG_DIR/input/fsh/profiles/${name}.fsh"
        write_fsh_profile "$name" "$f"
        ;;
      JSON)
        f="$IG_DIR/input/resources/StructureDefinition-$(to_kebab "$name").json"
        write_sd_profile_json "$name" "$f"
        ;;
      XML)
        f="$IG_DIR/input/resources/StructureDefinition-$(to_kebab "$name").xml"
        write_sd_profile_xml "$name" "$f"
        ;;
    esac
    success "Profile: $name"
  done

  # Extensions (FSH only for brevity; JSON/XML follow same pattern)
  for name in "${EXT_NAMES[@]}"; do
    if [ "$FORMAT" = "FSH" ]; then
      f="$IG_DIR/input/fsh/extensions/${name}.fsh"
      write_fsh_extension "$name" "$f"
      success "Extension: $name"
    fi
  done

  # Value Sets
  for name in "${VS_NAMES[@]}"; do
    if [ "$FORMAT" = "FSH" ]; then
      f="$IG_DIR/input/fsh/vocabulary/${name}VS.fsh"
      write_fsh_valueset "$name" "$f"
      success "ValueSet: $name"
    fi
  done

  # Code Systems
  for name in "${CS_NAMES[@]}"; do
    if [ "$FORMAT" = "FSH" ]; then
      f="$IG_DIR/input/fsh/vocabulary/${name}CS.fsh"
      write_fsh_codesystem "$name" "$f"
      success "CodeSystem: $name"
    fi
  done

  # Examples
  if [ -n "$HAS_EXAMPLES" ]; then
    case "$FORMAT" in
      FSH)
        write_fsh_example "$IG_DIR/input/fsh/examples/PatientExample.fsh"
        success "Example: PatientExample.fsh"
        ;;
      JSON|XML)
        cat > "$IG_DIR/input/examples/Patient-example.json" <<'EXEOF'
{
  "resourceType": "Patient",
  "id": "example",
  "name": [{ "family": "Example", "given": ["Test"] }],
  "gender": "male",
  "birthDate": "1990-01-01"
}
EXEOF
        success "Example: Patient-example.json"
        ;;
    esac
  fi

  # Capability Statement
  if [ -n "$HAS_CAPSTMT" ] && [ "$FORMAT" = "FSH" ]; then
    write_fsh_capstmt "$IG_DIR/input/fsh/examples/CapabilityStatement-server.fsh"
    success "CapabilityStatement: server"
  fi

  # ── VS Code tasks ─────────────────────────────────────────
  mkdir -p "$IG_DIR/.vscode"
  cat > "$IG_DIR/.vscode/tasks.json" <<'VSCODE_TASKS'
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
VSCODE_TASKS
  success ".vscode/tasks.json"

  # Also drop in JetBrains run configs
  mkdir -p "$IG_DIR/.idea/runConfigurations"
  for conf in "FHIR_Build_IG" "FHIR_Watch_Mode" "FHIR_Update_Publisher"; do
    cat > "$IG_DIR/.idea/runConfigurations/${conf}.xml" <<JBXML
<component name="ProjectRunConfigurationManager">
  <configuration default="false" name="${conf//_/ }" type="ShConfigurationType" singleton="true">
    <option name="SCRIPT_PATH" value="\$PROJECT_DIR\$/_$(echo "${conf}" | sed 's/FHIR_Build_IG/_genonce/;s/FHIR_Watch_Mode/_gencontinuous/;s/FHIR_Update_Publisher/_updatePublisher/').sh" />
    <option name="SCRIPT_WORKING_DIRECTORY" value="\$PROJECT_DIR\$" />
    <option name="INTERPRETER_PATH" value="/bin/bash" />
    <option name="EXECUTE_IN_TERMINAL" value="true" />
    <option name="RUN_WITH_PTY" value="true" />
    <method v="2" />
  </configuration>
</component>
JBXML
  done
  success ".idea/runConfigurations/ (JetBrains)"

  # ── Publisher scripts ─────────────────────────────────────
  echo ""
  info "Generating publisher scripts (shared cache at ~/.torch/)..."
  write_publisher_scripts
  success "_genonce.sh / _genonce.bat"
  success "_gencontinuous.sh / _gencontinuous.bat"
  success "_updatePublisher.sh / _updatePublisher.bat"

  # Done
  echo ""
  hr
  echo -e "  ${G}${B}Scaffold complete!${NC}"
  echo ""
  echo -e "  ${D}Location:${NC}  $IG_DIR"
  echo ""
  echo -e "  ${O}${B}Next steps:${NC}"

  if [ "$FORMAT" = "FSH" ]; then
    echo -e "  ${D}1.${NC}  cd $IG_DIR"
    echo -e "  ${D}2.${NC}  ./_updatePublisher.sh          ${D}# downloads to ~/.torch/ (shared)${NC}"
    echo -e "  ${D}3.${NC}  sushi . && ./_genonce.sh"
  else
    echo -e "  ${D}1.${NC}  cd $IG_DIR"
    echo -e "  ${D}2.${NC}  ./_updatePublisher.sh          ${D}# downloads to ~/.torch/ (shared)${NC}"
    echo -e "  ${D}3.${NC}  ./_genonce.sh"
  fi

  echo ""
  echo -e "  ${D}Use _gencontinuous.sh to watch for changes during authoring.${NC}"
  echo -e "  ${D}publisher.jar is shared across all your IGs via ~/.torch/${NC}"
  echo -e "  ${D}Terminology cache is shared automatically by the publisher at ~/fhircache/${NC}"
  echo ""
  echo -e "  ${D}Learn more at torchlab.dev${NC}"
  echo ""
}

main "$@"
