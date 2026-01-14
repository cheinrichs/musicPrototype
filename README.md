# Ear Trainer

A playful, "squishy" ear-training mobile app for kids built with Flutter.

## Features

- **High vs Low Game**: Listen to two notes and determine if the second is higher or lower
- **Squishy UI**: Playful animations with bounce and scale effects
- **Progress Tracking**: Streak counting and session tracking (stored locally)
- **Reward System**: Confetti celebrations after completing games
- **Offline-First**: No internet connection required

## Getting Started

### Prerequisites

- Flutter SDK (3.10.7 or higher)
- Xcode (for iOS development)
- iOS Simulator or physical device

### Setup

```bash
# Install dependencies and verify toolchain
make bootstrap

# Run on iOS simulator
make run-ios
```

### One-Command Workflows

| Command | Description |
|---------|-------------|
| `make bootstrap` | Install dependencies and verify Flutter |
| `make test` | Run all tests |
| `make lint` | Run analyzer and check formatting |
| `make format` | Apply dart formatting |
| `make run-ios` | Run on iOS simulator |
| `make build-ios` | Build iOS app (debug) |
| `make clean` | Clean build artifacts |

## Project Structure

```
lib/
├── app/              # App bootstrap, routing, theme
│   ├── app.dart
│   ├── router.dart
│   └── state/        # Global state management
├── audio/            # Audio engine + asset mapping
│   ├── audio_controller.dart
│   ├── note.dart
│   └── sfx_type.dart
├── games/
│   └── high_low/     # High vs Low game
│       ├── models/
│       ├── services/
│       ├── state/
│       └── screens/
├── rewards/          # Reward screens
├── models/           # Shared data models
└── ui/
    ├── components/   # Reusable UI components
    ├── screens/      # App screens
    └── theme/        # Colors, typography, spacing

assets/
├── audio/
│   ├── notes/        # Piano note samples (C4-B5)
│   └── sfx/          # Sound effects
└── images/           # Characters, icons, stickers
```

## Tech Stack

- **Flutter** - Cross-platform UI framework
- **flutter_soloud** - Low-latency audio playback
- **flutter_animate** - Squishy animation effects
- **confetti** - Celebration animations
- **go_router** - Type-safe navigation
- **shared_preferences** - Local storage
- **provider** - State management

## Game Flow

1. **Home Screen** - Choose a game or tap Play
2. **Game Play** - Listen to 10 prompts, tap Higher or Lower
3. **Reward Screen** - See your score with confetti celebration
4. **Play Again** or return home

## Audio Assets

The app includes generated sine wave audio files for development. For production, consider replacing with higher-quality piano samples from:
- [freesound.org](https://freesound.org)
- [samplefocus.com](https://samplefocus.com)
- University of Iowa Electronic Music Studios

## Development

### Running Tests

```bash
make test
```

### Code Quality

```bash
# Check for issues
make lint

# Auto-format code
make format
```

## License

This project is private and not licensed for distribution.
