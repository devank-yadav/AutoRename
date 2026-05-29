#!/bin/bash
# Compiles a CLI harness from the pipeline sources (excluding the AppKit app
# shell) and runs a real extraction → name → rename test on sample files.
set -euo pipefail
cd "$(dirname "$0")"

mkdir -p build
BIN="build/autorename-test"

SOURCES=(
    Sources/Models.swift
    Sources/Settings/SettingsStore.swift
    Sources/Naming/FilenameSanitizer.swift
    Sources/Naming/NamingService.swift
    Sources/Extraction/Extractor.swift
    Sources/Extraction/ImageExtractor.swift
    Sources/Extraction/DocumentExtractor.swift
    Sources/Extraction/AudioExtractor.swift
    Sources/Extraction/VideoExtractor.swift
    Tests/main.swift
)

echo "==> Compiling test harness"
swiftc \
    -target arm64-apple-macos13.0 \
    -framework AppKit \
    -framework Vision \
    -framework PDFKit \
    -framework AVFoundation \
    -framework Speech \
    -framework UniformTypeIdentifiers \
    -framework Security \
    -o "$BIN" \
    "${SOURCES[@]}"

echo "==> Running"
echo
"./$BIN"
