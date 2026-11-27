# Today stopped scrolling after logging a stone (28 Nov 2026)

PJ: straight after logging a stone, Today locked in place and couldn't be scrolled.

## Cause

Holding the stone for 0.8s opens the stone sheet while the finger is still down. Presenting the sheet cancels the stone gesture, and a cancelled `LongPressGesture.sequenced(before: DragGesture)` never calls `onEnded`. So `endPress()` never ran, `stonePressed` stayed true, and `.scrollDisabled(stonePressed)` kept Today from scrolling after the sheet closed.

## Fix (`DhammaDiary/Views/Today/TodayView.swift`)

- `@GestureState stoneGestureActive` is set while the press is live. SwiftUI resets gesture state on cancellation too, so `onChange(of: stoneGestureActive)` ends a press that's still marked as held, without recording a mind check-in (`endPress(record: false)`).
- Backstop: the stone sheet's `onDismiss` does the same before reloading the stones.
- A normal release still goes through `onEnded` and records a slide as before.

## Verification

- Build and 105 tests pass. The app was installed and opened on Today in the "DD Screens" simulator.

## Not verified

- The long press itself: the simulator can't be pressed and held from here, so the fix hasn't been tried by touch. To check on the phone: hold the stone until the sheet opens, save or cancel it, then scroll Today. Also check that a slide (mind check-in) still records once.
