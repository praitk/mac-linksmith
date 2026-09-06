# Linksmith

Linksmith is a native macOS utility for creating and managing symbolic links directly from Finder.

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
- presents a destination folder chooser;
- when one folder is selected, can instead create links inside that folder after choosing the source items;
- when one file is selected, can move that file to a chosen folder and replace the original with a symbolic link;
- creates relative symbolic links by default;
- optionally creates absolute symbolic links through the host app setting;
- remembers up to 10 recent destination folders;
- stores persistent folder access as security-scoped bookmarks; and
- handles naming conflicts with incrementing suffixes such as `report 2.pdf`.

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
LinksmithCore
  │
  ▼
Foundation / macOS filesystem
```

`LinksmithAction` translates Finder input into file URLs and presents the destination chooser. `LinksmithCore` owns path generation, collision handling, symlink creation, shared settings, and recent-destination persistence. The host app and extension share settings through the `group.com.praitk.Linksmith` App Group.

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
swift test --package-path LinksmithCore
```

### Using the Quick Action

1. Build and run the **Linksmith** scheme once.
2. In Finder, select one or more files or folders.
3. Choose **Quick Actions → Create Symlink…**.
4. Select a destination folder.

To create links inside a folder instead, select exactly one folder in Finder, choose **Quick Actions → Create Symlink…**, click **Create Links Here**, then choose the files or folders to link into it.

To move a file and leave a symbolic link in its original location, select exactly one file in Finder, choose **Quick Actions → Create Symlink…**, click **Move and Replace with Link**, then choose the folder where the file should be moved.

If the action is not visible during development, enable `LinksmithAction` in macOS extension settings or Finder's Quick Actions customization interface, then relaunch Finder.

## Project status

Linksmith is in early development. The first end-to-end symbolic-link workflow is implemented and covered by tests for path generation, collision handling, multiple selections, and relative-versus-absolute links.

## License

Linksmith is available under the [MIT License](LICENSE).
