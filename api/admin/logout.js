import { clearCookie, json, sessionCookie } from '../../server/admin.js';

export function POST() {
  const response = json({ ok: true });
  response.headers.set('Set-Cookie', clearCookie(sessionCookie));
  return response;
}
