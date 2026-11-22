# Diary editor keeps the typed line in view (22 Nov 2026)

## Problem

PJ reported that on Tonight, a long entry ran down behind the keyboard while typing. The line being typed went out of view and had to be scrolled up by hand.

The cause: the `TextEditor` sat inside the page's `ScrollView` with only `minHeight: 220`, so it grew with its text. The editor never scrolled itself, and SwiftUI doesn't move the outer scroll view to follow the cursor.

## Fix (`DhammaDiary/Views/Diary/TonightView.swift`)

- While writing, the editor's height is fixed to the visible area above the keyboard, less 24pt. The height comes from `onGeometryChange` on the scroll view, which shrinks when the keyboard is up.
- The editor then scrolls inside itself, and UIKit keeps the cursor in view, including when editing in the middle of the text.
- When the editor gains focus, or the visible height changes, a `ScrollViewReader` scrolls the page so the editor's top is at the top.
- While writing, there is a 48pt bottom margin inside the editor, so the keyboard's floating Done button doesn't cover the last line.
- When not writing, the editor grows with its text as before, so the whole entry can be read on the page.
- New DEBUG launch argument: `-debug.writeEntry YES` fills the editor with a long draft and starts writing.

## Verification

- Build and all 96 tests pass.
- Simulator (iOS 26.2, "DD Onboarding"): with a long draft, the editor fills the space above the keyboard and the cursor at the end is visible: [screenshot](../session-artifacts/2026-11-22-diary-editor-keyboard-01.png).
- Not checked: typing itself. The simulator can't be typed into from the command line, because Accessibility access is not allowed. The keyboard's Done button didn't show on the simulator either. Please check both on the phone.
