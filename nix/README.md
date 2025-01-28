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

## Confirm Nix is installed

Don't forget to check that you have Nix installed:

```shell
curl -L https://nixos.org/nix/install | sh -s -- --daemon
nix --version
```

## Modules

### default.nix

This includes basic utilites that are likely to be used with any project.

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

### compiled.nix

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

### js.nix

This modules is intended for use with JS/TS projects:

```shell
nix-shell js.nix
...
[nix-shell:~/repos/learning-nix/wasm_snake_game_udemy]$ npm --version
8.19.2
```

### nvim.nix

Please make sure that you have a valid `~/.config/nvim` directory on your local. [nvim-module.nix](nvim-module.nix) will try to read
configurations from there via `XDG_CONFIG_HOME`. 

```shell
~/repos/bash-utils/nix/dynamic-nix-shell.sh compiled js nvim
unpacking 'https://github.com/NixOS/nixpkgs/archive/4e96537f163fad24ed9eb317798a79afc85b51b7.tar.gz' into the Git cache...
info: using existing install for 'stable-x86_64-unknown-linux-gnu'
info: default toolchain set to 'stable-x86_64-unknown-linux-gnu'

  stable-x86_64-unknown-linux-gnu unchanged - rustc 1.79.0 (129f3b996 2024-06-10)


[nix-shell:~/repos/wasm_snake_game_udemy]$ nvim
```

After this `nvim` would be able to connect to a running LSP (`tsserver`, `rust_analyzer`) from your project.


## Updating Nix stable version

Versions of the packaged software packages depend on the underlying "pinned" Nix packages version.

Feel free to use [NIXOS_VERSION](NIXOS_VERSION) file to update to the desired (intended latest) stable version. To do so, just update this line in the mentioned file:

```shell
NIXOS_VERSION="24.11"  # Can be changed when new stable versions come out
```

and run the [update-nix-pins.sh](./update-nix-pins.sh) script. Below is the approximate expected output:

```shell
./update-nix-pins.sh
Current directory contents:
Finding Nix files to update...
Found: ./combined.nix
Found: ./default.nix
Found: ./compiled.nix
Found: ./js.nix
Do you want to update these files to use nixos-24.11 (commit: e24b4c09e963677b1beea49d411cd315a024ad3a)? (y/n) y
Updating ./combined.nix...
Updating ./default.nix...
Updating ./compiled.nix...
Updating ./js.nix...
Updated Nix files to use commit e24b4c09e963677b1beea49d411cd315a024ad3a

Verifying changes:

./combined.nix contains:
{ pkgs ? import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/e24b4c09e963677b1beea49d411cd315a024ad3a.tar.gz") {} }:


./default.nix contains:
{ pkgs ? import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/e24b4c09e963677b1beea49d411cd315a024ad3a.tar.gz") {} }:


./compiled.nix contains:
{ pkgs ? import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/e24b4c09e963677b1beea49d411cd315a024ad3a.tar.gz") {} }:


./js.nix contains:
{ pkgs ? import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/e24b4c09e963677b1beea49d411cd315a024ad3a.tar.gz") {} }:
```

## Running all modules together

```shell
nix-shell combined.nix
```

## Dynamically choosing modules that you want to pick for your environment

```shell
./dynamic-nix-shell.sh compiled js
```

Instead of `js` and `compiled` (or with either/ both of them) you may choose any other module available in this directory (any file ending in `-module.nix`).
