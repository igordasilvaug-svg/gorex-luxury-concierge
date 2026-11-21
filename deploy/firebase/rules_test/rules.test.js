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
  doc, getDoc, setDoc, updateDoc, deleteDoc,
} = require('firebase/firestore');

// Chemin relatif : le test vit dans deploy/firebase/rules_test/, les règles
// dans deploy/firebase/. Le chemin absolu d'origine rendait le test
// inutilisable hors de la machine qui l'avait écrit.
//
// `GOREX_RULES_PATH` permet de désigner explicitement le fichier testé :
// l'émulateur refuse un fichier de règles hors de son dossier projet, donc le
// lanceur `run_rules_tests.sh` copie les règles à côté de l'émulateur et
// indique ici la copie. Sans cette variable, la copie divergerait du fichier
// versionné sans que personne ne s'en aperçoive.
const RULES_PATH = process.env.GOREX_RULES_PATH
  || path.join(__dirname, '..', 'firestore.rules');
const RULES = fs.readFileSync(RULES_PATH, 'utf8');
console.log(`Règles testées : ${RULES_PATH} (${RULES.split('\n').length} lignes)`);

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

  // ══════════════════════════════════════════════════════════════════════
  // 26 à 39 : ABONNEMENTS (CONTRATS)
  //
  // Ce qui est vérifié ici est le cœur du circuit commercial : un client doit
  // pouvoir DÉPOSER une demande, mais jamais se déclarer abonné, accepté ou
  // facturable. Une seule de ces barrières qui cède, et le client peut
  // s'auto-attribuer un contrat qu'il contestera ensuite.
  // ══════════════════════════════════════════════════════════════════════

  // Un client DISTINCT et réellement validé : `gx-cli-1` a été suspendu au
  // test 18, il ne peut donc plus rien créer (c'est voulu).
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'user_profiles', 'cli2'), {
      id: 'cli2', role: 'vipClient', clientId: 'gx-cli-2ok',
      email: 'abonne@example.com', fullName: 'Client Abonne',
    });
    await setDoc(doc(db, 'clients', 'gx-cli-2ok'), {
      id: 'gx-cli-2ok', code: 'GRX-VIP-0002', fullName: 'Client Abonne',
      email: 'abonne@example.com', phone: '+32470002222',
      language: 'fr', approvalStatus: 'approved', active: true,
    });
  });

  const cli2 = testEnv
    .authenticatedContext('cli2', tok('abonne@example.com'))
    .firestore();
  const fin2 = testEnv
    .authenticatedContext('fin1', tok('fin@gorex-group.eu'))
    .firestore();

  const subBody = (extra = {}) => ({
    id: 's1',
    clientId: 'gx-cli-2ok',
    clientEmail: 'abonne@example.com',
    tierId: 'tier_essential',
    tierName: 'GOREX ESSENTIAL',
    cycle: 'annual',
    amount: 4800,
    status: 'requested',
    requestedAt: '2026-01-01T00:00:00Z',
    ...extra,
  });

  await check(
    '26. client valide depose une demande d abonnement',
    () => setDoc(doc(cli2, 'subscriptions', 'sub-ok-' + RUN2), subBody()),
    'ALLOW',
  );

  await check(
    '27. client s ecrit lui-meme status=active',
    () => setDoc(doc(cli2, 'subscriptions', 'sub-active-' + RUN2),
      subBody({ status: 'active' })),
    'DENY',
  );

  await check(
    '28. client s invente une decision favorable',
    () => setDoc(doc(cli2, 'subscriptions', 'sub-dec-' + RUN2),
      subBody({ decidedBy: 'ceo@gorex-group.eu', decidedAt: '2026-01-01T00:00:00Z' })),
    'DENY',
  );

  await check(
    '29. client depose un abonnement pour un AUTRE dossier',
    () => setDoc(doc(cli2, 'subscriptions', 'sub-other-' + RUN2),
      subBody({ clientId: 'gx-cli-1' })),
    'DENY',
  );

  await check(
    '30. client lit son propre abonnement',
    () => getDoc(doc(cli2, 'subscriptions', 'sub-ok-' + RUN2)),
    'ALLOW',
  );

  // Un abonnement appartenant à un AUTRE dossier, écrit hors règles : c'est
  // la vraie situation de cloisonnement (et non un document inexistant, dont
  // le refus ne prouverait rien des règles de lecture).
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'subscriptions', 'sub-autre-' + RUN2),
      subBody({ id: 'sub-autre-' + RUN2, clientId: 'gx-cli-1',
        clientEmail: 'diag.client@example.com' }));
  });

  await check(
    '31. client lit l abonnement d un autre client',
    () => getDoc(doc(cli2, 'subscriptions', 'sub-autre-' + RUN2)),
    'DENY',
  );

  await check(
    '32. client passe son abonnement en actif apres coup',
    () => updateDoc(doc(cli2, 'subscriptions', 'sub-ok-' + RUN2), { status: 'active' }),
    'DENY',
  );

  await check(
    '33. client supprime son abonnement',
    () => deleteDoc(doc(cli2, 'subscriptions', 'sub-ok-' + RUN2)),
    'DENY',
  );

  await check(
    '34. finance decide d un abonnement (accepte)',
    () => updateDoc(doc(fin2, 'subscriptions', 'sub-ok-' + RUN2), {
      status: 'approved',
      decidedBy: 'fin@gorex-group.eu',
      decidedAt: '2026-01-02T00:00:00Z',
    }),
    'ALLOW',
  );

  await check(
    '35. finance active l abonnement',
    () => updateDoc(doc(fin2, 'subscriptions', 'sub-ok-' + RUN2), {
      status: 'active',
      activatedAt: '2026-01-03T00:00:00Z',
    }),
    'ALLOW',
  );

  await check(
    '36. senior concierge (approbateur) peut lire les abonnements',
    () => getDoc(doc(testEnv.authenticatedContext('sen1', tok('sen@gorex-group.eu'))
      .firestore(), 'subscriptions', 'sub-ok-' + RUN2)),
    'ALLOW',
  );

  // Le client `gx-cli-1` est suspendu : la règle de création exige
  // `isApprovedClient()`, donc elle doit refuser.
  await check(
    '37. client suspendu depose une demande d abonnement',
    () => setDoc(doc(client, 'subscriptions', 'sub-susp-' + RUN2),
      subBody({ clientId: 'gx-cli-1' })),
    'DENY',
  );

  await check(
    '38. anonyme lit un abonnement',
    () => getDoc(doc(anon, 'subscriptions', 'sub-ok-' + RUN2)),
    'DENY',
  );

  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'subscription_tiers', 'tier_test-' + RUN2), {
      id: 'tier_test-' + RUN2, name: 'TEST', annualPrice: 1, monthlyPrice: 1,
    });
  });

  await check(
    '39. client lit la grille tarifaire',
    () => getDoc(doc(cli2, 'subscription_tiers', 'tier_test-' + RUN2)),
    'ALLOW',
  );

  await check(
    '39b. client MODIFIE un tarif',
    () => updateDoc(doc(cli2, 'subscription_tiers', 'tier_test-' + RUN2),
      { annualPrice: 1 }),
    'DENY',
  );

  // ══════════════════════════════════════════════════════════════════════
  // 40 à 48 : MANDAT SEPA SIGNÉ PAR LE DÉBITEUR
  //
  // Un mandat SEPA est signé par le débiteur, pas par le créancier. La règle
  // précédente interdisait toute écriture client au motif qu'il pourrait
  // « détourner un prélèvement », ce qui était faux : prélever sur l'IBAN
  // d'un tiers débite le tiers au profit de Gorex. Le risque réel — écrire un
  // mandat sur le dossier d'autrui — est ce qui est testé ici.
  // ══════════════════════════════════════════════════════════════════════
  const mandBody = (extra = {}) => ({
    id: 'm1',
    clientId: 'gx-cli-2ok',
    clientName: 'Client Abonne',
    mandateReference: 'GRX-ABO-2026-0001',
    iban: 'BE68539007547034',
    accountHolder: 'Client Abonne',
    type: 'core',
    status: 'active',
    signatureDate: '2026-01-04T00:00:00Z',
    createdAt: '2026-01-04T00:00:00Z',
    preNotificationDays: 14,
    ...extra,
  });

  await check(
    '40. client valide signe son propre mandat',
    () => setDoc(doc(cli2, 'sepa_mandates', 'mand-ok-' + RUN2), mandBody(
      { id: 'mand-ok-' + RUN2 })),
    'ALLOW',
  );

  await check(
    '41. client signe un mandat sur le dossier d autrui',
    () => setDoc(doc(cli2, 'sepa_mandates', 'mand-other-' + RUN2), mandBody(
      { id: 'mand-other-' + RUN2, clientId: 'gx-cli-1' })),
    'DENY',
  );

  await check(
    '42. client se declare mandat deja revoque',
    () => setDoc(doc(cli2, 'sepa_mandates', 'mand-cancel-' + RUN2), mandBody(
      { id: 'mand-cancel-' + RUN2, cancelledAt: '2026-01-04T00:00:00Z' })),
    'DENY',
  );

  await check(
    '43. client lit son propre mandat',
    () => getDoc(doc(cli2, 'sepa_mandates', 'mand-ok-' + RUN2)),
    'ALLOW',
  );

  await check(
    '44. client modifie son mandat apres signature',
    () => updateDoc(doc(cli2, 'sepa_mandates', 'mand-ok-' + RUN2),
      { iban: 'BE71096123456769' }),
    'DENY',
  );

  await check(
    '45. finance enregistre un mandat pour un client',
    () => setDoc(doc(fin2, 'sepa_mandates', 'mand-fin-' + RUN2), mandBody(
      { id: 'mand-fin-' + RUN2 })),
    'ALLOW',
  );

  await check(
    '46. client suspendu signe un mandat',
    () => setDoc(doc(client, 'sepa_mandates', 'mand-susp-' + RUN2), mandBody(
      { id: 'mand-susp-' + RUN2, clientId: 'gx-cli-1' })),
    'DENY',
  );

  await check(
    '47. client supprime son mandat',
    () => deleteDoc(doc(cli2, 'sepa_mandates', 'mand-ok-' + RUN2)),
    'DENY',
  );

  await check(
    '48. finance revoque un mandat client',
    () => updateDoc(doc(fin2, 'sepa_mandates', 'mand-ok-' + RUN2), {
      status: 'cancelled',
      cancelledAt: '2026-01-05T00:00:00Z',
    }),
    'ALLOW',
  );

  // ══════════════════════════════════════════════════════════════════════
  // 49 à 52 : LA CHARGE UTILE EXACTE DE L'APPLICATION, NULLS COMPRIS
  //
  // ── POURQUOI CES QUATRE TESTS EXISTENT ────────────────────────────────
  // Les tests précédents envoyaient des documents SANS les champs `null`
  // (`decidedAt`, `decidedBy`, `activatedAt`, `note`). Or `Subscription.toMap()`
  // les inclut explicitement à `null`, et `_encodeFields()` les transmet en
  // `nullValue`. Tester une autre forme que celle réellement écrite ne prouve
  // RIEN sur la production : la règle aurait pu accepter mes documents de test
  // et refuser ceux de l'application, tous les voyants restant au vert.
  //
  // Ces tests écrivent donc EXACTEMENT ce que le code Dart écrit.
  // ══════════════════════════════════════════════════════════════════════
  const subPayloadApp = (extra = {}) => ({
    id: 'sub-app',
    clientId: 'gx-cli-2ok',
    clientEmail: 'abonne@example.com',
    tierId: 'tier_executive',
    tierName: 'GOREX EXECUTIVE',
    cycle: 'annual',
    amount: 14400,
    status: 'requested',
    requestedAt: '2026-03-01T09:00:00.000Z',
    // Champs nuls envoyés par l'application (copyWith/fromMap les tolèrent).
    decidedAt: null,
    decidedBy: null,
    activatedAt: null,
    note: null,
    ...extra,
  });

  await check(
    '49. charge utile REELLE de l app (nuls compris) -> acceptee',
    () => setDoc(doc(cli2, 'subscriptions', 'sub-app-' + RUN2),
      subPayloadApp({ id: 'sub-app-' + RUN2 })),
    'ALLOW',
  );

  await check(
    '50. charge utile REELLE mais status=active -> refusee',
    () => setDoc(doc(cli2, 'subscriptions', 'sub-app-act-' + RUN2),
      subPayloadApp({ id: 'sub-app-act-' + RUN2, status: 'active' })),
    'DENY',
  );

  const mandPayloadApp = (extra = {}) => ({
    id: 'mand-app',
    clientId: 'gx-cli-2ok',
    clientName: 'Client Abonne',
    mandateReference: 'GRX-ABO-2026-0099',
    iban: 'BE68539007547034',
    bic: null,
    accountHolder: 'Client Abonne',
    type: 'core',
    status: 'active',
    signatureDate: '2026-03-01T09:00:00.000Z',
    createdAt: '2026-03-01T09:00:00.000Z',
    cancelledAt: null,
    lastUsedAt: null,
    preNotificationDays: 14,
    notes: 'Signé par le client dans son espace personnel.',
    ...extra,
  });

  await check(
    '51. mandat : charge utile REELLE de l app (nuls compris) -> acceptee',
    () => setDoc(doc(cli2, 'sepa_mandates', 'mand-app-' + RUN2),
      mandPayloadApp({ id: 'mand-app-' + RUN2 })),
    'ALLOW',
  );

  await check(
    '52. mandat : charge utile REELLE sur le dossier d autrui -> refusee',
    () => setDoc(doc(cli2, 'sepa_mandates', 'mand-app-oth-' + RUN2),
      mandPayloadApp({ id: 'mand-app-oth-' + RUN2, clientId: 'gx-cli-1' })),
    'DENY',
  );

  // ══════════════════════════════════════════════════════════════════════
  // 53 et 54 : LA DATE DE SIGNATURE EN TANT QUE TIMESTAMP
  //
  // ── BUG DE PRODUCTION TROUVÉ PAR LE TEST BOUT-EN-BOUT ─────────────────
  // Les tests 40 à 52 passaient en envoyant `signatureDate` comme CHAÎNE.
  // L'application, elle, écrit une chaîne ISO 8601 que l'encodeur REST
  // Firestore convertit en `timestampValue` : le serveur stocke donc un
  // TIMESTAMP. La règle exigeait `is string` et répondait 403 à
  // l'application — un refus que l'émulateur ne reproduisait pas, mes
  // documents de test n'ayant pas la même forme que les vrais.
  //
  // Ces deux tests écrivent un objet `Timestamp` Firestore, exactement comme
  // le serveur le reçoit. C'est ce qui aurait dû exister dès le départ.
  // ══════════════════════════════════════════════════════════════════════
  const { Timestamp } = require('firebase/firestore');

  const mandBodyTs = (extra = {}) => ({
    id: 'mand-ts',
    clientId: 'gx-cli-2ok',
    clientName: 'Client Abonne',
    mandateReference: 'GRX-ABO-2026-0100',
    iban: 'BE68539007547034',
    bic: null,
    accountHolder: 'Client Abonne',
    type: 'core',
    status: 'active',
    // L'objet réellement stocké par Firestore.
    signatureDate: Timestamp.fromDate(new Date('2026-03-01T09:00:00Z')),
    createdAt: Timestamp.fromDate(new Date('2026-03-01T09:00:00Z')),
    cancelledAt: null,
    lastUsedAt: null,
    preNotificationDays: 14,
    notes: 'Signe par le client depuis son espace personnel.',
    ...extra,
  });

  await check(
    '53. mandat avec signatureDate en TIMESTAMP -> accepte',
    () => setDoc(doc(cli2, 'sepa_mandates', 'mand-ts-' + RUN2),
      mandBodyTs({ id: 'mand-ts-' + RUN2 })),
    'ALLOW',
  );

  await check(
    '54. mandat TIMESTAMP mais status=active force sur autrui -> refuse',
    () => setDoc(doc(cli2, 'sepa_mandates', 'mand-ts-oth-' + RUN2),
      mandBodyTs({ id: 'mand-ts-oth-' + RUN2, clientId: 'gx-cli-1' })),
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
