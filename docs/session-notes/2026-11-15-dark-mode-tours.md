# Tour cards unreadable in dark mode

PJ, on their own phone (dark mode), found the Today coach card nearly blank: the card was hard-coded white (`Color.white.opacity(0.98)`), but its title and body use the system text colours, which are white in dark mode.

## Fix

The three tour cards (Today coach, Review tour, Diary tour) now use `Color(.tertiarySystemBackground)`: white in light mode as before, dark grey in dark mode. There are no other hard-coded white surfaces in the views.

## Check

58/58 tests pass. Screenshots in dark mode on a fresh, throwaway iPhone 17 simulator (deleted afterwards):

- [Today coach](../session-artifacts/2026-11-15-dark-tour-01-todayCoach.png)
- [Review tour](../session-artifacts/2026-11-15-dark-tour-02-reviewTour.png)
- [Diary tour](../session-artifacts/2026-11-15-dark-tour-03-diaryTour.png)
- [Welcome](../session-artifacts/2026-11-15-dark-tour-04-welcome.png)

Not yet checked on PJ's phone.
