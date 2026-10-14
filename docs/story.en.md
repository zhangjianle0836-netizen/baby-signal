# Why Baby Signal exists

[简体中文](story.md) · **English**

The project began when its initiator saw a video about a deaf mother caring for her child. A comment described a challenge that made him pause: someone who cannot hear crying may need to watch their baby continuously or more frequently.

Everyday information often arrives as sound: a baby's cry, a doorbell or a device alert. Deaf and hard-of-hearing caregivers need that information too, in a form they can perceive.

The idea was simple: a phone near the baby listens locally, identifies candidate crying, and provides a tactile watch reminder with clear pictures and text. The mother checks and cares for the baby in person. Dismissing an alert should let monitoring continue; if it is interrupted, the interface should say so and provide a quick way to resume.

The first implementation uses an iPhone and Apple Watch because those were available for testing. It does not assume all families can afford them. Lower-cost phones, wristbands and other accessible reminders are welcome future directions.

## Why publish an unfinished version?

Testing exposed important failures. The built-in classifier stopped after a particular phone locked. A CPU alternative kept background processing working in one test-alarm recovery, but the existing short crying fixture did not satisfy consecutive confirmation. A watch vibration in a test does not prove that it will wake a sleeping wearer.

These findings belong beside the interface. Publishing code, states, failures and verification methods helps others understand what the prototype can do, what remains missing and where improvements can begin.

This is an inspectable engineering starting point, not a validated overnight care tool. Unresolved detection and background problems must not be treated as the caregiver's responsibility to discover in use.

## Protecting the original people

This account summarizes the inspiration; we did not independently verify personal circumstances or establish collaboration. Public materials exclude original faces, usernames, location, private messages, health details and identifying family information. Private conversations and comments are not reproduced verbatim.

![Fictional caregiving and reminder scenes](images/origin-story.png)

The image was generated with Codex's built-in image_gen tool. Characters and surroundings are fictional. It is not a news photograph, user-research evidence or a success case. The prompt contains no original identities or health details. [Generation prompt](story-image-prompt.json)
