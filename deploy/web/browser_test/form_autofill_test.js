// GOREX LUXURY CONCIERGE — Le formulaire est-il utilisable par un gestionnaire
// de mots de passe ? Ce test mesure les ATTRIBUTS RÉELS du DOM, pas les bonnes
// intentions du code Dart.
//
// Il couvre DEUX écrans, parce que le second a révélé une régression que le
// premier ne pouvait pas voir :
//
//  1. Écran de connexion : 1 champ identifiant + 1 champ mot de passe.
//     Attendu : username / current-password.
//
//  2. Écran de changement obligatoire : 1 temporaire + 1 nouveau + 1 confirmation.
//     Attendu : current-password, puis new-password deux fois, et surtout des
//     `name`/`id` TOUS DIFFÉRENTS. La première version du script marquait les
//     trois en current-password avec le même nom : le gestionnaire aurait
//     écrasé deux champs sur trois et n'aurait plus proposé de génération.
//
// Usage :
//   node form_autofill_test.js                    # fixtures locales
//   node form_autofill_test.js https://…          # production (connexion seule)
//   GOREX_AUTOFILL_JS=/chemin.js node form_autofill_test.js   # autre source

const fs = require('fs');
const path = require('path');
const http = require('http');

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
      /* suivant */
    }
  }
  throw new Error(
    'puppeteer-core introuvable. Installez-le ou définissez GOREX_PUPPETEER_DIR.',
  );
}

const SCRIPT_SRC =
  process.env.GOREX_AUTOFILL_JS ||
  path.resolve(__dirname, '..', '..', '..', 'web', 'form-autofill.js');

// Reproduit EXACTEMENT ce que Flutter web produit : des input sans name ni id,
// avec autocomplete="off", et aucun <form>.
const LOGIN = `<!doctype html><html><head><meta charset="utf-8"></head><body>
<flutter-view>
  <input type="email" autocomplete="off" aria-label="ADRESSE E-MAIL">
  <input type="password" autocomplete="off" aria-label="MOT DE PASSE">
</flutter-view>
<script src="/form-autofill.js"></script>
</body></html>`;

const CHANGE = `<!doctype html><html><head><meta charset="utf-8"></head><body>
<flutter-view>
  <input type="password" autocomplete="off" aria-label="Mot de passe temporaire">
  <input type="password" autocomplete="off" aria-label="Nouveau mot de passe">
  <input type="password" autocomplete="off" aria-label="Confirmer le mot de passe">
</flutter-view>
<script src="/form-autofill.js"></script>
</body></html>`;

function serve() {
  return new Promise((resolve) => {
    const server = http.createServer((req, res) => {
      if (req.url.startsWith('/form-autofill.js')) {
        res.writeHead(200, { 'Content-Type': 'application/javascript' });
        res.end(fs.readFileSync(SCRIPT_SRC, 'utf8'));
        return;
      }
      const html = req.url.startsWith('/change') ? CHANGE : LOGIN;
      res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
      res.end(html);
    });
    server.listen(0, '127.0.0.1', () => resolve(server));
  });
}

const read = (page) =>
  page.evaluate(() =>
    [...document.querySelectorAll('input')].map((el) => ({
      type: el.type,
      name: el.getAttribute('name') || '',
      id: el.getAttribute('id') || '',
      autocomplete: (el.getAttribute('autocomplete') || '').toLowerCase(),
      label: el.getAttribute('aria-label') || '',
    })),
  );

function report(title, checks) {
  let pass = 0;
  console.log(`\n=== ${title} ===`);
  for (const [name, ok] of checks) {
    if (ok) pass++;
    console.log(`  ${ok ? '✓' : '✗'} ${name}`);
  }
  console.log(`  ${pass}/${checks.length}`);
  return { pass, total: checks.length };
}

