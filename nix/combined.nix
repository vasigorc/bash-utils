{ pkgs ? import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/e24b4c09e963677b1beea49d411cd315a024ad3a.tar.gz") {} }:

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
