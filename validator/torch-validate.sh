#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
#  Torch  ·  FHIR Validator Wrapper  ·  torchlab.dev
#  macOS / Linux
#
#  Wraps the HL7 FHIR Validator CLI (validator_cli.jar).
#  Downloads the jar automatically on first use.
#
#  Usage:
#    torch-validate.sh [options] <file|directory>
#
#  Options:
#    -v, --fhir-version <ver>   FHIR version: R4 | R4B | R5  [default: R4]
#    -ig <pkg>                  IG to validate against (e.g. hl7.fhir.us.core#6.1.0)
#    -p, --profile <url>        Profile canonical URL to validate against
#    -tx, --tx-server <url>     Terminology server  [default: https://tx.fhir.org/r4]
#    --no-tx                    Disable terminology validation (offline mode)
#    -o, --output <fmt>         Output format: text | json | xml  [default: text]
#    -r, --recurse              Validate all files in directory recursively
#    --download                 Download / update validator_cli.jar then exit
#    -h, --help                 Show this help
# ──────────────────────────────────────────────────────────────

set -euo pipefail

# ── Colours ───────────────────────────────────────────────────
if [ -t 1 ]; then
  O='\033[38;5;214m'  G='\033[0;32m'  R='\033[0;31m'
  Y='\033[1;33m'  C='\033[0;36m'  B='\033[1m'  D='\033[2m'  NC='\033[0m'
else
  O='' G='' R='' Y='' C='' B='' D='' NC=''
fi

hr()   { echo -e "${D}────────────────────────────────────────────────────────${NC}"; }
info() { echo -e "  ${C}→${NC}  $*"; }
ok()   { echo -e "  ${G}✔${NC}  $*"; }
warn() { echo -e "  ${Y}⚠${NC}  $*"; }
err()  { echo -e "  ${R}✘${NC}  $*" >&2; }

banner() {
  echo ""
  echo -e "${O}${B}  ████████╗ ██████╗ ██████╗  ██████╗██╗  ██╗${NC}"
  echo -e "  ${D}FHIR Validator Wrapper  ·  v1.0  ·  torchlab.dev${NC}"
  echo ""
  hr
}

usage() {
  cat <<EOF

${O}${B}Torch FHIR Validator${NC}  ·  torchlab.dev

${B}Usage:${NC}
  torch-validate.sh [options] <file|directory>

${B}Options:${NC}
  -v, --fhir-version <ver>   FHIR version: R4 | R4B | R5  [default: R4]
  -ig <pkg>                  IG package (e.g. hl7.fhir.us.core#6.1.0)
  -p, --profile <url>        Profile canonical URL
  -tx, --tx-server <url>     Terminology server URL
  --no-tx                    Offline mode (skip terminology validation)
  -o, --output <fmt>         text | json | xml  [default: text]
  -r, --recurse              Recursively validate directory
  --download                 Download / update validator_cli.jar and exit
  -h, --help                 Show this help

${B}Examples:${NC}
  torch-validate.sh Patient-example.json
  torch-validate.sh -v R4 -ig hl7.fhir.us.core#6.1.0 input/resources/
  torch-validate.sh --no-tx -p http://hl7.org/fhir/StructureDefinition/Patient Patient.json
  torch-validate.sh --download

${D}Requires Java 17+. Validator jar is cached in ~/.torch/validator_cli.jar${NC}

EOF
  exit 0
}

# ── Defaults ──────────────────────────────────────────────────
FHIR_VER="4.0.1"
IG_PKGS=()
PROFILES=()
TX_SERVER="https://tx.fhir.org/r4"
NO_TX=false
OUTPUT_FMT="text"
RECURSE=false
DOWNLOAD_ONLY=false
TARGETS=()

JAR_DIR="$HOME/.torch"
JAR_PATH="$JAR_DIR/validator_cli.jar"
JAR_URL="https://github.com/hapifhir/org.hl7.fhir.core/releases/latest/download/validator_cli.jar"

# ── Parse args ────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)          usage ;;
    --download)         DOWNLOAD_ONLY=true; shift ;;
    --no-tx)            NO_TX=true; shift ;;
    -r|--recurse)       RECURSE=true; shift ;;
    -v|--fhir-version)
      shift
      case "${1^^}" in
        R4)  FHIR_VER="4.0.1" ;;
        R4B) FHIR_VER="4.3.0" ;;
        R5)  FHIR_VER="5.0.0" ;;
        4.0.1|4.3.0|5.0.0) FHIR_VER="$1" ;;
        *)  err "Unknown FHIR version: $1"; exit 1 ;;
      esac
      shift ;;
    -ig)
      shift; IG_PKGS+=("$1"); shift ;;
    -p|--profile)
      shift; PROFILES+=("$1"); shift ;;
    -tx|--tx-server)
      shift; TX_SERVER="$1"; shift ;;
    -o|--output)
      shift; OUTPUT_FMT="$1"; shift ;;
    -*)
      err "Unknown option: $1"; usage ;;
    *)
      TARGETS+=("$1"); shift ;;
  esac
