#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Installing git hooks...${NC}"

# Make sure .githooks directory exists
if [ ! -d ".githooks" ]; then
    echo -e "${RED}Error: .githooks directory not found${NC}"
    exit 1
fi

# Configure git to use custom hooks directory
git config core.hooksPath .githooks

# Make hooks executable
chmod +x .githooks/pre-commit

echo -e "${GREEN}✅ Git hooks installed successfully${NC}"
echo -e "${BLUE}Hooks will now run automatically on git operations${NC}"