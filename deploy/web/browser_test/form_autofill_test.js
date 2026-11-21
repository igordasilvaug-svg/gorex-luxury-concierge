// GOREX LUXURY CONCIERGE — Le formulaire est-il utilisable par un gestionnaire
// de mots de passe ? Ce test mesure les ATTRIBUTS RÉELS du DOM, pas les bonnes
// intentions du code Dart.
//
// Il échoue sur la version d'avant la correction (« autocomplete="off" »,
// aucun name, aucun id) et passe après.
//
// Usage :
//   node form_autofill_test.js                    # fixture locale
//   node form_autofill_test.js https://…          # production
//   GOREX_AUTOFILL_JS=/chemin.js node form_autofill_test.js   # autre source

const fs = require('fs');
const path = require('path');
const http = require('http');
const os = require('os');

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

// Fixture : reproduit EXACTEMENT ce que Flutter web produit — deux input sans
// name ni id, avec autocomplete="off", et aucun <form>.
const FIXTURE = `<!doctype html><html><head><meta charset="utf-8"></head><body>
<flutter-view>
  <input type="email" autocomplete="off" aria-label="ADRESSE E-MAIL">
  <input type="password" autocomplete="off" aria-label="MOT DE PASSE">
</flutter-view>
<script src="/form-autofill.js"></script>
</body></html>`;

function serve(tmpDir) {
  return new Promise((resolve) => {
    const server = http.createServer((req, res) => {
      if (req.url.startsWith('/form-autofill.js')) {
        res.writeHead(200, { 'Content-Type': 'application/javascript' });
        res.end(fs.readFileSync(SCRIPT_SRC, 'utf8'));
        return;
      }
      res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
      res.end(FIXTURE);
    });
    server.listen(0, '127.0.0.1', () => resolve(server));
  });
}

(async () => {
  const puppeteer = loadPuppeteer();
  const target = process.argv[2];
  let server = null;
  let url = target;

  if (!target) {
    if (!fs.existsSync(SCRIPT_SRC)) {
      console.error(`✗ script introuvable : ${SCRIPT_SRC}`);
      process.exit(2);
    }
    server = await serve(os.tmpdir());
    url = `http://127.0.0.1:${server.address().port}/`;
  }

  const browser = await puppeteer.launch({
    executablePath: '/usr/bin/google-chrome',
    headless: 'new',
    args: ['--no-sandbox', '--disable-gpu', '--disable-dev-shm-usage'],
    defaultViewport: { width: 430, height: 932 },
  });
  const page = await browser.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));

  // Sur la production, il faut activer la sémantique pour que Flutter crée les
  // champs d'édition réels dans le DOM.
  await page.goto(url, { waitUntil: 'networkidle2', timeout: 90000 });
  const waitMs = target ? 11000 : 600;
  await new Promise((r) => setTimeout(r, waitMs));
  if (target) {
    await page.evaluate(() => {
      const ph = document.querySelector('flt-semantics-placeholder');
      if (ph) ph.click();
    });
    await new Promise((r) => setTimeout(r, 2500));
  }

  const state = await page.evaluate(() =>
    [...document.querySelectorAll('input')].map((el) => ({
      type: el.type,
      name: el.getAttribute('name') || '',
      id: el.getAttribute('id') || '',
      autocomplete: (el.getAttribute('autocomplete') || '').toLowerCase(),
      marker: el.getAttribute('data-gorex-autofill') || '',
    })),
  );

  await browser.close();
  if (server) server.close();

  console.log('=== ATTRIBUTS RÉELS DU DOM ===');
  state.forEach((s, i) =>
    console.log(
      `  [${i}] type=${s.type} name="${s.name}" id="${s.id}" autocomplete="${s.autocomplete}" marqueur=${s.marker || '-'}`,
    ),
  );

  const byType = (t) => state.find((s) => s.type === t);
  const email = byType('email');
  const pwd = byType('password');

  const checks = [
    ['le champ identifiant existe', !!email],
    ['le champ mot de passe existe', !!pwd],
    ['identifiant : autocomplete="username"', !!email && email.autocomplete === 'username'],
    ['identifiant : name non vide', !!email && email.name.length > 0],
    ['identifiant : id non vide', !!email && email.id.length > 0],
    ['mot de passe : autocomplete="current-password"', !!pwd && pwd.autocomplete === 'current-password'],
    ['mot de passe : name non vide', !!pwd && pwd.name.length > 0],
    ['mot de passe : id non vide', !!pwd && pwd.id.length > 0],
    ['les deux champs ont des noms DIFFÉRENTS', !!email && !!pwd && email.name !== pwd.name],
    [
      'plus aucun autocomplete="off"',
      !state.some((s) => s.autocomplete === 'off' || s.autocomplete === ''),
    ],
    ['aucune exception JavaScript', errors.length === 0],
  ];

  let pass = 0;
  console.log('\n=== VÉRIFICATIONS ===');
  for (const [name, ok] of checks) {
    if (ok) pass++;
    console.log(`  ${ok ? '✓' : '✗'} ${name}`);
  }
  console.log(`\n  ${pass}/${checks.length}`);

  if (errors.length) {
    console.log('\n=== ERREURS JAVASCRIPT ===');
    [...new Set(errors)].forEach((e) => console.log('  - ' + e));
  }

  process.exit(pass === checks.length ? 0 : 1);
})().catch((e) => {
  console.error('ECHEC SCRIPT :', e.message);
  process.exit(3);
});
