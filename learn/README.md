# notemyminds Learning Resources

Welcome to the notemyminds learning documentation. This directory contains comprehensive guides about different aspects of the notemyminds project.

## Table of Contents

1. [Project Overview](01_project_overview.md)
   - Technical Stack
   - Core Architecture
   - Key Components
   - Project Initialization
   - Configuration

2. [Navigation and Routing](02_navigation.md)
   - Router Configuration
   - Route Structure
   - View Structure
   - Shell Route
   - Deep Linking

3. [Data Management](03_data_management.md)
   - Local Storage (ObjectBox)
   - Google Drive Sync
   - Data Models
   - Repository Pattern
   - Caching Strategy

4. [UI Architecture](04_ui_architecture.md)
   - MVVM Pattern Implementation
   - Shared Components
   - Theme System
   - Layout Patterns
   - Error Handling
   - Internationalization

5. [Development Workflows](05_development_workflows.md)
   - Project Setup
   - Development Scripts
   - Code Style
   - Testing
   - Debug Tools
   - Common Tasks
   - Release Process
   - Troubleshooting

6. [Tag System and Analytics](06_tag_system.md)
   - Tag Types
   - Analytics System
   - Data Visualization
   - Tag Management
   - Insights Generation
   - Data Export

## Key Features

- 📝 Advanced note-taking with rich text editing
- 🏷️ Comprehensive tagging system
- 🔄 Google Drive synchronization
- 📊 Analytics and insights
- 🌍 Internationalization support
- 🎨 Theming system

## Getting Started

1. Set up your development environment:

   ```bash
   flutter pub get
   ./scripts/build_runner.sh
   ```

2. Run the app:

   ```bash
   ./scripts/run_app.sh --notemyminds
   ```

3. Start exploring the documentation based on your needs:
   - New to the project? Start with [Project Overview](01_project_overview.md)
   - Working on UI? Check [UI Architecture](04_ui_architecture.md)
   - Adding features? See [Development Workflows](05_development_workflows.md)

## Best Practices

- Follow the MVVM pattern for new features
- Use the repository pattern for data access
- Keep UI components modular and reusable
- Write tests for new functionality
- Update documentation when making architectural changes

## Need Help?

- Check the troubleshooting sections in each guide
- Review the code examples
- Look at existing implementations for reference
