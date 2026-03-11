# App Icon Service

> Abstraction over dynamic app icon functionality for iOS.

`AppIconService` provides a platform-aware interface for changing the app
icon at runtime. On iOS it uses `FlutterDynamicIconPlus`; on Android
dynamic icons are not supported.

---

## Table of Contents

1. [Overview](#1-overview)
2. [Files & Classes](#2-files--classes)
3. [Public API](#3-public-api)
4. [Available Icons](#4-available-icons)
5. [Platform Support](#5-platform-support)

---

## 1. Overview

Trovara lets users personalise their app icon from a predefined set of
alternatives. The icons are registered in the iOS `Info.plist` under
`CFBundleAlternateIcons` and selected at runtime via the Flutter dynamic
icon plugin.

---

## 2. Files & Classes

| File                                      | Purpose                |
| ----------------------------------------- | ---------------------- |
| `lib/core/services/app_icon_service.dart` | Service implementation |

Dependencies: `flutter_dynamic_icon_plus`, `dart:io`.

---

## 3. Public API

All methods are **static**.

### `isSupported`

```dart
static Future<bool> get isSupported
```

Returns `true` on iOS if the device supports alternate icons, `false`
on all other platforms.

### `getCurrentIcon()`

```dart
static Future<String> getCurrentIcon()
```

Returns the identifier of the currently active icon. Returns `'default'`
when using the primary icon or on unsupported platforms.

### `changeIcon(iconIdentifier)`

```dart
static Future<void> changeIcon(String iconIdentifier)
```

Changes the app icon. Pass `'default'` to restore the primary icon. Throws
on failure (e.g. invalid identifier, unsupported platform).

### `getIconDetails()`

```dart
static List<Map<String, String?>> getIconDetails()
```

Returns metadata for all available icons (for UI display):

| Key           | Type      | Description                      |
| ------------- | --------- | -------------------------------- |
| `identifier`  | `String`  | Icon identifier for `changeIcon` |
| `path`        | `String`  | Asset path for preview image     |
| `label`       | `String`  | Display name                     |
| `description` | `String?` | Short description                |

---

## 4. Available Icons

| Identifier | Label   | Asset path                      |
| ---------- | ------- | ------------------------------- |
| `default`  | Default | `assets/app_icon/1024x1024.png` |
| `happy`    | Happy   | `assets/app_icon/happy.png`     |
| `sleepy`   | Sleepy  | `assets/app_icon/sleepy.png`    |

---

## 5. Platform Support

| Platform | Supported | Mechanism                     |
| -------- | --------- | ----------------------------- |
| iOS      | Yes       | `FlutterDynamicIconPlus`      |
| Android  | No        | Returns `false` / `'default'` |
| Web      | No        | Returns `false` / `'default'` |
