{ pkgs }:

{
  buildInputs = with pkgs; [
# Core Python installation
    python311

# Package managers and virtual environment tools
      python311Packages.pip
      python311Packages.virtualenv
      conda

# Development tools
      python311Packages.ipython  # Better REPL experience
      python311Packages.jupyter  # Notebook interface

# Build dependencies often needed for pip install
      gcc
      pkg-config

# Useful for scientific/ML builds
      openssl
      zlib
      ];

  shellHook = ''
# Set up core Python paths
    export PYTHONPATH="$PYTHONPATH:${pkgs.python311}/lib/python3.11/site-packages"

# Better Python REPL experience
    export PYTHONSTARTUP="$HOME/.pythonrc"

# Ensure pip uses per-project virtual environments by default
    export PIP_REQUIRE_VIRTUALENV=true

# Create virtual environment if it doesn't exist
    if [ ! -d ".venv" ]; then
      echo "No virtual environment found. You can create one with:"
        echo "  python -m venv .venv"
        echo "  virtualenv .venv"
        echo "  poetry init"
        echo "  conda create -n myenv"
    else
      echo "Virtual environment '.venv' found"
        fi

        echo "Python development environment activated!"
        echo "Python $(python --version) is available"
        echo "Remember to activate your project's virtual environment"
        echo "  source .venv/bin/activate"
        '';
}
