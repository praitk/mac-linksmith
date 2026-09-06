# Agent Instructions

## Automated Testing

Use `swift test --disable-sandbox` when running the `LinksmithCore` package tests. Plain `swift test` can fail in this environment when SwiftPM tries to apply its own sandbox.

## Finder Quick Action Testing

When asking the user to test the Finder Quick Action, always provide the refresh commands below. Finder and PlugInKit can keep using an older `Linksmith.app` or `LinksmithAction.appex` even after Xcode builds a newer one.

Use a disposable file for Finder tests until the workflow is known to be safe.

```bash
APP="$(find "$HOME/Library/Developer/Xcode/DerivedData" -path '*/Build/Products/Debug/Linksmith.app' -type d -print0 2>/dev/null | xargs -0 stat -f '%m %N' | sort -nr | head -1 | cut -d' ' -f2-)"

echo "Using Linksmith app: $APP"
stat -f 'App built: %Sm' "$APP/Contents/MacOS/Linksmith"
stat -f 'Extension built: %Sm' "$APP/Contents/PlugIns/LinksmithAction.appex/Contents/MacOS/LinksmithAction"

killall LinksmithAction 2>/dev/null
killall Linksmith 2>/dev/null

pluginkit -e ignore -i com.praitk.Linksmith.LinksmithAction
pluginkit -a "$APP/Contents/PlugIns/LinksmithAction.appex"
pluginkit -e use -i com.praitk.Linksmith.LinksmithAction

killall pkd
killall sharingd
killall Finder
open /System/Library/CoreServices/Finder.app
open "$APP"

pluginkit -m -A -v -i com.praitk.Linksmith.LinksmithAction
```

Expected current extension metadata:

```text
NSExtensionPointIdentifier: com.apple.services
NSExtensionPrincipalClass: ActionRequestHandler
NSExtensionServiceRoleType: NSExtensionServiceRoleTypeViewer
```

Expected Debug picker title:

```text
APP HANDOFF - Choose Destination Folder
```

If the picker title has no `APP HANDOFF` prefix, the user is still running stale app code. If the picker title starts with `EXTENSION PICKER`, the extension-side picker path is being used and must be investigated before further Finder testing.
