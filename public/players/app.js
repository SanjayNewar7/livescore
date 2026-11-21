const $ = selector => document.querySelector(selector);
const state = { data: null, sha: null, selectedId: null, creating: false, dirty: false, busy: false };
const fields = ['id', 'name', 'teamName', 'teamId', 'position', 'jersey', 'nationality', 'imageUrl'];
const seasonText = ['statsSeason', 'statsLeague', 'statsTeam'];
const seasonNumbers = ['goals', 'goalsPer90', 'shots', 'shotsOnTarget', 'passAccuracy', 'tackles', 'interceptions'];
const totalNumbers = ['careerAppearances', 'careerGoals', 'careerAssists'];

function notice(message, error = false) {
  const el = $('#notice');
  el.textContent = message;
  el.classList.toggle('error', error);
  el.hidden = false;
}

async function api(path, options) {
  const response = await fetch(path, { credentials: 'same-origin', ...options });
  const result = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(result.error || `Request failed (${response.status})`);
  return result;
}

function setMode(authorized, configured = true) {
  $('#authPanel').hidden = authorized;
  $('#editorPanel').hidden = !authorized;
  $('#addPlayer').hidden = !authorized;
  $('#logout').hidden = !authorized;
  $('#signIn').hidden = authorized || !configured;
  if (!authorized && configured) {
    $('#authTitle').textContent = 'Sign in to manage players';
    $('#authMessage').textContent = 'Use your GitHub account to manage the player catalog. There is no separate admin password.';
  }
  if (!authorized && !configured) {
    $('#authTitle').textContent = 'Admin setup is required';
    $('#authMessage').textContent = 'GitHub sign-in needs to be connected in the Vercel project before this workspace can be used.';
    $('#signIn').hidden = true;
  }
}

async function boot() {
  if (new URLSearchParams(location.search).has('error')) {
    notice('GitHub sign-in did not complete for the allowed account.', true);
    history.replaceState(null, '', '/players/');
  }
  try {
    const session = await api('/api/admin/session');
    setMode(session.authenticated, session.configured);
    if (session.authenticated) {
      $('#account').textContent = `@${session.login}`;
      await loadData();
    }
  } catch (error) {
    setMode(false);
    notice(error.message, true);
  }
}

async function loadData() {
  const result = await api('/api/admin/players');
  state.data = result.data;
  state.sha = result.sha;
  state.dirty = false;
  $('#playerCount').textContent = state.data.famousPlayers.length;
  renderList();
  if (state.selectedId) {
    const player = state.data.famousPlayers.find(item => item.id === state.selectedId);
    if (player) showPlayer(player);
    else showEmpty();
  }
}

function filteredPlayers() {
  const query = $('#search').value.trim().toLowerCase();
  return state.data.famousPlayers.filter(player =>
    [player.name, player.teamName, player.nationality, player.id]
      .some(value => (value || '').toLowerCase().includes(query)))
    .sort((a, b) => a.name.localeCompare(b.name));
}

function renderList() {
  if (!state.data) return;
  const list = $('#playerList');
  list.replaceChildren();
  const players = filteredPlayers();
  $('#shownCount').textContent = `Showing ${players.length} of ${state.data.famousPlayers.length}`;
  for (const player of players) {
    const button = document.createElement('button');
    button.type = 'button';
    button.className = `player-item${state.selectedId === player.id ? ' active' : ''}`;
    if (player.imageUrl) {
      const image = document.createElement('img');
      image.src = player.imageUrl;
      image.alt = '';
      image.loading = 'lazy';
      image.onerror = () => { image.replaceWith(fallback()); };
      button.append(image);
    } else button.append(fallback());
    const copy = document.createElement('span');
    const name = document.createElement('strong');
    name.textContent = player.name;
    const meta = document.createElement('small');
    meta.textContent = `${player.teamName || 'No club'} · ${player.position || 'Player'}`;
    copy.append(name, meta);
    const arrow = document.createElement('span');
    arrow.className = 'arrow'; arrow.textContent = '›';
    button.append(copy, arrow);
    button.onclick = () => {
      if (!mayLeave()) return;
      showPlayer(player);
    };
    list.append(button);
  }
}

function fallback() {
  const node = document.createElement('span');
  node.className = 'player-fallback'; node.textContent = '♟';
  return node;
}

