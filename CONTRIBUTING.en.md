# Contributing to Baby Signal

[简体中文](CONTRIBUTING.md) · **English**

Fork, change and submit a pull request. Read the current README limitations first: this is not a dependable overnight care tool.

Useful contributions include diagnosing locked-screen classification separately from capture, testing proposed system-recognition bridges, improving CPU detection with independent positive/negative samples, checking repeated alerts/recovery/permissions/disconnection, and co-designing accessible interactions with consenting deaf caregivers.

Configure your own signing locally in ignored `Config/Signing.local.xcconfig`. Do not publish Team IDs, accounts, certificates or device identifiers.

Use `scripts/verify.sh`. Respect its single-instance lock and at most two build jobs. Do targeted checks first, then run final complete checks once, sequentially. Explain the problem, resulting behavior, checks actually run, device/system versions and remaining gaps in a PR. Keep capture, scoring, scheduling, watch perception and waking evidence separate.

For translations, update both `Shared/Localization/en.lproj/Localizable.strings` and `zh-Hans.lproj/Localizable.strings`; keys, format placeholders and meaning must match. App and extension permission/name resources live in their own language folders. Keep prototype limitations and privacy wording equally clear in both languages. A new string needs an English translation, a Chinese entry and verification of its actual resource target.

Report only necessary device models, versions, anonymous steps and sanitized error domains/codes. Remove identifiers, contact details, location, health information, chat screenshots and real baby audio/photos. Never make a baby cry for tests. Do not copy leaked private data into a public issue; use a private contact actually provided on the maintainer's GitHub profile, or stop public distribution if none is available.
