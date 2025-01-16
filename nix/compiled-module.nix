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
  '';
}
