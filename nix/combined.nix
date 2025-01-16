{ pkgs ? import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/06278c77b5d162e62df170fec307e83f1812d94b.tar.gz") {} }:

let
  compiled = import ./compiled-module.nix { inherit pkgs; };
  default = import ./default-module.nix { inherit pkgs; };
  js = import ./js-module.nix { inherit pkgs; };
in
pkgs.mkShell {
  buildInputs = compiled.buildInputs ++ default.buildInputs ++ js.buildInputs;
  shellHook = compiled.shellHook + default.shellHook + js.shellHook;
}
