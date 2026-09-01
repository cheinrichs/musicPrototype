.PHONY: bootstrap test lint format run-ios run-ios-dev build-ios clean help

# Default target
help:
	@echo "Available commands:"
	@echo "  make bootstrap  - Install dependencies and verify toolchain"
	@echo "  make test       - Run all tests"
	@echo "  make lint       - Run analyzer and check formatting"
	@echo "  make format     - Apply dart formatting"
	@echo "  make run-ios    - Run on iOS simulator"
	@echo "  make run-ios-dev - Run on iOS simulator with dev tools enabled"
	@echo "  make build-ios  - Build iOS app"
	@echo "  make clean      - Clean build artifacts"

bootstrap:
	@echo "Checking Flutter installation..."
	flutter doctor -v
	@echo "Installing dependencies..."
	flutter pub get
	@echo "Bootstrap complete!"

test:
	flutter test --coverage

lint:
	flutter analyze
	dart format --set-exit-if-changed .

format:
	dart format .

# Embeds the checked-out commit into "Report this round" (Trello card
# on0EymSu) via BuildInfo — see lib/app/build_info.dart and the matching
# --dart-define in .github/workflows/deploy.yml's CI build.
COMMIT_SHA := $(shell git rev-parse HEAD)

run-ios:
	flutter run -d "iPhone" --dart-define=COMMIT_SHA=$(COMMIT_SHA)

run-ios-dev:
	flutter run -d "iPhone" --dart-define=DEV_MODE=true --dart-define=COMMIT_SHA=$(COMMIT_SHA)

build-ios:
	flutter build ios --debug --dart-define=COMMIT_SHA=$(COMMIT_SHA)

clean:
	flutter clean
	rm -rf build/
	rm -rf .dart_tool/
	@echo "Clean complete!"
