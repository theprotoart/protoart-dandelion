# Privacy

**ProtoArt Dandelion makes no network connections** and has no account, telemetry, analytics or update check.

- **Scanning** happens on your Mac. Dandelion reads file names, sizes and dates in the places it cleans
  (caches, logs, Xcode data, developer caches, mail downloads, installers in Downloads, the Trash, and the
  folders you point Space Lens or Large Files at). It never reads or uploads the contents of your files.
- **Other apps' data:** it only looks inside other apps' containers when you have given it Full Disk Access.
  Without it, those items are shown as "needs access" and left alone.
- **Removing** moves items to the Trash by default (the **Safe** switch). Only the Trash category and items
  you choose with the switch off are deleted permanently.
- **Maintenance tasks** that need an administrator run through macOS's own password prompt; Dandelion never
  sees or stores your password.
- **Settings** (theme and the Safe switch) are saved in the app's own preferences (`local.protoart.dandelion`).
- No logs are written.

To remove everything, delete the app and `~/Library/Preferences/local.protoart.dandelion.plist`.
