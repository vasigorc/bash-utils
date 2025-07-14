{ pkgs ? import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/650e572363c091045cdbc5b36b0f4c1f614d3058.tar.gz") {} }:

let
  shellConfig = import ./default-module.nix { inherit pkgs; };
in
pkgs.mkShell shellConfig
