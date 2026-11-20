# Anime avatar catalog setup

The app reads a public list of avatars from `api/avatars.js`. The function reads
the 27 images in Cloudinary's dynamic asset folder `LiveGoal Avatar` using the
Admin API. It returns only asset IDs and public delivery URLs. The Cloudinary
API secret must stay on the server.

1. Deploy this repository to a Vercel project. In the Vercel project settings,
   add `CLOUDINARY_API_KEY` and `CLOUDINARY_API_SECRET` as environment variables
   for the function. Do not put either value in Flutter or in source control.
2. Visit `https://YOUR-PROJECT.vercel.app/api/avatars` and confirm it returns an
   `avatars` array. If it is empty, confirm the Cloudinary folder is named
   exactly `LiveGoal Avatar` and that its assets have public delivery enabled.
3. Build Flutter with
   `flutter build apk --dart-define=AVATAR_CATALOG_URL=https://YOUR-PROJECT.vercel.app/api/avatars`.
   Use the same define for `flutter run` and release App Bundles.

The app caches the catalog on the phone and saves the chosen avatar image in
application documents storage for offline display. The first avatar download
requires a network connection. If no catalog URL is configured, custom photos
and suggested names still work, but anime avatar selection is unavailable.
