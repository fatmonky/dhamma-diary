# When does a day end?

Midnight is a poor boundary for a reflection journal. If you sit down at 00:40 to write about your day, the app shouldn't decide that your day has already ended and a new one, with nothing in it yet, has begun.

Dhamma Diary uses a 3am day. Anything before 03:00 belongs to the day you were living. A stone logged at 1am counts towards yesterday's balance, appears under yesterday in Review, and the journal entry you write then is yesterday's entry.

The rule is simple to state and fiddly to get right. The plan said: subtract three hours, then take the date. That sounds safe, but on the morning the clocks spring forward, 03:30 minus three hours of real time is 23:30 the night before. So the app now asks a plainer question: is this moment before 03:00 on its own date? If so, it belongs to the previous day. The tests pin this down with New York's 2026 clock changes: a 23-hour day in March and a 25-hour day in November.

Writing those tests also turned up an old White Stone bug. Each stone stores a day key next to its timestamp, and editing a stone's time was meant to update both. It never did, because the database framework quietly skips the code that was supposed to do it. Now there's one method that changes both together, and a test that would catch it breaking again.

Nothing looks different in the app today. You'd only notice at 2am.
