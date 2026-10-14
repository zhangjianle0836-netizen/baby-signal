# Interface visuals

[简体中文](visual-design.md) · **English**

Cream background, ivory cards, clay primary buttons and warm brown-gray explanatory text accompany pictures and short instructions. States use symbols and text rather than sound/color alone. White-on-primary-button calculated contrast is approximately 6.5:1.

## Images

Generated with built-in `image_gen`. [Generation/edit prompts](illustration-prompts.json).

- [Phone placement](../BabySignal/Assets.xcassets/GuidePhone.imageset/illustration.png): outside the crib.
- [Watch wearing](../BabySignal/Assets.xcassets/GuideWatch.imageset/illustration.png): placement and tactile alert.
- [Check the baby](../BabySignal/Assets.xcassets/GuideCare.imageset/illustration.png): attentive caregiving.
- [Anonymous project story](images/origin-story.png): fictional motivation/concept scenes; [prompt](story-image-prompt.json).

Images are instructional/conceptual, not live video, health/safety assessments or documentary evidence.

Light-mode home and dark/large-text home states were previously inspected on iPhone 14 Pro. Native font scaling and accessible labels are implemented; complete VoiceOver, all sizes/pages and long translated labels still require verification.

Debug `--ui-dark` and `--ui-large-text` preview appearance without changing system settings; Release ignores these overrides. Language previews use launch-time Apple language arguments, followed by a normal relaunch. These previews must not be counted as device-wide permission/alarm/Watch language tests.
