import { createCipheriv, createDecipheriv, createHash, randomBytes, timingSafeEqual } from 'node:crypto';

export const adminOrigin = process.env.ADMIN_ORIGIN || 'https://livescore-one.vercel.app';
export const repoFile = 'https://api.github.com/repos/SanjayNewar7/livescore/contents/public/predefined_data.json';
const cookieName = 'livegoal_admin';

function sessionKey() {
  const secret = process.env.GITHUB_CLIENT_SECRET;
  if (!secret) return null;
  return createHash('sha256').update(`livegoal-admin-session:${secret}`).digest();
}

export function configured() {
  return Boolean(process.env.GITHUB_CLIENT_ID && process.env.GITHUB_CLIENT_SECRET);
}

export function cookie(name, value, maxAge) {
  return `${name}=${encodeURIComponent(value)}; Path=/; HttpOnly; Secure; SameSite=Lax; Max-Age=${maxAge}`;
}

export function clearCookie(name) {
  return cookie(name, '', 0);
}

export function readCookie(request, name) {
  const match = (request.headers.get('cookie') || '').split('; ')
    .find(part => part.startsWith(`${name}=`));
  if (!match) return null;
  try { return decodeURIComponent(match.slice(name.length + 1)); } catch { return null; }
}

export function sealSession(token, login) {
  const iv = randomBytes(12);
  const cipher = createCipheriv('aes-256-gcm', sessionKey(), iv);
  const payload = Buffer.from(JSON.stringify({ token, login, expires: Date.now() + 7 * 86400000 }));
  const encrypted = Buffer.concat([cipher.update(payload), cipher.final()]);
  return Buffer.concat([iv, cipher.getAuthTag(), encrypted]).toString('base64url');
}

function openSession(request) {
  const value = readCookie(request, cookieName);
  const key = sessionKey();
  if (!value || !key) return null;
  try {
    const bytes = Buffer.from(value, 'base64url');
    const decipher = createDecipheriv('aes-256-gcm', key, bytes.subarray(0, 12));
    decipher.setAuthTag(bytes.subarray(12, 28));
    const data = JSON.parse(Buffer.concat([
      decipher.update(bytes.subarray(28)), decipher.final(),
    ]).toString());
    return data.expires > Date.now() && data.login?.toLowerCase() === 'sanjaynewar7'
      ? data : null;
  } catch { return null; }
}

export async function adminSession(request) {
  const session = openSession(request);
  if (!session) return null;
  try {
    const response = await github('/user', session.token);
    if (!response.ok) return null;
    const user = await response.json();
    return user.login?.toLowerCase() === 'sanjaynewar7' ? session : null;
  } catch { return null; }
}

export function stateMatches(a, b) {
  if (!a || !b || a.length !== b.length) return false;
  return timingSafeEqual(Buffer.from(a), Buffer.from(b));
}

export function github(path, token, options = {}) {
  const url = path.startsWith('https://') ? path : `https://api.github.com${path}`;
  return fetch(url, {
    ...options,
    headers: {
      Accept: 'application/vnd.github+json',
      Authorization: `Bearer ${token}`,
      'X-GitHub-Api-Version': '2022-11-28',
      'User-Agent': 'LiveGoal-Players-Admin',
      ...options.headers,
    },
  });
}

export const sessionCookie = cookieName;

export function json(data, status = 200) {
  return Response.json(data, {
    status,
    headers: { 'Cache-Control': 'no-store' },
  });
}
