#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
#  Torch  ·  FHIR Dev Environment Check  ·  torchlab.dev
#  macOS / Linux
# ──────────────────────────────────────────────────────────────

# ── Colours ───────────────────────────────────────────────────
if [ -t 1 ]; then
  O='\033[38;5;214m'   # Orange – Torch brand
  G='\033[0;32m'       # Green
  R='\033[0;31m'       # Red
  Y='\033[1;33m'       # Yellow
  C='\033[0;36m'       # Cyan
  B='\033[1m'          # Bold
  D='\033[2m'          # Dim
  NC='\033[0m'         # Reset
else
  O='' G='' R='' Y='' C='' B='' D='' NC=''
fi

PASS="${G}✔${NC}"
FAIL="${R}✘${NC}"
WARN="${Y}⚠${NC}"
INFO="${C}→${NC}"

# ── State ─────────────────────────────────────────────────────
PASS_COUNT=0; FAIL_COUNT=0; WARN_COUNT=0
PATH_PATCHES=()
CORPORATE_HINTS=()
MISSING_TOOLS=()
OUTDATED_TOOLS=()

# ── Helpers ───────────────────────────────────────────────────
hr()      { echo -e "${D}────────────────────────────────────────────────────────${NC}"; }
section() { echo ""; echo -e "${O}${B}  $1${NC}"; hr; }
indent()  { echo -e "  $*"; }

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
  echo -e "  ${D}FHIR Dev Environment Check  ·  v1.0  ·  torchlab.dev${NC}"
  echo ""
  hr
}