done

# ── Java check ────────────────────────────────────────────────
check_java() {
  if ! command -v java &>/dev/null; then
    err "Java not found. Install Java 17+: https://adoptium.net"
    exit 1
  fi
  local ver
  ver=$(java -version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  local major
  major=$(echo "$ver" | cut -d. -f1)
  [ "$major" = "1" ] && major=$(echo "$ver" | cut -d. -f2)
  if (( major < 17 )); then
    err "Java $major found — Java 17+ required. Upgrade at https://adoptium.net"
    exit 1
  fi
  ok "Java $major ($ver)"
}

# ── Download jar ──────────────────────────────────────────────
download_jar() {
  mkdir -p "$JAR_DIR"
  info "Downloading FHIR Validator (latest)..."
  info "$JAR_URL"
  if command -v curl &>/dev/null; then
    curl -L --progress-bar "$JAR_URL" -o "$JAR_PATH"
  elif command -v wget &>/dev/null; then
    wget --show-progress -q "$JAR_URL" -O "$JAR_PATH"
  else
    err "Neither curl nor wget found — cannot download validator."
    exit 1
  fi
  ok "Saved to $JAR_PATH"
}

# ── Collect files ─────────────────────────────────────────────
collect_targets() {
  local collected=()
  for t in "${TARGETS[@]}"; do
    if [ -f "$t" ]; then
      collected+=("$t")
    elif [ -d "$t" ]; then
      if $RECURSE; then
        while IFS= read -r f; do collected+=("$f"); done < \
          <(find "$t" -type f \( -name "*.json" -o -name "*.xml" \) ! -path "*/output/*" ! -path "*/input-cache/*" ! -path "*/fsh-generated/*" ! -name "package.json")
      else
        while IFS= read -r f; do collected+=("$f"); done < \
          <(find "$t" -maxdepth 1 -type f \( -name "*.json" -o -name "*.xml" \) ! -name "package.json")
      fi
    else
      warn "Not found: $t"
    fi
  done
  echo "${collected[@]:-}"
}

# ── Main ──────────────────────────────────────────────────────
banner

if $DOWNLOAD_ONLY; then
  check_java
  download_jar
  echo ""
  ok "Validator ready at $JAR_PATH"
  echo ""
  exit 0
fi

if [ ${#TARGETS[@]} -eq 0 ]; then
  err "No target file or directory specified."
  usage
fi

check_java

# Download jar if missing
if [ ! -f "$JAR_PATH" ]; then
  warn "validator_cli.jar not found — downloading now..."
  echo ""
  download_jar
  echo ""
fi

# Build files list
read -ra FILES <<< "$(collect_targets)"

if [ ${#FILES[@]} -eq 0 ]; then
  err "No FHIR JSON/XML files found in specified target(s)."
  exit 1
fi

# ── Build java command ─────────────────────────────────────────
JAVA_ARGS=("java" "-jar" "$JAR_PATH")
JAVA_ARGS+=("-version" "$FHIR_VER")

for pkg in "${IG_PKGS[@]}"; do
  JAVA_ARGS+=("-ig" "$pkg")
done

for prof in "${PROFILES[@]}"; do
  JAVA_ARGS+=("-profile" "$prof")
done

if $NO_TX; then
  JAVA_ARGS+=("-tx" "n/a")
else
  JAVA_ARGS+=("-tx" "$TX_SERVER")
fi

case "$OUTPUT_FMT" in
  json) JAVA_ARGS+=("-output-style" "json") ;;
  xml)  JAVA_ARGS+=("-output-style" "xml")  ;;
esac

JAVA_ARGS+=("${FILES[@]}")

# ── Run ───────────────────────────────────────────────────────
echo ""
echo -e "  ${O}${B}Validating ${#FILES[@]} file(s) against FHIR $FHIR_VER${NC}"
[ ${#IG_PKGS[@]} -gt 0 ]  && info "IGs:      ${IG_PKGS[*]}"
[ ${#PROFILES[@]} -gt 0 ] && info "Profiles: ${PROFILES[*]}"
$NO_TX && info "Mode:     offline (terminology disabled)" || info "Tx:       $TX_SERVER"
echo ""
hr
echo ""

"${JAVA_ARGS[@]}"

EXIT_CODE=$?
echo ""
hr

if [ $EXIT_CODE -eq 0 ]; then
  ok "Validation completed. Review output above."
else
  warn "Validation completed with issues (exit $EXIT_CODE). Review output above."
fi

echo ""
echo -e "  ${D}Learn FHIR validation at torchlab.dev${NC}"
echo ""
exit $EXIT_CODE
