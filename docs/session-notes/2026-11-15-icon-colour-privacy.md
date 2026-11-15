# Icon, robe brown, privacy policy (v1 build step 8)

Spec: `docs/spec/v1.md` §2 and §6. PJ's direction: the icon is a white stone on an open book page; the app's brown, throughout, is the robe colour of the monk in the foreground of PJ's alms-round photo.

## Colour

- Sampled from the photo: orange-hued, saturated pixels on the foreground monk's robe, sorted by brightness. The lit cloth (about the 85th percentile) is **#894E26**; the median is the shadowed cloth (#57280A). #894E26 gives 6.6:1 contrast on white, so it works for links and button fills.
- Dark mode uses a lighter version of the same hue, **#C47E48** (5.2:1 on iOS's dark grouped background). #894E26 on black would be 3.2:1, too low for small text.
- The `AccentColor` asset holds both. `ColorHelpers.accent` reads it, and all 21 hard-coded uses of the old brown (#876138) now use it. There's no other brown left in the Swift code.
- Spec §2 and AGENTS.md record the colour.

## Icon

- `scripts/icon/make_icon.py` (Pillow) draws `AppIcon.png`: an open book with lined pages on the robe brown, a white stone resting across the gutter, soft shadows. Run `python3 -I scripts/icon/make_icon.py`.
- Removed the White Stone icon source `AppIcon.svg` and the unused `WhiteStoneLogo` image set (nothing referenced it).

## Privacy policy

`docs/privacy-policy.md` rewritten for Dhamma Diary from spec §6: the name, "The only data Dhamma Diary stores is the stones you log and the journal entries you write, on your device", what an entry holds, no notifications or sync, the SuttaCentral and feedback links, and the feedback email as the contact. Publishing it on inquivision.com is step 10.

## Tests

58/58 pass.

## Screenshots

- [Home screen icon](../session-artifacts/2026-11-15-icon-colour-01-home.png), next to the old White Stone app
- [Today](../session-artifacts/2026-11-15-icon-colour-02-tab0.png)
- [Diary](../session-artifacts/2026-11-15-icon-colour-03-tab2.png)
- [Diary, dark mode](../session-artifacts/2026-11-15-icon-colour-04-diary-dark.png)

## Not verified / for PJ

- The icon is drawn in code, which works for now but isn't designer-quality. PJ to decide whether it ships or gets redrawn.
- Noticed, not changed: Today's line "Your ratio today of good thoughts to bad thoughts" (inherited from White Stone) uses good/bad wording.
