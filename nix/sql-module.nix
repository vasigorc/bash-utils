{ pkgs }:

{
  buildInputs = with pkgs; [
    sqlfluff
    postgresql
    sqls
  ];

  shellHook = '''';
}
