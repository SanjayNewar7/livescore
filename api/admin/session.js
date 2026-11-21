import { adminSession, configured, json } from '../../server/admin.js';

export async function GET(request) {
  if (!configured()) return json({ configured: false, authenticated: false });
  const session = await adminSession(request);
  return json({ configured: true, authenticated: Boolean(session), login: session?.login });
}
