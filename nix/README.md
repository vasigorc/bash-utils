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

## modules

### default.nix

Very important: this module requires that you use a zsh setup. Please follow the installation requirements
before using this module:

- [Install zsh](https://github.com/ohmyzsh/ohmyzsh/wiki/Installing-ZSH#install-and-set-up-zsh-as-default)
- [Install oh-my-zsh](https://ohmyz.sh/#install)
- [Install zsh-nix-shell](https://github.com/chisui/zsh-nix-shell?tab=readme-ov-file#installation)

Don't worry if you don't feel like using this module, despite what its name may convey - it is completely optional.

This includes basic utilites that are likely to be used with any project.

to run this, copy `default.nix` into any directory and just run nix shell:

```shell
nix-shell
# doing some tests: ohmyzsh + zsh are used
➜  nix git:(main) ✗ git ls-files --others --exclude-standard
default.nix
# silver-search is working
➜  nix git:(main) ✗ ag nix
default.nix
1:{ pkgs ? import (fetchtarball "https://github.com/nixos/nixpkgs/archive/06278c77b5d162e62df170fec307e83f1812d94b.tar.gz") {} }:
```

### compiled.nix

this module includes technologies that:
- allow writing modern memory-safe native code
- packaging and shipping this code with webassembly

to run this module in isolation you could do:

```shell
nix-shell compiled.nix
these 177 paths will be fetched (877.03 mib download, 3473.07 mib unpacked):
...
info: using existing install for 'stable-x86_64-unknown-linux-gnu'
info: default toolchain set to 'stable-x86_64-unknown-linux-gnu'

  stable-x86_64-unknown-linux-gnu unchanged - rustc 1.79.0 (129f3b996 2024-06-10)
...
# testing a few of the installed nix packages
[nix-shell:~/repos/bash-utils/nix]$ cargo --version
cargo 1.79.0 (ffa9cf99a 2024-06-03)

[nix-shell:~/repos/bash-utils/nix]$ emcc --help | head -5
emscripten compiler frontend (emcc)
***********************************

the emscripten compiler frontend ("emcc") is used to call the
emscripten compiler from the command line. it is effectively a drop-in
exception ignored in: <_io.textiowrapper name='<stdout>' mode='w' encoding='utf-8'>
brokenpipeerror: [errno 32] broken pipe

[nix-shell:~/repos/bash-utils/nix]$ zig version
0.9.1
```

### js.nix

this modules is intended for use with js/ts projects:

```shell
nix-shell js.nix
...
[nix-shell:~/repos/learning-nix/wasm_snake_game_udemy]$ npm --version
8.19.2
```

### nvim.nix

please make sure that you have a valid `~/.config/nvim` directory on your machine. [nvim-module.nix](nvim-module.nix) will try to read
configurations from there via `xdg_config_home`.

```shell
~/repos/bash-utils/nix/dynamic-nix-shell.sh compiled js nvim
unpacking 'https://github.com/nixos/nixpkgs/archive/4e96537f163fad24ed9eb317798a79afc85b51b7.tar.gz' into the git cache...
info: using existing install for 'stable-x86_64-unknown-linux-gnu'
info: default toolchain set to 'stable-x86_64-unknown-linux-gnu'

  stable-x86_64-unknown-linux-gnu unchanged - rustc 1.79.0 (129f3b996 2024-06-10)


[nix-shell:~/repos/wasm_snake_game_udemy]$ nvim
```

after this `nvim` would be able to connect to a running lsp (`tsserver`, `rust_analyzer`) from your project.

Also for `git` support to properly to work, either install `lazygit` manually, or rely to the package brought
by this module, but either way ensure to have a config file for `lazygit` (see [instructions](https://github.com/jesseduffield/lazygit/blob/master/docs/Config.md#user-config)).

You may use the [config file](./../lazygit/config.yaml) from this repository, so for Linux you could do:

```shell
curl -sSf https://raw.githubusercontent.com/vasigorc/bash-utils/main/lazygit/config.yaml ~/.config/lazygit/config.yml
```

### platform.nix

This module currently contains Docker and Docker compose packages, but it is intended to host other Platform / DevOps
dependencies such as AWS CLI, Terraform, Kubernetes, etc.

### python.nix

This may evolve into a `ml.nix` eventually, however, for now we will keep this labeled as `python.nix`. A few of the dependencies that we couldn't add:

- [Max](https://www.modular.com/max) is a proprietary platform
- [Mojo](https://docs.modular.com/mojo/manual/) doesn't have a Nix package. We could install it manually with Nix's `mkDerivation` in the future
- A few typical Python ML libraries, like PyTorch, TensorFlow, or even NumPy I think is better to manage on project level via `conda` or `pip`

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

## Automatically use project specific environment

In order to automatically use project specific environment, you can use the following setup:

1. Install [direnv](https://direnv.net/)

   ```shell
   nix-env -iA nixpkgs.direnv nixpkgs.nix-direnv
   ```
   
2. Add the following line to your `~/.zshrc` file:

   ```shell
   eval "$(direnv hook zsh)"
   ```
   
3. Reload your shell configuration:

   ```shell
   source ~/.zshrc
   ```
   
4. Add an `.envrc` file to your project root directory specifying the modules you want to use, for example:

   ```shell
   use nix ~/repos/bash-utils/nix/combined.nix
   ```
  
5. Run `direnv allow` to enable the environment.

## Dynamically choosing modules that you want to pick for your environment

```shell
./dynamic-nix-shell.sh compiled js
```

Instead of `js` and `compiled` (or with either/ both of them) you may choose any other module available in this directory (any file ending in `-module.nix`).
