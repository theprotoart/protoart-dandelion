# Security

## Reporting a vulnerability

Please report security problems privately with GitHub's **Report a vulnerability** button on the
**Security** tab, not in a public issue.

## Security design

- **No privileged helper:** Dandelion installs no background helper or daemon. Tasks that need an
  administrator (flush DNS, purge memory, rebuild Spotlight, thin snapshots) ask macOS for your password
  each time, through the standard prompt, with fixed commands.
- **Trash first:** removals go to the Trash unless you turn the Safe switch off. Apps that are running
  are never removed. Apple's own apps and system folders are never offered.
- **Fixed commands:** maintenance tasks are a fixed list of built-in macOS commands compiled into the app;
  no file name or text you type is ever passed to a shell. `launchctl`, `pluginkit` and `osascript` are
  called by absolute path with argument arrays.
- **Finder fallback:** if an app is owned by an administrator, Dandelion asks Finder to move it to the Trash,
  so macOS shows its own password prompt.
- **No network:** there's no telemetry, analytics or auto-update.

## Known limitations

- Releases are signed ad hoc, not notarized; check the SHA-256 of a download against the release notes.
- Each new build has a new signature, so macOS asks again for Full Disk Access and App Management.
