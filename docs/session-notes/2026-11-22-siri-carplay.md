# Siri phrases and a CarPlay widget experiment (22 Nov 2026)

Branch `siri-carplay`, made from `lock-screen-widgets`; it needs the small Log a stone and Tonight's line widgets. Spec 9.11.

PJ asked how to use the app in CarPlay. A CarPlay app needs an Apple entitlement in a fixed list of categories (audio, communication, navigation, charging, fuelling, parking, food ordering, driving task, voice assistant). A journal doesn't fit any of them. So instead:

## Siri (`DhammaDiary/Intents/VoiceIntents.swift`)

App Shortcuts work in Siri, Spotlight and CarPlay with no setup:
- "Log a white stone in Dhamma Diary", or "Add a black stone in Dhamma Diary"
- "My mind is noisy in Dhamma Diary" (also in between or still; quiet, calm and busy are accepted as synonyms)
- "Dhamma Diary check-in": Siri asks "Noisy, in between, or still?"
- "What's tonight's question in Dhamma Diary": Siri reads the question

Logs go into the widget queue and are imported when the app next becomes active. If Siri is used while the app is already open on screen, the log appears after the app next comes back to the foreground.

## CarPlay widgets (experiment)

- iOS 26 can show iPhone widgets on CarPlay; WidgetKit has a `WidgetLocation.carPlay`.
- iOS 26 also lets a widget ask whether a simplified version is wanted (`levelOfDetail`). When it is:
  - Log a stone shows just the two stones, at 62pt;
  - Tonight's line shows the line alone in a larger font.
- Before iOS 26, or when it isn't simplified, the widgets are unchanged.
- Not yet known:
  - whether CarPlay asks for the simplified version;
  - which of our widgets it offers;
  - whether the stone buttons can be tapped there.

## Verification

- Build and all 100 tests pass.
- The built app's App Intents metadata lists the three shortcuts and their phrases.
- Not checked:
  - Siri itself: it can't be driven from the command line or the simulator.
  - CarPlay: it needs the car, or the CarPlay Simulator app with the phone connected.

## To try on the phone (TestFlight build from this branch)

1. **Siri:** say "Hey Siri, log a white stone in Dhamma Diary", then open the app and check Today's counts.
2. **CarPlay:** connect to the car → CarPlay Settings on the phone (Settings → General → CarPlay → your car) → widgets → add Dhamma Diary's. Note which ones are offered, how they look, and whether taps work.
