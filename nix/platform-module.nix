{ pkgs }:

{
  buildInputs = with pkgs; [
# Docker and related tools
    docker
      docker-compose
  ];

  shellHook = ''
    '';
}
