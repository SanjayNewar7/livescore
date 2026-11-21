import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

process.env.GITHUB_CLIENT_ID = 'test-client';
process.env.GITHUB_CLIENT_SECRET = 'test-secret';
const { sealSession, sessionCookie } = await import('../server/admin.js');
const admin = await import('../api/admin/players.js');
const data = JSON.parse(readFileSync(new URL('../public/predefined_data.json', import.meta.url), 'utf8'));
let sha = 'first-sha';
let commits = 0;
globalThis.fetch = async (url, options) => {
  if (url.endsWith('/user')) return Response.json({ login: 'SanjayNewar7' });
  if (url.includes('/contents/public/predefined_data.json') && options?.method === 'PUT') {
    const body = JSON.parse(options.body);
    assert.equal(body.branch, 'master');
    assert.equal(body.sha, sha);
    const saved = JSON.parse(Buffer.from(body.content, 'base64').toString('utf8'));
    assert.equal(saved.famousPlayers[0].name, 'Verification Player');
    assert.notEqual(saved.revision, data.revision);
    commits++;
    sha = 'next-sha';
    return Response.json({ content: { sha } });
  }
  if (url.includes('/contents/public/predefined_data.json')) {
    return Response.json({ sha, content: Buffer.from(JSON.stringify(data)).toString('base64') });
  }
  throw new Error(`Unexpected request: ${url}`);
};

const unauthorized = await admin.GET(new Request('https://livescore-one.vercel.app/api/admin/players'));
assert.equal(unauthorized.status, 401);
const cookie = `${sessionCookie}=${encodeURIComponent(sealSession('test-token', 'SanjayNewar7'))}`;
const request = new Request('https://livescore-one.vercel.app/api/admin/players', {
  headers: { Cookie: cookie },
});
const loaded = await admin.GET(request);
assert.equal(loaded.status, 200);
assert.equal((await loaded.json()).data.famousPlayers.length, 100);
const next = structuredClone(data);
next.famousPlayers[0].name = 'Verification Player';
const saveRequest = new Request('https://livescore-one.vercel.app/api/admin/players', {
  method: 'POST',
  headers: { Cookie: cookie, Origin: 'https://livescore-one.vercel.app', 'Content-Type': 'application/json' },
  body: JSON.stringify({ data: next, sha: 'first-sha' }),
});
assert.equal((await admin.POST(saveRequest)).status, 200);
assert.equal(commits, 1);
const stale = new Request('https://livescore-one.vercel.app/api/admin/players', {
  method: 'POST',
  headers: { Cookie: cookie, Origin: 'https://livescore-one.vercel.app', 'Content-Type': 'application/json' },
  body: JSON.stringify({ data: next, sha: 'first-sha' }),
});
assert.equal((await admin.POST(stale)).status, 409);
assert.equal(commits, 1);
console.log('Admin API verification passed.');
