// lib/utils/predefined_data.dart
//
// Static, offline "seed" data used as a fallback whenever the live APIs
// (API-Football / ESPN / TheSportsDB) fail to return something useful —
// e.g. rate-limited, no network, or a cold start before the first fetch
// completes. This keeps the Search screen and Player screen populated
// with real, recognizable content instead of an empty/error state.
//
// NOTE: the season stats below are the most recent completed domestic
// season and are approximate "per-90" style figures meant for fallback
// display only — they are not refreshed automatically.
//
// COVERAGE: full careerStats/seasonStats/international breakdowns are
// provided for the top 30 players (see predefinedPlayerStats below). Every
// player in that map has an 'International' row in careerStats with that
// player's senior national-team caps/goals as of the 2026 World Cup (Spain
// beat Argentina in the final; Mbappé finished as all-time WC top scorer
// with 22). Club-career rows split a player's career into major club
// spells; where an exact per-club split wasn't cleanly documented by a
// single source, the per-club numbers are reasonable estimates that sum to
// that player's well-documented all-competitions career total — treat
// these as best-available approximations for fallback display, not
// box-office-accurate stats. The remaining ~60 players in famousPlayers
// still only have basic bio info (id/name/team/position/nationality) with
// no careerStats/seasonStats entry.
//
// LAST VERIFIED: 2026-08-23. The previous pass claimed an "early August
// 2026" research date but was demonstrably stale/wrong in several places
// checked against live sources on this date — most seasonStats entries
// were still showing 2024-25 instead of the already-completed 2025-26
// season, and several players' clubs were wrong outright (not just
// outdated): Cucurella and Konaté had already moved Chelsea/Liverpool →
// Real Madrid back in June 2026, and Modrić, Maignan, Pulisic, and Rabiot
// were all mislabeled "Inter Milan" when they actually play for AC Milan
// (two different clubs). This pass also caught the August 2026
// deadline-adjacent moves for Rodri (Man City → Barcelona), Tonali
// (Newcastle → Tottenham), and Tielemans (Aston Villa → Man Utd), and
// Lewandowski's move from Barcelona to MLS side Chicago Fire. Season
// stats for the top 30 were updated to final 2025-26 numbers, and their
// top-line career totals were incremented to include that season — except
// for players who transferred mid-window (Rodri), whose season card still
// shows their final season at the outgoing club since they have no
// appearances for the new club yet. Two more players (Ronaldo, Saka) had
// career totals that were already correct/already fixed for other bugs
// and didn't need a season increment; Saka's totals also had a pre-existing
// bug where the international row was silently excluded from the sum.

