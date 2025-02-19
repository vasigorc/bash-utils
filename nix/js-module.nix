{ pkgs }:

{
  buildInputs = with pkgs; [
    # Node.js and basic tools
    nodejs
    nodePackages.yo

    # Typescript
    nodePackages.typescript
    nodePackages.typescript-language-server
    nodePackages.ts-node # For direct TS execution

    nodePackages.eslint
    nodePackages.prettier

    # Deno
    deno
  ];

  shellHook = ''
    # You can add any Node.js-specific environment setup here
    export NODE_PATH="$NODE_PATH:${pkgs.nodePackages.prettier}/lib/node_modules"
    export NODE_PATH="$NODE_PATH:${pkgs.nodePackages.eslint}/lib/node_modules"

    # TypeScript paths
    export NODE_PATH="$NODE_PATH:${pkgs.nodePackages.typescript}/lib/node_modules"

    # Ensure deno cache directory exists
    export DENO_DIR="$HOME/.cache/deno"
    mkdir -p "$DENO_DIR"

    echo "JavaScript/TypeScript development environment activated!"
    echo "Node.js $(node --version) is available"
    echo "TypeScript $(tsc --version) is available"
    if command -v deno >/dev/null 2>&1; then
      echo "Deno $(deno --version) is available"
    else
      echo "Warning: Deno installation not found in PATH"
    fi
  '';
}
