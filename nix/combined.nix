{ pkgs ? import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/650e572363c091045cdbc5b36b0f4c1f614d3058.tar.gz") {} }:

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
