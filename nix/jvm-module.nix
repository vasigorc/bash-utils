{ pkgs }:

{
  buildInputs = with pkgs; [
    # Base JVM tools
    coursier
    metals
    
    # Required for SDKMAN installation
    curl
    which
    unzip
    zip
    gawk
  ];

  shellHook = ''
    # Install SDKMAN if not already installed
    export SDKMAN_DIR="$HOME/.sdkman"
    if [ ! -d "$SDKMAN_DIR" ]; then
      echo "Installing SDKMAN..."
      curl -s "https://get.sdkman.io" | bash
    fi
    
    # Source SDKMAN
    [ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ] && source "$SDKMAN_DIR/bin/sdkman-init.sh"
    
    # Install Java 17 (Temurin) if not installed
    if ! sdk list java | grep -q "installed" | grep -q "tem-17"; then
      echo "Installing Temurin Java 17..."
      sdk install java 17.0.9-tem
    fi
    
    # Set Java 17 as default
    sdk default java 17.0.9-tem
    
    # Install Scala 2.13.16 specifically
    if ! sdk list scala | grep -q "installed" | grep -q "2.13.16"; then
      echo "Installing Scala 2.13.16..."
      sdk install scala 2.13.16
    fi
    
    # Set Scala 2.13.16 as default
    sdk default scala 2.13.16
    
    # Install the latest SBT
    if ! command -v sbt > /dev/null || ! sdk list sbt | grep -q "\*"; then
      echo "Installing latest SBT..."
      # Force installation of the latest SBT
      yes | sdk install sbt
      
      # Make sure sbt is in PATH
      export PATH=$PATH:$HOME/.sdkman/candidates/sbt/current/bin
      
      # Check if installation was successful
      if command -v sbt > /dev/null; then
        echo "SBT installed successfully. Version: $(sbt --script-version)"
      else
        echo "WARNING: SBT installation may have failed. Please check manually."
      fi
    else
      echo "SBT is already installed."
    fi
    
    # Add coursier and metals to PATH
    export PATH=$PATH:$HOME/.local/share/coursier/bin
  '';
}