function mayLeave() {
  return !state.dirty || confirm('Discard the changes you have not saved?');
}

function showEmpty() {
  state.selectedId = null;
  state.creating = false;
  state.dirty = false;
  $('#emptyState').hidden = false;
  $('#playerForm').hidden = true;
  renderList();
}

function showPlayer(player, creating = false) {
  state.creating = creating;
  state.selectedId = creating ? null : player.id;
  state.dirty = false;
  $('#emptyState').hidden = true;
  $('#playerForm').hidden = false;
  $('#editMode').textContent = creating ? 'NEW PLAYER' : 'PLAYER PROFILE';
  $('#detailTitle').textContent = creating ? 'Create player' : 'Player details';
  $('#deletePlayer').hidden = creating;
  for (const key of fields) $('#playerForm').elements[key].value = player[key] || '';
  $('#playerForm').elements.id.disabled = !creating;
  const stats = creating ? null : state.data.predefinedPlayerStats[player.id];
  $('#hasStats').checked = Boolean(stats);
  for (const key of totalNumbers) $('#playerForm').elements[key].value = stats?.[key] ?? 0;
  for (const key of seasonText) $('#playerForm').elements[key].value = stats?.seasonStats?.[key] ?? '';
  for (const key of seasonNumbers) $('#playerForm').elements[key].value = stats?.seasonStats?.[key] ?? 0;
  renderCareerRows(stats?.careerStats || []);
  toggleStats();
  updateHero();
  $('#saveState').textContent = 'No unsaved changes';
  renderList();
  if (window.innerWidth <= 800) $('#playerForm').scrollIntoView({ behavior: 'smooth' });
}

function renderCareerRows(rows) {
  const host = $('#careerRows');
  host.replaceChildren();
  if (!rows.length) {
    const empty = document.createElement('div');
    empty.className = 'career-empty';
    empty.textContent = 'No career rows yet. Add a club or international entry.';
    host.append(empty);
    return;
  }
  const head = document.createElement('div');
  head.className = 'career-head';
  for (const label of ['Season', 'Club / country', 'Apps', 'Goals', 'Assists', '']) {
    const span = document.createElement('span'); span.textContent = label; head.append(span);
  }
  host.append(head);
  for (const row of rows) addCareerRow(row);
}

function addCareerRow(row = {}) {
  const host = $('#careerRows');
  host.querySelector('.career-empty')?.remove();
  if (!host.querySelector('.career-head')) renderCareerRows([row]);
  else {
    const line = document.createElement('div');
    line.className = 'career-row';
    line.dataset.original = JSON.stringify(row);
    for (const key of ['season', 'team', 'appearances', 'goals', 'assists']) {
      const input = document.createElement('input');
      input.dataset.key = key;
      input.setAttribute('aria-label', key);
      input.value = row[key] ?? '';
      if (!['season', 'team'].includes(key)) {
        input.type = 'number'; input.min = '0'; input.step = '1';
      }
      input.addEventListener('input', markDirty);
      line.append(input);
    }
    const remove = document.createElement('button');
    remove.type = 'button'; remove.textContent = '×'; remove.setAttribute('aria-label', 'Remove career row');
    remove.onclick = () => { line.remove(); markDirty(); if (!host.querySelector('.career-row')) renderCareerRows([]); };
    line.append(remove); host.append(line);
  }
}

function toggleStats() {
  const hidden = !$('#hasStats').checked;
  $('#statsFields').hidden = hidden;
  $('#seasonSection').hidden = hidden;
  $('#historySection').hidden = hidden;
}

function updateHero() {
  const form = $('#playerForm');
  $('#heroName').textContent = form.elements.name.value.trim() || 'New player';
  $('#heroMeta').textContent = [form.elements.teamName.value.trim(), form.elements.position.value.trim()]
    .filter(Boolean).join(' · ') || 'Add profile details below';
  const image = $('#preview');
  const url = form.elements.imageUrl.value.trim();
  image.style.display = url ? 'block' : 'none';
  $('#photoFallback').style.display = url ? 'none' : 'block';
  if (url) image.src = url;
}

function markDirty() {
  state.dirty = true;
  $('#saveState').textContent = 'Unsaved changes';
}

