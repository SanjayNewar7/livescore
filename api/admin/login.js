import { randomBytes } from 'node:crypto';
import { adminOrigin, configured, cookie, json } from '../../server/admin.js';

export function GET() {
  if (!configured()) return json({ error: 'GitHub sign-in is not configured.' }, 503);
  const state = randomBytes(24).toString('hex');
  const url = new URL('https://github.com/login/oauth/authorize');
  url.searchParams.set('client_id', process.env.GITHUB_CLIENT_ID);
  url.searchParams.set('redirect_uri', `${adminOrigin}/api/admin/callback`);
  url.searchParams.set('scope', 'public_repo');
  url.searchParams.set('state', state);
  url.searchParams.set('allow_signup', 'false');
  return new Response(null, {
    status: 302,
    headers: {
      Location: url.toString(),
      'Set-Cookie': cookie('livegoal_oauth_state', state, 600),
      'Cache-Control': 'no-store',
    },
  });
}
