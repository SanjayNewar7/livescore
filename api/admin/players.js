import { adminSession, adminOrigin, github, json, repoFile } from '../../server/admin.js';

function validate(data) {
  if (!data || data.schemaVersion !== 1 ||
      !Array.isArray(data.famousPlayers) ||
      !Array.isArray(data.famousClubs) ||
      typeof data.predefinedPlayerStats !== 'object' ||
      !data.predefinedPlayerStats || Array.isArray(data.predefinedPlayerStats) ||
      typeof data.clubLogoIds !== 'object' || !data.clubLogoIds ||
      data.famousPlayers.length === 0 || data.famousPlayers.length > 500 ||
      data.famousClubs.length === 0 ||
      Object.keys(data.predefinedPlayerStats).length === 0 ||
      Object.keys(data.clubLogoIds).length === 0) return 'Invalid dataset structure.';
  const ids = new Set();
  const fields = ['id', 'name', 'teamName', 'teamId', 'position',
    'jersey', 'nationality', 'imageUrl'];
  for (const player of data.famousPlayers) {
    if (!player || fields.some(key => typeof player[key] !== 'string' ||
        player[key].length > 500) ||
        !player.id.trim() || !player.name.trim() || ids.has(player.id)) {
      return 'Every player needs a unique ID and valid details.';
    }
    if (player.imageUrl && (!player.imageUrl.startsWith('https://') ||
        !URL.canParse(player.imageUrl))) return 'Player image URLs must use HTTPS.';
    ids.add(player.id);
  }
  for (const [id, stats] of Object.entries(data.predefinedPlayerStats)) {
    if (!ids.has(id) || !stats || !Array.isArray(stats.careerStats) ||
        !stats.seasonStats || typeof stats.seasonStats !== 'object' ||
        ['careerAppearances', 'careerGoals', 'careerAssists'].some(key =>
          typeof stats[key] !== 'number' || !Number.isFinite(stats[key]) || stats[key] < 0)) {
      return `Invalid statistics for player ${id}.`;
    }
  }
  return null;
}

async function readFile(token) {
  const response = await github(`${repoFile}?ref=master`, token);
  if (!response.ok) return { error: response.status };
  const file = await response.json();
  return {
    sha: file.sha,
    data: JSON.parse(Buffer.from(file.content.replace(/\s/g, ''), 'base64').toString('utf8')),
  };
}

export async function GET(request) {
  const session = await adminSession(request);
  if (!session) return json({ error: 'Sign in with the allowed GitHub account.' }, 401);
  try {
    const result = await readFile(session.token);
    if (result.error) return json({ error: 'Could not load repository data.' }, 502);
    return json(result);
  } catch { return json({ error: 'Could not load repository data.' }, 502); }
}

export async function POST(request) {
  const session = await adminSession(request);
  if (!session) return json({ error: 'Sign in with the allowed GitHub account.' }, 401);
  if (request.headers.get('origin') !== adminOrigin ||
      !request.headers.get('content-type')?.startsWith('application/json')) {
    return json({ error: 'Invalid request origin.' }, 403);
  }
  try {
    const text = await request.text();
    if (text.length > 1000000) return json({ error: 'Dataset is too large.' }, 413);
    const body = JSON.parse(text);
    const data = body.data;
    const error = validate(data);
    if (error || typeof body.sha !== 'string') {
      return json({ error: error || 'Missing file version.' }, 400);
    }
    const current = await readFile(session.token);
    if (current.error) return json({ error: 'Could not verify the current file.' }, 502);
    if (current.sha !== body.sha) {
      return json({ error: 'The data changed elsewhere. Reload before saving.' }, 409);
    }
    data.revision = new Date().toISOString();
    const content = Buffer.from(`${JSON.stringify(data, null, 2)}\n`).toString('base64');
    const update = await github(repoFile, session.token, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        message: `Update player data from LiveGoal admin`,
        content,
        sha: current.sha,
        branch: 'master',
      }),
    });
    if (!update.ok) {
      return json({ error: update.status === 409
        ? 'The file changed elsewhere. Reload before saving.'
        : 'GitHub rejected the update. Check the app permission.' }, update.status === 409 ? 409 : 502);
    }
    const result = await update.json();
    return json({ ok: true, sha: result.content.sha, revision: data.revision });
  } catch { return json({ error: 'Could not save player data.' }, 500); }
}
