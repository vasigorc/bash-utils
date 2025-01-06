# Nix dev env

Currently I am working on compiling a modularized environment setup for different
languages / frameworks that I may be using:

```shell
/modules
  ├── compiled.nix   # Rust, WASM, Zig, LLVM
  ├── jvm.nix        # SDKMAN, Metals, Kotlin
  ├── ruby.nix       # Ruby, Gems
  ├── ml.nix         # Python, Mojo, Max
  ├── platform.nix   # AWS, Terraform
  ├── default.nix    # Docker, Zsh, JQ, Git, Fzf, etc.
shell.nix
```

## default.nix

So far I only got to my `default.nix`.

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
