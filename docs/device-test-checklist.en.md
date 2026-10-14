# Device verification checklist

[简体中文](device-test-checklist.md) · **English**

A successful build or silence classification is not evidence of dependable care monitoring or waking someone. One test watch vibration was reported after a 15-second delay and immediate locking; repeatability is not established.

## Installation and permissions

- [ ] Record models and full system/Xcode versions, without public device identifiers.
- [ ] Install with personal signing and launch after disconnecting the Mac.
- [ ] Test microphone/alarm access granted, denied and revoked. Never display active monitoring without valid analysis.
- [ ] Check behavior after signing expires and is renewed.

## Alerts, separate from detection

Test away from a resting baby; the phone may ring.

- [ ] Compare locked/unlocked phone states and actual watch perception/latency.
- [ ] Test Sleep Focus, Do Not Disturb, silent phone, locked/removed/charging watch.
- [ ] Stop on the watch and confirm system-ended state without automatically claiming perception.
- [ ] Confirm receipt separately; cancel pending alarms; relaunch and handle remaining alarms.
- [ ] Test range, walls, network loss and disconnection. Record unexpected phone sounds.

## Detection

Use lawful recordings for engineering checks; playback does not replace household observations. Never make a baby cry for testing.

- [ ] Short, quiet, intermittent and sustained crying: missed events and latency.
- [ ] TV/phone crying, adult crying, cats, speech, fan and white noise: false alerts.
- [ ] Different distances, orientations and placements; all sensitivity levels.
- [ ] Persistent crying does not flood alarms; new events can follow dismissal/quiet rearming.
- [ ] Silence continues producing analysis without false events.

## Background and recovery

Repeat without a debugger. Current built-in locked-screen failure is a known blocker, not a passed item.

- [ ] Locked-phone sound analysis and real sound-to-alert triggering.
- [ ] Calls, FaceTime, Siri and alarms: interruption and recovery.
- [ ] App alarm → stop → next detection; quick-resume action after failure.
- [ ] Audio device changes, late results after stop, rapid start/stop and permissions still being requested.
- [ ] Force quit/reboot does not claim the old session remains active.
- [ ] Hours of power use, temperature, analysis continuity and watch battery.

## Accessibility, language and overnight boundaries

Keep existing care arrangements. Daytime perception does not demonstrate waking from sleep.

- [ ] Repeat any natural-sleep perception evaluation safely and with consent.
- [ ] Chinese and English: home, guide, settings, history, permissions, alarm labels and Live Activities.
- [ ] Switching language with existing records/alarms preserves meaning; scheduled alarm text may retain its creation language.
- [ ] Large text, dark mode, landscape, scrolling and long English labels do not hide controls.
- [ ] VoiceOver reads controls, state and records; no dependence on color/sound alone.
- [ ] Users distinguish stopping an alert, stopping monitoring and acknowledging receipt.

Record scene/settings, sound start, event, alarm, actual perception, dismissal and recovery times separately. Measure misses, false alerts, end-to-end latency and recovery—not a threshold-derived accuracy claim.
