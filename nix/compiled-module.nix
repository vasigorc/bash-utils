{ pkgs }:

{
  buildInputs = with pkgs; [
    wabt               # WebAssembly Binary Toolkit, includes wat2wasm
    wasmer             # Wasmer runtime for running WebAssembly
    gcc                # GNU Compiler Collection
    gnumake            # Build tool
    emscripten         # WebAssembly compilation
    zig                # Zig programming language
    clang              # c/C++ compiler from LLVM
    llvmPackages.llvm  # Complete LLVM toolchain, includes clang
    rustup             # Rustup for Rust and Cargo
  ];

  shellHook = ''
    # Ensure rustup is initialized
    rustup default stable

    # Add nightly toolchain if not present
    if ! rustup toolchain list | grep -q "nightly"; then
    rustup toolchain install nightly
    fi

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

    # Add required targets for nightly toolchain if not present
    check_and_add_target "wasm32-unknown-unknown" "nightly"
    check_and_add_target "wasm32-unknown-unknown" "stable"
    check_and_add_target "wasm32-wasi" "nightly"
    check_and_add_target "wasm32-wasi" "stable"
    
    # Add required components for nightly toolchain if not present
    check_and_add_component "rustfmt" "stable"
    check_and_add_component "rustfmt" "nightly"
    '';
}
