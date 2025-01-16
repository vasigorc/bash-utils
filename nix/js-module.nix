{ pkgs }:

{
  buildInputs = with pkgs; [
    nodejs
    nodePackages.yo
    nodePackages.eslint
    nodePackages.prettier
  ];

  shellHook = ''
    # You can add any Node.js-specific environment setup here
    export NODE_PATH="$NODE_PATH:${pkgs.nodePackages.prettier}/lib/node_modules"
    export NODE_PATH="$NODE_PATH:${pkgs.nodePackages.eslint}/lib/node_modules"
  '';
}
