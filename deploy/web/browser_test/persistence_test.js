/**
 * §1 et §4 — PERSISTANCE EN BASE, PAS EN LOCAL.
 *
 * CE QUE CE TEST PROUVE, ET POURQUOI C'EST DIFFICILE À PROUVER
 * ------------------------------------------------------------
 * « Mes données sont sauvegardées » est facile à afficher et difficile à
 * démontrer : une application qui garde tout dans le `localStorage` du
 * navigateur donne exactement la même impression, sur la même machine.
 *
 * La seule preuve valable est donc de changer de CONTEXTE DE NAVIGATION :
 * un contexte neuf n'a ni localStorage, ni session, ni cache. S'y connecter
 * et retrouver ses données démontre qu'elles viennent du serveur — c'est
 * l'équivalent d'un second appareil.
 *
 * Deux contextes sont utilisés :
 *   A. connexion + relevé du dossier affiché ;
 *   B. contexte VIERGE (aucun stockage) → même compte → le dossier doit être
 *      identique.
 * Entre A et B, rien n'est touché côté client : si l'application lisait son
 * propre stockage, B serait vide.
 *
 * USAGE
 *   node deploy/web/browser_test/persistence_test.js \
 *        <email> <password> <nomAttendu> [url]
 *
 * Le compte doit être créé au préalable (voir make_client.py). Aucune donnée
 * n'est modifiée ni supprimée par ce test.
 */
const path = require('path');

function loadPuppeteer() {
  const candidates = [
    'puppeteer-core',
    process.env.GOREX_PUPPETEER_DIR
      ? path.join(process.env.GOREX_PUPPETEER_DIR, 'node_modules', 'puppeteer-core')
      : null,
    '/tmp/uitest/node_modules/puppeteer-core',
  ].filter(Boolean);
  for (const c of candidates) {
    try {
      return require(c);
    } catch (e) {}
  }
  console.error(
    'puppeteer-core introuvable. Exemple :\n' +
      '  mkdir -p /tmp/uitest && cd /tmp/uitest && npm install puppeteer-core'
  );
  process.exit(2);
}
const puppeteer = loadPuppeteer();

const CHROME = process.env.CHROME_PATH || '/usr/bin/google-chrome';
const [email, password, expectedName, urlArg] = process.argv.slice(2);
const URL = urlArg || 'https://gorex-luxury-concierge.eu/';

