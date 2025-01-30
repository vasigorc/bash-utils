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
    python311Packages.ipython
    python311Packages.jupyter

    # LSP tools
    pyright
    python311Packages.ruff

    # Build dependencies
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

    echo "Python development environment ready!"
    echo "Python $(python --version) is available"
    '';
}
