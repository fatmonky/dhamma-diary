# Check in and log from the widget, and a Control Center control (spec 9.8)

Branch `mind-on-today`. PJ chose ideas 1–3 from the widget brainstorm: check in from the widget, a Control Center / Action button control, and log a stone from the widget.

## What changed

- **Check-in widget** (`DhammaDiaryWidget/CheckInWidget.swift`, kind `MindCheckIn`, small and medium): the question, Still · In between · Noisy buttons (10 / 50 / 90), and on medium a "Log a stone" row with white and black stone buttons plus "Noted at 21:40." after a tap that day. Tapping elsewhere opens Today (`dhammadiary://today`).
- **Control** (`MindCheckInControl`, iOS 18): "Mind check-in" opens Today. It can go in Control Center, on the Lock Screen, or on the Action button.
- **How taps are recorded:** the widget can't open the store (it's in the app's own container since the 20 Nov store fix). Buttons run intents (`DhammaDiary/Intents/WidgetIntents.swift`, compiled into both targets) that append to `WidgetLogQueue` in the App Group. `WidgetLogImporter` turns the queue into `MindCheck` / `Stone` records on launch and whenever the app becomes active, keeping each tap's time; it removes only what it imported and remembers imported ids so nothing is imported twice. Today reloads after an import.
- AGENTS.md and the privacy policy (taps wait briefly in shared on-device storage) updated.

## Tests

92/92 pass. New `WidgetLogTests` (5): each kind becomes the right record with the tap's time and reflection day; no double import; removal keeps taps that arrived meanwhile; last-noted time; empty queue.

## Not verified

- The widget's look and its buttons: widgets can't be added to a simulator Home Screen from the command line, so there's no screenshot. Check the Xcode preview, or add it on the phone (long-press the Home Screen → + → Dhamma Diary → Mind check-in).
- The control in Control Center and on the Action button (iOS 18, phone only).
- On the phone: a widget tap shows up in Today and Review once the app is opened, once each, at the time of the tap.
