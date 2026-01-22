#!/usr/bin/env bash
set -euo pipefail

# Ruby development environment setup for macOS (Apple Silicon / Intel)
# Idempotent - safe to run multiple times

RUBY_VERSION="${1:-3.3.0}"

echo "==> Checking for Homebrew..."
if ! command -v brew &>/dev/null; then
  echo "    Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Add Homebrew to PATH for this script (Apple Silicon path)
  if [[ -f "/opt/homebrew/bin/brew" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    eval "$(/usr/local/bin/brew shellenv)"
  fi
else
  echo "    Homebrew already installed"
fi

echo "==> Installing dependencies via Homebrew..."
brew install openssl readline libyaml gmp

echo "==> Setting up rbenv..."
if ! command -v rbenv &>/dev/null; then
  brew install rbenv ruby-build
else
  echo "    rbenv already installed, upgrading..."
  brew upgrade rbenv ruby-build 2>/dev/null || true
fi

# Ensure rbenv is initialized for this script
eval "$(rbenv init - bash)"

echo "==> Configuring shell..."
SHELL_RC="$HOME/.zshrc"
RBENV_INIT_LINE='eval "$(rbenv init - zsh)"'

grep -qxF "$RBENV_INIT_LINE" "$SHELL_RC" 2>/dev/null || echo "$RBENV_INIT_LINE" >>"$SHELL_RC"

# Ensure Homebrew is in shell config (Apple Silicon)
BREW_LINE='eval "$(/opt/homebrew/bin/brew shellenv)"'
if [[ -f "/opt/homebrew/bin/brew" ]]; then
  grep -qxF "$BREW_LINE" "$SHELL_RC" 2>/dev/null || echo "$BREW_LINE" >>"$SHELL_RC"
fi

echo "==> Installing Ruby $RUBY_VERSION..."
if rbenv versions --bare | grep -qx "$RUBY_VERSION"; then
  echo "    Ruby $RUBY_VERSION already installed"
else
  rbenv install "$RUBY_VERSION"
fi

rbenv global "$RUBY_VERSION"

echo "==> Installing gems..."
gem install solargraph --conservative
gem install debug --conservative

echo "==> Verifying installation..."
echo "    rbenv:      $(rbenv --version)"
echo "    ruby:       $(ruby --version)"
echo "    solargraph: $(solargraph --version)"

echo "==> Done! Restart your shell or run: source ~/.zshrc"
