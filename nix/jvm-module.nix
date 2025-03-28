{ pkgs }:

{
  buildInputs = with pkgs; [
    # JDK
    temurin-bin-17

    # Scala ecosystem
    scala_2_13
    sbt
    coursier
    metals

  ];

  shellHook = ''
      # Set JAVA_HOME explicitly
      export JAVA_HOME=${pkgs.temurin-bin-17}

      # Add coursier bin directory to PATH
      export PATH=$PATH:$HOME/.local/share/coursier/bin

      echo "JVM development environment ready with Temurin JDK 17, Scala 2.13, and SBT"
  '';
}