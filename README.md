<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/logo-dark.svg">
    <source media="(prefers-color-scheme: light)" srcset="assets/logo-light.svg">
    <img src="assets/logo-light.svg" alt="Torch" width="380" />
  </picture>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-win%20%7C%20mac%20%7C%20linux-orange?style=flat-square" alt="platform" />
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-orange?style=flat-square" alt="MIT License" /></a>
  <a href="https://www.npmjs.com/package/@torchlab/fhir"><img src="https://img.shields.io/badge/npm-%40torchlab%2Ffhir-orange?style=flat-square" alt="npm package" /></a>
  <a href="https://torchlab.dev"><img src="https://img.shields.io/badge/torchlab.dev-orange?style=flat-square" alt="torchlab.dev" /></a>
</p>

<p align="center">
  Standalone shell scripts for FHIR IG development — no Node.js or npm required.
</p>

---

```bash
# macOS / Linux — one-time setup
git clone https://github.com/TorchLabFHIR/TorchScripts.git ~/.torch/scripts
bash ~/.torch/scripts/profile-setup/torch-profile-setup.sh

# Windows (PowerShell)
git clone https://github.com/TorchLabFHIR/TorchScripts.git $env:USERPROFILE\.torch\scripts
& "$env:USERPROFILE\.torch\scripts\profile-setup\torch-profile-setup.ps1"
```

> **Have Node.js?** The npm package is easier: `npm install -g @torchlab/fhir`
> It bundles these same scripts and adds the `torch` unified CLI.

---

## What's included

| Script | Platform | Purpose |
|--------|----------|---------|
| `env-check/torch-env-check.sh` | macOS / Linux | Check + auto-install your FHIR dev environment |
| `env-check/torch-env-check.ps1` | Windows | Check + auto-install your FHIR dev environment |
| `ig-scaffold/torch-ig-scaffold.sh` | macOS / Linux | Interactive IG project wizard |
| `ig-scaffold/torch-ig-scaffold.ps1` | Windows | Interactive IG project wizard |
| `validator/torch-validate.sh` | macOS / Linux | FHIR resource validator wrapper |
| `validator/torch-validate.ps1` | Windows | FHIR resource validator wrapper |
| `profile-setup/torch-profile-setup.sh` | macOS / Linux | Install shell aliases globally |
| `profile-setup/torch-profile-setup.ps1` | Windows | Install PowerShell functions globally |
| `ci-cd/fhir-ig-publish.yml` | GitHub Actions | Build IG + deploy to GitHub Pages on push |
| `ci-cd/fhir-ig-validate.yml` | GitHub Actions | Validate changed resources on PRs |
| `ide/vscode/tasks.json` | VS Code | Task template — build, watch, update, validate |
| `ide/vscode/keybindings.json` | VS Code | Suggested keyboard shortcuts |
| `ide/vscode/extensions.json` | VS Code | Recommended FHIR extensions |
| `ide/jetbrains/*.xml` | JetBrains | Run configurations for all JetBrains IDEs |

---

## Installation

### Option A — Clone and set up globally (recommended)

Clone once. Run the profile setup to install commands in every future terminal.

```bash
# macOS / Linux
git clone https://github.com/TorchLabFHIR/TorchScripts.git ~/.torch/scripts
bash ~/.torch/scripts/profile-setup/torch-profile-setup.sh
```

```powershell
# Windows (PowerShell)
git clone https://github.com/TorchLabFHIR/TorchScripts.git $env:USERPROFILE\.torch\scripts
& "$env:USERPROFILE\.torch\scripts\profile-setup\torch-profile-setup.ps1"
```

