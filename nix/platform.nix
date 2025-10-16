{ pkgs ? import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/a493e93b4a259cd9fea8073f89a7ed9b1c5a1da2.tar.gz") {} }:

let
  shellConfig = import ./platform-module.nix { inherit pkgs; };
in
pkgs.mkShell shellConfig