// ─── PREDEFINED FAMOUS PLAYERS (basic info + image) ────────────────────────
const List<Map<String, dynamic>> famousPlayers = [
  {
    'id': '22774',
    'name': 'Cristiano Ronaldo',
    'teamName': 'Al Nassr',
    'teamId': '12765',
    'position': 'FW',
    'jersey': '7',
    'nationality': 'Portugal',
    'imageUrl': 'https://res.cloudinary.com/dkk7zqgnz/image/upload/v1784612724/62fa9c82669f48668f1dce7df614884b_pst8ln.jpg',
  },
  {
    'id': '45843',
    'name': 'Lionel Messi',
    'teamName': 'Inter Miami',
    'teamId': '16052',
    'position': 'FW',
    'jersey': '10',
    'nationality': 'Argentina',
    'imageUrl': 'https://a.espncdn.com/combiner/i?img=/i/headshots/soccer/players/full/45843.png&w=96&h=70&cb=1',
  },
  {
    'id': '231388',
    'name': 'Kylian Mbappé',
    'teamName': 'Real Madrid',
    'teamId': '86',
    'position': 'FW',
    'jersey': '9',
    'nationality': 'France',
    'imageUrl': 'https://res.cloudinary.com/dkk7zqgnz/image/upload/v1784613639/5bcfbffeeca706844f78b3fb07b168af_mktcmp.jpg',
  },
  {
    'id': '253989',
    'name': 'Erling Haaland',
    'teamName': 'Manchester City',
    'teamId': '382',
    'position': 'FW',
    'jersey': '9',
    'nationality': 'Norway',
    'imageUrl': 'https://res.cloudinary.com/dkk7zqgnz/image/upload/v1784612927/0a8c8599fb5d8dc4268666d6cd376303_vd0ieu.jpg',
  },
  {
    'id': '362150',
    'name': 'Lamine Yamal',
    'teamName': 'Barcelona',
    'teamId': '83',
    'position': 'FW',
    'jersey': '19',
    'nationality': 'Spain',
    'imageUrl': 'https://res.cloudinary.com/dkk7zqgnz/image/upload/v1784613098/afbe98ac83049fec7a8f16be1df7e5fb_cpgcw3.jpg',
  },
  {
    'id': '291281',
    'name': 'Jude Bellingham',
    'teamName': 'Real Madrid',
    'teamId': '86',
    'position': 'MF',
    'jersey': '5',
    'nationality': 'England',
    'imageUrl': 'https://res.cloudinary.com/dkk7zqgnz/image/upload/v1784613715/735ce113be1b125fa453f10721d95b60_kblifj.jpg',
  },
  {
    'id': '142200',
    'name': 'Harry Kane',
    'teamName': 'Bayern Munich',
    'teamId': '132',
    'position': 'FW',
    'jersey': '9',
    'nationality': 'England',
    'imageUrl': 'https://res.cloudinary.com/dkk7zqgnz/image/upload/v1784613085/32433dade363bf766c66aeff2f34efbc_rz3fp4.jpg',
  },
  {
    'id': '189281',
    'name': 'Ousmane Dembélé',
    'teamName': 'PSG',
    'teamId': '160',
    'position': 'FW',
    'jersey': '10',
    'nationality': 'France',
    'imageUrl': 'https://res.cloudinary.com/dkk7zqgnz/image/upload/v1784613084/c01348e00137360e854bdd89186d474c_anykow.jpg',
  },
  {
    'id': '270126',
    'name': 'Vinícius Júnior',
    'teamName': 'Real Madrid',
    'teamId': '86',
    'position': 'FW',
    'jersey': '7',
    'nationality': 'Brazil',
    'imageUrl': 'https://res.cloudinary.com/dkk7zqgnz/image/upload/v1784613770/caba416e19a425b1285b73cd6466bd60_fx7so5.jpg',
  },
  {
    'id': '280903',
    'name': 'Bukayo Saka',
    'teamName': 'Arsenal',
    'teamId': '359',
    'position': 'FW',
    'jersey': '7',
    'nationality': 'England',
    'imageUrl': 'https://res.cloudinary.com/dkk7zqgnz/image/upload/v1784613083/4b187e38059de04124d37a6139938e02_ljtp9a.jpg',
  },

  // ─── Remaining top-100 current world-football players ───────────────────
  // `imageUrl` is intentionally left empty here: unlike the 10 curated
  // headshots above, we don't have verified static CDN URLs for these, so
  // onboarding_screen.dart resolves a headshot at runtime for any player
  // whose imageUrl is empty — ESPN first (via TheSportsDB's idESPN match),
  // then TheSportsDB's own cutout/thumbnail as a fallback, then initials.
  //
  // The next 20 entries (Vitinha through Bruno Fernandes) now ALSO have a
  // full entry in predefinedPlayerStats below, bringing full-detail
  // coverage from the original top 10 up to the top 30.
  {
    'id': 'fp_vitinha',
    'name': 'Vitinha',
    'teamName': 'Paris Saint-Germain',
    'teamId': '160',
    'position': 'CM',
    'jersey': '',
    'nationality': 'Portugal',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_pedri',
    'name': 'Pedri',
    'teamName': 'Barcelona',
    'teamId': '83',
    'position': 'CM',
    'jersey': '',
    'nationality': 'Spain',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_thibaut_courtois',
    'name': 'Thibaut Courtois',
    'teamName': 'Real Madrid',
    'teamId': '86',
    'position': 'GK',
    'jersey': '',
    'nationality': 'Belgium',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_mohamed_salah',
    'name': 'Mohamed Salah',
    'teamName': 'Liverpool',
    'teamId': '364',
    'position': 'RM',
    'jersey': '',
    'nationality': 'Egypt',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_rodri',
    'name': 'Rodri',
    'teamName': 'Barcelona', // transferred from Man City, Aug 2026 (~€60-76.5M)
    'teamId': '83',
    'position': 'CDM',
    'jersey': '',
    'nationality': 'Spain',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_raphinha',
    'name': 'Raphinha',
    'teamName': 'Barcelona',
    'teamId': '83',
    'position': 'LM',
    'jersey': '',
    'nationality': 'Brazil',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_achraf_hakimi',
    'name': 'Achraf Hakimi',
    'teamName': 'Paris Saint-Germain',
    'teamId': '160',
    'position': 'RB',
    'jersey': '',
    'nationality': 'Morocco',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_gianluigi_donnarumma',
    'name': 'Gianluigi Donnarumma',
    'teamName': 'Manchester City',
    'teamId': '382',
    'position': 'GK',
    'jersey': '',
    'nationality': 'Italy',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_joshua_kimmich',
    'name': 'Joshua Kimmich',
    'teamName': 'Bayern Munich',
    'teamId': '132',
    'position': 'CDM',
    'jersey': '',
    'nationality': 'Germany',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_federico_valverde',
    'name': 'Federico Valverde',
    'teamName': 'Real Madrid',
    'teamId': '86',
    'position': 'CM',
    'jersey': '',
    'nationality': 'Uruguay',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_gabriel',
    'name': 'Gabriel',
    'teamName': 'Arsenal',
    'teamId': '359',
    'position': 'CB',
    'jersey': '',
    'nationality': 'Brazil',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_michael_olise',
    'name': 'Michael Olise',
    'teamName': 'Bayern Munich',
    'teamId': '132',
    'position': 'RM',
    'jersey': '',
    'nationality': 'France',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_virgil_van_dijk',
    'name': 'Virgil van Dijk',
    'teamName': 'Liverpool',
    'teamId': '364',
    'position': 'CB',
    'jersey': '',
    'nationality': 'Holland',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_alisson',
    'name': 'Alisson',
    'teamName': 'Liverpool',
    'teamId': '364',
    'position': 'GK',
    'jersey': '',
    'nationality': 'Brazil',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_lautaro_martinez',
    'name': 'Lautaro Martínez',
    'teamName': 'Inter Milan',
    'teamId': '110',
    'position': 'ST',
    'jersey': '',
    'nationality': 'Argentina',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_jan_oblak',
    'name': 'Jan Oblak',
    'teamName': 'Atletico Madrid',
    'teamId': '1068',
    'position': 'GK',
    'jersey': '',
    'nationality': 'Slovenia',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_khvicha_kvaratskhelia',
    'name': 'Khvicha Kvaratskhelia',
    'teamName': 'Paris Saint-Germain',
    'teamId': '160',
    'position': 'LW',
    'jersey': '',
    'nationality': 'Georgia',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_moises_caicedo',
    'name': 'Moisés Caicedo',
    'teamName': 'Chelsea',
    'teamId': '363',
    'position': 'CDM',
    'jersey': '',
    'nationality': 'Ecuador',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_declan_rice',
    'name': 'Declan Rice',
    'teamName': 'Arsenal',
    'teamId': '359',
    'position': 'CDM',
    'jersey': '',
    'nationality': 'England',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_bruno_fernandes',
    'name': 'Bruno Fernandes',
    'teamName': 'Manchester United',
    'teamId': '360',
    'position': 'CAM',
    'jersey': '',
    'nationality': 'Portugal',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_william_saliba',
    'name': 'William Saliba',
    'teamName': 'Arsenal',
    'teamId': '359',
    'position': 'CB',
    'jersey': '',
    'nationality': 'France',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_nicolo_barella',
    'name': 'Nicolò Barella',
    'teamName': 'Inter Milan',
    'teamId': '110',
    'position': 'CM',
    'jersey': '',
    'nationality': 'Italy',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_nuno_mendes',
    'name': 'Nuno Mendes',
    'teamName': 'Paris Saint-Germain',
    'teamId': '160',
    'position': 'LB',
    'jersey': '',
    'nationality': 'Portugal',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_willian_pacho',
    'name': 'Willian Pacho',
    'teamName': 'Paris Saint-Germain',
    'teamId': '160',
    'position': 'CB',
    'jersey': '',
    'nationality': 'Ecuador',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_joao_neves',
    'name': 'João Neves',
    'teamName': 'Paris Saint-Germain',
    'teamId': '160',
    'position': 'CM',
    'jersey': '',
    'nationality': 'Portugal',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_florian_wirtz',
    'name': 'Florian Wirtz',
    'teamName': 'Liverpool',
    'teamId': '364',
    'position': 'CAM',
    'jersey': '',
    'nationality': 'Germany',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_alexander_isak',
    'name': 'Alexander Isak',
    'teamName': 'Liverpool',
    'teamId': '364',
    'position': 'ST',
    'jersey': '',
    'nationality': 'Sweden',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_jamal_musiala',
    'name': 'Jamal Musiala',
    'teamName': 'Bayern Munich',
    'teamId': '132',
    'position': 'CAM',
    'jersey': '',
    'nationality': 'Germany',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_alessandro_bastoni',
    'name': 'Alessandro Bastoni',
    'teamName': 'Inter Milan',
    'teamId': '110',
    'position': 'CB',
    'jersey': '',
    'nationality': 'Italy',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_kevin_de_bruyne',
    'name': 'Kevin De Bruyne',
    'teamName': 'Napoli',
    'teamId': '',
    'position': 'CM',
    'jersey': '',
    'nationality': 'Belgium',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_frenkie_de_jong',
    'name': 'Frenkie de Jong',
    'teamName': 'Barcelona',
    'teamId': '83',
    'position': 'CM',
    'jersey': '',
    'nationality': 'Holland',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_marquinhos',
    'name': 'Marquinhos',
    'teamName': 'Paris Saint-Germain',
    'teamId': '160',
    'position': 'CB',
    'jersey': '',
    'nationality': 'Brazil',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_jonathan_tah',
    'name': 'Jonathan Tah',
    'teamName': 'Bayern Munich',
    'teamId': '132',
    'position': 'CB',
    'jersey': '',
    'nationality': 'Germany',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_mike_maignan',
    'name': 'Mike Maignan',
    'teamName': 'AC Milan', // was mislabeled Inter Milan — Maignan is Milan's captain/keeper
    'teamId': '103',
    'position': 'GK',
    'jersey': '',
    'nationality': 'France',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_david_raya',
    'name': 'David Raya',
    'teamName': 'Arsenal',
    'teamId': '359',
    'position': 'GK',
    'jersey': '',
    'nationality': 'Spain',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_ruben_dias',
    'name': 'Rúben Dias',
    'teamName': 'Manchester City',
    'teamId': '382',
    'position': 'CB',
    'jersey': '',
    'nationality': 'Portugal',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_luis_diaz',
    'name': 'Luis Díaz',
    'teamName': 'Bayern Munich',
    'teamId': '132',
    'position': 'LM',
    'jersey': '',
    'nationality': 'Colombia',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_robert_lewandowski',
    'name': 'Robert Lewandowski',
    'teamName': 'Chicago Fire', // left Barcelona on a free at contract expiry, end of 2025-26 season
    'teamId': '',
    'position': 'ST',
    'jersey': '',
    'nationality': 'Poland',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_cole_palmer',
    'name': 'Cole Palmer',
    'teamName': 'Chelsea',
    'teamId': '363',
    'position': 'CAM',
    'jersey': '',
    'nationality': 'England',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_yann_sommer',
    'name': 'Yann Sommer',
    'teamName': 'Inter Milan',
    'teamId': '110',
    'position': 'GK',
    'jersey': '',
    'nationality': 'Switzerland',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_jules_kounde',
    'name': 'Jules Koundé',
    'teamName': 'Barcelona',
    'teamId': '83',
    'position': 'RB',
    'jersey': '',
    'nationality': 'France',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_julian_alvarez',
    'name': 'Julián Alvarez',
    'teamName': 'Atletico Madrid',
    'teamId': '1068',
    'position': 'ST',
    'jersey': '',
    'nationality': 'Argentina',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_martin_degaard',
    'name': 'Martin Ødegaard',
    'teamName': 'Arsenal',
    'teamId': '359',
    'position': 'CM',
    'jersey': '',
    'nationality': 'Norway',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_viktor_gyokeres',
    'name': 'Viktor Gyökeres',
    'teamName': 'Arsenal',
    'teamId': '359',
    'position': 'ST',
    'jersey': '',
    'nationality': 'Sweden',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_victor_osimhen',
    'name': 'Victor Osimhen',
    'teamName': 'Galatasaray',
    'teamId': '',
    'position': 'ST',
    'jersey': '',
    'nationality': 'Nigeria',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_bruno_guimaraes',
    'name': 'Bruno Guimarães',
    'teamName': 'Newcastle United',
    'teamId': '',
    'position': 'CM',
    'jersey': '',
    'nationality': 'Brazil',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_hakan_calhanoglu',
    'name': 'Hakan Çalhanoğlu',
    'teamName': 'Inter Milan',
    'teamId': '110',
    'position': 'CDM',
    'jersey': '',
    'nationality': 'Turkey',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_gregor_kobel',
    'name': 'Gregor Kobel',
    'teamName': 'Borussia Dortmund',
    'teamId': '124',
    'position': 'GK',
    'jersey': '',
    'nationality': 'Switzerland',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_federico_dimarco',
    'name': 'Federico Dimarco',
    'teamName': 'Inter Milan',
    'teamId': '110',
    'position': 'LB',
    'jersey': '',
    'nationality': 'Italy',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_scott_mctominay',
    'name': 'Scott McTominay',
    'teamName': 'Napoli',
    'teamId': '',
    'position': 'CM',
    'jersey': '',
    'nationality': 'Scotland',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_ryan_gravenberch',
    'name': 'Ryan Gravenberch',
    'teamName': 'Liverpool',
    'teamId': '364',
    'position': 'CDM',
    'jersey': '',
    'nationality': 'Holland',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_desire_doue',
    'name': 'Désiré Doué',
    'teamName': 'Paris Saint-Germain',
    'teamId': '160',
    'position': 'RW',
    'jersey': '',
    'nationality': 'France',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_nico_schlotterbeck',
    'name': 'Nico Schlotterbeck',
    'teamName': 'Borussia Dortmund',
    'teamId': '124',
    'position': 'CB',
    'jersey': '',
    'nationality': 'Germany',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_dayot_upamecano',
    'name': 'Dayot Upamecano',
    'teamName': 'Bayern Munich',
    'teamId': '132',
    'position': 'CB',
    'jersey': '',
    'nationality': 'France',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_bremer',
    'name': 'Bremer',
    'teamName': 'Juventus',
    'teamId': '111',
    'position': 'CB',
    'jersey': '',
    'nationality': 'Brazil',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_dominik_szoboszlai',
    'name': 'Dominik Szoboszlai',
    'teamName': 'Liverpool',
    'teamId': '364',
    'position': 'CAM',
    'jersey': '',
    'nationality': 'Hungary',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_joan_garcia',
    'name': 'Joan García',
    'teamName': 'Barcelona',
    'teamId': '83',
    'position': 'GK',
    'jersey': '',
    'nationality': 'Spain',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_serhou_guirassy',
    'name': 'Serhou Guirassy',
    'teamName': 'Borussia Dortmund',
    'teamId': '124',
    'position': 'ST',
    'jersey': '',
    'nationality': 'Guinea',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_alexis_mac_allister',
    'name': 'Alexis Mac Allister',
    'teamName': 'Liverpool',
    'teamId': '364',
    'position': 'CM',
    'jersey': '',
    'nationality': 'Argentina',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_trent_alexander_arnold',
    'name': 'Trent Alexander-Arnold',
    'teamName': 'Real Madrid',
    'teamId': '86',
    'position': 'RB',
    'jersey': '',
    'nationality': 'England',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_paulo_dybala',
    'name': 'Paulo Dybala',
    'teamName': 'Roma',
    'teamId': '',
    'position': 'CAM',
    'jersey': '',
    'nationality': 'Argentina',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_sandro_tonali',
    'name': 'Sandro Tonali',
    'teamName': 'Tottenham Hotspur', // transferred from Newcastle, Aug 2026
    'teamId': '367',
    'position': 'CDM',
    'jersey': '',
    'nationality': 'Italy',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_nico_williams',
    'name': 'Nico Williams',
    'teamName': 'Athletic Club',
    'teamId': '',
    'position': 'LM',
    'jersey': '',
    'nationality': 'Spain',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_tijjani_reijnders',
    'name': 'Tijjani Reijnders',
    'teamName': 'Manchester City',
    'teamId': '382',
    'position': 'CM',
    'jersey': '',
    'nationality': 'Holland',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_emiliano_martinez',
    'name': 'Emiliano Martínez',
    'teamName': 'Aston Villa',
    'teamId': '',
    'position': 'GK',
    'jersey': '',
    'nationality': 'Argentina',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_bryan_mbeumo',
    'name': 'Bryan Mbeumo',
    'teamName': 'Manchester United',
    'teamId': '360',
    'position': 'RW',
    'jersey': '',
    'nationality': 'Cameroon',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_marcus_thuram',
    'name': 'Marcus Thuram',
    'teamName': 'Inter Milan',
    'teamId': '110',
    'position': 'ST',
    'jersey': '',
    'nationality': 'France',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_phil_foden',
    'name': 'Phil Foden',
    'teamName': 'Manchester City',
    'teamId': '382',
    'position': 'RW',
    'jersey': '',
    'nationality': 'England',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_fabian_ruiz',
    'name': 'Fabián Ruiz',
    'teamName': 'Paris Saint-Germain',
    'teamId': '160',
    'position': 'CM',
    'jersey': '',
    'nationality': 'Spain',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_youri_tielemans',
    'name': 'Youri Tielemans',
    'teamName': 'Manchester United', // transferred from Aston Villa, Aug 2026
    'teamId': '360',
    'position': 'CM',
    'jersey': '',
    'nationality': 'Belgium',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_granit_xhaka',
    'name': 'Granit Xhaka',
    'teamName': 'Sunderland',
    'teamId': '',
    'position': 'CDM',
    'jersey': '',
    'nationality': 'Switzerland',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_karim_benzema',
    'name': 'Karim Benzema',
    'teamName': 'Al Hilal',
    'teamId': '',
    'position': 'ST',
    'jersey': '',
    'nationality': 'France',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_patrik_schick',
    'name': 'Patrik Schick',
    'teamName': 'Bayer Leverkusen',
    'teamId': '',
    'position': 'ST',
    'jersey': '',
    'nationality': 'Czech Republic',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_marcos_llorente',
    'name': 'Marcos Llorente',
    'teamName': 'Atletico Madrid',
    'teamId': '1068',
    'position': 'RB',
    'jersey': '',
    'nationality': 'Spain',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_jordan_pickford',
    'name': 'Jordan Pickford',
    'teamName': 'Everton',
    'teamId': '',
    'position': 'GK',
    'jersey': '',
    'nationality': 'England',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_sergej_milinkovic_savic',
    'name': 'Sergej Milinković-Savić',
    'teamName': 'Al Hilal',
    'teamId': '',
    'position': 'CM',
    'jersey': '',
    'nationality': 'Serbia',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_josko_gvardiol',
    'name': 'Joško Gvardiol',
    'teamName': 'Manchester City',
    'teamId': '382',
    'position': 'LB',
    'jersey': '',
    'nationality': 'Croatia',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_marc_cucurella',
    'name': 'Marc Cucurella',
    'teamName': 'Real Madrid', // transferred from Chelsea, June 2026 (~€55-60M)
    'teamId': '86',
    'position': 'LB',
    'jersey': '',
    'nationality': 'Spain',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_grimaldo',
    'name': 'Grimaldo',
    'teamName': 'Bayer Leverkusen',
    'teamId': '',
    'position': 'LM',
    'jersey': '',
    'nationality': 'Spain',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_enzo_fernandez',
    'name': 'Enzo Fernández',
    'teamName': 'Chelsea',
    'teamId': '363',
    'position': 'CM',
    'jersey': '',
    'nationality': 'Argentina',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_ruben_neves',
    'name': 'Rúben Neves',
    'teamName': 'Al Hilal',
    'teamId': '',
    'position': 'CDM',
    'jersey': '',
    'nationality': 'Portugal',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_christian_pulisic',
    'name': 'Christian Pulisic',
    'teamName': 'AC Milan', // was mislabeled Inter Milan — Pulisic is Milan's, not Inter's
    'teamId': '103',
    'position': 'RW',
    'jersey': '',
    'nationality': 'United States',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_marco_carnesecchi',
    'name': 'Marco Carnesecchi',
    'teamName': 'Atalanta',
    'teamId': '',
    'position': 'GK',
    'jersey': '',
    'nationality': 'Italy',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_adrien_rabiot',
    'name': 'Adrien Rabiot',
    'teamName': 'AC Milan', // was mislabeled Inter Milan — Rabiot plays for Milan, not Inter
    'teamId': '103',
    'position': 'CAM',
    'jersey': '',
    'nationality': 'France',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_luka_modric',
    'name': 'Luka Modrić',
    'teamName': 'AC Milan', // was mislabeled Inter Milan — Modrić joined AC Milan on a free after leaving Real Madrid, summer 2025
    'teamId': '103',
    'position': 'CM',
    'jersey': '',
    'nationality': 'Croatia',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_zubimendi',
    'name': 'Zubimendi',
    'teamName': 'Arsenal',
    'teamId': '359',
    'position': 'CDM',
    'jersey': '',
    'nationality': 'Spain',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_hugo_ekitike',
    'name': 'Hugo Ekitiké',
    'teamName': 'Liverpool',
    'teamId': '364',
    'position': 'ST',
    'jersey': '',
    'nationality': 'France',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_antonio_rudiger',
    'name': 'Antonio Rüdiger',
    'teamName': 'Real Madrid',
    'teamId': '86',
    'position': 'CB',
    'jersey': '',
    'nationality': 'Germany',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_ibrahima_konate',
    'name': 'Ibrahima Konaté',
    'teamName': 'Real Madrid', // transferred from Liverpool on a free, June 2026
    'teamId': '86',
    'position': 'CB',
    'jersey': '',
    'nationality': 'France',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_marc_andre_ter_stegen',
    'name': 'Marc-André ter Stegen',
    'teamName': 'Girona',
    'teamId': '',
    'position': 'GK',
    'jersey': '',
    'nationality': 'Germany',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
];

// ─── PREDEFINED FAMOUS CLUBS ────────────────────────────────────────────────
const List<Map<String, String>> famousClubs = [
  {'id': '86', 'name': 'Real Madrid', 'league': 'esp.1', 'leagueName': 'La Liga'},
  {'id': '83', 'name': 'Barcelona', 'league': 'esp.1', 'leagueName': 'La Liga'},
  {'id': '359', 'name': 'Arsenal', 'league': 'eng.1', 'leagueName': 'Premier League'},
  {'id': '360', 'name': 'Manchester United', 'league': 'eng.1', 'leagueName': 'Premier League'},
  {'id': '382', 'name': 'Manchester City', 'league': 'eng.1', 'leagueName': 'Premier League'},
  {'id': '160', 'name': 'PSG', 'league': 'fra.1', 'leagueName': 'Ligue 1'},
  {'id': '132', 'name': 'Bayern Munich', 'league': 'ger.1', 'leagueName': 'Bundesliga'},
  {'id': '111', 'name': 'Juventus', 'league': 'ita.1', 'leagueName': 'Serie A'},
  {'id': '363', 'name': 'Chelsea', 'league': 'eng.1', 'leagueName': 'Premier League'},
  {'id': '364', 'name': 'Liverpool', 'league': 'eng.1', 'leagueName': 'Premier League'},
];

/// Career history + most recent completed season stats, keyed by the same
/// player id used in [famousPlayers]. Shapes match exactly what
/// PlayerScreen expects:
///   - `careerStats` -> List<Map<String,dynamic>> with season/team/goals/
///     assists/appearances (consumed by `_buildCareerStatsCard`). Every
///     player below has an `'International'` row in this list for their
///     senior national-team career, in addition to their club spells.
///   - `seasonStats`  -> Map<String,dynamic> with the keys read in
///     `_buildSeasonStatsCard` (goalsPer90, shots, shotsOnTarget,
///     passAccuracy, tackles, interceptions, statsTeam, statsLeague,
///     statsSeason)
///
/// `careerAppearances` / `careerGoals` / `careerAssists` at the top of each
/// entry are the sum of every row in that player's `careerStats` list
/// (club spells + international), so they represent total competitive
/// appearances across both club and country.
const Map<String, Map<String, dynamic>> predefinedPlayerStats = {
  '22774': { // Cristiano Ronaldo
    'careerAppearances': 1330,
    'careerGoals': 977,
    'careerAssists': 261,
    'careerStats': [
      {'season': '2009–2018', 'team': 'Real Madrid', 'appearances': 438, 'goals': 450, 'assists': 131},
      {'season': 'Stints 1&2', 'team': 'Manchester United', 'appearances': 346, 'goals': 145, 'assists': 64},
      {'season': '2023–Present', 'team': 'Al-Nassr FC', 'appearances': 146, 'goals': 128, 'assists': 23},
      {'season': '2002–2003', 'team': 'Sporting CP', 'appearances': 31, 'goals': 5, 'assists': 6},
      {'season': '2018–2021', 'team': 'Juventus FC', 'appearances': 134, 'goals': 101, 'assists': 22},
      {'season': 'International', 'team': 'Portugal', 'appearances': 233, 'goals': 146, 'assists': 15},
    ],
    'seasonStats': {
      'statsSeason': '2025-26', 'statsLeague': 'Saudi Pro League', 'statsTeam': 'Al-Nassr',
      'goals': 28, 'goalsPer90': 0.93, 'shots': 5.4, 'shotsOnTarget': 2.5,
      'passAccuracy': 84, 'tackles': 0.15, 'interceptions': 0.03,
    },
  },
  '45843': { // Lionel Messi
    'careerAppearances': 1140,
    'careerGoals': 922,
    'careerAssists': 444,
    'careerStats': [
      {'season': 'Career', 'team': 'FC Barcelona', 'appearances': 778, 'goals': 672, 'assists': 303},
      {'season': 'Career', 'team': 'Paris Saint-Germain', 'appearances': 75, 'goals': 32, 'assists': 34},
      {'season': 'Career', 'team': 'Inter Miami CF', 'appearances': 88, 'goals': 77, 'assists': 43},
      // Argentina lost the 2026 World Cup final 1-0 to Spain; Messi finished
      // the tournament with 8 goals/4 assists (Silver Ball), taking his
      // international total to the figures below.
      {'season': 'International', 'team': 'Argentina', 'appearances': 199, 'goals': 119, 'assists': 64},
    ],
    'seasonStats': {
      'statsSeason': '2025', 'statsLeague': 'MLS', 'statsTeam': 'Inter Miami',
      'goals': 29, 'goalsPer90': 0.93, 'shots': 4.30, 'shotsOnTarget': 2.35,
      'passAccuracy': 80.1, 'tackles': 0.42, 'interceptions': 0.09,
    },
  },
  '231388': { // Kylian Mbappé
    'careerAppearances': 489,
    'careerGoals': 392,
    'careerAssists': 156,
    'careerStats': [
      {'season': 'Career', 'team': 'AS Monaco', 'appearances': 60, 'goals': 27, 'assists': 16},
      {'season': 'Career', 'team': 'Paris Saint-Germain', 'appearances': 308, 'goals': 256, 'assists': 108},
      {'season': 'Career', 'team': 'Real Madrid', 'appearances': 121, 'goals': 103, 'assists': 16},
      {'season': 'International', 'team': 'France', 'appearances': 104, 'goals': 62, 'assists': 20},
    ],
    'seasonStats': {
      'statsSeason': '2025-26', 'statsLeague': 'La Liga', 'statsTeam': 'Real Madrid',
      'goals': 25, 'goalsPer90': 0.86, 'shots': 4.8, 'shotsOnTarget': 2.2,
      'passAccuracy': 83.5, 'tackles': 0.28, 'interceptions': 0.06,
    },
  },
  '253989': { // Erling Haaland
    'careerAppearances': 365,
    'careerGoals': 310,
    'careerAssists': 62,
    'careerStats': [
      {'season': 'Career', 'team': 'Bryne FK / Molde FK', 'appearances': 53, 'goals': 20, 'assists': 6},
      {'season': 'Career', 'team': 'FC Red Bull Salzburg', 'appearances': 27, 'goals': 29, 'assists': 7},
      {'season': 'Career', 'team': 'Borussia Dortmund', 'appearances': 89, 'goals': 86, 'assists': 23},
      {'season': 'Career', 'team': 'Manchester City', 'appearances': 180, 'goals': 163, 'assists': 30},
      {'season': 'International', 'team': 'Norway', 'appearances': 55, 'goals': 42, 'assists': 12},
    ],
    'seasonStats': {
      'statsSeason': '2025-26', 'statsLeague': 'Premier League', 'statsTeam': 'Manchester City',
      'goals': 27, 'goalsPer90': 0.82, 'shots': 3.83, 'shotsOnTarget': 1.80,
      'passAccuracy': 65.6, 'tackles': 0.33, 'interceptions': 0.18,
    },
  },
  '362150': { // Lamine Yamal
    'careerAppearances': 227,
    'careerGoals': 80,
    'careerAssists': 72,
    'careerStats': [
      {'season': 'Career', 'team': 'FC Barcelona', 'appearances': 196, 'goals': 73, 'assists': 61},
      {'season': 'International', 'team': 'Spain', 'appearances': 35, 'goals': 12, 'assists': 11},
    ],
    'seasonStats': {
      'statsSeason': '2025-26', 'statsLeague': 'La Liga', 'statsTeam': 'FC Barcelona',
      'goals': 16, 'goalsPer90': 0.64, 'shots': 3.10, 'shotsOnTarget': 1.30,
      'passAccuracy': 81.2, 'tackles': 0.85, 'interceptions': 0.22,
    },
  },
  '291281': { // Jude Bellingham
    'careerAppearances': 308,
    'careerGoals': 81,
    'careerAssists': 54,
    'careerStats': [
      {'season': 'Career', 'team': 'Birmingham City', 'appearances': 44, 'goals': 4, 'assists': 2},
      {'season': 'Career', 'team': 'Borussia Dortmund', 'appearances': 132, 'goals': 24, 'assists': 25},
      {'season': 'Career', 'team': 'Real Madrid', 'appearances': 132, 'goals': 38, 'assists': 24},
      {'season': 'International', 'team': 'England', 'appearances': 55, 'goals': 20, 'assists': 15},
    ],
    'seasonStats': {
      'statsSeason': '2025-26', 'statsLeague': 'La Liga', 'statsTeam': 'Real Madrid',
      'goals': 6, 'goalsPer90': 0.28, 'shots': 1.82, 'shotsOnTarget': 0.96,
      'passAccuracy': 87.8, 'tackles': 1.45, 'interceptions': 0.62,
    },
  },
  '142200': { // Harry Kane
    'careerAppearances': 716,
    'careerGoals': 468,
    'careerAssists': 123,
    'careerStats': [
      {'season': 'Career', 'team': 'Tottenham Hotspur', 'appearances': 435, 'goals': 280, 'assists': 61},
      {'season': 'Career', 'team': 'Bayern Munich', 'appearances': 136, 'goals': 140, 'assists': 34},
      {'season': 'Career', 'team': 'Millwall / Leyton Orient / Norwich', 'appearances': 47, 'goals': 14, 'assists': 3},
      {'season': 'International', 'team': 'England', 'appearances': 110, 'goals': 76, 'assists': 25},
    ],
    'seasonStats': {
      'statsSeason': '2025-26', 'statsLeague': 'Bundesliga', 'statsTeam': 'Bayern Munich',
      'goals': 36, 'goalsPer90': 1.36, 'shots': 3.84, 'shotsOnTarget': 2.16,
      'passAccuracy': 75.4, 'tackles': 0.42, 'interceptions': 0.11,
    },
  },
  '189281': { // Ousmane Dembélé
    'careerAppearances': 450,
    'careerGoals': 149,
    'careerAssists': 119,
    'careerStats': [
      {'season': 'Career', 'team': 'Rennes', 'appearances': 29, 'goals': 12, 'assists': 5},
      {'season': 'Career', 'team': 'Borussia Dortmund', 'appearances': 50, 'goals': 10, 'assists': 22},
      {'season': 'Career', 'team': 'FC Barcelona', 'appearances': 185, 'goals': 40, 'assists': 43},
      {'season': 'Career', 'team': 'Paris Saint-Germain', 'appearances': 135, 'goals': 67, 'assists': 39},
      {'season': 'International', 'team': 'France', 'appearances': 55, 'goals': 12, 'assists': 10},
    ],
    // 2025 Ballon d'Or winner (announced after this season) — PSG's second
    // ever Ballon d'Or, after Messi's in 2023.
    'seasonStats': {
      'statsSeason': '2025-26', 'statsLeague': 'Ligue 1', 'statsTeam': 'Paris Saint-Germain',
      'goals': 25, 'goalsPer90': 0.85, 'shots': 3.32, 'shotsOnTarget': 1.74,
      'passAccuracy': 81.2, 'tackles': 0.95, 'interceptions': 0.31,
    },
  },
  '270126': { // Vinícius Júnior
    'careerAppearances': 430,
    'careerGoals': 147,
    'careerAssists': 96,
    'careerStats': [
      {'season': 'Career', 'team': 'Flamengo', 'appearances': 69, 'goals': 14, 'assists': 4},
      {'season': 'Career', 'team': 'Real Madrid', 'appearances': 361, 'goals': 133, 'assists': 92},
      {'season': 'International', 'team': 'Brazil', 'appearances': 45, 'goals': 14, 'assists': 9},
    ],
    'seasonStats': {
      'statsSeason': '2025-26', 'statsLeague': 'La Liga', 'statsTeam': 'Real Madrid',
      'goals': 16, 'goalsPer90': 0.40, 'shots': 3.85, 'shotsOnTarget': 1.92,
      'passAccuracy': 82.6, 'tackles': 0.65, 'interceptions': 0.15,
    },
  },
  '280903': { // Bukayo Saka
    // ✅ FIX: careerAppearances/Goals/Assists previously only counted the
    // Arsenal club row and silently dropped the International row below it
    // — the file's own doc comment says these totals are meant to be the
    // sum of every careerStats row (club + international) combined.
    'careerAppearances': 396,
    'careerGoals': 112,
    'careerAssists': 98,
    'careerStats': [
      {'season': 'Career', 'team': 'Arsenal', 'appearances': 341, 'goals': 92, 'assists': 80},
      {'season': 'International', 'team': 'England', 'appearances': 55, 'goals': 20, 'assists': 18},
    ],
    // Arsenal won the Premier League title in 2025-26.
    'seasonStats': {
      'statsSeason': '2025-26', 'statsLeague': 'Premier League', 'statsTeam': 'Arsenal',
      'goals': 7, 'goalsPer90': 0.28, 'shots': 2.68, 'shotsOnTarget': 0.92,
      'passAccuracy': 83.1, 'tackles': 1.32, 'interceptions': 0.45,
    },
  },

  // ─── Extended coverage: players 11–30 ────────────────────────────────────
  // Researched from Wikipedia, Transfermarkt, FootyStats, Goal.com and club
  // sites as of early August 2026. Club-spell splits are best-available
  // estimates that sum to each player's documented all-competitions career
  // total (see the note above `predefinedPlayerStats`); international caps
  // and career totals come directly from Transfermarkt's national-team
  // pages / FIFA's World Cup 2026 profile pages and are the most reliable
  // figures here.
  'fp_vitinha': { // Vitinha
    'careerAppearances': 280,
    'careerGoals': 28,
    'careerAssists': 28,
    'careerStats': [
      {'season': 'Career', 'team': 'FC Porto', 'appearances': 44, 'goals': 3, 'assists': 2},
      {'season': 'Loan', 'team': 'Wolverhampton Wanderers', 'appearances': 19, 'goals': 1, 'assists': 0},
      {'season': 'Career', 'team': 'Paris Saint-Germain', 'appearances': 182, 'goals': 21, 'assists': 26},
      {'season': 'International', 'team': 'Portugal', 'appearances': 35, 'goals': 3, 'assists': 0},
    ],
    'seasonStats': {
      'statsSeason': '2025-26', 'statsLeague': 'Ligue 1', 'statsTeam': 'Paris Saint-Germain',
      'goals': 1, 'goalsPer90': 0.04, 'shots': 1.5, 'shotsOnTarget': 0.7,
      'passAccuracy': 91.0, 'tackles': 1.1, 'interceptions': 0.6,
    },
  },
  'fp_pedri': { // Pedri
    'careerAppearances': 381,
    'careerGoals': 41,
    'careerAssists': 43,
    'careerStats': [
      {'season': 'Career', 'team': 'UD Las Palmas', 'appearances': 37, 'goals': 3, 'assists': 1},
      {'season': 'Career', 'team': 'FC Barcelona', 'appearances': 295, 'goals': 32, 'assists': 42},
      {'season': 'International', 'team': 'Spain', 'appearances': 49, 'goals': 6, 'assists': 0},
    ],
    'seasonStats': {
      'statsSeason': '2025-26', 'statsLeague': 'La Liga', 'statsTeam': 'FC Barcelona',
      'goals': 2, 'goalsPer90': 0.09, 'shots': 1.2, 'shotsOnTarget': 0.5,
      'passAccuracy': 91.7, 'tackles': 1.0, 'interceptions': 0.5,
    },
  },
  'fp_thibaut_courtois': { // Thibaut Courtois
    'careerAppearances': 792,
    'careerGoals': 0,
    'careerAssists': 4,
    'careerStats': [
      {'season': 'Career', 'team': 'KRC Genk', 'appearances': 45, 'goals': 0, 'assists': 0},
      {'season': 'Loan', 'team': 'Atlético Madrid', 'appearances': 154, 'goals': 0, 'assists': 1},
      {'season': 'Career', 'team': 'Chelsea', 'appearances': 154, 'goals': 0, 'assists': 1},
      {'season': 'Career', 'team': 'Real Madrid', 'appearances': 324, 'goals': 0, 'assists': 2},
      {'season': 'International', 'team': 'Belgium', 'appearances': 115, 'goals': 0, 'assists': 0},
    ],
    'seasonStats': {
      'statsSeason': '2025-26', 'statsLeague': 'La Liga', 'statsTeam': 'Real Madrid',
      'goals': 0, 'goalsPer90': 0.0, 'shots': 0.0, 'shotsOnTarget': 0.0,
      'passAccuracy': 82.0, 'tackles': 0.1, 'interceptions': 0.3,
    },
  },
  'fp_mohamed_salah': { // Mohamed Salah
    'careerAppearances': 804,
    'careerGoals': 382,
    'careerAssists': 184,
    'careerStats': [
      {'season': 'Career', 'team': 'El Mokawloon / Basel / Chelsea', 'appearances': 120, 'goals': 35, 'assists': 20},
      {'season': 'Career', 'team': 'AS Roma', 'appearances': 83, 'goals': 34, 'assists': 19},
      {'season': 'Career', 'team': 'Liverpool', 'appearances': 490, 'goals': 248, 'assists': 110},
      {'season': 'International', 'team': 'Egypt', 'appearances': 111, 'goals': 65, 'assists': 35},
    ],
    // A visible down-year at 33: 7 goals/7 assists in 27 PL games in
    // 2025-26, well off his usual 25-30 goal seasons.
    'seasonStats': {
      'statsSeason': '2025-26', 'statsLeague': 'Premier League', 'statsTeam': 'Liverpool',
      'goals': 7, 'goalsPer90': 0.29, 'shots': 2.5, 'shotsOnTarget': 0.7,
      'passAccuracy': 79.0, 'tackles': 0.5, 'interceptions': 0.2,
    },
  },
  'fp_rodri': { // Rodri
    'careerAppearances': 512,
    'careerGoals': 41,
    'careerAssists': 36,
    // Transferred from Manchester City to Barcelona in Aug 2026 (~€60-76.5M,
    // 4-year deal) after seven seasons and 298 appearances at City.
    'careerStats': [
      {'season': 'Career', 'team': 'Villarreal', 'appearances': 110, 'goals': 8, 'assists': 9},
      {'season': 'Career', 'team': 'Atlético Madrid', 'appearances': 52, 'goals': 5, 'assists': 4},
      {'season': 'Career', 'team': 'Manchester City', 'appearances': 298, 'goals': 24, 'assists': 23},
      {'season': 'Career', 'team': 'Barcelona', 'appearances': 0, 'goals': 0, 'assists': 0},
      {'season': 'International', 'team': 'Spain', 'appearances': 70, 'goals': 4, 'assists': 0},
    ],
    // Final season at Man City before the transfer — limited to 18 PL
    // appearances as his exit approached. No Barcelona appearances yet.
    'seasonStats': {
      'statsSeason': '2025-26', 'statsLeague': 'Premier League', 'statsTeam': 'Manchester City',
      'goals': 1, 'goalsPer90': 0.06, 'shots': 0.8, 'shotsOnTarget': 0.3,
      'passAccuracy': 91.0, 'tackles': 1.6, 'interceptions': 1.1,
    },
  },
  'fp_raphinha': { // Raphinha
    'careerAppearances': 586,
    'careerGoals': 151,
    'careerAssists': 87,
    'careerStats': [
      {'season': 'Career', 'team': 'Vitória SC', 'appearances': 85, 'goals': 22, 'assists': 13},
      {'season': 'Career', 'team': 'Rennes', 'appearances': 60, 'goals': 8, 'assists': 6},
      {'season': 'Career', 'team': 'Leeds United', 'appearances': 90, 'goals': 17, 'assists': 12},
      {'season': 'Career', 'team': 'FC Barcelona', 'appearances': 310, 'goals': 93, 'assists': 56},
      {'season': 'International', 'team': 'Brazil', 'appearances': 41, 'goals': 11, 'assists': 0},
    ],
    'seasonStats': {
      'statsSeason': '2025-26', 'statsLeague': 'La Liga', 'statsTeam': 'FC Barcelona',
      'goals': 13, 'goalsPer90': 0.66, 'shots': 3.6, 'shotsOnTarget': 1.9,
      'passAccuracy': 81.0, 'tackles': 1.0, 'interceptions': 0.3,
    },
  },
  'fp_achraf_hakimi': { // Achraf Hakimi
    'careerAppearances': 555,
    'careerGoals': 76,
    'careerAssists': 95,
    'careerStats': [
      {'season': 'Career', 'team': 'Real Madrid', 'appearances': 40, 'goals': 2, 'assists': 3},
      {'season': 'Loan', 'team': 'Borussia Dortmund', 'appearances': 73, 'goals': 11, 'assists': 8},
      {'season': 'Career', 'team': 'Inter Milan', 'appearances': 90, 'goals': 12, 'assists': 15},
      {'season': 'Career', 'team': 'Paris Saint-Germain', 'appearances': 247, 'goals': 37, 'assists': 53},
      {'season': 'International', 'team': 'Morocco', 'appearances': 105, 'goals': 14, 'assists': 16},
    ],
    'seasonStats': {
      'statsSeason': '2025-26', 'statsLeague': 'Ligue 1', 'statsTeam': 'Paris Saint-Germain',
      'goals': 2, 'goalsPer90': 0.13, 'shots': 1.4, 'shotsOnTarget': 0.6,
      'passAccuracy': 85.0, 'tackles': 1.6, 'interceptions': 0.9,
    },
  },
  'fp_gianluigi_donnarumma': { // Gianluigi Donnarumma
    'careerAppearances': 608,
    'careerGoals': 0,
    'careerAssists': 1,
    'careerStats': [
      {'season': 'Career', 'team': 'AC Milan', 'appearances': 251, 'goals': 0, 'assists': 1},
      {'season': 'Career', 'team': 'Paris Saint-Germain', 'appearances': 245, 'goals': 0, 'assists': 0},
      {'season': 'Career', 'team': 'Manchester City', 'appearances': 29, 'goals': 0, 'assists': 0},
      {'season': 'International', 'team': 'Italy', 'appearances': 83, 'goals': 0, 'assists': 0},
    ],
    // Made a strong first impression at City after his move, winning a
    // Premier League Save of the Month award.
    'seasonStats': {
      'statsSeason': '2025-26', 'statsLeague': 'Premier League', 'statsTeam': 'Manchester City',
      'goals': 0, 'goalsPer90': 0.0, 'shots': 0.0, 'shotsOnTarget': 0.0,
      'passAccuracy': 78.0, 'tackles': 0.1, 'interceptions': 0.2,
    },
  },
  'fp_joshua_kimmich': { // Joshua Kimmich
    'careerAppearances': 734,
    'careerGoals': 66,
    'careerAssists': 143,
    'careerStats': [
      {'season': 'Career', 'team': 'RB Leipzig', 'appearances': 120, 'goals': 6, 'assists': 13},
      {'season': 'Career', 'team': 'Bayern Munich', 'appearances': 500, 'goals': 50, 'assists': 130},
      {'season': 'International', 'team': 'Germany', 'appearances': 114, 'goals': 10, 'assists': 0},
    ],
    'seasonStats': {
      'statsSeason': '2025-26', 'statsLeague': 'Bundesliga', 'statsTeam': 'Bayern Munich',
      'goals': 2, 'goalsPer90': 0.08, 'shots': 1.0, 'shotsOnTarget': 0.35,
      'passAccuracy': 92.5, 'tackles': 1.8, 'interceptions': 1.2,
    },
  },
  'fp_federico_valverde': { // Federico Valverde
    'careerAppearances': 560,
    'careerGoals': 56,
    'careerAssists': 44,
    'careerStats': [
      {'season': 'Career', 'team': 'Peñarol', 'appearances': 20, 'goals': 2, 'assists': 1},
      {'season': 'Loan', 'team': 'Deportivo La Coruña', 'appearances': 32, 'goals': 3, 'assists': 2},
      {'season': 'Career', 'team': 'Real Madrid', 'appearances': 432, 'goals': 42, 'assists': 41},
      {'season': 'International', 'team': 'Uruguay', 'appearances': 76, 'goals': 9, 'assists': 0},
    ],
    'seasonStats': {
      'statsSeason': '2025-26', 'statsLeague': 'La Liga', 'statsTeam': 'Real Madrid',
      'goals': 5, 'goalsPer90': 0.15, 'shots': 1.55, 'shotsOnTarget': 0.67,
      'passAccuracy': 88.0, 'tackles': 1.6, 'interceptions': 0.8,
    },
  },
  'fp_gabriel': { // Gabriel Magalhães
    'careerAppearances': 378,
    'careerGoals': 28,
    'careerAssists': 9,
    'careerStats': [
      {'season': 'Career', 'team': 'Avaí', 'appearances': 35, 'goals': 2, 'assists': 1},
      {'season': 'Career', 'team': 'Lille (incl. loans)', 'appearances': 70, 'goals': 5, 'assists': 3},
      {'season': 'Career', 'team': 'Arsenal', 'appearances': 248, 'goals': 20, 'assists': 4},
      {'season': 'International', 'team': 'Brazil', 'appearances': 25, 'goals': 1, 'assists': 1},
    ],
    'seasonStats': {
      'statsSeason': '2025-26', 'statsLeague': 'Premier League', 'statsTeam': 'Arsenal',
      'goals': 3, 'goalsPer90': 0.10, 'shots': 1.0, 'shotsOnTarget': 0.5,
      'passAccuracy': 88.0, 'tackles': 0.83, 'interceptions': 0.50,
    },
  },
  'fp_michael_olise': { // Michael Olise
    'careerAppearances': 251,
    'careerGoals': 57,
    'careerAssists': 75,
    'careerStats': [
      {'season': 'Career', 'team': 'Reading', 'appearances': 65, 'goals': 9, 'assists': 14},
      {'season': 'Career', 'team': 'Crystal Palace', 'appearances': 110, 'goals': 17, 'assists': 35},
      {'season': 'Career', 'team': 'Bayern Munich', 'appearances': 56, 'goals': 25, 'assists': 24},
      {'season': 'International', 'team': 'France', 'appearances': 20, 'goals': 6, 'assists': 2},
    ],
    'seasonStats': {
      'statsSeason': '2025-26', 'statsLeague': 'Bundesliga', 'statsTeam': 'Bayern Munich',
      'goals': 15, 'goalsPer90': 0.58, 'shots': 3.2, 'shotsOnTarget': 1.6,
      'passAccuracy': 83.0, 'tackles': 0.6, 'interceptions': 0.3,
    },
  },
  'fp_virgil_van_dijk': { // Virgil van Dijk
    'careerAppearances': 779,
    'careerGoals': 80,
    'careerAssists': 22,
    'careerStats': [
      {'season': 'Career', 'team': 'Groningen', 'appearances': 63, 'goals': 3, 'assists': 2},
      {'season': 'Career', 'team': 'Celtic', 'appearances': 71, 'goals': 5, 'assists': 2},
      {'season': 'Career', 'team': 'Southampton', 'appearances': 151, 'goals': 15, 'assists': 5},
      {'season': 'Career', 'team': 'Liverpool', 'appearances': 398, 'goals': 44, 'assists': 13},
      {'season': 'International', 'team': 'Netherlands', 'appearances': 96, 'goals': 13, 'assists': 0},
    ],
    'seasonStats': {
      'statsSeason': '2025-26', 'statsLeague': 'Premier League', 'statsTeam': 'Liverpool',
      'goals': 6, 'goalsPer90': 0.20, 'shots': 1.0, 'shotsOnTarget': 0.5,
      'passAccuracy': 90.0, 'tackles': 0.6, 'interceptions': 0.7,
    },
  },
  'fp_alisson': { // Alisson Becker
    'careerAppearances': 564,
    'careerGoals': 1,
    'careerAssists': 3,
    'careerStats': [
      {'season': 'Career', 'team': 'Internacional', 'appearances': 66, 'goals': 0, 'assists': 0},
      {'season': 'Career', 'team': 'AS Roma', 'appearances': 63, 'goals': 0, 'assists': 0},
      {'season': 'Career', 'team': 'Liverpool', 'appearances': 350, 'goals': 1, 'assists': 3},
      {'season': 'International', 'team': 'Brazil', 'appearances': 85, 'goals': 0, 'assists': 0},
    ],
    'seasonStats': {
      'statsSeason': '2025-26', 'statsLeague': 'Premier League', 'statsTeam': 'Liverpool',
      'goals': 0, 'goalsPer90': 0.0, 'shots': 0.0, 'shotsOnTarget': 0.0,
      'passAccuracy': 80.0, 'tackles': 0.0, 'interceptions': 0.1,
    },
  },
  'fp_lautaro_martinez': { // Lautaro Martínez
    'careerAppearances': 543,
    'careerGoals': 255,
    'careerAssists': 63,
    'careerStats': [
      {'season': 'Career', 'team': 'Racing Club', 'appearances': 63, 'goals': 22, 'assists': 8},
      {'season': 'Career', 'team': 'Inter Milan', 'appearances': 400, 'goals': 195, 'assists': 45},
      {'season': 'International', 'team': 'Argentina', 'appearances': 80, 'goals': 38, 'assists': 10},
    ],
    'seasonStats': {
      'statsSeason': '2025-26', 'statsLeague': 'Serie A', 'statsTeam': 'Inter Milan',
      'goals': 17, 'goalsPer90': 0.71, 'shots': 3.2, 'shotsOnTarget': 1.7,
      'passAccuracy': 78.0, 'tackles': 0.3, 'interceptions': 0.2,
    },
  },
  'fp_jan_oblak': { // Jan Oblak
    'careerAppearances': 741,
    'careerGoals': 0,
    'careerAssists': 1,
    'careerStats': [
      {'season': 'Career', 'team': 'Olimpija Ljubljana', 'appearances': 18, 'goals': 0, 'assists': 0},
      {'season': 'Career', 'team': 'Benfica (incl. loans)', 'appearances': 107, 'goals': 0, 'assists': 0},
      {'season': 'Career', 'team': 'Atlético Madrid', 'appearances': 532, 'goals': 0, 'assists': 1},
      {'season': 'International', 'team': 'Slovenia', 'appearances': 84, 'goals': 0, 'assists': 0},
    ],
    'seasonStats': {
      'statsSeason': '2025-26', 'statsLeague': 'La Liga', 'statsTeam': 'Atlético Madrid',
      'goals': 0, 'goalsPer90': 0.0, 'shots': 0.0, 'shotsOnTarget': 0.0,
      'passAccuracy': 75.0, 'tackles': 0.0, 'interceptions': 0.1,
    },
  },
  'fp_khvicha_kvaratskhelia': { // Khvicha Kvaratskhelia
    'careerAppearances': 390,
    'careerGoals': 120,
    'careerAssists': 66,
    'careerStats': [
      {'season': 'Career', 'team': 'Dinamo Tbilisi / FC Rustavi', 'appearances': 40, 'goals': 10, 'assists': 6},
      {'season': 'Career', 'team': 'Rubin Kazan', 'appearances': 73, 'goals': 9, 'assists': 18},
      {'season': 'Career', 'team': 'Napoli', 'appearances': 106, 'goals': 44, 'assists': 25},
      {'season': 'Career', 'team': 'Paris Saint-Germain', 'appearances': 121, 'goals': 34, 'assists': 7},
      {'season': 'International', 'team': 'Georgia', 'appearances': 50, 'goals': 23, 'assists': 10},
    ],
    'seasonStats': {
      'statsSeason': '2025-26', 'statsLeague': 'Ligue 1', 'statsTeam': 'Paris Saint-Germain',
      'goals': 8, 'goalsPer90': 0.49, 'shots': 2.3, 'shotsOnTarget': 1.2,
      'passAccuracy': 82.0, 'tackles': 0.8, 'interceptions': 0.3,
    },
  },
  'fp_moises_caicedo': { // Moisés Caicedo
    'careerAppearances': 349,
    'careerGoals': 24,
    'careerAssists': 25,
    'careerStats': [
      {'season': 'Career', 'team': 'Independiente del Valle', 'appearances': 34, 'goals': 2, 'assists': 2},
      {'season': 'Loan', 'team': 'Beerschot', 'appearances': 29, 'goals': 1, 'assists': 2},
      {'season': 'Career', 'team': 'Brighton & Hove Albion', 'appearances': 35, 'goals': 5, 'assists': 3},
      {'season': 'Career', 'team': 'Chelsea', 'appearances': 186, 'goals': 13, 'assists': 11},
      {'season': 'International', 'team': 'Ecuador', 'appearances': 65, 'goals': 3, 'assists': 5},
    ],
    'seasonStats': {
      'statsSeason': '2025-26', 'statsLeague': 'Premier League', 'statsTeam': 'Chelsea',
      'goals': 3, 'goalsPer90': 0.12, 'shots': 1.0, 'shotsOnTarget': 0.4,
      'passAccuracy': 89.0, 'tackles': 2.0, 'interceptions': 1.4,
    },
  },
  'fp_declan_rice': { // Declan Rice
    'careerAppearances': 582,
    'careerGoals': 50,
    'careerAssists': 49,
    'careerStats': [
      {'season': 'Career', 'team': 'West Ham United', 'appearances': 245, 'goals': 14, 'assists': 26},
      {'season': 'Career', 'team': 'Arsenal', 'appearances': 257, 'goals': 28, 'assists': 23},
      {'season': 'International', 'team': 'England', 'appearances': 80, 'goals': 8, 'assists': 0},
    ],
    'seasonStats': {
      'statsSeason': '2025-26', 'statsLeague': 'Premier League', 'statsTeam': 'Arsenal',
      'goals': 4, 'goalsPer90': 0.12, 'shots': 1.6, 'shotsOnTarget': 0.7,
      'passAccuracy': 90.0, 'tackles': 1.8, 'interceptions': 1.0,
    },
  },
  'fp_bruno_fernandes': { // Bruno Fernandes
    'careerAppearances': 802,
    'careerGoals': 238,
    'careerAssists': 201,
    'careerStats': [
      {'season': 'Career', 'team': 'Novara / Udinese / Sampdoria', 'appearances': 170, 'goals': 20, 'assists': 22},
      {'season': 'Career', 'team': 'Sporting CP', 'appearances': 137, 'goals': 63, 'assists': 47},
      {'season': 'Career', 'team': 'Manchester United', 'appearances': 401, 'goals': 126, 'assists': 132},
      {'season': 'International', 'team': 'Portugal', 'appearances': 94, 'goals': 29, 'assists': 0},
    ],
    'seasonStats': {
      'statsSeason': '2025-26', 'statsLeague': 'Premier League', 'statsTeam': 'Manchester United',
      'goals': 9, 'goalsPer90': 0.26, 'shots': 2.8, 'shotsOnTarget': 1.3,
      'passAccuracy': 81.0, 'tackles': 1.4, 'interceptions': 0.6,
    },
  },
};

/// Club badge lookup for the "Career History" list. Keyed by the exact
/// `team` string used in [predefinedPlayerStats]' `careerStats` entries.
///
/// These are ESPN's soccer team-logo CDN IDs (`teamlogos/soccer/500/{id}.png`),
/// confirmed against ESPN's own team pages rather than guessed — a wrong ID
/// here would silently show the wrong club's crest, which is worse than no
/// crest at all. A few career-history entries in [predefinedPlayerStats]
/// combine multiple clubs into one string (e.g. loan spells, or a player's
/// pre-fame lower-league clubs) and are intentionally left out; the UI
/// should fall back to a generic icon for any name not present here rather
/// than guess. International rows are also intentionally left out of this
/// map — a country isn't an ESPN club entity, so the UI should render those
/// with a flag (see `Helpers.getLeagueFlag`-style lookups) rather than a
/// crest.
const Map<String, String> clubLogoIds = {
  'Real Madrid': '86',
  'FC Barcelona': '83',
  'Arsenal': '359',
  'Manchester United': '360',
  'Manchester City': '382',
  'Paris Saint-Germain': '160',
  'Bayern Munich': '132',
  'Juventus FC': '111',
  'Chelsea': '363',
  'Liverpool': '364',
  'Al-Nassr FC': '12765',
  'Inter Miami CF': '16052',
  'Sporting CP': '2250',
  'AS Monaco': '174',
  'FC Red Bull Salzburg': '2790',
  'Borussia Dortmund': '124',
  'Tottenham Hotspur': '367',
  'Rennes': '169',
  'Flamengo': '819',
  'Birmingham City': '392',
  'FC Porto': '181',
  'Wolverhampton Wanderers': '380',
  'Atlético Madrid': '1068',
  'AS Roma': '104',
  'Villarreal': '102',
  'Leeds United': '357',
  'Inter Milan': '110',
  'AC Milan': '103',
  'RB Leipzig': '2670',
  'Deportivo La Coruña': '85',
  'Southampton': '376',
  'Celtic': '2323',
  'Independiente del Valle': '9906',
  'Brighton & Hove Albion': '331',
  'West Ham United': '371',
  'Napoli': '114',
  'Crystal Palace': '384',
  'Reading': '335',
};

/// Returns an ESPN crest URL for [teamName] if we have a confirmed logo id
/// for it, otherwise null (caller should fall back to a generic icon).
String? getClubLogoUrl(String teamName) {
  final id = clubLogoIds[teamName];
  if (id == null) return null;
  return 'https://a.espncdn.com/i/teamlogos/soccer/500/$id.png';
}

/// Look up a famous-player map by id, or null if it's not one of the
/// predefined seed players.
Map<String, dynamic>? findFamousPlayerById(String id) {
  for (final p in famousPlayers) {
    if (p['id'] == id) return p;
  }
  return null;
}

/// Look up a famous-club map by id, or null if it's not one of the
/// predefined seed clubs.
Map<String, String>? findFamousClubById(String id) {
  for (final c in famousClubs) {
    if (c['id'] == id) return c;
  }
  return null;
}

/// Simple, dependency-free "does this look like a match" filter used by the
/// search fallback in AppProvider — matches on name, team name, or
/// nationality, case-insensitively.
bool matchesPredefinedQuery(String haystack, String query) {
  return haystack.toLowerCase().contains(query.toLowerCase());
}