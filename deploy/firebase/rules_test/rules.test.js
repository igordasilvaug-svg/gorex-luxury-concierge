// Tests de comportement des règles Firestore — ÉMULATEUR OFFICIEL.
// La permission IAM `firebaserules.rulesets.test` est absente du compte de
// service ; l'émulateur exécute donc les VRAIES règles, localement, sans
// aucune simulation de ma part.
//
// PRÉREQUIS (une seule fois) :
//     cd deploy/firebase/rules_test && npm install
//
// EXÉCUTION (deux terminaux) :
//     npm run emulator      # laisse tourner
//     npm test              # dans un autre terminal
//
// Le fichier de règles testé est CELUI QUI EST VERSIONNÉ, puis publié :
//     deploy/firebase/firestore.rules
const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const {
  doc, getDoc, setDoc, updateDoc,
} = require('firebase/firestore');

// Chemin relatif : le test vit dans deploy/firebase/rules_test/, les règles
// dans deploy/firebase/. Le chemin absolu d'origine rendait le test
// inutilisable hors de la machine qui l'avait écrit.
const RULES_PATH = path.join(__dirname, '..', 'firestore.rules');
const RULES = fs.readFileSync(RULES_PATH, 'utf8');

const CLIENT_UID = 'cli1';
const CLIENT_EMAIL = 'diag.client@example.com';

const tok = (email) => ({
  email,
  email_verified: true,
  firebase: { sign_in_provider: 'password' },
});

let testEnv;

const seedProfiles = async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const people = [
      ['cli1', 'vipClient', 'gx-cli-1', CLIENT_EMAIL],
      ['ceo1', 'ceo', '', 'ceo@gorex-group.eu'],
      ['mgr1', 'conciergeManager', '', 'mgr@gorex-group.eu'],
      ['sen1', 'seniorConcierge', '', 'sen@gorex-group.eu'],
      ['conc1', 'concierge', '', 'conc@gorex-group.eu'],
      ['fin1', 'finance', '', 'fin@gorex-group.eu'],
    ];
    for (const [uid, role, clientId, email] of people) {
      await setDoc(doc(db, 'user_profiles', uid), {
        id: uid, role, clientId, email, fullName: uid,
      });
    }
    // Fiche client déjà en base (pending) pour les tests de mise à jour.
    await setDoc(doc(db, 'clients', 'gx-cli-1'), {
      id: 'gx-cli-1',
      code: 'GX-CLI-1',
      fullName: 'Diag Client',
      email: CLIENT_EMAIL,
      phone: '+32000000000',
      language: 'fr',
      approvalStatus: 'pending',
      active: true,
    });
  });
};

const baseClient = () => ({
  code: 'GX-CLI-2',
  fullName: 'Nouveau Client',
  email: CLIENT_EMAIL,
  phone: '+32470000000',
  language: 'fr',
  approvalStatus: 'pending',
  active: true,
});

const results = [];
const check = async (label, fn, expect) => {
  let ok = false;
  let detail = '';
  try {
    if (expect === 'ALLOW') {
      await assertSucceeds(fn());
      ok = true;
    } else {
      await assertFails(fn());
      ok = true;
    }
  } catch (e) {
    detail = String(e.message || e).split('\n')[0].slice(0, 160);
  }
  results.push({ label, expect, ok, detail });
  console.log(
    `${ok ? 'PASS' : 'FAIL'}  ${label.padEnd(52)} attendu=${expect}` +
      (ok ? '' : `  -> ${detail}`),
  );
};

