# Changelog

## Unreleased (security audit)

- Signed with the hardened runtime, so no other program can load code into Dandelion and use its
  Full Disk Access.
- Protected folders: the system's top-level folders, home folders, your Documents/Library/Desktop… and whole
  drives can no longer be removed as a whole (their contents still can). Space Lens won't tick them.
- Removals refuse paths that run through a symbolic link, and Cleanup ignores a cache folder that is a link.
- Uninstaller no longer offers another installed app's files when its ID starts with the same name
  (com.foo.app.beta beside com.foo.app).
- New `Run Security Tests.command` with 45 checks.

## 1.0.0-beta3

- Uninstaller: apps owned by an administrator (for example ones installed with a .pkg) are moved to the
  Trash through Finder, which asks for your password. When macOS blocks a removal, buttons open the
  Full Disk Access and App Management settings.
- Scans no longer stall on macOS permission prompts; each category is scanned on its own and the
  status line says when macOS is waiting for you to allow access.
- Leftovers: fewer false positives (app extensions, helpers and plug-ins count as installed).

## 1.0.0-beta2

- Location switch in Space Lens responds to clicks and drags; folder picker no longer freezes the window.
- Large Files: filter by kind, "last opened" date, hidden-files switch.
- Layout fixes: nothing clips or overlaps at the minimum window size.

## 1.0.0-beta1

- First test build: Smart Scan, Cleanup, Uninstaller, Space Lens, Large Files, Maintenance,
  Login Items and a menu-bar monitor, in a powder-coated rack panel (blue or burnt orange).
