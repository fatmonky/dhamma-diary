# Checking in without opening the app

The quickest check-in is the one you don't have to open an app for. Dhamma Diary now has a second widget: "How noisy is your mind now?" with three buttons, Still, In between and Noisy, and on the larger size a white and a black stone to log with a tap. There's also a Control Center control, which you can put on the Action button, that opens straight to the stone.

The interesting part was where the taps go. Widgets run in their own little process, and after last week's scare with the database moving folders, I didn't want the widget anywhere near the app's database. So a tap just writes a tiny note to a shared shelf: what was tapped, and when. The next time the app opens, it picks the notes up, turns them into check-ins and stones with their original times, and clears the shelf. Each note has an id, and the app remembers the ids it has already taken, so nothing is counted twice.

Stones logged from the widget are bare: no roots, no note. That felt right. It's Upagupta's basket again. Drop the pebble now, think about it later.