(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'gorex-concierge-lab',
    firestore: { rules: RULES, host: '127.0.0.1', port: 8080 },
  });

  // ── 1 & 2 : inscription ────────────────────────────────────────────────
  await seedProfiles();
  const client = testEnv.authenticatedContext(CLIENT_UID, tok(CLIENT_EMAIL)).firestore();

  await check(
    '1. client s inscrit en pending',
    () => setDoc(doc(client, 'clients', 'new1'), baseClient()),
    'ALLOW',
  );

  await check(
    '2. client s inscrit deja approved',
    () => setDoc(doc(client, 'clients', 'new2'),
      { ...baseClient(), approvalStatus: 'approved' }),
    'DENY',
  );

  // ── 3 & 4 : la fiche existante (pending, liée à son email) ─────────────
  await check(
    '3. client s auto-valide apres coup',
    () => updateDoc(doc(client, 'clients', 'gx-cli-1'), { approvalStatus: 'approved' }),
    'DENY',
  );

  await check(
    '4. client modifie son telephone',
    () => updateDoc(doc(client, 'clients', 'gx-cli-1'), { phone: '+32471111111' }),
    'ALLOW',
  );

  await check(
    '4b. client tente d activer son compte',
    () => updateDoc(doc(client, 'clients', 'gx-cli-1'), { active: true, approvalStatus: 'approved' }),
    'DENY',
  );

  await check(
    '4c. client change son palier d abonnement',
    () => updateDoc(doc(client, 'clients', 'gx-cli-1'), { subscriptionTierId: 'tier-ceo' }),
    'DENY',
  );

  // ── 5, 6, 7 : décision d'accès par le personnel ────────────────────────
  // Chaque approbateur travaille sur une fiche DISTINCTE et encore en
  // attente : sinon la 2e écriture serait un no-op (aucune clé modifiée),
  // ce qui fausserait le test en la faisant passer pour autorisée.
  const approve = async (uid, expect, label, target) => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'clients', target), {
        id: target, code: 'GX-' + target, fullName: 'En attente',
        email: 'attente@example.com', phone: '+32000',
        language: 'fr', approvalStatus: 'pending', active: true,
      });
    });
    const db = testEnv.authenticatedContext(uid, tok(uid)).firestore();
    await check(label, () => updateDoc(doc(db, 'clients', target),
      { approvalStatus: 'approved' }), expect);
  };

  await approve('conc1', 'DENY', '5. concierge simple valide le dossier', 'ap5');
  await approve('mgr1', 'ALLOW', '6. concierge manager valide le dossier', 'ap6');
  await approve('sen1', 'ALLOW', '7. senior concierge valide le dossier', 'ap7');
  await approve('ceo1', 'ALLOW', '7b. CEO valide le dossier', 'ap7b');
  await approve('fin1', 'DENY', '7c. finance valide le dossier (hors role)', 'ap7c');

  // ── 8 : cloisonnement entre clients ────────────────────────────────────
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'clients', 'other9'), {
      id: 'other9', code: 'GX-OTHER', fullName: 'Autre',
      email: 'autre@example.com', phone: '+32000',
      language: 'fr', approvalStatus: 'approved', active: true,
    });
  });

  await check(
    '8. client lit la fiche d un autre client',
    () => getDoc(doc(client, 'clients', 'other9')),
    'DENY',
  );

  await check(
    '8b. client lit sa propre fiche',
    () => getDoc(doc(client, 'clients', 'gx-cli-1')),
    'ALLOW',
  );

  // ── 9 : un client ne peut pas s'octroyer un rôle ───────────────────────
  await check(
    '9. client s ecrit role=ceo dans son profil',
    () => updateDoc(doc(client, 'user_profiles', CLIENT_UID), { role: 'ceo' }),
    'DENY',
  );

  // ── 10 : demandes de service ───────────────────────────────────────────
  // Identifiants UNIQUES : l'émulateur conserve les données entre deux
  // exécutions, et un setDoc sur un document existant devient une MISE À JOUR
  // (refusée pour un client) — ce qui ferait échouer le test pour une raison
  // étrangère aux règles.
  const RUN = Date.now().toString(36);

  await check(
    '10. client PENDING cree une demande -> bloque',
    () => setDoc(doc(client, 'requests', 'r1-' + RUN), {
      id: 'r1-' + RUN, clientEmail: CLIENT_EMAIL, title: 'Test', status: 'new',
    }),
    'DENY',
  );

  await check(
    '11. client cree une demande au nom d autrui',
    () => setDoc(doc(client, 'requests', 'r2-' + RUN), {
      id: 'r2-' + RUN, clientEmail: 'autre@example.com', title: 'Usurpation', status: 'new',
    }),
    'DENY',
  );

  // ── 14 : un client NON validé ne peut pas consommer de service ─────────
  // Le profil du client pointe vers gx-cli-1, qui est encore 'pending'.
  const RUN2 = Date.now().toString(36);

  await check(
    '14. client PENDING cree une demande (doit etre bloque)',
    () => setDoc(doc(client, 'requests', 'p-' + RUN2), {
      id: 'p-' + RUN2, clientEmail: CLIENT_EMAIL, title: 'Trop tot', status: 'new',
    }),
    'DENY',
  );

  await check(
    '15. client PENDING cree une reservation (doit etre bloque)',
    () => setDoc(doc(client, 'bookings', 'b-' + RUN2), {
      id: 'b-' + RUN2, clientId: 'gx-cli-1', title: 'Trop tot',
    }),
    'DENY',
  );

  // Validation par le manager, puis NOUVEAU contexte : le jeton a pu etre
  // emis avant la validation, la regle doit lire la BASE et non le jeton.
  const mgr2 = testEnv.authenticatedContext('mgr1', tok('mgr1')).firestore();
  await updateDoc(doc(mgr2, 'clients', 'gx-cli-1'), { approvalStatus: 'approved' });

  await check(
    '16. client VALIDE cree une demande (doit passer)',
    () => setDoc(doc(client, 'requests', 'q-' + RUN2), {
      id: 'q-' + RUN2, clientEmail: CLIENT_EMAIL, title: 'Ok', status: 'new',
    }),
    'ALLOW',
  );

  await check(
    '17. client VALIDE cree une reservation (doit passer)',
    () => setDoc(doc(client, 'bookings', 'c-' + RUN2), {
      id: 'c-' + RUN2, clientId: 'gx-cli-1', title: 'Ok',
    }),
    'ALLOW',
  );

  // Suspension : l'acces doit se refermer immediatement.
  await updateDoc(doc(mgr2, 'clients', 'gx-cli-1'), { active: false });

  await check(
    '18. client SUSPENDU ne cree plus de demande',
    () => setDoc(doc(client, 'requests', 'r-' + RUN2), {
      id: 'r-' + RUN2, clientEmail: CLIENT_EMAIL, title: 'Suspendu', status: 'new',
    }),
    'DENY',
  );

  // ── 12 : non authentifié ───────────────────────────────────────────────
  const anon = testEnv.unauthenticatedContext().firestore();
  await check(
    '12. anonyme lit une fiche client',
    () => getDoc(doc(anon, 'clients', 'gx-cli-1')),
    'DENY',
  );

  await check(
    '13. anonyme liste les clients',
    () => getDoc(doc(anon, 'clients', 'new1')),
    'DENY',
  );

  // ── 19 à 21 : qui peut CRÉER une fiche déjà validée ? ────────────────────
  // Défaut corrigé : `isStaff()` autorisait n'importe quel rôle métier à créer
  // une fiche APPROVED, donc à ouvrir un accès complet en une seule écriture.
  const staffClient = (extra = {}) => ({
    code: 'GRX-VIP-0500',
    fullName: 'Fiche montée par le personnel',
    email: 'monte@example.com',
    phone: '+32470000500',
    language: 'fr',
    approvalStatus: 'approved',
    active: true,
    ...extra,
  });

  const conc = testEnv.authenticatedContext('conc1', tok('conc@gorex-group.eu')).firestore();

  await check(
    '19. concierge cree une fiche DEJA validee',
    () => setDoc(doc(conc, 'clients', 'byconc1-' + RUN2), staffClient()),
    'DENY',
  );

  await check(
    '20. concierge cree une fiche EN ATTENTE',
    () => setDoc(doc(conc, 'clients', 'byconc2-' + RUN2),
      staffClient({ approvalStatus: 'pending' })),
    'ALLOW',
  );

  await check(
    '21. senior cree une fiche DEJA validee',
    () => setDoc(doc(testEnv.authenticatedContext('sen1', tok('sen@gorex-group.eu'))
      .firestore(), 'clients', 'bysen1-' + RUN2), staffClient()),
    'ALLOW',
  );

  // ── 22 à 24 : réservation des numéros de dossier ────────────────────────
  // Le numéro définitif est réservé par CRÉATION d'un document
  // `client_codes/<numéro>` avec la précondition « n'existe pas ». Seul
  // l'encadrement peut le faire ; un client ne doit pas pouvoir saturer la
  // numérotation.
  const codeBody = (c) => ({ code: c, clientId: 'x', claimedAt: '2026-01-01T00:00:00Z' });

  await check(
    '22. client reserve un numero de dossier',
    () => setDoc(doc(client, 'client_codes', 'GRX-VIP-9001'), codeBody('GRX-VIP-9001')),
    'DENY',
  );

  await check(
    '23. concierge simple reserve un numero',
    () => setDoc(doc(conc, 'client_codes', 'GRX-VIP-9002'), codeBody('GRX-VIP-9002')),
    'DENY',
  );

  await check(
    '24. senior reserve un numero',
    () => setDoc(doc(testEnv.authenticatedContext('sen1', tok('sen@gorex-group.eu'))
      .firestore(), 'client_codes', 'GRX-VIP-9003-' + RUN2),
    codeBody('GRX-VIP-9003-' + RUN2)),
    'ALLOW',
  );

  await check(
    '25. reecriture d un numero deja reserve',
    async () => {
      const db = testEnv.authenticatedContext('sen1', tok('sen@gorex-group.eu')).firestore();
      const p = 'GRX-VIP-9004-' + RUN2;
      await setDoc(doc(db, 'client_codes', p), codeBody(p));
      await setDoc(doc(db, 'client_codes', p), codeBody(p));
    },
    'DENY',
  );

  await testEnv.cleanup();

  const ko = results.filter((r) => !r.ok);
  console.log('\n' + '='.repeat(70));
  console.log(`${results.length - ko.length}/${results.length} tests passés`);
  if (ko.length) {
    console.log('ÉCHECS :');
    ko.forEach((r) => console.log('  -', r.label, '->', r.detail));
  }
  process.exit(ko.length ? 2 : 0);
})().catch((e) => {
  console.error('ERREUR FATALE:', e);
  process.exit(1);
});
