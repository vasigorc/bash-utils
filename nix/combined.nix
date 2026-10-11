{
  pkgs ?
    import
      (fetchTarball "https://github.com/NixOS/nixpkgs/archive/7c8764b7c7b09b34f632464276218ef9090eaa11.tar.gz")
      {
        config.allowUnfree = true;
      },
}:

let
  compiled = import ./compiled-module.nix { inherit pkgs; };
  default = import ./default-module.nix { inherit pkgs; };
  js = import ./js-module.nix { inherit pkgs; };
  platform = import ./platform-module.nix { inherit pkgs; };
  python = import ./python-module.nix { inherit pkgs; };
  jvm = import ./jvm-module.nix { inherit pkgs; };
  asciidoc = import ./asciidoc-module.nix { inherit pkgs; };
  nvim = import ./nvim-module.nix { inherit pkgs; };
  sqls = import ./sql-module.nix { inherit pkgs; };
  ruby = import ./ruby-module.nix { inherit pkgs; };
in
pkgs.mkShell {
  buildInputs =
    compiled.buildInputs
    ++ default.buildInputs
    ++ js.buildInputs
    ++ platform.buildInputs
    ++ python.buildInputs
    ++ jvm.buildInputs
    ++ asciidoc.buildInputs
    ++ nvim.buildInputs
    ++ sqls.buildInputs
    ++ ruby.buildInputs;
  shellHook =
    compiled.shellHook
    + default.shellHook
    + js.shellHook
    + python.shellHook
    + jvm.shellHook
    + asciidoc.shellHook
    + nvim.shellHook
    + sqls.shellHook;
}
