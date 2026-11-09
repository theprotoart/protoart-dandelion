# ProtoArt Dandelion

**Cleans and tidies your Mac, in a powder-coated rack panel.**

ProtoArt Dandelion (PD-1) is a free, open-source Mac cleaning app for macOS, written in SwiftUI. It finds
caches, logs, developer junk, app leftovers and big forgotten files, shows where your disk space went, and
runs the usual maintenance tasks. Everything it removes goes to the Trash first unless you say otherwise.

Nothing is uploaded and the app makes no network connections.

## Download

Get the DMG from [Releases](https://github.com/theprotoart/protoart-dandelion/releases) or
[Hugging Face](https://huggingface.co/brushpenbob/protoart-dandelion). It isn't notarised yet: the first
time, open it from **System Settings → Privacy & Security → Open Anyway**. Check the SHA-256 against the
release notes.

To clean other apps' data and remove apps installed by an administrator, turn Dandelion on in
**System Settings → Privacy & Security → Full Disk Access** and **App Management** (macOS has no pop-up
for these; the app has buttons that open the right page).

## Features

- **Smart Scan:** one button runs the junk, leftovers and login-item checks together.
- **Cleanup:** user caches, logs, Xcode data (DerivedData, archives, simulators), developer caches
  (npm, Gradle, SwiftPM), Mail downloads, installers in Downloads and the Trash. Caches of running apps are
  left unticked.
- **Uninstaller:** removes an app with its support files, caches, preferences and containers; finds
  **leftovers** from apps you already deleted. Running apps and Apple's apps are never removed.
- **Space Lens:** a ring map of what fills your home folder, the disk, Applications or any folder.
- **Large Files:** big and old files by kind (video, audio, images, archives, documents), with last-opened dates.
- **Maintenance:** flush DNS, free RAM, thin Time Machine snapshots, reindex Spotlight, rebuild Launch
  Services, reset Quick Look, restart Dock and Finder; plus a list of the apps using the most memory.
- **Login Items:** see and switch off launch agents that start with your Mac.
- **Menu-bar monitor:** CPU, memory and free disk at a glance.
- **Looks:** blue or burnt-orange powder coat (Light / Dark / follow macOS), plus Amber, Cream, Slate and
  Ember skins.

## Requirements

macOS 14 or newer, Apple Silicon or Intel (universal app, about 3 MB).

## Build from source

Needs Apple's Command Line Tools (`xcode-select --install`).

```bash
bash "Build ProtoArt Dandelion.command"     # or double-click it
bash "Make DMG for friends.command"         # or double-click it
```

The Swift source is in `Sources/Dandelion/`; the icon is drawn by `tools/make-icon.swift`.

## License

Apache-2.0. See LICENSE and NOTICE.
