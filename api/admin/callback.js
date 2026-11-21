import {
  adminOrigin, clearCookie, cookie, github, readCookie,
  sealSession, sessionCookie, stateMatches,
} from '../../server/admin.js';

export async function GET(request) {
  const url = new URL(request.url);
  const state = url.searchParams.get('state');
  const saved = readCookie(request, 'livegoal_oauth_state');
  const headers = new Headers({
    'Cache-Control': 'no-store',
    'Set-Cookie': clearCookie('livegoal_oauth_state'),
  });
  if (!stateMatches(state, saved) || !url.searchParams.get('code')) {
    headers.set('Location', `${adminOrigin}/players/?error=signin`);
    return new Response(null, { status: 302, headers });
  }
  try {
    const response = await fetch('https://github.com/login/oauth/access_token', {
      method: 'POST',
      headers: { Accept: 'application/json', 'Content-Type': 'application/json' },
      body: JSON.stringify({
        client_id: process.env.GITHUB_CLIENT_ID,
        client_secret: process.env.GITHUB_CLIENT_SECRET,
        code: url.searchParams.get('code'),
        redirect_uri: `${adminOrigin}/api/admin/callback`,
      }),
    });
    const result = await response.json();
    if (!response.ok || !result.access_token) throw new Error('Token exchange failed');
    const userResponse = await github('/user', result.access_token);
    if (!userResponse.ok) throw new Error('Account lookup failed');
    const user = await userResponse.json();
    if (user.login?.toLowerCase() !== 'sanjaynewar7') {
      headers.set('Location', `${adminOrigin}/players/?error=forbidden`);
      return new Response(null, { status: 302, headers });
    }
    headers.append('Set-Cookie', cookie(sessionCookie,
      sealSession(result.access_token, user.login), 7 * 86400));
    headers.set('Location', `${adminOrigin}/players/`);
  } catch {
    headers.set('Location', `${adminOrigin}/players/?error=signin`);
  }
  return new Response(null, { status: 302, headers });
}
