# Dynamic Island and Lock Screen Live Activities

[简体中文](live-activity.md) · **English**

The WidgetKit extension shares `MonitoringActivityState` with the app. ActivityKit requests, updates and ends activities locally; no push server or independent watch app is required.

Status follows valid analysis: preparing → monitoring; confirmed candidate crying → crying alert; interruption/retry → interrupted; valid analysis after recovery → resumed. Stop removes the activity. A new process ends old activities because the previous audio session no longer exists.

Normal content is submitted about every ten seconds; status changes are submitted immediately and sequentially. `staleDate` is the latest analysis time plus 30 seconds, capped by display lifetime. The extension shows a check/open-app message when `context.isStale` is true. iOS controls actual presentation timing.

An activity lasts up to eight hours. This version expires its displayed status at 7 hours 55 minutes. When foregrounded after 7.5 hours, it can replace the activity; it does not create a new activity forcibly in the background. Removing an activity is respected for that session. Session time includes temporary interruptions.

## Evidence and limitations

Compact interrupted status was inspected on device. The earlier CPU build later showed normal compact status, and a participant reported a resumed Lock Screen card after a test alarm. These do not prove the current built-in classifier works while locked. Expanded presentation, all languages/font sizes, eight-hour behavior, permission changes and VoiceOver remain device test targets.

App and extension share Chinese/English tables. An interrupted or stale view offers an app recovery entry point. Activities are not audio keep-alive mechanisms and do not substitute for the watch alarm.

[Apple documentation](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities)
