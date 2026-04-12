#!/usr/bin/env bash

set -u

SKIP_APP_STORE=0
DRY_RUN=${DRY_RUN:-0}
PROMPT_VARIANT=${PROMPT_VARIANT:-powerlevel10k}

FAILED_ITEMS=()
HAS_COLOR=0
COLOR_RESET=''
COLOR_BOLD=''
COLOR_DIM=''
COLOR_RED=''
COLOR_GREEN=''
COLOR_YELLOW=''
COLOR_BLUE=''
COLOR_MAGENTA=''
COLOR_CYAN=''

usage() {
  cat <<'EOF'
Usage: ./setup-macos.sh [options]

Options:
  --skip-app-store   Skip Mac App Store installations
  --help             Show this help text

Environment:
  DRY_RUN=1          Print commands instead of running them
EOF
}

setup_ui() {
  if [ -t 1 ] && command -v tput >/dev/null 2>&1 && [ "$(tput colors 2>/dev/null || printf '0')" -ge 8 ]; then
    HAS_COLOR=1
    COLOR_RESET="$(tput sgr0)"
    COLOR_BOLD="$(tput bold)"
    COLOR_DIM="$(tput dim)"
    COLOR_RED="$(tput setaf 1)"
    COLOR_GREEN="$(tput setaf 2)"
    COLOR_YELLOW="$(tput setaf 3)"
    COLOR_BLUE="$(tput setaf 4)"
    COLOR_MAGENTA="$(tput setaf 5)"
    COLOR_CYAN="$(tput setaf 6)"
  fi
}

print_status() {
  local color="$1"
  local label="$2"
  local text="$3"

  printf '%s%s%-10s%s %s\n' "$color" "$COLOR_BOLD" "$label" "$COLOR_RESET" "$text"
}

banner() {
  printf '\n%s%s%s\n' "$COLOR_BOLD" '========================================' "$COLOR_RESET"
  printf '%s%s%s\n' "$COLOR_BOLD" "$1" "$COLOR_RESET"
  printf '%s%s%s\n' "$COLOR_BOLD" '========================================' "$COLOR_RESET"
}

section() {
  printf '\n%s%s[%s]%s\n' "$COLOR_BLUE" "$COLOR_BOLD" "$1" "$COLOR_RESET"
}

group() {
  printf '%s%s-> %s%s\n' "$COLOR_MAGENTA" "$COLOR_BOLD" "$1" "$COLOR_RESET"
}

warn() {
  printf '%sWarning:%s %s\n' "$COLOR_YELLOW" "$COLOR_RESET" "$1" >&2
}

record_failure() {
  local item="$1"
  FAILED_ITEMS+=("$item")
  print_status "$COLOR_RED" '[fail]' "$item"
}

run_cmd() {
  if [ "$DRY_RUN" = "1" ]; then
    printf '%s[dry-run]%s' "$COLOR_DIM" "$COLOR_RESET"
    printf ' %q' "$@"
    printf '\n'
    return 0
  fi

  "$@"
}

append_line_if_missing() {
  local line="$1"
  local file="$2"

  mkdir -p "$(dirname "$file")"
  touch "$file"

  if ! grep -Fqx "$line" "$file"; then
    printf '\n%s\n' "$line" >>"$file"
  fi
}

replace_or_append_line() {
  local pattern="$1"
  local replacement="$2"
  local file="$3"
  local tmp_file="$file.tmp.$$"
  local found=0
  local line

  mkdir -p "$(dirname "$file")"
  touch "$file"

  : >"$tmp_file"

  while IFS= read -r line || [ -n "$line" ]; do
    if printf '%s\n' "$line" | grep -Eq "$pattern"; then
      if [ "$found" -eq 0 ]; then
        printf '%s\n' "$replacement" >>"$tmp_file"
        found=1
      fi
    else
      printf '%s\n' "$line" >>"$tmp_file"
    fi
  done <"$file"

  if [ "$found" -eq 0 ]; then
    printf '\n%s\n' "$replacement" >>"$tmp_file"
  fi

  mv "$tmp_file" "$file"
}

remove_lines_matching() {
  local pattern="$1"
  local file="$2"
  local tmp_file="$file.tmp.$$"
  local line

  touch "$file"
  : >"$tmp_file"

  while IFS= read -r line || [ -n "$line" ]; do
    if ! printf '%s\n' "$line" | grep -Eq "$pattern"; then
      printf '%s\n' "$line" >>"$tmp_file"
    fi
  done <"$file"

  mv "$tmp_file" "$file"
}

install_rosetta() {
  if [ "$(uname -m)" != "arm64" ]; then
    return 0
  fi

  if pkgutil --pkg-info=com.apple.pkg.RosettaUpdateAuto >/dev/null 2>&1; then
    print_status "$COLOR_DIM" '[skip]' 'Rosetta 2 already installed'
    return 0
  fi

  print_status "$COLOR_CYAN" '[install]' 'Rosetta 2'
  if run_cmd softwareupdate --install-rosetta --agree-to-license; then
    print_status "$COLOR_GREEN" '[ok]' 'Rosetta 2'
  else
    record_failure 'Rosetta 2'
  fi
}

