# Dhamma Diary: screen recording for App Review

Record on a physical iPhone, not the simulator. Daily Review's haptics only work on a device, and Apple asked for a device recording. Aim for 3–5 minutes. iOS screen recording doesn't capture haptics, but it does capture the stone sounds if the microphone and device audio are on. It's fine either way.

## Prepare beforehand
- **Fresh install** of the build under review, so onboarding shows from the start. Delete any existing copy of Dhamma Diary first, which also clears its data. TODO(PJ): use the same build number you submit. Either install it from TestFlight, or build it from Xcode in Release configuration (the demo-data hooks are debug-only).
- **Ringer on**, volume up, so the stone sounds play.
- **Do Not Disturb off**, if you'll show a reminder arriving (optional).
- **No accounts or demo data needed:** the app has no login and makes no network requests.
- **Optional:** add the Dhamma Diary widgets to the Home Screen and Lock Screen before you start, so you can show them at the end without editing the screen on camera.
- **iOS screen recording:** add it to Control Center if it isn't there already.

## Shot list
1. **Launch.** Start recording on the Home Screen, then tap the Dhamma Diary icon.
2. **Onboarding: welcome.** Read briefly, then continue.
3. **Today coach.** Follow the coach: swipe the stone left or right to flip between white and black, and hold to log.
4. **First stone.** Log a white stone. In the sheet, pick a root and add a short note, for example "Helped a colleague", then save.
5. **Review tour, then Diary tour.** Tap through both.
6. **Mind check-in invite.** Turn reminders on, choose how many a day, and allow notifications in the iOS prompt. This shows the only notification permission request.
7. **Today: more stones.** Log one black stone and one more white stone.
8. **Mind check-in.** Press and slide the stone up or down, then release. The day's mind line appears.
9. **Review.**
   - Show the stats line, calendar and mind chart.
   - Tap **Daily Review**. The stones fall into white and black heaps with sound, then the day's tally, the mind line and "No diary entry yet" appear.
   - Go back.
10. **This week.** Tap **This week**. The week's stones fall, then each day's row appears. Go back.
11. **Diary › Tonight.**
    - Show the passage and question.
    - Type a short entry and tap **Save**.
    - Tap **Read the full sutta**. Safari opens suttacentral.net. Return to the app.
12. **Diary › Entries.** Open the entry just saved.
13. **Diary › Passages.** Scroll the list briefly and open one passage.
14. **Review › Daily Review again.** It now shows the saved entry.
15. **About.** Scroll through: the app's purpose, the Upagupta story, the SuttaCentral/Sujato credit and the feedback button. Don't send an email.
16. **Widgets (optional).** Go to the Home Screen and Lock Screen and show the widgets. Tap a stone button on the check-in widget, open the app, and show the stone on Today.
17. **Siri (optional).** Say "Log a white stone in Dhamma Diary".
18. **Stop recording.**

## Flows Apple listed

| Flow | In this app |
| --- | --- |
| Account registration | Not applicable: there are no accounts. |
| Login | Not applicable: no login. |
| Account deletion | Not applicable: no accounts. All data is on the device and is removed when the app is deleted. In the app, a journal entry is deleted by clearing its text, and a mind check-in by touching and holding it in Review. |
| User-generated content, reporting and blocking | Not applicable: journal entries, stones and check-ins stay private on the device and are never shared with other users. |
| Paid content or features | Not applicable: the app is free, with no in-app purchases or subscriptions. |

## After recording
- Trim the start and end if needed, keeping app launch in.
- Upload the video as an attachment in App Store Connect, or host it and paste the link into item 1 of `APP_REVIEW_NOTES.md`.