function readForm() {
  const form = $('#playerForm');
  const player = {};
  for (const key of fields) player[key] = form.elements[key].value.trim();
  if (!player.id || !player.name) throw new Error('Player ID and name are required.');
  if (player.imageUrl && !player.imageUrl.startsWith('https://')) {
    throw new Error('Image URL must use HTTPS.');
  }
  let stats = null;
  if ($('#hasStats').checked) {
    const previous = state.data.predefinedPlayerStats[state.selectedId] || {};
    const seasonStats = { ...(previous.seasonStats || {}) };
    for (const key of seasonText) seasonStats[key] = form.elements[key].value.trim();
    for (const key of seasonNumbers) seasonStats[key] = Number(form.elements[key].value || 0);
    stats = { ...previous, seasonStats };
    for (const key of totalNumbers) stats[key] = Number(form.elements[key].value || 0);
    stats.careerStats = [...document.querySelectorAll('.career-row')].map(line => {
      const row = JSON.parse(line.dataset.original);
      for (const input of line.querySelectorAll('input')) {
        row[input.dataset.key] = input.type === 'number' ? Number(input.value || 0) : input.value.trim();
      }
      return row;
    });
  }
  return { player, stats };
}

async function persist(data, selectedId, message) {
  if (state.busy) return;
  state.busy = true;
  $('#savePlayer').disabled = true;
  $('#saveState').textContent = 'Saving…';
  try {
    await api('/api/admin/players', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ data, sha: state.sha }),
    });
    state.selectedId = selectedId;
    state.creating = false;
    await loadData();
    if (selectedId === null) showEmpty();
    notice(`${message} Vercel is publishing the new data for the app.`);
  } catch (error) {
    notice(error.message, true);
    $('#saveState').textContent = 'Save failed';
  } finally {
    state.busy = false;
    $('#savePlayer').disabled = false;
  }
}

$('#playerForm').addEventListener('submit', event => {
  event.preventDefault();
  try {
    const { player, stats } = readForm();
    const data = structuredClone(state.data);
    if (state.creating) {
      if (data.famousPlayers.some(item => item.id === player.id)) {
        throw new Error('This player ID already exists.');
      }
      data.famousPlayers.push(player);
    } else {
      const index = data.famousPlayers.findIndex(item => item.id === state.selectedId);
      if (index < 0) throw new Error('Player was removed. Reload the catalog.');
      data.famousPlayers[index] = { ...data.famousPlayers[index], ...player };
    }
    if (stats) data.predefinedPlayerStats[player.id] = stats;
    else delete data.predefinedPlayerStats[player.id];
    persist(data, player.id, state.creating ? 'Player created.' : 'Player updated.');
  } catch (error) { notice(error.message, true); }
});

$('#deletePlayer').addEventListener('click', () => {
  if (!state.selectedId || !confirm('Delete this player and their statistics?')) return;
  const data = structuredClone(state.data);
  data.famousPlayers = data.famousPlayers.filter(item => item.id !== state.selectedId);
  delete data.predefinedPlayerStats[state.selectedId];
  persist(data, null, 'Player deleted.');
});

$('#addPlayer').addEventListener('click', () => {
  if (!state.data || !mayLeave()) return;
  showPlayer(Object.fromEntries(fields.map(key => [key, ''])), true);
});
$('#reload').addEventListener('click', async () => {
  if (!mayLeave()) return;
  try { await loadData(); if (state.creating) showEmpty(); notice('Catalog reloaded from GitHub.'); }
  catch (error) { notice(error.message, true); }
});
$('#search').addEventListener('input', renderList);
$('#addRow').addEventListener('click', () => { addCareerRow({ season: '', team: '', appearances: 0, goals: 0, assists: 0 }); markDirty(); });
$('#hasStats').addEventListener('change', () => { toggleStats(); markDirty(); });
$('#playerForm').addEventListener('input', event => {
  if (event.target.matches('input')) { markDirty(); updateHero(); }
});
$('#preview').addEventListener('error', () => { $('#preview').style.display = 'none'; $('#photoFallback').style.display = 'block'; });
$('#logout').addEventListener('click', async () => { await api('/api/admin/logout', { method: 'POST' }); location.href = '/players/'; });
window.addEventListener('beforeunload', event => { if (state.dirty) { event.preventDefault(); event.returnValue = ''; } });
boot();