After that, `torch-check`, `torch-scaffold`, `fhir-validate`, and the other [shell aliases](#shell-aliases) are available in any terminal.

### Option B — Run scripts directly (no install)

Download or clone the repo, then call scripts directly:

```bash
# macOS / Linux
./env-check/torch-env-check.sh
./ig-scaffold/torch-ig-scaffold.sh

# Windows
.\env-check\torch-env-check.ps1
.\ig-scaffold\torch-ig-scaffold.ps1
```

---

## Quick start

### 1 — Check your environment

Scans for Java, Node.js, SUSHI, Ruby, Jekyll, .NET SDK, and Firely Terminal. On Windows it offers to install missing tools via winget. Detects PATH gaps and proxy/corporate environments, and prints IT request templates if needed.

```bash
# macOS / Linux
./env-check/torch-env-check.sh

# Windows
.\env-check\torch-env-check.ps1
```

### 2 — Set up shell aliases (once)

Installs all commands to your shell profile so they're available everywhere.

```bash
# macOS / Linux — adds aliases to ~/.zshrc or ~/.bashrc
./profile-setup/torch-profile-setup.sh

# Windows — adds functions to $PROFILE
.\profile-setup\torch-profile-setup.ps1
```

Also prompts to install recommended VS Code extensions.

### 3 — Scaffold a new FHIR IG

An interactive 6-step wizard: authoring format (FSH/SUSHI, JSON, XML), FHIR version (R4 / R4B / R5), IG identity, publisher details, components (profiles, extensions, value sets, code systems, examples, capability statement), and output directory.

```bash
# macOS / Linux
./ig-scaffold/torch-ig-scaffold.sh

# Windows
.\ig-scaffold\torch-ig-scaffold.ps1
```

Generates a ready-to-build project:

```
my-ig/
├── sushi-config.yaml          ← or ImplementationGuide.json / .xml
├── input/
│   ├── fsh/                   ← stub profiles, extensions, value sets
│   └── pagecontent/index.md
├── _genonce.sh / .bat         ← build once (uses shared ~/.torch/publisher.jar)
├── _gencontinuous.sh / .bat   ← build and watch
├── _updatePublisher.sh / .bat ← download latest publisher to ~/.torch/
├── .vscode/tasks.json         ← Ctrl+Shift+B builds the IG
├── .idea/runConfigurations/   ← JetBrains run configs
└── .gitignore
```

### 4 — Validate FHIR resources

Downloads `validator_cli.jar` to `~/.torch/` on first run. Subsequent runs are instant.

```bash
# macOS / Linux
./validator/torch-validate.sh Patient-example.json
./validator/torch-validate.sh -v R4 -ig hl7.fhir.us.core#6.1.0 input/resources/
./validator/torch-validate.sh --no-tx Patient-example.json   # offline

# Windows
.\validator\torch-validate.ps1 Patient-example.json
.\validator\torch-validate.ps1 -FhirVersion R4 -Ig hl7.fhir.us.core#6.1.0 .\input\resources\
.\validator\torch-validate.ps1 -NoTx Patient-example.json    # offline
```

---

## Prerequisites

| Tool | Minimum | Purpose |
|------|---------|---------|
| Java | 17 (21 recommended) | HL7 Publisher, FHIR Validator |
| Node.js | 18 LTS | SUSHI (FSH compiler) |
| SUSHI | 3.x | FSH → FHIR resource compilation |
| Ruby | 3.0 | Jekyll (IG site generation) |
| Jekyll | 4.0 | IG site generation |
| .NET SDK | 8.0 | Firely Terminal |
| Git | 2.x | Version control |

Run `torch-check` (or `./env-check/torch-env-check.sh`) to detect and install everything automatically.

---

## Shell aliases

After running `profile-setup`, these commands are available in every terminal:

| Command | Description |
|---------|-------------|
| `torch-check` | Scan environment — detect, patch PATH, offer installs |
| `torch-scaffold` | Start interactive IG scaffold wizard |
| `fhir-validate <file>` | Validate a FHIR resource or directory (alias: `fv`) |
| `ig-run` | Build the IG once (`_genonce` in current dir) |
| `ig-watch` | Build and watch for changes (`_gencontinuous`) |
| `ig-update` | Download / update shared `publisher.jar` |
| `ig-sushi` | Compile FSH with SUSHI only |
| `ig-build` | SUSHI + full IG build in one step |
| `ig-open` | Open `output/index.html` in your browser |
| `fhir-new <Type>` | Create a starter FHIR resource JSON file |
| `fhir-pub` | Run IG Publisher directly from anywhere |
| `torch-update-publisher` | Download latest `publisher.jar` to `~/.torch/` |
| `torch-update` | Pull latest scripts from GitHub |

### Activate without running profile setup

```bash
# bash / zsh — source aliases for the current session
source ~/.torch/torch.env

# PowerShell — dot-source functions for the current session
. "$env:USERPROFILE\.torch\torch.ps1"
```

---

## Shared publisher & validator cache

Every `_genonce` and `_updatePublisher` script uses a single shared directory so you download each jar exactly once, regardless of how many IG projects you have.

```
~/.torch/                       %USERPROFILE%\.torch\  (Windows)
├── publisher.jar               ← one copy for all your IGs (~100 MB)
└── validator_cli.jar           ← one copy for all your validations
```

The HL7 terminology cache (`~/fhircache`) is already shared automatically by the publisher — no configuration needed.

---

## VS Code integration

### Per-project tasks (generated by scaffold)

Each new IG includes `.vscode/tasks.json` pre-wired for:

| Task | Default shortcut | Action |
|------|-----------------|--------|
| FHIR: Build IG | `Ctrl+Shift+B` | Runs `_genonce` |
| FHIR: Watch mode | — | Runs `_gencontinuous` (background) |
| FHIR: SUSHI + Build | — | Compiles FSH then runs publisher |
| FHIR: Run SUSHI | — | FSH compile only |
| FHIR: Update Publisher | — | Downloads latest `publisher.jar` |
| FHIR: Validate current file | — | Validates the file open in the editor |
| FHIR: Open output in browser | — | Opens `output/index.html` |

### Global keybindings

Copy `ide/vscode/keybindings.json` into your VS Code keybindings (`Ctrl+Shift+P` → *Open Keyboard Shortcuts JSON*).

### Recommended extensions

Install manually or via `torch-check`:

| Extension | ID |
|-----------|---|
| FHIR Tools | `Yannick-Lagger.vscode-fhir-tools` |
| FSH Language Support | `kmahalingam.vscode-language-fsh` |
| XML | `redhat.vscode-xml` |
| YAML | `redhat.vscode-yaml` |
| REST Client | `humao.rest-client` |

---

## JetBrains integration

Copy the XML files from `ide/jetbrains/` into `.idea/runConfigurations/` in your IG project. Works across IntelliJ IDEA, WebStorm, Rider, PyCharm, and all other JetBrains IDEs.

> **Windows note:** The provided configs use a Unix shell script type. Windows-compatible `.bat`-based configs are generated automatically when you scaffold a new IG on Windows.

---

## CI/CD

Drop these workflows into `.github/workflows/` in your IG repository.

| File | Trigger | What it does |
|------|---------|-------------|
| `ci-cd/fhir-ig-publish.yml` | Push to `main` | Runs SUSHI (if FSH), builds IG, deploys to GitHub Pages |
| `ci-cd/fhir-ig-validate.yml` | Pull request | Validates changed resources, posts results as a PR comment |

**One-time GitHub Pages setup:**
1. *Settings → Pages → Source → GitHub Actions*
2. Set `FHIR_VERSION` in the workflow file
3. Push to `main` — your IG publishes automatically

---

## Corporate / managed environments

`torch-check` detects proxy settings, non-admin environments, and tools installed outside PATH. It patches PATH for the current session and prints permanent fix instructions.

If you cannot install software yourself, it generates a ready-to-send IT request with every missing tool and its install command.

**Set proxy before running scripts:**

```bash
export HTTP_PROXY=http://proxy.company.com:8080
export HTTPS_PROXY=http://proxy.company.com:8080
```

```powershell
$env:HTTP_PROXY  = "http://proxy.company.com:8080"
$env:HTTPS_PROXY = "http://proxy.company.com:8080"
```

---

## Troubleshooting

**`publisher.jar not found`**
Run `./_updatePublisher.sh` (or `.bat`) from your IG project root. It downloads to `~/.torch/publisher.jar` and symlinks it into `input-cache/`.

**`sushi: command not found`**
Run `torch-check` — it patches PATH for the session and shows you how to make it permanent.

**Terminology / tx server errors**
The `_genonce` scripts detect connectivity automatically and add `-tx n/a` when offline. To force offline mode manually, edit `_genonce.sh/.bat` or pass `-tx n/a` to the publisher directly.

**Windows: Execution policy error**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

The `torch-profile-setup.ps1` script offers to set this automatically during setup.

**`OutOfMemoryError` during IG build**
```bash
export _JAVA_OPTIONS="-Xmx4g"
```
Or add `-Xmx4g` to the `java` invocation in `_genonce.sh` / `_genonce.bat`.

---

## Resources

- [torchlab.dev](https://torchlab.dev) — FHIR learning platform
- [@torchlab/fhir on npm](https://www.npmjs.com/package/@torchlab/fhir) — the CLI wrapper for these scripts
- [HL7 FHIR IG Publisher](https://github.com/HL7/fhir-ig-publisher)
- [SUSHI / FSH School](https://fshschool.org)
- [FHIR Validator](https://confluence.hl7.org/display/FHIR/Using+the+FHIR+Validator)
- [Firely Terminal](https://docs.fire.ly/projects/Firely-Terminal)

---

## License

[MIT](LICENSE) © [TorchLab](https://torchlab.dev)
