# Built-in recognition and quick recovery

[简体中文](quick-resume.md) · **English**

The current build uses Apple `SNClassifySoundRequest(.version1)` / `baby_crying`, with thresholds 0.45 / 0.65 / 0.80. Earlier YAMNet files are retained for comparison and excluded from the app build.

The test device has a known locked-screen classifier failure. These interactions provide recovery entry points; they do not fix that system behavior.

## Flow

1. The caregiver stops the system alarm; automatic recovery is retained.
2. If interrupted/failed, the home screen provides **Resume monitoring**, without requiring an entire session stop/start.
3. While reconnecting, the same location shows **Resuming… Please wait**, disabled to avoid duplicate restarts.
4. An interrupted/stale Lock Screen card or expanded Dynamic Island opens `babysignal://recover`; valid analysis is required before showing resumed status.
5. The crying acknowledgment ends this alert and attempts recovery only when monitoring intent remains. Acknowledging old history after explicit stop does not turn on the microphone.

A ringing system alarm must end first. Revoked permissions need authorization. Tapping a recovery link after a cold launch is an explicit user request; ordinary app launch never starts the microphone automatically.

## Evidence

Earlier core checks covered preserving intent, settling time and late callbacks. Device snapshots showed three locked-screen restart failures; after foregrounding the app, valid analysis returned. The initial recovering state hid the button despite instructions referencing it; that was corrected. Final button/deep-link operations still need end-to-end device coverage.

The bilingual build adds shared labels and history-description translation without claiming new detection reliability. See the README for current check counts.