ensure_homebrew() {
  if command -v brew >/dev/null 2>&1; then
    print_status "$COLOR_DIM" '[skip]' 'Homebrew already installed'
    return 0
  fi

  print_status "$COLOR_CYAN" '[install]' 'Homebrew'
  if [ "$DRY_RUN" = '1' ]; then
    run_cmd env INTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    print_status "$COLOR_GREEN" '[ok]' 'Homebrew'
    return 0
  fi

  if [ -r /dev/tty ]; then
    if env INTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" </dev/tty; then
      print_status "$COLOR_GREEN" '[ok]' 'Homebrew'
      return 0
    fi
  elif run_cmd env INTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
    print_status "$COLOR_GREEN" '[ok]' 'Homebrew'
    return 0
  fi

  {
    warn 'Homebrew installation failed; cannot continue'
    exit 1
  }
}

configure_homebrew_shellenv() {
  local brew_prefix
  brew_prefix="$(brew --prefix)"

  append_line_if_missing "eval \"\$(${brew_prefix}/bin/brew shellenv)\"" "$HOME/.zprofile"
  # shellcheck disable=SC1090
  eval "$("${brew_prefix}/bin/brew" shellenv)"

  export HOMEBREW_NO_ANALYTICS=1
  run_cmd brew analytics off >/dev/null 2>&1 || true
}

brew_install_formula() {
  local formula="$1"

  if brew list --formula "$formula" >/dev/null 2>&1; then
    print_status "$COLOR_DIM" '[skip]' "formula $formula"
    return 0
  fi

  print_status "$COLOR_CYAN" '[install]' "formula $formula"
  if run_cmd brew install "$formula"; then
    print_status "$COLOR_GREEN" '[ok]' "formula $formula"
  else
    record_failure "brew formula $formula"
  fi
}

brew_install_cask() {
  local cask="$1"

  if brew list --cask "$cask" >/dev/null 2>&1; then
    print_status "$COLOR_DIM" '[skip]' "cask $cask"
    return 0
  fi

  print_status "$COLOR_CYAN" '[install]' "cask $cask"
  if run_cmd brew install --cask "$cask"; then
    print_status "$COLOR_GREEN" '[ok]' "cask $cask"
  else
    record_failure "brew cask $cask"
  fi
}

install_grouped_formulas() {
  group 'Core CLI'
  local core_cli=(bat coreutils eza fd fzf jq ripgrep shellcheck tmux wget zoxide)
  local item
  for item in "${core_cli[@]}"; do
    brew_install_formula "$item"
  done

  group 'Development Tooling'
  local dev_tools=(ffmpeg gh git git-delta mas mise pnpm uv zsh-autosuggestions zsh-completions zsh-syntax-highlighting)
  if [ "$PROMPT_VARIANT" = 'starship' ]; then
    dev_tools+=(starship)
  fi
  for item in "${dev_tools[@]}"; do
    brew_install_formula "$item"
  done
}

install_oh_my_zsh() {
  if [ -d "$HOME/.oh-my-zsh" ]; then
    print_status "$COLOR_DIM" '[skip]' 'oh-my-zsh'
    return 0
  fi

  print_status "$COLOR_CYAN" '[install]' 'oh-my-zsh'
  if [ "$DRY_RUN" = '1' ]; then
    run_cmd sh -c "
      export RUNZSH=no
      export CHSH=no
      export KEEP_ZSHRC=yes
      curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh | sh
    "
    print_status "$COLOR_GREEN" '[ok]' 'oh-my-zsh'
    return 0
  fi

  if RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended; then
    print_status "$COLOR_GREEN" '[ok]' 'oh-my-zsh'
  else
    record_failure 'oh-my-zsh'
  fi
}

install_powerlevel10k() {
  local theme_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"

  if [ -d "$theme_dir" ]; then
    print_status "$COLOR_DIM" '[skip]' 'powerlevel10k'
    return 0
  fi

  print_status "$COLOR_CYAN" '[install]' 'powerlevel10k'
  if run_cmd git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$theme_dir"; then
    print_status "$COLOR_GREEN" '[ok]' 'powerlevel10k'
  else
    record_failure 'powerlevel10k'
  fi
}

configure_powerlevel10k_shell() {
  replace_or_append_line '^ZSH_THEME=.*$' 'ZSH_THEME="powerlevel10k/powerlevel10k"' "$HOME/.zshrc"
  append_line_if_missing 'plugins+=(git zsh-autosuggestions zsh-syntax-highlighting)' "$HOME/.zshrc"
  append_line_if_missing 'source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh' "$HOME/.zshrc"
  append_line_if_missing 'source $(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh' "$HOME/.zshrc"
  print_status "$COLOR_GREEN" '[ok]' 'Powerlevel10k shell integration updated'
}

configure_starship_shell() {
  remove_lines_matching '^ZSH_THEME="powerlevel10k/powerlevel10k"$' "$HOME/.zshrc"
  append_line_if_missing 'eval "$(starship init zsh)"' "$HOME/.zshrc"
  print_status "$COLOR_GREEN" '[ok]' 'Starship shell integration updated'
}

