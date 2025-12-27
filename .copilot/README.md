# NoteMinds Copilot Configuration

This directory contains configuration and instructions for GitHub Copilot to understand and work effectively with the NoteMinds project.

## Directory Structure

```
.copilot/
├── config.json             # Main configuration file
├── context/               # Project context information
│   ├── project.md         # Project overview and setup
│   ├── architecture.md    # Architecture patterns
│   └── workflows.md       # Development workflows
└── instructions/          # Coding guidelines
    ├── coding.md         # General coding patterns
    ├── testing.md        # Testing guidelines
    └── style.md          # Code style guide
```

## Configuration

The `config.json` file configures:
- Project metadata
- Context sources
- Instruction sources
- Language preferences

## Context Files

Context files provide Copilot with background information about:
- Project structure and setup
- Architecture patterns
- Development workflows
- Technical stack
- Key dependencies

## Instruction Files

Instruction files guide Copilot on:
- Coding patterns and conventions
- Testing approaches
- Style guidelines
- Best practices

## Usage

Copilot will automatically load this context when:
- Starting a new chat session
- Analyzing code
- Making suggestions
- Answering questions about the project

No manual loading of instructions is needed - Copilot will use this configuration automatically.