{ pkgs }:

{
  buildInputs = with pkgs; [
    # Docker and related tools
    docker
    docker-compose
    terraform
    tflint
    terraform-docs
    tfsec
  ];

  shellHook = '''';
}
