{ pkgs }:

let
  # Determine if we're running on Darwin (macOS)
  isDarwin = pkgs.stdenv.isDarwin;

  # Create a list of Python packages, conditionally including conda
  pythonPackages = with pkgs; [
    # Core Python installation
    python311

    # Package managers and virtual environment tools
    python311Packages.pip
    python311Packages.virtualenv
  ]
  # Conditionally add conda only for non-Darwin platforms
  ++ (if isDarwin then [] else [ pkgs.conda ]);
in
{
  buildInputs = pythonPackages ++ (with pkgs; [
    # package and project manager for Python (written in Rust)
    uv
    # Development tools
    python311Packages.ipython
    python311Packages.jupyter
    python313Packages.huggingface-hub

    # LSP tools
    pyright
    python311Packages.ruff

    # Build dependencies
    gcc
    pkg-config

    # Useful for scientific/ML builds
    openssl
    zlib
  ]);

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
