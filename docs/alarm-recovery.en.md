# Locked detection and recovery after alarm dismissal

[简体中文](alarm-recovery.md) · **English**

## Observed failures

Apple's built-in classifier failed after locking with `com.apple.SoundAnalysis / 2`. Audio-session reactivation then failed with `560557684` (`!int`). The generic error did not expose the classifier's internal cause; this is not proof of a GPU failure on this particular device. [Similar developer report](https://developer.apple.com/forums/thread/811582)

The original retry flow cleared monitoring intent after three failures. Changes preserved explicit user intent through transient failures, tolerated alarms already removed before the stop intent ran, polled scheduled/alerting → absent transitions, deduplicated stop callbacks and waited for actual analysis before declaring recovery. Explicit stop and ordinary cold launch never automatically start recording.

## Earlier CPU experiment

A CPU-only YAMNet Core ML conversion, with native 16 kHz log-mel preprocessing, was tested. [Pinned assets](yamnet-assets.json) · [Upstream/model notices](../THIRD_PARTY_NOTICES.en.md).

One locked system test alarm ended; valid analysis resumed about 2.3 seconds later. The participant reported a resumed Lock Screen card and normal compact Dynamic Island status. This was one test-alarm cycle, not an all-night or real-crying result.

An external short crying fixture produced nine windows; the peak infant-cry score was approximately 0.463, with only one window above 0.30. Consecutive confirmation did not trigger an alarm. Phone-microphone playback trials also produced no crying event. These are known misses, not an accuracy benchmark. The CPU approach was subsequently removed from the active build at the user's request.

## Current build

The app is back on the built-in classifier. Quick recovery was added; foreground valid analysis has been observed after background failure, but locked recognition remains unresolved. Earlier CPU success must not be used as evidence for this build. [Quick recovery](quick-resume.en.md)

Local diagnostics retain at most 60 lifecycle/error entries and a state snapshot, never audio. Debug `--recovery-check` explicitly starts an authorized engineering check and schedules a test only after healthy foreground analysis. Normal launches do not trigger it. All-night operation and real infant-event alert/recovery cycles remain unverified.
