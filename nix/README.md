# Nix dev env

Currently I am working on compiling a modularized environment setup for different
languages / frameworks that I may be using:

```shell
compiled.nix   # Rust, WASM, Zig, LLVM
jvm.nix        # SDKMAN, Metals, Kotlin
ruby.nix       # Ruby, Gems
ml.nix         # Python, Mojo, Max
platform.nix   # AWS, Terraform
default.nix    # Docker, Zsh, JQ, Git, Fzf, etc.
js.nix         # nvm, npm, yeoman, etc
combined.nix   # All of the above combined
```

## default.nix

This includes basic utilites that are likely to be used with any project.

Don't forget to check that you have Nix installed:

```shell
curl -L https://nixos.org/nix/install | sh -s -- --daemon
nix --version
```

To run this, copy `default.nix` into any directory and just run Nix shell:

```shell
nix-shell
# doing some tests: ohmyzsh + zsh are used
➜  nix git:(main) ✗ git ls-files --others --exclude-standard
default.nix
# silver-search is working
➜  nix git:(main) ✗ ag nix
default.nix
1:{ pkgs ? import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/06278c77b5d162e62df170fec307e83f1812d94b.tar.gz") {} }:
```

## compiled.nix

This module includes technologies that:
- allow writing modern memory-safe native code
- packaging and shipping this code with WebAssembly

To run this module in isolation you could do:

```shell
nix-shell compiled.nix
these 177 paths will be fetched (877.03 MiB download, 3473.07 MiB unpacked):
...
info: using existing install for 'stable-x86_64-unknown-linux-gnu'
info: default toolchain set to 'stable-x86_64-unknown-linux-gnu'

  stable-x86_64-unknown-linux-gnu unchanged - rustc 1.79.0 (129f3b996 2024-06-10)
...
# testing a few of the installed Nix packages
[nix-shell:~/repos/bash-utils/nix]$ cargo --version
cargo 1.79.0 (ffa9cf99a 2024-06-03)

[nix-shell:~/repos/bash-utils/nix]$ emcc --help | head -5
Emscripten Compiler Frontend (emcc)
***********************************

The Emscripten Compiler Frontend ("emcc") is used to call the
Emscripten compiler from the command line. It is effectively a drop-in
Exception ignored in: <_io.TextIOWrapper name='<stdout>' mode='w' encoding='utf-8'>
BrokenPipeError: [Errno 32] Broken pipe

[nix-shell:~/repos/bash-utils/nix]$ zig version
0.9.1
```

## js.nix

This modules is intended for use with JS/TS projects:

```shell
nix-shell js.nix
...
[nix-shell:~/repos/learning-nix/wasm_snake_game_udemy]$ npm --version
8.19.2
```

## combined.nix

Combined all of the above.
