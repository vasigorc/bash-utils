{ pkgs ? import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/e24b4c09e963677b1beea49d411cd315a024ad3a.tar.gz") {} }:

let
  shellConfig = import ./asciidoc-module.nix { inherit pkgs; };
in
pkgs.mkShell shellConfig