(async () => {
  const puppeteer = loadPuppeteer();
  const target = process.argv[2];
  let server = null;
  let base = target;

  if (!target) {
    if (!fs.existsSync(SCRIPT_SRC)) {
      console.error(`✗ script introuvable : ${SCRIPT_SRC}`);
      process.exit(2);
    }
    server = await serve();
    base = `http://127.0.0.1:${server.address().port}/`;
  }

  const browser = await puppeteer.launch({
    executablePath: '/usr/bin/google-chrome',
    headless: 'new',
    args: ['--no-sandbox', '--disable-gpu', '--disable-dev-shm-usage'],
    defaultViewport: { width: 430, height: 932 },
  });

  const totals = { pass: 0, total: 0 };

  // ── 1. Écran de connexion ──────────────────────────────────────────────
  {
    const page = await browser.newPage();
    const errors = [];
    page.on('pageerror', (e) => errors.push(e.message));
    await page.goto(base, { waitUntil: 'networkidle2', timeout: 90000 });
    await new Promise((r) => setTimeout(r, target ? 11000 : 600));
    if (target) {
      await page.evaluate(() => {
        const ph = document.querySelector('flt-semantics-placeholder');
        if (ph) ph.click();
      });
      await new Promise((r) => setTimeout(r, 2500));
    }

    const state = await read(page);
    console.log('=== ATTRIBUTS RÉELS (connexion) ===');
    state.forEach((s, i) =>
      console.log(
        `  [${i}] type=${s.type} name="${s.name}" id="${s.id}" autocomplete="${s.autocomplete}"`,
      ),
    );
    const email = state.find((s) => s.type === 'email');
    const pwd = state.find((s) => s.type === 'password');
    const r = report('CONNEXION', [
      ['champ identifiant présent', !!email],
      ['champ mot de passe présent', !!pwd],
      ['identifiant → autocomplete="username"', !!email && email.autocomplete === 'username'],
      ['identifiant → name non vide', !!email && email.name.length > 0],
      ['identifiant → id non vide', !!email && email.id.length > 0],
      ['mot de passe → autocomplete="current-password"', !!pwd && pwd.autocomplete === 'current-password'],
      ['mot de passe → name non vide', !!pwd && pwd.name.length > 0],
      ['mot de passe → id non vide', !!pwd && pwd.id.length > 0],
      ['les deux noms DIFFÈRENT', !!email && !!pwd && email.name !== pwd.name],
      ['plus aucun autocomplete="off"', !state.some((s) => !s.autocomplete)],
      ['aucune exception JavaScript', errors.length === 0],
    ]);
    totals.pass += r.pass;
    totals.total += r.total;
    if (errors.length) [...new Set(errors)].forEach((e) => console.log('  ! ' + e));
    await page.close();
  }

  // ── 2. Écran de changement obligatoire (fixtures locales seulement) ────
  if (!target) {
    const page = await browser.newPage();
    const errors = [];
    page.on('pageerror', (e) => errors.push(e.message));
    await page.goto(base + 'change', { waitUntil: 'networkidle2', timeout: 30000 });
    await new Promise((r) => setTimeout(r, 900));

    const state = await read(page);
    console.log('\n=== ATTRIBUTS RÉELS (changement obligatoire) ===');
    state.forEach((s, i) =>
      console.log(
        `  [${i}] label="${s.label}" name="${s.name}" id="${s.id}" autocomplete="${s.autocomplete}"`,
      ),
    );

    const names = state.map((s) => s.name);
    const ids = state.map((s) => s.id);
    const r = report('CHANGEMENT OBLIGATOIRE', [
      ['3 champs de mot de passe', state.length === 3],
      ['champ temporaire → current-password', state[0] && state[0].autocomplete === 'current-password'],
      ['champ nouveau → new-password', state[1] && state[1].autocomplete === 'new-password'],
      ['champ confirmation → new-password', state[2] && state[2].autocomplete === 'new-password'],
      ['les 3 noms sont DIFFÉRENTS', new Set(names).size === 3 && names.every((n) => n)],
      ['les 3 id sont DIFFÉRENTS', new Set(ids).size === 3 && ids.every((n) => n)],
      ['aucun autocomplete="off" restant', !state.some((s) => !s.autocomplete)],
      ['aucune exception JavaScript', errors.length === 0],
    ]);
    totals.pass += r.pass;
    totals.total += r.total;
    if (errors.length) [...new Set(errors)].forEach((e) => console.log('  ! ' + e));
    await page.close();
  }

  await browser.close();
  if (server) server.close();

  console.log(`\nTOTAL : ${totals.pass}/${totals.total}`);
  process.exit(totals.pass === totals.total ? 0 : 1);
})().catch((e) => {
  console.error('ECHEC SCRIPT :', e.message);
  process.exit(3);
});
