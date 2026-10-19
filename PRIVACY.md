# Privacy policy

LadderLab does not collect personal data. It has no accounts, no telemetry, no analytics
and no advertising, and your schematics never leave your computer unless you send them
somewhere yourself.

## What goes over the network

LadderLab does not transfer any information to other networked systems unless you ask
for it, with one exception: **the update check**.

- **Update check.** When LadderLab starts, and when you choose Help > Check for updates…,
  it asks GitHub whether a newer version has been released: a single HTTPS request to
  `https://api.github.com/repos/JarasonPC/ladder-lab/releases/latest`. The request contains
  nothing about you or your work. Like every web request it shows GitHub your IP address,
  and it names the program version (for example `User-Agent: LadderLab/0.4.1`). GitHub's
  [privacy statement](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement)
  applies to it. To stop the check at start, untick **Help > Check for updates at startup**.
- **Links.** LadderLab on GitHub, Report a problem, the new-version button and the project
  website in the About window open in your web browser, only when you click them.

## What is stored on your computer

Everything below stays on your computer:

- **Your files**: schematics (`.ladder`) and exported PNG and PDF files, where you save them.
- **Settings**: recent files, view options, language, panel sizes and the update check
  setting, in `settings.cfg` in the LadderLab data folder.
- **Recovery copies**: while a schematic has unsaved changes, a copy is kept in the
  `recovery` folder of the data folder, so the work survives a crash. It is removed when
  you save the schematic or discard the changes.
- **Logs**: the program's own messages (no personal data) in the `logs` folder of the data
  folder, as every program made with Godot keeps them.
- **File association (Windows)**: see [System changes](CODE_SIGNING.md#system-changes).

The data folder is `%APPDATA%\Godot\app_userdata\LadderLab` on Windows. Deleting it
removes all of the above except your own files.

## Questions

Ask in the [issues](https://github.com/JarasonPC/ladder-lab/issues) of the project.
