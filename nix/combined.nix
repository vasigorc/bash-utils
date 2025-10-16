{ pkgs ? import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/a493e93b4a259cd9fea8073f89a7ed9b1c5a1da2.tar.gz") {} }:

let
  compiled = import ./compiled-module.nix { inherit pkgs; };
  default = import ./default-module.nix { inherit pkgs; };
  js = import ./js-module.nix { inherit pkgs; };
  platform = import ./platform-module.nix { inherit pkgs; };
  python = import ./python-module.nix { inherit pkgs;};
  jvm = import ./jvm-module.nix { inherit pkgs; };
  asciidoc = import ./asciidoc-module.nix { inherit pkgs; };
  nvim = import ./nvim-module.nix { inherit pkgs; };
in
pkgs.mkShell {
  buildInputs = compiled.buildInputs ++ default.buildInputs ++ js.buildInputs ++ platform.buildInputs ++ python.buildInputs ++ jvm.buildInputs ++ asciidoc.buildInputs ++ nvim.buildInputs;
  shellHook = compiled.shellHook + default.shellHook + js.shellHook + python.shellHook + jvm.shellHook + asciidoc.shellHook + nvim.shellHook;
}