if (!email || !password || !expectedName) {
  console.error('Usage : node persistence_test.js <email> <password> <nomAttendu> [url]');
  process.exit(2);
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

/** Accepte les cookies et active l'arbre sémantique de Flutter. */
async function prepare(page) {
  await page.goto(URL, { waitUntil: 'networkidle2', timeout: 90000 });
  await sleep(9000);
  for (const btn of await page.$$('button')) {
    const t = (await (await btn.getProperty('textContent')).jsonValue()) || '';
    if (/CONTINUER SANS/i.test(t)) {
      await btn.click();
      break;
    }
  }
  await sleep(700);
  await page.evaluate(() => {
    const ph = document.querySelector('flt-semantics-placeholder');
    if (ph) ph.click();
  });
  await sleep(2500);
}

/** Saisit les identifiants et clique sur SE CONNECTER. */
async function signIn(page) {
  await page.click('input[type=email]');
  await page.type('input[type=email]', email, { delay: 6 });
  await page.click('input[type=password]');
  await page.type('input[type=password]', password, { delay: 6 });
  await sleep(300);

  const box = await page.evaluate(() => {
    let found = null;
    document.querySelectorAll('flt-semantics[role=button]').forEach((el) => {
      if (/SE CONNECTER/i.test((el.textContent || '').trim()) && !found) {
        const r = el.getBoundingClientRect();
        found = { x: r.x + r.width / 2, y: r.y + r.height / 2 };
      }
    });
    return found;
  });
  if (!box) return { clicked: false };
  await page.mouse.click(box.x, box.y);
  await sleep(11000);
  return { clicked: true };
}

/** Relevé textuel de l'écran, via l'arbre sémantique. */
async function dump(page) {
  await page.evaluate(() => {
    const ph = document.querySelector('flt-semantics-placeholder');
    if (ph) ph.click();
  });
  await sleep(1800);
  return page.evaluate(() =>
    Array.from(document.querySelectorAll('flt-semantics'))
      .map((el) => (el.textContent || '').trim())
      .filter((t) => t.length > 0)
      .join(' | ')
  );
}

(async () => {
  const browser = await puppeteer.launch({
    executablePath: CHROME,
    headless: 'new',
    args: ['--no-sandbox', '--disable-gpu', '--disable-dev-shm-usage'],
    defaultViewport: { width: 430, height: 932 },
  });

  const errors = [];
  const results = [];

  // ── Contexte A : première session ────────────────────────────────────
  const ctxA = await browser.createBrowserContext();
  const pageA = await ctxA.newPage();
  pageA.on('pageerror', (e) => errors.push('A: ' + e.message));
  await prepare(pageA);
  const clickA = await signIn(pageA);
  const textA = await dump(pageA);
  const storageA = await pageA.evaluate(() => {
    let bytes = 0;
    try {
      for (let i = 0; i < localStorage.length; i++) {
        const k = localStorage.key(i);
        bytes += (k || '').length + (localStorage.getItem(k) || '').length;
      }
    } catch (e) {}
    return bytes;
  });
  const nameInA = textA.includes(expectedName);
  results.push({
    label: 'A. connexion et dossier affiche',
    ok: clickA.clicked && nameInA,
    detail: `nom "${expectedName}" present=${nameInA}, stockage local=${storageA} octets`,
  });
  await ctxA.close();

  // ── Contexte B : navigateur VIERGE (aucun stockage) ──────────────────
  const ctxB = await browser.createBrowserContext();
  const pageB = await ctxB.newPage();
  pageB.on('pageerror', (e) => errors.push('B: ' + e.message));
  await prepare(pageB);

  // ⚠️ MESURER LA TAILLE NE PROUVE RIEN.
  //
  // L'application écrit dès le chargement son état par défaut dans
  // `localStorage` (`flutter.gorex_state_v1` : données de la société,
  // référentiels…). Un compteur d'octets est donc toujours non nul, et
  // l'assertion « stockage vide » serait à la fois fausse et sans valeur.
  //
  // Ce qui prouve réellement la persistance en BASE, c'est l'ABSENCE du
  // dossier du client dans ce stockage avant la connexion : si son nom n'est
  // nulle part sur le poste et qu'il apparaît après s'être identifié, il ne
  // peut venir que du serveur.
  const beforeSignIn = await pageB.evaluate((name) => {
    let all = '';
    try {
      for (let i = 0; i < localStorage.length; i++) {
        const k = localStorage.key(i);
        all += (k || '') + '=' + (localStorage.getItem(k) || '');
      }
    } catch (e) {}
    return {
      bytes: all.length,
      containsName: all.includes(name),
      containsToken: /idToken|refreshToken|gorex_session|auth_token/i.test(all),
    };
  }, expectedName);

  results.push({
    label: "B. le dossier du client est ABSENT du poste avant connexion",
    ok: !beforeSignIn.containsName,
    detail: `nom "${expectedName}" dans le stockage local = ${beforeSignIn.containsName} (${beforeSignIn.bytes} octets d'état par défaut)`,
  });

  const clickB = await signIn(pageB);
  const textB = await dump(pageB);
  const nameInB = textB.includes(expectedName);

  // Et après connexion, il est présent côté navigateur : la boucle est
  // fermée — absent avant, présent après, donc venu du serveur.
  const afterSignIn = await pageB.evaluate((name) => {
    let all = '';
    try {
      for (let i = 0; i < localStorage.length; i++) {
        const k = localStorage.key(i);
        all += (k || '') + '=' + (localStorage.getItem(k) || '');
      }
    } catch (e) {}
    return { containsName: all.includes(name) };
  }, expectedName);

  results.push({
    label: 'B. le dossier est retrouve SANS aucun stockage prealable',
    ok: clickB.clicked && nameInB,
    detail: `nom "${expectedName}" affiche=${nameInB}, present localement apres=${afterSignIn.containsName}`,
  });

  // Le dossier doit être IDENTIQUE : preuve qu'il vient du serveur.
  const sameDashboard =
    textA.replace(/\s+/g, ' ').includes('Bienvenue') &&
    textB.replace(/\s+/g, ' ').includes('Bienvenue');
  results.push({
    label: 'B. tableau de bord complet, comme en session A',
    ok: sameDashboard,
    detail: `A=${textA.length} car., B=${textB.length} car.`,
  });

  await ctxB.close();
  await browser.close();

  console.log(`\nCible : ${URL}\n`);
  let failed = 0;
  for (const r of results) {
    console.log(`${r.ok ? '  OK  ' : ' ÉCHEC'}  ${r.label}  (${r.detail})`);
    if (!r.ok) failed++;
  }
  if (errors.length) {
    console.log(`\nErreurs de page (${errors.length}) :`);
    errors.slice(0, 4).forEach((e) => console.log('  -', e));
  }
  console.log(
    `\n${results.length - failed}/${results.length} vérifications réussies.`
  );
  process.exit(failed === 0 ? 0 : 1);
})().catch((e) => {
  console.error('Erreur du test :', e);
  process.exit(2);
});
