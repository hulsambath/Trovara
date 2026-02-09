## Dynamic App Icons Setup

This project uses dynamic app icons. The following icons are available:

- **default**: Default
  - The default NoteMyMinds app icon
  - Icon file: `assets/app_icon/1024x1024.png`

- **happy**: Happy
  - A cheerful smiley icon
  - Icon file: `assets/app_icon/happy.png`

- **sleepy**: Sleepy
  - A relaxed sleepy icon
  - Icon file: `assets/app_icon/sleepy.png`

### Usage

```dart
// Change to a specific icon
await DynamicAppIconPlus.changeIcon('default');

// Reset to default
await DynamicAppIconPlus.resetToDefault();
```
