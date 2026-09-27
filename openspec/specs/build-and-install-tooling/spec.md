# Build and Install Tooling Specification

## Purpose

Defines the developer-facing local build, install, and uninstall behavior needed to compile the extension and register/unregister it with macOS Launch Services on the developer's own machine, without requiring manual Xcode GUI steps.

## Requirements

### Requirement: One-command local build
The system SHALL provide a script that compiles the host app and its embedded Quick Look extension from the command line without requiring manual Xcode GUI interaction.

#### Scenario: Successful build produces an app bundle
- **WHEN** a developer runs the build script from a clean checkout with Xcode command line tools installed
- **THEN** the script SHALL compile the project via `xcodebuild` and produce a `.app` bundle containing the embedded Quick Look extension, printing the output location on success

#### Scenario: Build failure is reported clearly
- **WHEN** compilation fails for any reason (e.g. syntax error, missing dependency)
- **THEN** the script SHALL exit with a non-zero status and print the underlying build tool's failure output to aid debugging

### Requirement: One-command install and registration
The system SHALL provide a script that installs the built app and registers its Quick Look extension with Launch Services so it becomes active for `.md` files without requiring a reboot.

#### Scenario: Install copies app and registers extension
- **WHEN** a developer runs the install script after a successful build
- **THEN** the script SHALL copy the built app to an install location (defaulting to `/Applications`, overridable via an argument), register it with Launch Services, and reset the Quick Look cache so the extension is available the next time Quick Look is invoked on a `.md` file

#### Scenario: Install without a prior build fails clearly
- **WHEN** a developer runs the install script before running the build script (no built app present)
- **THEN** the script SHALL exit with a non-zero status and a clear message instructing the developer to run the build script first

### Requirement: One-command uninstall
The system SHALL provide a script that removes the installed app and unregisters the extension so it no longer applies to `.md` files.

#### Scenario: Uninstall removes app and deactivates extension
- **WHEN** a developer runs the uninstall script after previously installing the extension
- **THEN** the script SHALL remove the app from its install location, refresh Launch Services registration, and the Quick Look extension SHALL no longer be invoked for `.md` files afterward
