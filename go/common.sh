#!/bin/bash

# Common development workflow
go fmt ./...        # Format code
go vet ./...        # Detect potential issues
go mod verify       # Verify dependencies
go mod tidy         # Clean dependencies
go test ./...       # Run tests
go build ./...      # Build all packages
go get github.com/some/package@v1.2.3  # Install package
