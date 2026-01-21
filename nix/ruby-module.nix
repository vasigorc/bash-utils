{ pkgs }:

{
  buildInputs = with pkgs; [
    ruby_3_4
    rubyPackages_3_4.ruby-lsp
    rubocop
  ];

  shellHook = '''';
}
