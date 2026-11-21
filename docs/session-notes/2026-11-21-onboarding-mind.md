# Onboarding for the mind check-in, and choosing how many reminders (21 Nov 2026)

Branch `onboarding-mind`, from `main` at e3d74ec. Spec 9.9.

## What PJ asked for
Onboarding still described the app before the mind check-in. PJ approved four changes (coach step, Review tour copy, shorter invite, invite even after skipping) and asked first for a setting for how many reminders a day.

## What changed
- **Reminders a day, 1–6** (`MindCheckSchedule.windows(perDay:)`, `MindCheckNotifications.perDay` / `setPerDay(_:)`, key `mindCheck.perDay`, default 3). 9am–9pm is split into that many equal windows, one random time in each, at least an hour apart; three gives the old 9–13, 13–17, 17–21. Changing the number clears and reschedules the week ahead. Six a day is 42 pending notifications, under iOS's 64.
- **Review:** "Reminders are off. Turn on" / "Reminders: 3 a day ⌄ 9am–9pm … Stop". "3 a day" is a menu, Once a day to 6 times a day. "at random" was dropped so the row fits one line on an iPhone (checked by rendering it at card width).
- **Today coach:** a middle card, "Slide to note your mind". It's a Next card like the swipe card, since the overlay blocks the stone; trying the gesture there would need the overlay reworked.
- **Review tour:** now starts with "Mind today".
- **Invite:** bell icon instead of the Voice Memos-like waveform, shorter copy, and "How many a day?" (1–6, segmented, starts at 3).
- **Skipping still asks:** every Skip / Not now (welcome, coach, first-stone sheet, Review tour, Diary tour) leads to the invite. From a sheet, the invite opens in that sheet's `onDismiss`, since two sheets can't be up at once.
- DEBUG launch argument `-debug.coachStep N` opens the coach at a card, for screenshots.
- AGENTS.md onboarding rule, the privacy policy ("three a day unless you choose between one and six") and spec 9.9 updated.

## Verification
- Build and all 96 tests pass (new: any count 1–6 fits 9am–9pm an hour apart over 300 seeds each; count clamped; a 6-a-day plan is 42 times).
- Screenshots on a fresh throwaway simulator ("DD Onboarding", left booted):
  - [Coach: Slide to note your mind](../session-artifacts/2026-11-21-onboarding-mind-01-coach-slide.png)
  - [Reminders invite with How many a day?](../session-artifacts/2026-11-21-onboarding-mind-02-invite.png)
  - [Review tour copy](../session-artifacts/2026-11-21-onboarding-mind-03-review-tour.png)
  - [Review reminders row (rendered at card width)](../session-artifacts/2026-11-21-onboarding-mind-04-review-reminders.png)
- Not checked: the reminders "on" row in the running app (the simulator can't grant notification permission without tapping the prompt), the skip → invite transitions by tapping through, and that changing the count reschedules on a real phone.
