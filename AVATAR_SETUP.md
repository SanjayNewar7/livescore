# Anime avatar catalog setup

The app reads a public list of avatars from `api/avatars.js`. The function reads
the 27 images in Cloudinary's dynamic asset folder `LiveGoal Avatar` using the
Admin API. It returns only asset IDs and public delivery URLs. The Cloudinary
API secret must stay on the server.

1. Deploy this repository to a Vercel project with the Root Directory set to
   the repository root and the production branch set to `master`. In the Vercel project settings,
   add `CLOUDINARY_API_KEY` and `CLOUDINARY_API_SECRET` as environment variables
   for the function. Do not put either value in Flutter or in source control.
2. Visit `https://YOUR-PROJECT.vercel.app/api/avatars` and confirm it returns an
   `avatars` array. If it reports no images, confirm that the Cloudinary API
   key and secret belong to the same product environment as the 27 images,
   that its cloud name is `dkk7zqgnz`, and that the root asset folder is named
   exactly `LiveGoal Avatar`. Check a sample asset's public delivery URL.
3. Build Flutter normally. The app defaults to
   `https://livescore-one.vercel.app/api/avatars` for both debug and release builds.
   To point a build at another catalog, pass
   `--dart-define=AVATAR_CATALOG_URL=https://YOUR-PROJECT.vercel.app/api/avatars`
   to `flutter run`, `flutter build apk`, or `flutter build appbundle`.

The app caches the catalog on the phone and saves the chosen avatar image in
application documents storage for offline display. The first avatar download
requires a network connection. If the first download fails, the app retries
when connectivity returns. Custom photos and suggested names also work offline.