# version_gte <current> <minimum>  →  0 if current >= minimum
version_gte() {
  local IFS=.
  read -ra CUR <<< "${1%%[^0-9.]*}"
  read -ra MIN <<< "${2%%[^0-9.]*}"
  local i
  for ((i=0; i < ${#MIN[@]}; i++)); do
    local c=${CUR[i]:-0}
    local m=${MIN[i]:-0}
    (( c > m )) && return 0
    (( c < m )) && return 1
  done
  return 0
}

pass()  { indent "${PASS} ${B}$1${NC}  ${D}$2${NC}"; ((PASS_COUNT++)); }
fail()  { indent "${FAIL} ${B}$1${NC}  ${R}$2${NC}"; ((FAIL_COUNT++)); }
warn()  { indent "${WARN} ${B}$1${NC}  ${Y}$2${NC}"; ((WARN_COUNT++)); }
info()  { indent "${INFO} ${D}$1${NC}"; }

patch_path() {
  local dir="$1"
  local label="$2"
  if [[ ":$PATH:" != *":$dir:"* ]] && [ -d "$dir" ]; then
    export PATH="$dir:$PATH"
    PATH_PATCHES+=("$dir  ${D}($label)${NC}")
    return 0
  fi
  return 1
}

detect_corporate() {
  local hints=()
  [ -n "${http_proxy:-}${HTTP_PROXY:-}${https_proxy:-}${HTTPS_PROXY:-}" ] && \
    hints+=("System proxy environment variable detected")
  local npm_proxy
  npm_proxy=$(npm config get proxy 2>/dev/null || true)
  [ "$npm_proxy" != "null" ] && [ -n "$npm_proxy" ] && \
    hints+=("npm proxy configured: $npm_proxy")
  local git_proxy
  git_proxy=$(git config --global http.proxy 2>/dev/null || true)
  [ -n "$git_proxy" ] && hints+=("Git HTTP proxy: $git_proxy")
  CORPORATE_HINTS=("${hints[@]}")
}

# ── Tool checks ───────────────────────────────────────────────

check_git() {
  section "Git"
  local MIN="2.0.0"
  if ! command -v git &>/dev/null; then
    fail "git" "not found"
    MISSING_TOOLS+=("git")
    info "Install: https://git-scm.com/downloads"
    return
  fi
  local ver
  ver=$(git --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  if version_gte "$ver" "$MIN"; then
    pass "git" "$ver"
  else
    warn "git" "$ver  (minimum $MIN)"
    OUTDATED_TOOLS+=("git")
  fi
}

check_java() {
  section "Java  ${D}(required for HL7 Publisher & Validator)${NC}"
  local MIN="17" REC="21"

  # Try to locate java even if not in PATH
  local java_bin=""
  if command -v java &>/dev/null; then
    java_bin="java"
  else
    # Common locations
    for candidate in \
      "$JAVA_HOME/bin/java" \
      /usr/lib/jvm/temurin-21-amd64/bin/java \
      /Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home/bin/java \
      /opt/homebrew/opt/openjdk@21/bin/java \
      /usr/lib/jvm/java-21-openjdk-amd64/bin/java \
      /usr/lib/jvm/java-17-openjdk-amd64/bin/java \
      /opt/homebrew/opt/openjdk@17/bin/java; do
      [ -x "$candidate" ] && java_bin="$candidate" && break
    done
  fi

  if [ -z "$java_bin" ]; then
    fail "java" "not found"
    MISSING_TOOLS+=("java")
    info "Install Temurin (recommended): https://adoptium.net"
    info "Or via Homebrew (macOS): brew install --cask temurin"
    info "Or via apt (Linux):  sudo apt install temurin-21-jdk"
    return
  fi

  local ver
  ver=$("$java_bin" -version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+(_[0-9]+)?' | head -1)
  local major
  major=$(echo "$ver" | cut -d. -f1)
  # Java 1.8 style version
  [ "$major" = "1" ] && major=$(echo "$ver" | cut -d. -f2)

  if ! command -v java &>/dev/null && [ -n "$java_bin" ]; then
    local java_dir
    java_dir=$(dirname "$java_bin")
    patch_path "$java_dir" "Java bin"
    warn "java" "found at $java_bin — not in PATH (patched for this session)"
    CORPORATE_HINTS+=("Java found outside PATH — may need IT to add $(dirname "$java_bin") to system PATH")
  fi

  if (( major >= REC )); then
    pass "java" "$ver (Java $major)"
  elif (( major >= MIN )); then
    warn "java" "$ver (Java $major) — Java $REC recommended for HL7 Publisher ≥ 1.6"
    OUTDATED_TOOLS+=("java")
  else
    fail "java" "Java $major — minimum required is Java $MIN"
    OUTDATED_TOOLS+=("java")
    info "Upgrade to Temurin $REC: https://adoptium.net"
  fi

  # JAVA_HOME hint
  if [ -z "${JAVA_HOME:-}" ]; then
    info "Tip: set JAVA_HOME for tools that need it (add to ~/.zshrc or ~/.bashrc)"
  fi
}

check_node() {
  section "Node.js  ${D}(required for SUSHI)${NC}"
  local MIN="18.0.0"
  if ! command -v node &>/dev/null; then
    # Try nvm common path
    local nvm_node="$HOME/.nvm/versions/node"
    if [ -d "$nvm_node" ]; then
      local latest
      latest=$(ls -v "$nvm_node" | tail -1)
      patch_path "$nvm_node/$latest/bin" "nvm node"
    fi
  fi

  if ! command -v node &>/dev/null; then
    fail "node" "not found"
    MISSING_TOOLS+=("node")
    info "Install LTS via nvm (recommended): https://github.com/nvm-sh/nvm"
    info "  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/HEAD/install.sh | bash"
    info "  nvm install --lts"
    info "Or direct download: https://nodejs.org"
    return
  fi

  local ver
  ver=$(node --version 2>/dev/null | sed 's/v//')
  if version_gte "$ver" "$MIN"; then
    pass "node" "v$ver"
  else
    warn "node" "v$ver  (minimum v$MIN — LTS)"
    OUTDATED_TOOLS+=("node")
    info "Upgrade:  nvm install --lts && nvm use --lts"
  fi
}

check_npm() {
  section "npm"
  local MIN="9.0.0"
  if ! command -v npm &>/dev/null; then
    fail "npm" "not found — should ship with Node.js"
    MISSING_TOOLS+=("npm")
    return
  fi
  local ver
  ver=$(npm --version 2>/dev/null)
  if version_gte "$ver" "$MIN"; then
    pass "npm" "$ver"
  else
    warn "npm" "$ver  (minimum $MIN)"
    OUTDATED_TOOLS+=("npm")
    info "Upgrade:  npm install -g npm@latest"
  fi
}

check_sushi() {
  section "SUSHI (fsh-sushi)  ${D}(FSH compiler for FHIR IGs)${NC}"
  local MIN="3.0.0"

  # Patch npm global bin into PATH if missing
  if ! command -v sushi &>/dev/null && command -v npm &>/dev/null; then
    local npm_bin
    npm_bin=$(npm config get prefix 2>/dev/null)/bin
    patch_path "$npm_bin" "npm global bin"
  fi

  if ! command -v sushi &>/dev/null; then
    fail "sushi" "not found"
    MISSING_TOOLS+=("sushi")
    info "Install:  npm install -g fsh-sushi"
    return
  fi

  local ver
  ver=$(sushi --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  if version_gte "$ver" "$MIN"; then
    pass "sushi" "$ver"
  else
    warn "sushi" "$ver  (minimum $MIN)"
    OUTDATED_TOOLS+=("sushi")
    info "Upgrade:  npm install -g fsh-sushi@latest"
  fi
}

check_ruby() {
  section "Ruby  ${D}(required for Jekyll / IG site generation)${NC}"
  local MIN="3.0.0"

  if ! command -v ruby &>/dev/null; then
    # Try rbenv / rvm
    if [ -d "$HOME/.rbenv/bin" ]; then
      patch_path "$HOME/.rbenv/bin" "rbenv"
      patch_path "$HOME/.rbenv/shims" "rbenv shims"
    elif [ -d "$HOME/.rvm/bin" ]; then
      patch_path "$HOME/.rvm/bin" "rvm"
    fi
  fi

  if ! command -v ruby &>/dev/null; then
    fail "ruby" "not found"
    MISSING_TOOLS+=("ruby")
    info "Install via rbenv (recommended):"
    info "  https://github.com/rbenv/rbenv"
    info "  rbenv install 3.3.0 && rbenv global 3.3.0"
    info "macOS (Homebrew): brew install ruby"
    info "Ubuntu/Debian:    sudo apt install ruby-full"
    return
  fi

  local ver
  ver=$(ruby --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  if version_gte "$ver" "$MIN"; then
    pass "ruby" "$ver"
  else
    warn "ruby" "$ver  (minimum $MIN)"
    OUTDATED_TOOLS+=("ruby")
    info "macOS ships Ruby 2.x — install Ruby 3 via rbenv or Homebrew"
  fi

  # Gem bin in PATH?
  if command -v gem &>/dev/null; then
    local gem_bin
    gem_bin=$(gem environment gemdir 2>/dev/null)/bin
    patch_path "$gem_bin" "gem bin"
  fi
}

check_bundler() {
  section "Bundler  ${D}(required by Jekyll)${NC}"
  local MIN="2.0.0"
  if ! command -v bundle &>/dev/null; then
    fail "bundler" "not found"
    MISSING_TOOLS+=("bundler")
    info "Install:  gem install bundler"
    return
  fi
  local ver
  ver=$(bundle --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  if version_gte "$ver" "$MIN"; then
    pass "bundler" "$ver"
  else
    warn "bundler" "$ver  (minimum $MIN)"
    OUTDATED_TOOLS+=("bundler")
    info "Upgrade:  gem update bundler"
  fi
}

check_jekyll() {
  section "Jekyll  ${D}(IG site generation)${NC}"
  local MIN="4.0.0"
  if ! command -v jekyll &>/dev/null; then
    fail "jekyll" "not found"
    MISSING_TOOLS+=("jekyll")
    info "Install:  gem install jekyll"
    return
  fi
  local ver
  ver=$(jekyll --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  if version_gte "$ver" "$MIN"; then
    pass "jekyll" "$ver"
  else
    warn "jekyll" "$ver  (minimum $MIN)"
    OUTDATED_TOOLS+=("jekyll")
    info "Upgrade:  gem update jekyll"
  fi
}

check_dotnet() {
  section ".NET SDK  ${D}(required for Firely Terminal)${NC}"
  local MIN="8.0.0"

  if ! command -v dotnet &>/dev/null; then
    patch_path "$HOME/.dotnet" "dotnet"
  fi

  if ! command -v dotnet &>/dev/null; then
    fail "dotnet" "not found"
    MISSING_TOOLS+=("dotnet")
    info "Install .NET 8 SDK: https://dotnet.microsoft.com/download"
    info "macOS (Homebrew): brew install dotnet"
    info "Ubuntu:  wget https://packages.microsoft.com/...  (see docs.microsoft.com)"
    return
  fi

  local ver
  ver=$(dotnet --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  if version_gte "$ver" "$MIN"; then
    pass "dotnet" "$ver"
  else
    warn "dotnet" "$ver  (minimum .NET $MIN)"
    OUTDATED_TOOLS+=("dotnet")
    info "Upgrade SDK: https://dotnet.microsoft.com/download"
  fi

  # Dotnet tools bin path
  patch_path "$HOME/.dotnet/tools" ".NET tools"
}

check_firely() {
  section "Firely Terminal (fhir)  ${D}(FHIR package manager & validator)${NC}"
  if ! command -v fhir &>/dev/null; then
    fail "firely terminal" "not found  ${D}(fhir command missing)${NC}"
    MISSING_TOOLS+=("firely-terminal")
    info "Install:  dotnet tool install -g Firely.Terminal"
    info "Requires .NET SDK 8+"
    return
  fi
  local ver
  ver=$(fhir --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
  pass "firely terminal" "$ver"
}

# ── Summary ───────────────────────────────────────────────────

print_summary() {
  echo ""
  section "Summary"

  local total=$(( PASS_COUNT + FAIL_COUNT + WARN_COUNT ))
  indent "${PASS} Passed:   $PASS_COUNT / $total"
  indent "${WARN} Warnings: $WARN_COUNT / $total"
  indent "${FAIL} Failed:   $FAIL_COUNT / $total"
  echo ""

  if [ ${#PATH_PATCHES[@]} -gt 0 ]; then
    echo -e "  ${Y}${B}PATH patched for this session:${NC}"
    for p in "${PATH_PATCHES[@]}"; do
      indent "  ${Y}+${NC} $p"
    done
    echo ""
    echo -e "  ${Y}To make PATH changes permanent, add the following to${NC}"
    local shell_rc="~/.zshrc"
    [ -n "${BASH_VERSION:-}" ] && shell_rc="~/.bashrc"
    echo -e "  ${B}$shell_rc${NC}${Y}:${NC}"
    for p in "${PATH_PATCHES[@]}"; do
      local dir
      dir=$(echo "$p" | awk '{print $1}')
      indent "  ${D}export PATH=\"$dir:\$PATH\"${NC}"
    done
    echo ""
  fi

  if [ ${#CORPORATE_HINTS[@]} -gt 0 ]; then
    echo -e "  ${C}${B}Corporate environment detected:${NC}"
    for h in "${CORPORATE_HINTS[@]}"; do
      indent "  ${INFO} $h"
    done
    echo ""
    echo -e "  ${C}If you cannot install tools yourself, forward this output${NC}"
    echo -e "  ${C}to your IT team with a request to install the missing items.${NC}"
    echo -e "  ${C}Reference: https://torchlab.dev/resources${NC}"
    echo ""
  fi

  if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    echo -e "  ${R}${B}Missing tools:${NC} ${MISSING_TOOLS[*]}"
    echo ""
    echo -e "  ${D}IT request template:${NC}"
    echo -e "  ${D}─────────────────────────────────────────────────${NC}"
    echo -e "  ${D}Please install the following developer tools required${NC}"
    echo -e "  ${D}for FHIR implementation guide development:${NC}"
    for t in "${MISSING_TOOLS[@]}"; do
      indent "  ${D}• $t${NC}"
    done
    echo -e "  ${D}Reference: https://torchlab.dev/resources${NC}"
    echo -e "  ${D}─────────────────────────────────────────────────${NC}"
    echo ""
  fi

  if [ $FAIL_COUNT -eq 0 ] && [ $WARN_COUNT -eq 0 ]; then
    echo -e "  ${G}${B}All checks passed — your environment is FHIR-ready! 🔥${NC}"
  elif [ $FAIL_COUNT -eq 0 ]; then
    echo -e "  ${Y}${B}Environment mostly ready — review warnings above.${NC}"
  else
    echo -e "  ${R}${B}Some tools are missing. Install them before building FHIR IGs.${NC}"
  fi
  echo ""
  echo -e "  ${D}Learn FHIR IG authoring at torchlab.dev${NC}"
  echo ""
}

# ── Main ──────────────────────────────────────────────────────

main() {
  header
  detect_corporate

  if [ ${#CORPORATE_HINTS[@]} -gt 0 ]; then
    echo -e "  ${Y}${B}Note:${NC} ${Y}Corporate environment indicators found — see summary.${NC}"
    echo ""
  fi

  check_git
  check_java
  check_node
  check_npm
  check_sushi
  check_ruby
  check_bundler
  check_jekyll
  check_dotnet
  check_firely

  print_summary
}

main "$@"
