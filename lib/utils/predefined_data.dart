// lib/utils/predefined_data.dart
//
// Static, offline "seed" data used as a fallback whenever the live APIs
// (API-Football / ESPN / TheSportsDB) fail to return something useful —
// e.g. rate-limited, no network, or a cold start before the first fetch
// completes. This keeps the Search screen and Player screen populated
// with real, recognizable content instead of an empty/error state.
//
// NOTE: the season stats below are the most recent completed domestic
// season (2024–25) and are approximate "per-90" style figures meant for
// fallback display only — they are not refreshed automatically.

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
    'teamName': 'Manchester City',
    'teamId': '382',
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
    'teamName': 'Inter Milan',
    'teamId': '110',
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
    'teamName': 'Barcelona',
    'teamId': '83',
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
    'teamName': 'Newcastle United',
    'teamId': '',
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
    'teamName': 'Aston Villa',
    'teamId': '',
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
    'teamName': 'Chelsea',
    'teamId': '363',
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
    'teamName': 'Inter Milan',
    'teamId': '110',
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
    'teamName': 'Inter Milan',
    'teamId': '110',
    'position': 'CAM',
    'jersey': '',
    'nationality': 'France',
    'imageUrl': '', // resolved at runtime via ESPN + TheSportsDB (see onboarding_screen.dart)
  },
  {
    'id': 'fp_luka_modric',
    'name': 'Luka Modrić',
    'teamName': 'Inter Milan',
    'teamId': '110',
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
    'teamName': 'Liverpool',
    'teamId': '364',
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

/// Career history + most recent completed season (2024–25) stats, keyed by
/// the same player id used in [famousPlayers]. Shapes match exactly what
/// PlayerScreen expects:
///   - `careerStats` -> List<Map<String,dynamic>> with season/team/goals/
///     assists/appearances (consumed by `_buildCareerStatsCard`)
///   - `seasonStats`  -> Map<String,dynamic> with the keys read in
///     `_buildSeasonStatsCard` (goalsPer90, shots, shotsOnTarget,
///     passAccuracy, tackles, interceptions, statsTeam, statsLeague,
///     statsSeason)
const Map<String, Map<String, dynamic>> predefinedPlayerStats = {
  '22774': { // Cristiano Ronaldo
    'careerAppearances': 1330,
    'careerGoals': 976,
    'careerAssists': 261,
    'careerStats': [
      {'season': '2009–2018', 'team': 'Real Madrid', 'appearances': 438, 'goals': 450, 'assists': 131},
      {'season': 'Stints 1&2', 'team': 'Manchester United', 'appearances': 346, 'goals': 145, 'assists': 64},
      {'season': '2023–Present', 'team': 'Al-Nassr FC', 'appearances': 146, 'goals': 127, 'assists': 23},
      {'season': '2002–2003', 'team': 'Sporting CP', 'appearances': 31, 'goals': 5, 'assists': 6},
      {'season': '2018–2021', 'team': 'Juventus FC', 'appearances': 134, 'goals': 101, 'assists': 22},
    ],
    'seasonStats': {
      'statsSeason': '2024-25', 'statsLeague': 'Saudi Pro League', 'statsTeam': 'Al-Nassr',
      'goals': 25, 'goalsPer90': 0.91, 'shots': 5.1, 'shotsOnTarget': 2.4,
      'passAccuracy': 84, 'tackles': 0.15, 'interceptions': 0.03,
    },
  },
  '45843': { // Lionel Messi
    'careerAppearances': 1164,
    'careerGoals': 919,
    'careerAssists': 457,
    'careerStats': [
      {'season': 'Career', 'team': 'FC Barcelona', 'appearances': 778, 'goals': 672, 'assists': 303},
      {'season': 'Career', 'team': 'Paris Saint-Germain', 'appearances': 75, 'goals': 32, 'assists': 34},
      {'season': 'Career', 'team': 'Inter Miami CF', 'appearances': 97, 'goals': 80, 'assists': 41},
    ],
    'seasonStats': {
      'statsSeason': '2024-25', 'statsLeague': 'MLS', 'statsTeam': 'Inter Miami',
      'goals': 20, 'goalsPer90': 0.95, 'shots': 4.30, 'shotsOnTarget': 2.35,
      'passAccuracy': 80.1, 'tackles': 0.42, 'interceptions': 0.09,
    },
  },
  '231388': { // Kylian Mbappé
    'careerAppearances': 445,
    'careerGoals': 350,
    'careerAssists': 150,
    'careerStats': [
      {'season': 'Career', 'team': 'AS Monaco', 'appearances': 60, 'goals': 27, 'assists': 16},
      {'season': 'Career', 'team': 'Paris Saint-Germain', 'appearances': 308, 'goals': 256, 'assists': 108},
      {'season': 'Career', 'team': 'Real Madrid', 'appearances': 77, 'goals': 61, 'assists': 10},
    ],
    'seasonStats': {
      'statsSeason': '2024-25', 'statsLeague': 'La Liga', 'statsTeam': 'Real Madrid',
      'goals': 31, 'goalsPer90': 0.91, 'shots': 4.74, 'shotsOnTarget': 2.50,
      'passAccuracy': 83.5, 'tackles': 0.28, 'interceptions': 0.06,
    },
  },
  '253989': { // Erling Haaland
    'careerAppearances': 320,
    'careerGoals': 272,
    'careerAssists': 52,
    'careerStats': [
      {'season': 'Career', 'team': 'Bryne FK / Molde FK', 'appearances': 53, 'goals': 20, 'assists': 6},
      {'season': 'Career', 'team': 'FC Red Bull Salzburg', 'appearances': 27, 'goals': 29, 'assists': 7},
      {'season': 'Career', 'team': 'Borussia Dortmund', 'appearances': 89, 'goals': 86, 'assists': 23},
      {'season': 'Career', 'team': 'Manchester City', 'appearances': 135, 'goals': 125, 'assists': 20},
    ],
    'seasonStats': {
      'statsSeason': '2024-25', 'statsLeague': 'Premier League', 'statsTeam': 'Manchester City',
      'goals': 21, 'goalsPer90': 0.78, 'shots': 3.83, 'shotsOnTarget': 1.80,
      'passAccuracy': 65.6, 'tackles': 0.33, 'interceptions': 0.18,
    },
  },
  '362150': { // Lamine Yamal
    'careerAppearances': 182,
    'careerGoals': 56,
    'careerAssists': 55,
    'careerStats': [
      {'season': 'Career', 'team': 'FC Barcelona', 'appearances': 151, 'goals': 49, 'assists': 44},
    ],
    'seasonStats': {
      'statsSeason': '2024-25', 'statsLeague': 'La Liga', 'statsTeam': 'FC Barcelona',
      'goals': 9, 'goalsPer90': 0.35, 'shots': 2.80, 'shotsOnTarget': 1.10,
      'passAccuracy': 81.2, 'tackles': 0.85, 'interceptions': 0.22,
    },
  },
  '291281': { // Jude Bellingham
    'careerAppearances': 280,
    'careerGoals': 75,
    'careerAssists': 50,
    'careerStats': [
      {'season': 'Career', 'team': 'Birmingham City', 'appearances': 44, 'goals': 4, 'assists': 2},
      {'season': 'Career', 'team': 'Borussia Dortmund', 'appearances': 132, 'goals': 24, 'assists': 25},
      {'season': 'Career', 'team': 'Real Madrid', 'appearances': 104, 'goals': 32, 'assists': 20},
    ],
    'seasonStats': {
      'statsSeason': '2024-25', 'statsLeague': 'La Liga', 'statsTeam': 'Real Madrid',
      'goals': 14, 'goalsPer90': 0.41, 'shots': 2.30, 'shotsOnTarget': 1.05,
      'passAccuracy': 87.8, 'tackles': 1.45, 'interceptions': 0.62,
    },
  },
  '142200': { // Harry Kane
    'careerAppearances': 685,
    'careerGoals': 432,
    'careerAssists': 118,
    'careerStats': [
      {'season': 'Career', 'team': 'Tottenham Hotspur', 'appearances': 435, 'goals': 280, 'assists': 61},
      {'season': 'Career', 'team': 'Bayern Munich', 'appearances': 105, 'goals': 104, 'assists': 29},
      {'season': 'Career', 'team': 'Millwall / Leyton Orient / Norwich', 'appearances': 47, 'goals': 14, 'assists': 3},
    ],
    'seasonStats': {
      'statsSeason': '2024-25', 'statsLeague': 'Bundesliga', 'statsTeam': 'Bayern Munich',
      'goals': 26, 'goalsPer90': 0.84, 'shots': 4.31, 'shotsOnTarget': 2.04,
      'passAccuracy': 75.4, 'tackles': 0.42, 'interceptions': 0.11,
    },
  },
  '189281': { // Ousmane Dembélé
    'careerAppearances': 410,
    'careerGoals': 124,
    'careerAssists': 105,
    'careerStats': [
      {'season': 'Career', 'team': 'Rennes', 'appearances': 29, 'goals': 12, 'assists': 5},
      {'season': 'Career', 'team': 'Borussia Dortmund', 'appearances': 50, 'goals': 10, 'assists': 22},
      {'season': 'Career', 'team': 'FC Barcelona', 'appearances': 185, 'goals': 40, 'assists': 43},
      {'season': 'Career', 'team': 'Paris Saint-Germain', 'appearances': 95, 'goals': 42, 'assists': 25},
    ],
    'seasonStats': {
      'statsSeason': '2024-25', 'statsLeague': 'Ligue 1', 'statsTeam': 'Paris Saint-Germain',
      'goals': 21, 'goalsPer90': 0.72, 'shots': 3.32, 'shotsOnTarget': 1.74,
      'passAccuracy': 81.2, 'tackles': 0.95, 'interceptions': 0.31,
    },
  },
  '270126': { // Vinícius Júnior
    'careerAppearances': 390,
    'careerGoals': 125,
    'careerAssists': 85,
    'careerStats': [
      {'season': 'Career', 'team': 'Flamengo', 'appearances': 69, 'goals': 14, 'assists': 4},
      {'season': 'Career', 'team': 'Real Madrid', 'appearances': 321, 'goals': 111, 'assists': 81},
    ],
    'seasonStats': {
      'statsSeason': '2024-25', 'statsLeague': 'La Liga', 'statsTeam': 'Real Madrid',
      'goals': 23, 'goalsPer90': 0.69, 'shots': 3.85, 'shotsOnTarget': 1.92,
      'passAccuracy': 82.6, 'tackles': 0.65, 'interceptions': 0.15,
    },
  },
  '280903': { // Bukayo Saka
    'careerAppearances': 310,
    'careerGoals': 85,
    'careerAssists': 75,
    'careerStats': [
      {'season': 'Career', 'team': 'Arsenal', 'appearances': 310, 'goals': 85, 'assists': 75},
    ],
    'seasonStats': {
      'statsSeason': '2024-25', 'statsLeague': 'Premier League', 'statsTeam': 'Arsenal',
      'goals': 6, 'goalsPer90': 0.24, 'shots': 2.68, 'shotsOnTarget': 0.92,
      'passAccuracy': 83.1, 'tackles': 1.32, 'interceptions': 0.45,
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
/// combine multiple clubs into one string (e.g. loan spells) and are
/// intentionally left out; the UI should fall back to a generic icon for
/// any name not present here rather than guess.
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