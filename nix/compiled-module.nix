{ pkgs }:

{
  buildInputs = with pkgs; [
    wabt               # WebAssembly Binary Toolkit, includes wat2wasm
    wasmer             # Wasmer runtime for running WebAssembly
    wasmtime           # Another backend WebAssembly runtime from Mozilla, more widely adopted than wasmer
    wasm-pack          # Rust-generated WebAssembly building, packaging and publishing tool
    gcc                # GNU Compiler Collection
    gnumake            # Build tool
    emscripten         # WebAssembly compilation
    zig                # Zig programming language
    clang              # c/C++ compiler from LLVM
    llvmPackages.llvm  # Complete LLVM toolchain, includes clang
    rustup             # Rustup for Rust and Cargo
    go                 # Go programming language
    gopls              # Go language server
    assemblyscript     # Arguably this could go into js-module.nix too, but I am using it as part of the WebAssembly set-up, which is already gathered in this module
  ];

  shellHook = ''
    # Ensure rustup is initialized
    rustup default stable

    # Function to check and add target for a specific toolchain
    check_and_add_target() {
      local target=$1
      local toolchain=$2
      if ! rustup target list --installed --toolchain $toolchain | grep -q "^$target"; then
      echo "Adding target $target for $toolchain toolchain..."
      rustup target add $target --toolchain $toolchain
      fi
    }

    # Function to check and add component for a specific toolchain
    check_and_add_component() {
      local component=$1
      local toolchain=$2
      
      if ! rustup component list --installed --toolchain $toolchain | grep "^$component"; then
        echo "Adding component $component for $toolchain toolchain..."
        rustup component add $component --toolchain $toolchain
      fi
    }

    # Add required targets and components for stable toolchain
    check_and_add_target "wasm32-unknown-unknown" "stable"
    check_and_add_component "rustfmt" "stable"

    # Only manage nightly toolchain on non-Apple Silicon platforms
    if [[ "$(uname -m)" != "arm64" || "$(uname -s)" != "Darwin" ]]; then
      # Add nightly toolchain if not present
      if ! rustup toolchain list | grep -q "nightly"; then
        rustup toolchain install nightly
      fi
      
      # Add required targets for nightly toolchain if not present
      check_and_add_target "wasm32-unknown-unknown" "nightly"
      check_and_add_target "wasm32-wasip1" "nightly"
    
      # Add required components for nightly toolchain if not present
      check_and_add_component "rustfmt" "nightly"
    fi
    '';
}
