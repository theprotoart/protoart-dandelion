# Security

## Reporting a vulnerability

Please report security problems privately with GitHub's **Report a vulnerability** button on the
**Security** tab, not in a public issue.

## Security design

- **No privileged helper:** Dandelion installs no background helper or daemon. Tasks that need an
  administrator (flush DNS, purge memory, rebuild Spotlight, thin snapshots) ask macOS for your password
  each time, through the standard prompt, with fixed commands.
- **Hardened runtime:** the app is signed with macOS's hardened runtime, so no other program can load its
  own code into Dandelion and borrow the Full Disk Access you give it. Its only exception
  (`Dandelion.entitlements`) lets it ask Finder to move protected apps to the Trash.
- **Trash first:** removals go to the Trash unless you turn the Safe switch off. Apps that are running
  are never removed. Apple's own apps are never offered.
- **Protected folders:** every removal goes through one function (`FS.remove`) that refuses the system's
  top-level folders, anyone's home folder, your home's standard folders (Documents, Library…), whole
  drives, and any path that runs through a symbolic link. What's inside those folders can still be removed.
- **Fixed commands:** maintenance tasks are a fixed list of built-in macOS commands compiled into the app;
  no file name or text you type is ever passed to a shell. `launchctl`, `pluginkit` and `osascript` are
  called by absolute path with argument arrays. File names given to Finder are escaped as AppleScript text.
- **No network:** there's no telemetry, analytics or auto-update.

## Known limitations

- Releases are signed ad hoc, not notarized; check the SHA-256 of a download against the release notes.
- Each new build has a new signature, so macOS asks again for Full Disk Access and App Management.
- Someone already running programs as you could still swap a folder for a link in the split second between
  Dandelion's check and the removal. That attacker could delete your files directly anyway, so this is
  accepted.

## Security tests

Double-click **Run Security Tests.command** (needs Apple's Command Line Tools). It compiles the tests in
`Tests/SecurityTests/` together with the app's own source files and works only in a temporary folder.
If a built app is present, it also checks the signature and tries to load outside code into the app.
Last run (14 Nov 2026, macOS 26.2): **54 of 54 passed** (beta4).

## Audit, 14 November 2026

**What kind of app this is:** a native macOS desktop app (Swift/SwiftUI, macOS 14+), distributed as a DMG.
It has **no** logins or accounts, payments, database, server, website, file uploads, AI features,
downloads or network connections of any kind (no networking APIs in the code). What it does have, and
what was audited: it reads and **deletes files** (often with Full Disk Access), runs a few **system
commands** (some with your admin password), sends **AppleScript to Finder**, and switches **launch agents**
on and off. Because nothing listens on a network and there are no users or web pages, most web risks
below cannot happen to it.

| # | Item | Applies? | What was checked / found | Status |
|---|------|----------|--------------------------|--------|
| 1 | Next.js header bypass | No | Not a website; no Next.js or middleware. | N/A |
| 2 | Exposed .git folder | Partly | Nothing is served on the web. The published DMG contains only the app and a Read Me; checked, no `.git`. | OK |
| 3 | Open Supabase storage | No | No Supabase or cloud storage. | N/A |
| 4 | Prices set by the browser | No | No payments or prices. | N/A |
| 5 | Credential stuffing | No | No logins. | N/A |
| 6 | Open database | No | No database; settings are two theme choices in the app's own preferences. | N/A |
| 7 | Polyfill.io / third-party scripts | No | No web views or scripts; no third-party code at all. | N/A |
| 8 | SMS pumping | No | No SMS or messaging. | N/A |
| 9 | Prompt injection | No | No AI features. | N/A |
| 10 | Weak JWT secret | No | No tokens or sessions. | N/A |
| 11 | Race conditions | Yes | Cleanup's buttons are disabled while it runs and every removal asks first; running a removal twice only reports the already-missing items. Remaining gap: a folder swapped for a link between check and removal (see Known limitations). | OK (accepted, low) |
| 12 | Account pre-hijacking | No | No accounts. | N/A |
| 13 | Subdomain takeover | No | No domains or hosting (GitHub/Hugging Face pages are theirs). | N/A |
| 14 | SSRF | No | The app makes no network requests. | N/A |
| 15 | Path traversal | Yes | Paths come from folder listings, not typed text. **Found:** a removal could follow a symbolic link *above* the item (a cache folder replaced by a link to Documents); the probe deleted the real file behind the link. **Fixed:** `FS.remove` refuses any path that runs through a link, and Cleanup no longer lists a cache folder that is a link. `..` is resolved without the /private→/var rewrite. | Fixed |
| 16 | Password-reset poisoning | No | No passwords or e-mail. | N/A |
| 17 | Source maps | No | Not a web app. The release binary is stripped of debug info and build paths (checked: 0 matches for local paths). | N/A |
| 18 | Clickjacking | No | No web pages. Destructive actions need a native confirmation alert. | N/A |
| 19 | Open redirect | No | No URLs handled; the app registers no URL scheme. It opens only two fixed System Settings links. | N/A |
| 20 | User enumeration | No | No users or sign-in. | N/A |
| 21 | Secrets in code, git history, built app | Yes | gitleaks on the git history and working tree: no leaks. Manual search for keys, tokens and passwords: none. The built app was scanned last release: no secrets, no local paths. | OK |
| 22 | Who can see private data | Partly | No accounts or server, so no other person can see your data through the app. It reads other apps' containers only with Full Disk Access you granted. **Found:** without the hardened runtime, any program could inject code into Dandelion (`DYLD_INSERT_LIBRARIES`) and use its Full Disk Access; the probe proved code ran inside the app. **Fixed:** signed with the hardened runtime; the test now proves injected code doesn't load. | Fixed |
| 23 | Logins / permission checks per action | Partly | No logins. The equivalent is macOS: admin tasks always go through macOS's own password prompt, and Finder control needs your one-time OK. Launch agents for all users or daemons can't be changed from the app. | OK |
| 24 | Injection (HTML/code, database queries) | Yes | No HTML or SQL. Shell commands are fixed strings. AppleScript built from file names was tested with quotes, backslashes, newlines and an injection attempt: all stay plain text, nothing runs. Escaping moved into one tested function. | OK |
| 25 | File uploads and downloads | Yes (deletion) | Nothing is uploaded or downloaded. File deletion is the risky part. **Found:** Space Lens could move whole critical folders (the Applications folder, /Library, /Users, your home) to the Trash after Finder's password prompt. **Fixed (with your OK):** these folders are refused everywhere and can't be ticked in Space Lens; their contents still can. **Found:** removing an app could also select files of a different installed app whose ID starts the same (e.g. `com.foo.app.beta` beside `com.foo.app`). **Fixed:** such files are left out. | Fixed |
| 26 | Electron settings | No | Native Swift app, not Electron. | N/A |
| 27 | AI model files / AI permissions | No | No AI or model files. | N/A |
| 28 | Dependencies (outdated / unpinned) | Yes | `Package.swift` has **no** third-party packages; only Apple's frameworks. Nothing to update or pin. | OK |
| 29 | Rate limits (signups, logins, costs) | No | No signups, logins or paid services. | N/A |
| 30 | Admin-password tasks | Yes | Run as fixed strings through `osascript … with administrator privileges`; nothing user-supplied is added. | OK |
| 31 | Launch agent control | Yes | Labels and paths come from plist files and go to `/bin/launchctl` as separate arguments (no shell). Only your own agents can be changed or removed. | OK |
