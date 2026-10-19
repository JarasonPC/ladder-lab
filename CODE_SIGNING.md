# Code signing policy

Free code signing provided by [SignPath.io](https://about.signpath.io/), certificate by
[SignPath Foundation](https://signpath.org/).

Signed Windows builds let Windows check that LadderLab comes from this project and has not
been changed since. Releases published before the project was accepted for signing are
not signed.

## What is signed

Only `LadderLab.exe` built by the [Release workflow](.github/workflows/release.yml) on
GitHub Actions from the source code in this public repository. The workflow runs the
tests, exports the program from the source in the repository, and sends it for signing.
Nothing built anywhere else, and no program or library made by others, is signed with
this certificate.

Every signing request is approved by hand by an approver (below) before the release is
published.

## Team roles

- **Committers and reviewers**: [JarasonPC](https://github.com/JarasonPC) (the members of
  this repository)
- **Approvers**: [JarasonPC](https://github.com/JarasonPC) (owner)

Everyone with write access to the repository or access to signing uses multi-factor
authentication on GitHub and SignPath. Access is removed as soon as someone no longer
needs it.

## Privacy policy

See [PRIVACY.md](PRIVACY.md). In short: LadderLab does not transfer any information to
other networked systems unless you ask for it, except one request to GitHub at start to
check for a new version, which you can turn off (Help > Check for updates at startup).

## System changes

LadderLab is not installed: it is one program file that runs from any folder, without
administrator rights.

- **File association (Windows)**: so that double-clicking a `.ladder` file opens it,
  LadderLab registers the extension for the current Windows user. It writes the registry
  keys `HKEY_CURRENT_USER\Software\Classes\.ladder` and
  `HKEY_CURRENT_USER\Software\Classes\LadderLab.Schematic`, nothing else, and nothing for
  other users or the whole computer. **File > Open .ladder files with LadderLab** turns
  this off and removes both keys.
- **Its own data** (settings, recovery copies, logs) is kept in
  `%APPDATA%\Godot\app_userdata\LadderLab`, see [PRIVACY.md](PRIVACY.md).

To remove LadderLab completely: untick File > Open .ladder files with LadderLab, close
the program, delete `LadderLab.exe` and the data folder above.

## Reporting a problem with a signed file

See [SECURITY.md](SECURITY.md).
