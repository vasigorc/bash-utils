{ pkgs ? import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/06278c77b5d162e62df170fec307e83f1812d94b.tar.gz") {} }:

pkgs.mkShell {
  buildInputs = [
    pkgs.wabt               # WebAssembly Binary Toolkit, includes wat2wasm
    pkgs.wasmer             # Wasmer runtime for running WebAssembly
    pkgs.gcc                # GNU Compiler Collection
    pkgs.gnumake            # Build tool
    pkgs.emscripten         # WebAssembly compilation
    pkgs.zig                # Zig programming language
    pkgs.llvmPackages.llvm  # Complete LLVM toolchain, includes clang
    pkgs.rustup             # Rustup for Rust and Cargo
  ];

  shellHook = ''
    # Ensure rustup is initialized
    rustup default stable
  '';
}
