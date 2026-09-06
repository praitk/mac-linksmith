# Linksmith

Linksmith is a native macOS utility for creating symbolic links directly from Finder.

The project aims to provide a small, transparent, and trustworthy implementation built entirely with Apple's native technologies.

> [!NOTE]
> Linksmith is currently under development and is not yet ready for general use.

## Goals

Linksmith is designed around a few principles:

- **Native macOS integration** — built with Swift and Apple's macOS frameworks.
- **Local operation** — filesystem operations happen entirely on the Mac.
- **Minimal attack surface** — no network communication, telemetry, background services, or unnecessary dependencies.
- **Auditable implementation** — security-sensitive filesystem operations should remain small and easy to understand.
- **Safe filesystem operations** — potentially destructive operations must validate their inputs and handle failures conservatively.

## Current functionality

Linksmith currently provides a Finder Quick Action named **Create Symlink…**:

- accepts one or more files or folders selected in Finder;
- hands the Finder selection to the Linksmith menu bar app, which presents the workflow UI;
- creates symbolic links for selected files or folders in a chosen destination folder;
- when one folder is selected, can instead create links inside that folder after choosing the source items;
- when one file is selected, can move that file to a chosen folder and replace the original with a symbolic link;
- when one symbolic link is selected, can swap its target with the link, copy the target over the link, or move the target over the link;
- creates relative symbolic links by default;
- switches requested relative links to absolute links when the source or destination is below a `.linksmith` marker boundary;
- optionally creates absolute symbolic links through the menu bar app setting;
- remembers up to 10 recent destination folders;
- stores persistent folder access as security-scoped bookmarks; and
- handles naming conflicts with incrementing suffixes such as `report 2.pdf`;
- previews multi-item link batches before creating anything; and
- asks before adding another link when the destination already contains a symbolic link to the same selected item.

Hard links are not implemented.

## Architecture

Linksmith is composed of a small SwiftUI host application, a Finder Action Extension, and a testable core Swift package.

```text
Finder
  │
  ▼
LinksmithAction
  │
  ▼
Linksmith host app
  │
  ▼
LinksmithCore
  │
  ▼
Foundation / macOS filesystem
```

`LinksmithAction` translates Finder input into file URLs, stores a pending handoff in shared app-group storage, opens the containing app, and exits without editing Finder items.
The Linksmith host app owns user interaction, including mode selection, folder and source pickers, recent destinations, and completion/error alerts.
`LinksmithCore` owns path generation, collision handling, symlink creation, shared settings, pending handoff storage, debug log storage, and recent-destination persistence.
The host app and extension share settings through the `group.com.praitk.Linksmith` App Group.

## Technology

- macOS
- Swift
- SwiftUI
- Finder Action Extension / Quick Actions
- App Groups and security-scoped bookmarks
- Swift Package Manager
- Swift Testing
- Xcode

The project aims to avoid third-party runtime dependencies.

## Security

Linksmith handles filesystem paths and operations, so security and predictable behavior are first-class design requirements.

The project should not require:

- network access
- telemetry or analytics
- shell command execution
- root privileges
- background services
- third-party runtime libraries

Potentially destructive functionality should only be introduced with appropriate validation, tests, and failure handling.

## Development

### Requirements

- macOS
- Xcode 26 or later
- Swift 6

Clone the repository and open the Xcode project:

```bash
git clone <repository-url>
cd mac-linksmith
open Linksmith.xcodeproj
```

To build from the command line:

```bash
xcodebuild \
  -project Linksmith.xcodeproj \
  -scheme Linksmith \
  -configuration Debug \
  build
```

To run the core test suite:

```bash
cd LinksmithCore
swift test --disable-sandbox
```

### Using the Quick Action

1. Build and run the **Linksmith** scheme once.
2. In Finder, select one or more files or folders.
3. Choose **Quick Actions → Create Symlink…**.
4. Complete the prompts in the Linksmith app.

For one or more selected files or folders, choose the destination folder where links should be created.
When multiple items are selected, Linksmith previews the planned links before creating anything, including any automatic renamed link names such as `report 2.pdf`.
If the destination already contains a symbolic link to the same selected item, Linksmith asks whether to add another link.

To create links inside a folder instead, select exactly one folder in Finder, choose **Quick Actions → Create Symlink…**, click **Create Links Here**, then choose the files or folders to link into it.

To create a link to the selected folder itself, select exactly one folder in Finder, choose **Quick Actions → Create Symlink…**, click **Link to This Folder**, then choose the destination folder.

To move a file and leave a symbolic link in its original location, select exactly one file in Finder, choose **Quick Actions → Create Symlink…**, click **Move and Replace with Link**, then choose the folder where the file should be moved.
Linksmith will ask you to authorize the original folder before replacing the original file with a symbolic link.

To replace a symbolic link with its target, select exactly one symbolic link in Finder, choose **Quick Actions → Create Symlink…**, then choose one of the symlink-specific options.
Linksmith asks for one common parent folder when that does not cross a `.linksmith` boundary, or separate folders when the marker boundary keeps the paths separate.

- **Swap Files** moves the target file to the symbolic link's location and creates a new symbolic link where the target file used to be.
- **Copy File Here** copies the target file to the symbolic link's location and leaves the original target file in place.
- **Move File Here** moves the target file to the symbolic link's location and removes it from its original location.

If the selected symbolic link is broken, Linksmith still recognizes it as a symbolic link and offers these options, but the replacement operation fails without removing the broken link.

The menu bar app also lets you choose whether newly created links should prefer relative or absolute targets.

### Relative and absolute links

By default, Linksmith creates relative symbolic links.
This keeps links portable when the source and destination move together within the same tree.

Place a file named `.linksmith` in a directory to mark the deepest folder that can still be included in a relative link.
When Linksmith is about to create a relative link, it walks from the source and destination directories up to their first common ancestor.
If a `.linksmith` file is found below that common ancestor on either path, Linksmith writes an absolute target path instead.
If the `.linksmith` file is in the common ancestor itself, the link remains relative because that marked folder is the relative-link boundary.

If the action is not visible during development, enable `LinksmithAction` in macOS extension settings or Finder's Quick Actions customization interface, then relaunch Finder.

## Project status

Linksmith is in early development.
The first end-to-end symbolic-link workflows are implemented and covered by tests for path generation, collision handling, multiple selections, batch planning, pending Finder handoff storage, recent destinations, move-and-replace behavior, selected-symlink replacement behavior, broken symlink handling, and marker-based relative-versus-absolute links.

## License

Linksmith is available under the [MIT License](LICENSE).
