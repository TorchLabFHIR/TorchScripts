#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
#  Torch  ·  Shell Profile Setup  ·  torchlab.dev
#  macOS / Linux (bash + zsh)
#
#  Installs Torch scripts to ~/.torch/scripts/ and adds
#  aliases + functions to your shell profile.
#  Run once from the root of the cloned torch-scripts repo.
# ──────────────────────────────────────────────────────────────

set -euo pipefail

# ── Colours ───────────────────────────────────────────────────
if [ -t 1 ]; then
  O='\033[38;5;214m' G='\033[0;32m' R='\033[0;31m'
  Y='\033[1;33m' C='\033[0;36m' B='\033[1m' D='\033[2m' NC='\033[0m'
else
  O='' G='' R='' Y='' C='' B='' D='' NC=''
fi

hr()      { echo -e "${D}────────────────────────────────────────────────────────${NC}"; }
info()    { echo -e "  ${C}→${NC}  $*"; }
ok()      { echo -e "  ${G}✔${NC}  $*"; }
warn()    { echo -e "  ${Y}⚠${NC}  $*"; }
section() { echo ""; echo -e "${O}${B}  $1${NC}"; hr; }

TORCH_DIR="$HOME/.torch"
SCRIPTS_DIR="$TORCH_DIR/scripts"
ENV_FILE="$TORCH_DIR/torch.env"
MARKER="# Torch FHIR Developer Tools — torchlab.dev"

# ── Detect shell and profile file ─────────────────────────────
detect_profile() {
  if [ -n "${ZSH_VERSION:-}" ] || [ "$SHELL" = "$(which zsh 2>/dev/null)" ]; then
    SHELL_NAME="zsh"
    PROFILE_FILE="${ZDOTDIR:-$HOME}/.zshrc"
  else
    SHELL_NAME="bash"
    # macOS bash uses .bash_profile; Linux uses .bashrc
    if [ "$(uname)" = "Darwin" ]; then
      PROFILE_FILE="$HOME/.bash_profile"
    else
      PROFILE_FILE="$HOME/.bashrc"
    fi
  fi
}

# ── Source script root (where this script lives) ──────────────
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

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
  echo -e "  ${D}Shell Profile Setup  ·  v1.0  ·  torchlab.dev${NC}"
  echo ""
  hr
}

# ── Install scripts to ~/.torch/scripts/ ──────────────────────
install_scripts() {
  section "Installing scripts"
  mkdir -p "$SCRIPTS_DIR"

  local files=(
    "env-check/torch-env-check.sh"
    "ig-scaffold/torch-ig-scaffold.sh"
    "validator/torch-validate.sh"
  )

  for rel in "${files[@]}"; do
    local src="$REPO_ROOT/$rel"
    local dst="$SCRIPTS_DIR/$(basename "$rel")"
    if [ -f "$src" ]; then
      cp "$src" "$dst"
      chmod +x "$dst"
      ok "$(basename "$rel")"
    else
      warn "Not found: $src (skipped)"
    fi
  done
}

# ── Write ~/.torch/torch.env (alias definitions) ──────────────
write_env_file() {
  section "Writing alias definitions → $ENV_FILE"
  mkdir -p "$TORCH_DIR"

  cat > "$ENV_FILE" <<ENVEOF
${MARKER}
# shellcheck shell=bash

TORCH_SCRIPTS="\$HOME/.torch/scripts"
TORCH_DIR="\$HOME/.torch"

# ── Torch tool aliases ────────────────────────────────────────
alias torch-check="\$TORCH_SCRIPTS/torch-env-check.sh"
alias torch-scaffold="\$TORCH_SCRIPTS/torch-ig-scaffold.sh"
alias fhir-validate="\$TORCH_SCRIPTS/torch-validate.sh"
alias fv="\$TORCH_SCRIPTS/torch-validate.sh"

# ── IG workflow (run from within an IG project directory) ─────
alias ig-run='./_genonce.sh'
alias ig-watch='./_gencontinuous.sh'
alias ig-update='./_updatePublisher.sh'
alias ig-sushi='sushi .'
alias ig-build='sushi . && ./_genonce.sh'

# Run publisher directly (useful outside a project)
alias fhir-pub='java -jar "\$TORCH_DIR/publisher.jar" -ig .'

# Open IG output in default browser
ig-open() {
  local index="\${1:-output/index.html}"
  if [ -f "\$index" ]; then
    if command -v xdg-open &>/dev/null; then xdg-open "\$index"
    elif command -v open &>/dev/null;     then open "\$index"
    else echo "Open manually: \$(realpath "\$index")"
    fi
  else
    echo "IG output not found at \$index — run ig-run first"
  fi
}

# Update shared publisher.jar from latest HL7 release
torch-update-publisher() {
  local jar="\$TORCH_DIR/publisher.jar"
  local url="https://github.com/HL7/fhir-ig-publisher/releases/latest/download/publisher.jar"
  echo "Downloading latest HL7 IG Publisher..."
  mkdir -p "\$TORCH_DIR"
  curl -L --progress-bar "\$url" -o "\$jar" && echo "Saved to \$jar"
}

# Pull latest Torch scripts from GitHub
torch-update() {
  local repo="${TORCH_REPO_URL:-https://github.com/torchlab-dev/fhir-scripts}"
  local tmp="\$(mktemp -d)"
  echo "Fetching latest Torch scripts from GitHub..."
  if git clone --depth 1 "\$repo" "\$tmp" 2>/dev/null; then
    bash "\$tmp/profile-setup/torch-profile-setup.sh" --update
    rm -rf "\$tmp"
  else
    echo "Could not reach \$repo — check connection"
    rm -rf "\$tmp"
  fi
}

# Quick FHIR resource snippet (opens $EDITOR with a starter)
fhir-new() {
  local type="\${1:-Patient}"
  local file="\${2:-\$type-example.json}"
  cat > "\$file" <<FHIREOF
{
  "resourceType": "\$type",
  "id": "example",
  "meta": {
    "profile": []
  }
}
FHIREOF
  echo "Created \$file"
  \${EDITOR:-nano} "\$file"
}
ENVEOF

  ok "torch.env written"
}

