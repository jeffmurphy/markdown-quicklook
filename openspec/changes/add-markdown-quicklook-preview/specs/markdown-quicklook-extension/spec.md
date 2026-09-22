## Purpose

Integrates with macOS Quick Look so that selecting a `.md` file in Finder and pressing the spacebar shows a rendered HTML preview instead of raw Markdown text, via a sandboxed `QLPreviewingController` App Extension.

## ADDED Requirements

### Requirement: Quick Look invocation for Markdown files
The system SHALL register a Quick Look preview provider for files with the `.md` extension on macOS 13 (Ventura) and later, and SHALL NOT be invoked for files without that extension.

#### Scenario: User previews a valid Markdown file
- **WHEN** the user selects a `.md` file in Finder and presses the spacebar
- **THEN** Quick Look SHALL display the extension's rendered HTML preview instead of raw Markdown source text

#### Scenario: Extension not applied to non-Markdown files
- **WHEN** the user selects a file that is not a registered `.md` file and presses the spacebar
- **THEN** this extension SHALL NOT be invoked for that file, and Quick Look SHALL fall back to the system's default handler for that file type

### Requirement: Offline rendering only
The extension SHALL render previews using only local, bundled assets and the previewed file's own contents/directory. It SHALL NOT perform any network requests while generating a preview.

#### Scenario: Preview generated without network access
- **WHEN** the extension renders a preview for any Markdown file
- **THEN** it SHALL only read its bundled rendering assets and files within the previewed document's containing directory (for relative image/link resolution), and SHALL NOT issue any HTTP/HTTPS or other network requests

### Requirement: Graceful handling of malformed or unreadable input
The extension SHALL present a stable, styled result for any input file rather than crashing, hanging, or displaying an unstyled raw error.

#### Scenario: Empty file
- **WHEN** the previewed file is empty
- **THEN** the extension SHALL display an empty but correctly styled preview, without crashing or showing raw error output

#### Scenario: Unreadable file
- **WHEN** the file cannot be read due to a permissions or I/O error
- **THEN** the extension SHALL present a clear, human-readable error message inside the Quick Look panel rather than crashing or hanging indefinitely

#### Scenario: Oversized file
- **WHEN** the previewed file's size exceeds the extension's defined maximum preview size
- **THEN** the extension SHALL render a truncated preview and SHALL indicate to the user that the content was truncated, rather than hanging or failing

### Requirement: Sandboxed, least-privilege execution
The extension SHALL run inside the App Sandbox with only the entitlements required to read the previewed file and its containing directory.

#### Scenario: Extension runs with minimal entitlements
- **WHEN** the extension is installed and invoked by Quick Look
- **THEN** it SHALL execute inside the App Sandbox with read-only access limited to the file being previewed and its containing folder, and SHALL request no additional sensitive entitlements (e.g. camera, microphone, outbound network, contacts)

### Requirement: Appearance follows system light/dark mode
The preview SHALL visually match the current macOS system appearance setting.

#### Scenario: System appearance is Dark
- **WHEN** macOS system appearance is set to Dark at the time of preview
- **THEN** the rendered preview SHALL use the extension's dark color theme

#### Scenario: System appearance is Light
- **WHEN** macOS system appearance is set to Light at the time of preview
- **THEN** the rendered preview SHALL use the extension's light color theme
