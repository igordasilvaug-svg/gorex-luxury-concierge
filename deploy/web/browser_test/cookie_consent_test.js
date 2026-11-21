/**
 * Test navigateur du bandeau de consentement (web/cookie-consent.js).
 *
 * POURQUOI CE TEST EXISTE
 * -----------------------
 * Une régression a vécu en production sans être vue : `setReserved()` émettait
 * un événement `resize`, et l'écouteur `resize` rappelait `setReserved()`.
 * `dispatchEvent` étant synchrone, la récursion n'arrêtait qu'à l'explosion de
 * la pile. Chaque visiteur recevait donc :
 *
 *     Uncaught RangeError: Maximum call stack size exceeded.
 *
 * Aucun test ne le voyait : `flutter analyze` ne lit pas du JavaScript, et le
 * défaut ne se manifeste que dans un vrai moteur de rendu, avec une vraie
 * `flutter-view`.
 *
 * CE QUE LE TEST VÉRIFIE
 * ----------------------
 *   1. aucune exception de page n'est levée ;
 *   2. l'espace réservé correspond réellement à la hauteur de la bannière
 *      (sinon la bannière recouvre le bas des écrans — régression antérieure) ;
 *   3. le nombre d'événements `resize` émis reste faible et borné (un déluge
 *      signale la récursion même si l'exception est rattrapée un jour) ;
 *   4. un clic sur un bouton libère l'espace et enregistre le choix.
 *
 * USAGE
 *   node deploy/web/browser_test/cookie_consent_test.js [url]
 *   (sans argument : teste la copie locale web/cookie-consent.js)
 *
 * Prérequis : puppeteer-core et un Chrome installé
 *   cd /tmp/uitest && npm install puppeteer-core
 */
const path = require('path');
const fs = require('fs');
const os = require('os');
// `puppeteer-core` n'est pas une dépendance du projet Flutter : il peut vivre
// dans un dossier de travail séparé. On le cherche donc à plusieurs endroits
// au lieu d'imposer un `cd` particulier avant de lancer le test.
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
    } catch (e) {
      /* on essaie le suivant */
    }
  }
  console.error(
    'puppeteer-core introuvable. Installez-le, par exemple :\n' +
      '  mkdir -p /tmp/uitest && cd /tmp/uitest && npm install puppeteer-core\n' +
      'ou indiquez GOREX_PUPPETEER_DIR=/chemin/du/dossier.'
  );
  process.exit(2);
}
const puppeteer = loadPuppeteer();

const CHROME = process.env.CHROME_PATH || '/usr/bin/google-chrome';
const SOURCE = process.env.GOREX_COOKIE_JS
  ? path.resolve(process.env.GOREX_COOKIE_JS)
  : path.resolve(__dirname, '..', '..', '..', 'web', 'cookie-consent.js');
const TARGET_URL = process.argv[2] || null;

// Budgets. Le nombre de `resize` est le signal clé : la version défectueuse en
// produisait plusieurs dizaines en deux secondes.
const MAX_RESIZE = 5;
const MAX_PAGEERRORS = 0;

function buildFixture() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'gorex-cookie-'));
  fs.copyFileSync(SOURCE, path.join(dir, 'cookie-consent.js'));
  // Une `flutter-view` factice reproduit la condition réelle : le script
  // attend que Flutter ait monté sa vue avant de mesurer la bannière.
  fs.writeFileSync(
    path.join(dir, 'index.html'),
    '<!doctype html><html lang="fr"><head><meta charset="utf-8"></head><body>' +
      '<script>' +
      "var fv=document.createElement('flutter-view');" +
      "fv.style.cssText='position:fixed;inset:0;height:200px';" +
      'document.body.appendChild(fv);' +
      '</script>' +
      '<script src="cookie-consent.js" defer></script>' +
      '</body></html>'
  );
  return dir;
}

