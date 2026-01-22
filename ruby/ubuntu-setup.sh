#!/usr/bin/env bash
set -euo pipefail

# Ruby development environment setup for Ubuntu 24.04
# Idempotent - safe to run multiple times

RUBY_VERSION="${1:-3.3.0}"

echo "==> Installing system dependencies..."
sudo apt update
sudo apt install -y \
  git curl \
  libssl-dev libreadline-dev zlib1g-dev \
  autoconf bison build-essential \
  libyaml-dev libncurses5-dev libffi-dev \
  libgdbm6 libgdbm-dev libdb-dev

echo "==> Setting up rbenv..."
if [[ ! -d "$HOME/.rbenv" ]]; then
  git clone https://github.com/rbenv/rbenv.git ~/.rbenv
else
  echo "    rbenv already installed, updating..."
  git -C ~/.rbenv pull --quiet
fi

if [[ ! -d "$HOME/.rbenv/plugins/ruby-build" ]]; then
  git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
else
  echo "    ruby-build already installed, updating..."
  git -C ~/.rbenv/plugins/ruby-build pull --quiet
fi

# Ensure rbenv is in PATH for this script
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init - bash)"

echo "==> Configuring shell..."
SHELL_RC="$HOME/.zshrc"
RBENV_PATH_LINE='export PATH="$HOME/.rbenv/bin:$PATH"'
RBENV_INIT_LINE='eval "$(rbenv init - zsh)"'

grep -qxF "$RBENV_PATH_LINE" "$SHELL_RC" 2>/dev/null || echo "$RBENV_PATH_LINE" >>"$SHELL_RC"
grep -qxF "$RBENV_INIT_LINE" "$SHELL_RC" 2>/dev/null || echo "$RBENV_INIT_LINE" >>"$SHELL_RC"

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
echo "    rbenv:     $(rbenv --version)"
echo "    ruby:      $(ruby --version)"
echo "    solargraph: $(solargraph --version)"

echo "==> Done! Restart your shell or run: source ~/.zshrc"
