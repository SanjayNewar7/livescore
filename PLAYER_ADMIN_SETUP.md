# LiveGoal player admin

The panel is at `https://livescore-one.vercel.app/players`. It uses the same
SportFont and green palette as the app. The public phone feed remains at
`https://livescore-one.vercel.app/predefined_data.json`.

The panel uses GitHub sign-in; there is no separate admin password. Only the
GitHub account `SanjayNewar7` can use its read or write API. The account's
`public_repo` permission lets the panel commit only through the authenticated
user's GitHub access. Each save writes `public/predefined_data.json` to
`master`, and Vercel publishes the new revision automatically.

## One-time connection

1. In GitHub, open **Settings → Developer settings → OAuth Apps → New OAuth App**.
2. Set **Homepage URL** to `https://livescore-one.vercel.app/` and
   **Authorization callback URL** to
   `https://livescore-one.vercel.app/api/admin/callback`.
3. In the Vercel **livescore** project (the project that owns the
   `livescore-one.vercel.app` alias), add `GITHUB_CLIENT_ID` and
   `GITHUB_CLIENT_SECRET` to **Production** environment variables. Keep the
   secret only in Vercel. Redeploy production after adding them.
4. Open `/players` and choose **Continue with GitHub**. Sign in as
   `SanjayNewar7` and approve the public repository access.

The editor shows player portraits, basic details, career totals, season
figures, and career history. It supports creating, updating, and deleting
players. A saved change appears on the phone after Vercel deploys the JSON
feed and the app next checks for updates. Existing app installations still
need the one-time app release containing the data sync code.
