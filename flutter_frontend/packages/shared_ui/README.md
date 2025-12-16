# Shared UI Package

Shared UI components for Msgr apps (Workspace and Personal editions).

## Purpose

This package contains all shared UI components, widgets, and theme system that are used across both the Workspace and Personal apps. This ensures consistency and reduces code duplication.

## What's Included

### Widgets
- **Message Components**: Message composer, message list, message items
- **Avatar Components**: User avatars, profile pictures
- **Common Components**: Loading indicators, error widgets, etc.

### Theme
- Color palette
- Typography system
- Spacing and sizing constants

### Utils
- Date formatters
- Message utilities
- UI helpers

## Usage

Add to your `pubspec.yaml`:

```yaml
dependencies:
  shared_ui:
    path: ../packages/shared_ui
```

Then import:

```dart
import 'package:shared_ui/shared_ui.dart';
```
