# Commit Message Guidelines

## Automatic Commit Description Generation

The pre-commit hook automatically generates a structured commit message template that includes:

1. **Change Categories**:
   - 🎨 UI Changes
   - 🔧 Model Changes
   - ⚙️ Core Changes
   - 🧩 Widget Changes
   - 🧪 Test Changes
   - 🖼️ Asset Changes
   - 📚 Documentation Changes
   - 📦 Other Changes

2. **File Changes**:
   - ✨ Added files
   - 📝 Modified files
   - 🗑️ Deleted files
   - With diff statistics (+additions/-deletions)

## Commit Message Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Type

Must be one of the following:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style/formatting
- `refactor`: Code refactoring
- `test`: Adding/updating tests
- `chore`: Maintenance tasks

### Scope

The scope should be the area of the change:
- `notes`: Note-related features
- `sync`: Synchronization functionality
- `ui`: User interface changes
- `tags`: Tagging system
- `auth`: Authentication
- `core`: Core functionality
- `deps`: Dependencies

### Subject
- Use imperative mood ("add" not "added" or "adds")
- Don't capitalize first letter
- No period (.) at the end

### Examples

```
feat(notes): add tag filtering system

- Implement tag filter UI component
- Add tag filter logic in NotesViewModel
- Update repository to support tag filtering
- Add tests for tag filtering

Closes #123
```

```
fix(sync): resolve conflict during note merge

- Add proper conflict resolution strategy
- Preserve local changes when conflict occurs
- Add user notification for conflicts
- Update sync documentation

Fixes #456
```

## Installation

Run the installation script:
```bash
chmod +x scripts/install_hooks.sh
./scripts/install_hooks.sh
```

This will:
1. Set up the git hooks directory
2. Make the pre-commit hook executable
3. Configure git to use the custom hooks

## Usage

1. Stage your changes:
   ```bash
   git add .
   ```

2. Start the commit:
   ```bash
   git commit
   ```

3. The pre-commit hook will:
   - Analyze staged changes
   - Generate a commit message template
   - Open your editor with the template

4. Edit the commit message:
   - Review the generated summary
   - Add your commit type and scope
   - Write a meaningful subject line
   - Add any additional details
   - Save and close

5. The commit will complete with your edited message

## Tips

1. **Keep Commits Focused**:
   - Each commit should represent one logical change
   - Split large changes into smaller commits

2. **Write Clear Messages**:
   - Use clear and concise language
   - Explain the "why" not just the "what"
   - Reference issues and PRs when relevant

3. **Review the Summary**:
   - Verify all changes are intentional
   - Check for unintended changes
   - Ensure sensitive data isn't included