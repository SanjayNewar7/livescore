# Updating player fallback data

The published feed is [`public/predefined_data.json`](public/predefined_data.json).
Vercel serves it at `https://livescore-one.vercel.app/predefined_data.json`.
No app rebuild is needed for changes to this JSON file.
Existing installations need one app update containing the new sync service;
after that, data-only changes arrive through the feed.

1. Edit the player fields in `famousPlayers` or `predefinedPlayerStats`.
   Keep the existing JSON structure, IDs, and `schemaVersion: 1`.
2. Set `revision` to a new unique value, such as the current UTC date and time.
3. Commit and push the JSON file to `master`. After the Vercel deployment is
   ready, verify the published URL contains the new revision.

The app checks when it starts, resumes, or regains connectivity. Android's
existing periodic worker also checks in the background while connected;
Android decides the exact execution time. It validates the response before
saving `predefined_data.json` in the app's private documents directory. The
saved copy works offline. On a new installation with no saved copy, the bundled
Dart constants are the fallback.

The Dart constants in `lib/utils/predefined_data.dart` are only the bundled
first-install fallback. Edit the published JSON for routine stat changes.
