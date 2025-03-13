{ pkgs }:

{
  buildInputs = with pkgs; [
    # AsciidoctorJ dependencies
    curl
    unzip
    jre  # Java Runtime Environment
  ];

  shellHook = ''
    # AsciidoctorJ installation
    ASCIIDOCTORJ_VERSION="2.5.7"
    ASCIIDOCTORJ_DIR="$HOME/.local/share/asciidoctorj-$ASCIIDOCTORJ_VERSION"
    
    if [ ! -d "$ASCIIDOCTORJ_DIR" ]; then
      echo "Installing AsciidoctorJ $ASCIIDOCTORJ_VERSION..."
      mkdir -p "$HOME/.local/share"
      
      # Download with verbose output and follow redirects
      echo "Downloading AsciidoctorJ $ASCIIDOCTORJ_VERSION..."
      curl -L -v "http://search.maven.org/remotecontent?filepath=org/asciidoctor/asciidoctorj/$ASCIIDOCTORJ_VERSION/asciidoctorj-$ASCIIDOCTORJ_VERSION-bin.zip" -o "/tmp/asciidoctorj.zip"
      
      # Check if download was successful
      if [ -s "/tmp/asciidoctorj.zip" ]; then
        echo "Download complete. Unzipping..."
        unzip -q "/tmp/asciidoctorj.zip" -d "$HOME/.local/share/"
        
        # Verify the directory structure
        if [ -f "$HOME/.local/share/asciidoctorj-$ASCIIDOCTORJ_VERSION/bin/asciidoctorj" ]; then
          echo "AsciidoctorJ unpacked successfully."
          chmod +x "$HOME/.local/share/asciidoctorj-$ASCIIDOCTORJ_VERSION/bin/asciidoctorj"
        else
          echo "Warning: Expected AsciidoctorJ executable not found at $HOME/.local/share/asciidoctorj-$ASCIIDOCTORJ_VERSION/bin/asciidoctorj"
          echo "Listing extracted contents:"
          find "$HOME/.local/share" -name "asciidoctorj*" -type f | head -n 10
        fi
        
        rm "/tmp/asciidoctorj.zip"
      else
        echo "Download failed. File is empty or does not exist."
        exit 1
      fi
      
      # Create a convenient wrapper script
      mkdir -p "$HOME/.local/bin"
      cat > "$HOME/.local/bin/asciidoctorj" << EOF
#!/bin/bash
# Check if the AsciidoctorJ executable exists
if [ ! -f "$ASCIIDOCTORJ_DIR/bin/asciidoctorj" ]; then
  echo "Error: AsciidoctorJ executable not found at $ASCIIDOCTORJ_DIR/bin/asciidoctorj"
  echo "Please ensure AsciidoctorJ is properly installed."
  exit 1
fi

# Execute AsciidoctorJ with all arguments passed to this script
$ASCIIDOCTORJ_DIR/bin/asciidoctorj "\$@"
EOF
      chmod +x "$HOME/.local/bin/asciidoctorj"
    fi
    
    # Add AsciidoctorJ to PATH
    export PATH="$PATH:$ASCIIDOCTORJ_DIR/bin:$HOME/.local/bin"
    
    echo "AsciidoctorJ $ASCIIDOCTORJ_VERSION is available"
  '';
}