#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 17 Pro}"
CAPTURE_DIR="/tmp/plantpal-readme-screenshots"
DESTINATION_DIR="$ROOT_DIR/docs/screenshots"
SCREENSHOTS=(garden plant-detail reminders guide-library guide-article field-capture)

mkdir -p "$CAPTURE_DIR" "$DESTINATION_DIR"

xcodebuild \
  -project "$ROOT_DIR/PlantPal.xcodeproj" \
  -scheme PlantPal \
  -destination "platform=iOS Simulator,name=$SIMULATOR_NAME" \
  -only-testing:PlantPalBuildScreenshots \
  test

for name in "${SCREENSHOTS[@]}"; do
  source="$CAPTURE_DIR/$name.png"
  destination="$DESTINATION_DIR/$name.jpg"

  if [[ ! -f "$source" ]]; then
    printf 'Missing expected screenshot: %s\n' "$source" >&2
    exit 1
  fi

  sips -s format jpeg -s formatOptions 82 "$source" --out "$destination" >/dev/null
done

printf 'Updated README screenshots in %s\n' "$DESTINATION_DIR"
