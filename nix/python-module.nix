{ pkgs }:

let
  # Determine if we're running on Darwin (macOS)
  isDarwin = pkgs.stdenv.isDarwin;
  isAppleSilicon = pkgs.stdenv.isAarch64 && isDarwin;

  # Create a list of Python packages, conditionally including conda
  pythonPackages = with pkgs; [
    # Core Python installation
    python312

    # Package managers and virtual environment tools
    python312Packages.pip
    python312Packages.virtualenv
  ]
  # Conditionally add conda only for non-Darwin platforms
  ++ (if isDarwin then [] else [ pkgs.conda ]);
in
{
  buildInputs = pythonPackages ++ (with pkgs; [
    # package and project manager for Python (written in Rust)
    uv
    # Development tools
    python312Packages.ipython
  ] ++ lib.optional (!isAppleSilicon) python312Packages.jupyter ++ [
    python313Packages.huggingface-hub

    # LSP tools
    pyright
    python312Packages.ruff

    # Build dependencies
    gcc
    pkg-config

    # Useful for scientific/ML builds
    openssl
    zlib
  ]);

  shellHook = ''
    # Set up core Python paths
    export PYTHONPATH="$PYTHONPATH:${pkgs.python312}/lib/python3.12/site-packages"

    # Better Python REPL experience
    export PYTHONSTARTUP="$HOME/.pythonrc"

    # Ensure pip uses per-project virtual environments by default
    export PIP_REQUIRE_VIRTUALENV=true

    echo "Python development environment ready!"
    echo "Python $(python --version) is available"
    '';
}
