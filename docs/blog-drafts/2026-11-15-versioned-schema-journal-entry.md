# A journal entry that remembers what it answered

White Stone had "reflections": one answer a day to a question picked from a short list, stored as a number pointing into that list. That works while the list never changes. Dhamma Diary's questions come from a passage set that I'll keep adding to and occasionally reword, so a number pointing into a list could quietly change the meaning of an old entry.

So the new `JournalEntry` keeps a copy of what was on screen that day: the passage reference, its title and the exact question. Reword a question next year and last year's entry still shows the question it actually answered.

The rules stay as simple as White Stone's:

- One entry per day. Saving again replaces the text.
- Clearing the text deletes the entry.
- You can only start an entry for today. A missed day stays missed, but anything already written can be edited.

These rules now live in one small place with their own tests. Before, each screen wrote to the database itself.

The other change is invisible: the database is versioned from day one. White Stone never was. That's fine until the first time a model changes and there's no path to carry people's data across. Dhamma Diary starts with a version 1 schema and an empty migration plan, so the first change will have somewhere to go.

For now, the evening tab shows a quiet placeholder where the passage will go. The passages themselves come next.