install_shell_prompt() {
  section 'Shell Integration'
  install_oh_my_zsh

  if [ "$PROMPT_VARIANT" = 'starship' ]; then
    configure_starship_shell
    return 0
  fi

  install_powerlevel10k
  configure_powerlevel10k_shell
}

install_grouped_casks() {
  local item

  group 'Window Managers and Launchers'
  local ui_shell=(aerospace ghostty iterm2 karabiner-elements maccy raycast rectangle stats wezterm)
  for item in "${ui_shell[@]}"; do
    brew_install_cask "$item"
  done

  group 'Browsers'
  local browsers=(brave-browser firefox firefox@nightly google-chrome helium-browser orion zen)
  for item in "${browsers[@]}"; do
    brew_install_cask "$item"
  done

  group 'Editors and AI Tools'
  local editors_ai=(claude claude-code cmux codex-app httpie httpie-desktop obsidian visual-studio-code zed)
  for item in "${editors_ai[@]}"; do
    brew_install_cask "$item"
  done

  group 'Containers and Virtualization'
  local containers=(container docker docker-desktop orbstack raspberry-pi-imager utm)
  for item in "${containers[@]}"; do
    brew_install_cask "$item"
  done

  group 'Productivity and Utilities'
  local productivity=(1password@7 anydesk balenaetcher disk-inventory-x dropbox font-meslo-lg-nerd-font imageoptim protonvpn simple-comic the-unarchiver transmission unetbootin)
  for item in "${productivity[@]}"; do
    brew_install_cask "$item"
  done

  group 'Media and Creative'
  local media=(dosbox-x-app fujifilm-tether-app fujifilm-x-raw-studio gog-galaxy handbrake handbrake-app iina ilok-license-manager scummvm-app sonos spotify steam vlc)
  for item in "${media[@]}"; do
    brew_install_cask "$item"
  done
}

install_mise_languages() {
  section 'Language Runtimes'
  append_line_if_missing 'eval "$(mise activate zsh)"' "$HOME/.zshrc"

  local tools=(
    'python@latest'
    'node@lts'
    'ruby@latest'
  )
  local tool

  for tool in "${tools[@]}"; do
    print_status "$COLOR_CYAN" '[install]' "runtime $tool"
    if run_cmd mise use -g "$tool"; then
      print_status "$COLOR_GREEN" '[ok]' "runtime $tool"
    else
      record_failure "mise runtime $tool"
    fi
  done
}

install_app_store_app() {
  local app_id="$1"
  local name="$2"

  if [ "$SKIP_APP_STORE" = "1" ]; then
    print_status "$COLOR_DIM" '[skip]' "App Store $name"
    return 0
  fi

  if ! command -v mas >/dev/null 2>&1; then
    record_failure 'mas utility unavailable'
    return 0
  fi

  if ! mas account >/dev/null 2>&1; then
    warn 'Not signed into the Mac App Store; skipping App Store installs'
    SKIP_APP_STORE=1
    return 0
  fi

  if mas list | grep -Fq "$name"; then
    print_status "$COLOR_DIM" '[skip]' "App Store $name"
    return 0
  fi

  print_status "$COLOR_CYAN" '[install]' "App Store $name"
  if run_cmd mas install "$app_id"; then
    print_status "$COLOR_GREEN" '[ok]' "App Store $name"
  else
    record_failure "App Store app $name"
  fi
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --skip-app-store)
        SKIP_APP_STORE=1
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        warn "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
    shift
  done
}

main() {
  setup_ui
  parse_args "$@"

  if [ "$(uname -s)" != 'Darwin' ]; then
    warn 'This script is intended for macOS only'
    exit 1
  fi

  banner 'macOS Development Setup'
  section 'System Preparation'
  install_rosetta
  ensure_homebrew
  configure_homebrew_shellenv

  section 'Homebrew Update'
  print_status "$COLOR_CYAN" '[install]' 'brew update'
  if run_cmd brew update; then
    print_status "$COLOR_GREEN" '[ok]' 'brew update'
  else
    record_failure 'brew update'
  fi

  section 'Homebrew Formulas'
  install_grouped_formulas

  section 'Homebrew Applications'
  install_grouped_casks

  install_mise_languages

  section 'Mac App Store'
  local app_store_apps=(
    '497799835:Xcode'
    '904280696:Things'
    '1091189122:Bear'
  )
  local item
  for item in "${app_store_apps[@]}"; do
    install_app_store_app "${item%%:*}" "${item#*:}"
  done

  append_line_if_missing 'eval "$(zoxide init zsh)"' "$HOME/.zshrc"
  install_shell_prompt

  if [ "${#FAILED_ITEMS[@]}" -gt 0 ]; then
    section 'Completed With Failures'
    printf '%s' "$COLOR_YELLOW"
    printf 'The following installs did not complete:\n'
    printf '%s\n' "$COLOR_RESET"
    printf ' - %s\n' "${FAILED_ITEMS[@]}" >&2
    exit 0
  fi

  section 'Completed'
  print_status "$COLOR_GREEN" '[ok]' 'Setup completed successfully'
}

main "$@"