(async () => {
  let url = TARGET_URL;
  let fixtureDir = null;
  if (!url) {
    if (!fs.existsSync(SOURCE)) {
      console.error('Fichier introuvable : ' + SOURCE);
      process.exit(2);
    }
    fixtureDir = buildFixture();
    url = 'file://' + path.join(fixtureDir, 'index.html');
  }

  const browser = await puppeteer.launch({
    executablePath: CHROME,
    headless: 'new',
    args: ['--no-sandbox', '--disable-gpu', '--disable-dev-shm-usage'],
    defaultViewport: { width: 430, height: 932 },
  });
  const page = await browser.newPage();

  const pageErrors = [];
  page.on('pageerror', (e) => pageErrors.push(e.message));

  // Compteur indépendant : même si le script rattrapait ses propres erreurs,
  // un déluge de `resize` resterait visible ici.
  await page.evaluateOnNewDocument(() => {
    window.__resizeCount = 0;
    window.addEventListener('resize', () => {
      window.__resizeCount++;
    });
  });

  await page.goto(url, { waitUntil: 'load', timeout: 90000 });
  await new Promise((r) => setTimeout(r, 2500));

  const before = await page.evaluate(() => {
    const barEl = document.querySelector('[aria-label="Cookie consent"]');
    return {
      reserved: getComputedStyle(document.documentElement)
        .getPropertyValue('--gorex-cookie-h')
        .trim(),
      resizeCount: window.__resizeCount,
      barHeight: barEl ? Math.ceil(barEl.getBoundingClientRect().height) : 0,
      hasBar: !!barEl,
      stored: localStorage.getItem('gorex_cookie_consent_v1'),
    };
  });

  const buttons = await page.$$('button');
  if (buttons.length === 0) {
    console.error('ÉCHEC : aucun bouton de consentement rendu.');
    await browser.close();
    process.exit(1);
  }
  await buttons[0].click();
  await new Promise((r) => setTimeout(r, 700));

  const after = await page.evaluate(() => ({
    reserved: getComputedStyle(document.documentElement)
      .getPropertyValue('--gorex-cookie-h')
      .trim(),
    resizeCount: window.__resizeCount,
    barGone: !document.querySelector('[aria-label="Cookie consent"]'),
    stored: localStorage.getItem('gorex_cookie_consent_v1'),
  }));

  await browser.close();
  if (fixtureDir) fs.rmSync(fixtureDir, { recursive: true, force: true });

  // ── Assertions ─────────────────────────────────────────────────────────
  const checks = [];
  const check = (label, ok, detail) => checks.push({ label, ok, detail });

  check('aucune exception levée', pageErrors.length <= MAX_PAGEERRORS,
    pageErrors.length ? pageErrors.join(' | ') : 'aucune');

  check('la bannière est affichée', before.hasBar, `hauteur=${before.barHeight}px`);

  const reservedPx = parseInt(before.reserved, 10) || 0;
  check('espace réservé = hauteur de la bannière',
    before.hasBar && reservedPx === before.barHeight,
    `réservé=${reservedPx}px, bannière=${before.barHeight}px`);

  check('aucune récursion de resize', before.resizeCount <= MAX_RESIZE,
    `${before.resizeCount} événement(s), plafond ${MAX_RESIZE}`);

  check('choix non enregistré avant le clic', before.stored === null,
    String(before.stored));

  check('le clic enregistre le choix', !!after.stored, String(after.stored));

  check('le clic libère l\'espace réservé', after.reserved === '0px',
    `réservé=${after.reserved}`);

  check('la bannière est retirée', after.barGone, String(after.barGone));

  let failed = 0;
  console.log(`\nCible : ${TARGET_URL ? TARGET_URL : 'copie locale ' + SOURCE}\n`);
  for (const c of checks) {
    console.log(`${c.ok ? '  OK  ' : ' ÉCHEC'}  ${c.label}  (${c.detail})`);
    if (!c.ok) failed++;
  }
  console.log(`\n${checks.length - failed}/${checks.length} vérifications réussies.`);
  process.exit(failed === 0 ? 0 : 1);
})().catch((e) => {
  console.error('Erreur du test :', e);
  process.exit(2);
});