# ── Add source line to shell profile ─────────────────────────
add_to_profile() {
  section "Shell profile setup"
  detect_profile
  info "Shell:   $SHELL_NAME"
  info "Profile: $PROFILE_FILE"
  echo ""

  # Check if already installed
  if [ -f "$PROFILE_FILE" ] && grep -qF "$MARKER" "$PROFILE_FILE" 2>/dev/null; then
    ok "Torch aliases already in $PROFILE_FILE — skipping"
    return
  fi

  local SOURCE_LINE='[ -f "$HOME/.torch/torch.env" ] && source "$HOME/.torch/torch.env"'
  local BLOCK
  BLOCK=$(cat <<BLOCK

${MARKER}
${SOURCE_LINE}
BLOCK
)

  printf "  ${C}?${NC} ${B}Add Torch aliases to %s?${NC} ${D}[Y/n]:${NC} " "$PROFILE_FILE"
  local ans
  read -r ans
  ans="${ans:-y}"

  if [[ "$ans" =~ ^[Yy] ]]; then
    # Create profile if it doesn't exist
    touch "$PROFILE_FILE"
    echo "$BLOCK" >> "$PROFILE_FILE"
    ok "Added to $PROFILE_FILE"
    info "Run:  source $PROFILE_FILE  (or open a new terminal)"
  else
    warn "Skipped. To add manually, append this to $PROFILE_FILE:"
    echo ""
    echo -e "  ${D}${MARKER}${NC}"
    echo -e "  ${D}${SOURCE_LINE}${NC}"
    echo ""
  fi
}

# ── VS Code tasks ─────────────────────────────────────────────
setup_vscode() {
  section "VS Code integration"

  if ! command -v code &>/dev/null; then
    info "VS Code CLI not found — skipping (install 'code' command via VS Code: Cmd+Shift+P → Shell Command)"
    return
  fi

  printf "  ${C}?${NC} ${B}Install FHIR recommended VS Code extensions?${NC} ${D}[Y/n]:${NC} "
  local ans; read -r ans; ans="${ans:-y}"

  if [[ "$ans" =~ ^[Yy] ]]; then
    local extensions=(
      "Yannick-Lagger.vscode-fhir-tools"
      "kmahalingam.vscode-language-fsh"
      "redhat.vscode-xml"
      "redhat.vscode-yaml"
      "humao.rest-client"
    )
    for ext in "${extensions[@]}"; do
      code --install-extension "$ext" --force 2>/dev/null && ok "$ext" || warn "Could not install $ext"
    done
  fi
}

# ── Summary ───────────────────────────────────────────────────
print_summary() {
  section "Done"
  echo -e "  ${G}${B}Torch is ready.${NC}  Open a new terminal or run:"
  echo ""
  echo -e "  ${D}source $PROFILE_FILE${NC}"
  echo ""
  echo -e "  ${O}${B}Available commands:${NC}"
  echo -e "  ${D}torch-check${NC}              Check your FHIR dev environment"
  echo -e "  ${D}torch-scaffold${NC}           Create a new FHIR IG project"
  echo -e "  ${D}fhir-validate <file>${NC}     Validate a FHIR resource"
  echo -e "  ${D}fv <file>${NC}                Alias for fhir-validate"
  echo -e "  ${D}ig-run${NC}                   Build IG (run from IG root)"
  echo -e "  ${D}ig-watch${NC}                 Build IG + watch for changes"
  echo -e "  ${D}ig-update${NC}                Update shared publisher.jar"
  echo -e "  ${D}ig-sushi${NC}                 Run SUSHI (FSH compile only)"
  echo -e "  ${D}ig-build${NC}                 SUSHI + build (FSH projects)"
  echo -e "  ${D}ig-open${NC}                  Open IG output in browser"
  echo -e "  ${D}fhir-new <type>${NC}          Create a starter FHIR resource file"
  echo -e "  ${D}torch-update-publisher${NC}   Download latest publisher.jar"
  echo ""
  echo -e "  ${D}Learn FHIR IG development at torchlab.dev${NC}"
  echo ""
}

# ── Entry point ───────────────────────────────────────────────
UPDATE_ONLY=false
for arg in "$@"; do
  [ "$arg" = "--update" ] && UPDATE_ONLY=true
done

if ! $UPDATE_ONLY; then
  header
fi

if [ -n "${TORCH_NPM_MANAGED:-}" ]; then
  echo -e "  ${C}npm-managed install detected${NC} — shell commands provided by @torchlab/fhir."
  echo -e "  ${D}Skipping alias setup. Configuring IDE integration only.${NC}"
  echo ""
  setup_vscode
  section "Done"
  echo -e "  ${G}${B}IDE integration complete.${NC}"
  echo -e "  ${D}Run 'torch --help' to see all available commands.${NC}"
  echo ""
  exit 0
fi

install_scripts
write_env_file
add_to_profile

if ! $UPDATE_ONLY; then
  setup_vscode
fi

print_summary
