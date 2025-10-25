{ pkgs }:

{
  buildInputs = with pkgs; [
    # JDK
    temurin-bin-21

    # Scala ecosystem
    scala_2_13
    sbt
    coursier
    metals

    # Kotlin ecosystem
    kotlin
    vimPlugins.nvim-treesitter-parsers.kotlin
    detekt
    ktfmt
    ktlint

    gradle

  ];

  shellHook = ''
    # Set JAVA_HOME explicitly
    export JAVA_HOME=${pkgs.temurin-bin-21}

    # Add coursier bin directory to PATH
    export PATH=$PATH:$HOME/.local/share/coursier/bin

    echo "JVM development environment ready with Temurin JDK 21, Scala 2.13, and SBT"
  '';
}
