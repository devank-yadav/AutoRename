# AutoRename

A macOS menu-bar app that renames files based on what is actually inside them.

Drop a screenshot called `Screenshot 2026-05-14 at 11.42.03.png` on it and get back
`invoice-from-northwind-march-2026.png`. Drop a voice memo and get a name drawn from
what was said in it. The app reads the file's contents — text, speech, subject matter —
and proposes a name from that, rather than from its metadata.

## How it works

Every file goes through the same three stages: **extract → name → sanitize**.

### 1. Extract

A per-type extractor pulls whatever text or subject matter the file contains. All of
this runs on-device, using Apple's frameworks.

| Type | Framework | What it pulls |
|---|---|---|
| Images | Vision | OCR via `VNRecognizeTextRequest`, plus subject tags from `VNClassifyImageRequest` |
| PDFs and documents | PDFKit | Text from the first pages via `PDFDocument` |
| Audio | Speech | On-device transcription |
| Video | AVFoundation + Vision | Audio track transcription, plus OCR and classification on frames sampled with `AVAssetImageGenerator` |

`Extractor.swift` dispatches on the file's `UTType`, so adding a new type means adding
one extractor and one case.

### 2. Name

`NamingService` sends the extracted context — text, detected subject tags, the original
filename — to OpenAI's `gpt-4o-mini` and asks for a short descriptive name in your
chosen language and length limit.

This is the only step that leaves your machine, and it only happens when you have set
an API key. Extraction is entirely local.

### 3. Sanitize

`FilenameSanitizer` turns the model's answer into something safe to write to disk:
strips quotes, backticks, and newlines; drops a trailing extension if the model added
one; splits on separators and re-cases according to your preference; applies your
naming template; truncates to the maximum length without leaving a dangling `-` or `_`.
If anything goes wrong, it falls back to the original filename rather than producing
a broken one.

## Install

Requires **macOS 13.0 or later**. No Xcode needed — only the Command Line Tools.

```bash
git clone https://github.com/devank-yadav/AutoRename.git
cd AutoRename
./build.sh
```

`build.sh` compiles the Swift sources directly with `swiftc`, targeting
`arm64-apple-macos13.0` and `x86_64-apple-macos13.0`, then lipos them into a universal
binary and assembles `build/AutoRename.app`. There is no `.xcodeproj` and no
`Package.swift` — the build script is the whole build system.

Move the resulting app to `/Applications` and launch it. It runs as a menu-bar item
with no Dock icon (`LSUIElement`).

## Setup

Open **Settings** from the menu-bar icon and paste an OpenAI API key. Get one at
[platform.openai.com](https://platform.openai.com/api-keys). The key is stored in your
macOS **Keychain**, never in a file inside the repo.

Key resolution order is: Keychain → local key file → a bundled `embedded-key.txt` if
you shipped one. The bundled option exists for distributing a pre-configured build to
someone non-technical; it is deliberately not committed here.

### Permissions

macOS will ask for two, both explained in `Info.plist`:

- **Speech Recognition** — to transcribe audio and video on-device.
- **Apple Events** — to read your current Finder selection so the app can rename it.

## Usage

- **Drop files** on the drop window, or
- **Select files in Finder** and trigger the app from the menu bar.

Either way you get a preview window listing each file's current and proposed name.
Nothing is written to disk until you confirm.

## Settings

| Setting | Default | Notes |
|---|---|---|
| Naming template | `{slug}` | Supports `{slug}` and `{date}` |
| Max length | `60` | Characters, truncated cleanly at word boundaries |
| Prepend date | off | Uses the file's creation date |
| Case style | — | Applied to the slug |
| Language | English | Passed to the model |

## Layout

```
Sources/
  AutoRenameApp.swift      NSApplication entry point
  MenuBarController.swift  Status-bar item and menu
  RenameCoordinator.swift  Owns the drop and preview windows
  FinderSelection.swift    Reads the current Finder selection
  Models.swift             FileContext and friends
  Extraction/              One extractor per file type
  Naming/                  NamingService + FilenameSanitizer
  Settings/                SettingsStore (UserDefaults + Keychain), SettingsWindow
  UI/                      DropWindow, PreviewWindow
Tests/
  main.swift               CLI harness — see ./test.sh
```

## Tests

```bash
./test.sh
```

Compiles a CLI harness from the pipeline sources — excluding the AppKit shell — and
runs a real extraction → name → rename pass over sample files.

## Status

Version 0.1. Working, and used daily by the author. The whole project is one commit,
so the git history says nothing about how it was built; the layout above is a better
guide than `git log`.

## License

MIT — see [LICENSE](LICENSE).
