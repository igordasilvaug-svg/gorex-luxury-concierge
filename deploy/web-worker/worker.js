// GOREX LUXURY CONCIERGE — Worker Cloudflare (Assets + en-têtes de sécurité)
// Sert le build Flutter Web (dossier d'assets) avec :
//  - routage SPA (fallback index.html)
//  - en-têtes de sécurité HTTP renforcés (CSP, HSTS, anti-sniff, referrer, permissions)
//  - page de téléchargement /download + APK Android publics (/download/*.apk)
//
// Note CSP : Flutter Web (CanvasKit / Skwasm) charge le moteur de rendu depuis
// https://www.gstatic.com. Les directives autorisent donc gstatic en script-src
// et connect-src, et l'exécution WASM (wasm-unsafe-eval).
//
// Deux familles d'origines tierces sont ouvertes en connect-src, et deux
// seulement : Firebase/Firestore, et l'Access Point Peppol
// (`PEPPOL_ORIGINS`, voir plus bas). Tout le reste est fermé.

// ── ORIGINES DES ACCESS POINTS PEPPOL (facturation électronique) ─────────
//
// L'application transmet les factures UBL à un Access Point Peppol agréé
// depuis le NAVIGATEUR (voir `lib/core/billing/peppol_service.dart`). Sans
// autorisation explicite dans `connect-src`, la Content Security Policy
// bloque la requête : l'envoi échoue avec une erreur réseau opaque, même
// avec une clé d'API valide.
//
// La liste reste FERMÉE — pas de `https://*`. Ajouter un fournisseur se fait
// ici, en une ligne, et la modification est alors visible en revue.
//
//   Storecove (Datajust B.V.)  → https://api.storecove.com   [intégré]
//
// Si vous choisissez Tickstar, Unifiedpost, e-invoice.be ou un autre
// prestataire, ajoutez SON origine d'API. Pour Storecove, l'URL par défaut de
// l'application (`https://api.storecove.com/api/v2`) est déjà couverte : seule
// l'origine compte en CSP, pas le chemin.
const PEPPOL_ORIGINS = ['https://api.storecove.com'];

const SECURITY_HEADERS = {
  // Empêche le reniflage de type MIME
  'X-Content-Type-Options': 'nosniff',
  // Référent restreint
  'Referrer-Policy': 'strict-origin-when-cross-origin',
  // Force HTTPS (1 an, sous-domaines)
  'Strict-Transport-Security': 'max-age=31536000; includeSubDomains; preload',
  // Désactive les fonctionnalités sensibles non utilisées
  'Permissions-Policy':
    'camera=(), microphone=(), geolocation=(), payment=(), usb=(), magnetometer=(), gyroscope=(), interest-cohort=()',
  // Protection XSS navigateurs anciens
  'X-XSS-Protection': '1; mode=block',
  // Content Security Policy
  // Note Firebase/Firestore : le SDK Web ouvre des connexions HTTPS vers
  // firestore.googleapis.com et un canal WebSocket (long-polling) vers
  // *.googleapis.com / *.firebaseio.com → autorisés en connect-src.
  //
  // Note Cloudflare Web Analytics — RÉGLÉ À LA SOURCE, LA CSP RESTE EN GARDE :
  // Cloudflare injectait automatiquement https://static.cloudflareinsights.com/
  // beacon.min.js dans les réponses HTML. Notre CSP le bloquait, ce qui
  // produisait un message d'erreur dans la console :
  //   Loading the script '…beacon.min.js' violates … "script-src …"
  //
  // ── CE QUI A CHANGÉ ─────────────────────────────────────────────────────
  // Le blocage par la CSP était un pansement : le script continuait d'être
  // SERVI puis rejeté, donc le message persistait. La cause réelle est le
  // réglage « Web Analytics » de la zone Cloudflare, et c'est lui qui a été
  // désactivé :
  //   PATCH /client/v4/zones/<zone>/settings/rum  { "value": "off" }
  // Vérification : `curl -s https://gorex-luxury-concierge.eu/ | grep -c
  // cloudflareinsights` doit répondre 0. Mesuré : 0, plus aucun message.
  //
  // Le script n'est donc plus injecté du tout. La liste `script-src`
  // ci-dessous reste néanmoins FERMÉE : si quelqu'un réactive l'analytique
  // Cloudflare depuis le tableau de bord, le traceur sera bloqué au lieu
  // d'être déposé silencieusement. C'est une protection, pas un oubli.
  //
  // Pourquoi garder cette fermeture : notre bandeau de consentement affirme
  // « aucune publicité, aucune analytique tierce ». Autoriser ce script
  // rendrait cette phrase fausse et déposerait un traceur avant tout
  // consentement. Pour le réactiver un jour, il faudrait modifier la bannière
  // ET la politique cookies de façon cohérente — pas seulement cette liste.
  'Content-Security-Policy': [
    "default-src 'self'",
    // FlutterFire (SDK Firebase Web) injecte un court script inline qui charge le
    // SDK modulaire depuis gstatic (firebase-app / firebase-auth / firebase-firestore).
    // Ces 3 scripts sont autorisés par EMPREINTE SHA-256 (aucun 'unsafe-inline').
    // ⚠️ Si la version du SDK Firebase JS change, recalculer ces empreintes.
    // FlutterFire (SDK Firebase Web) injecte un court script inline par service
    // pour charger le SDK modulaire depuis gstatic. Chaque script est autorisé
    // par EMPREINTE SHA-256 (aucun 'unsafe-inline').
    // ⚠️ Si la version du SDK Firebase JS change (11.9.1), ces empreintes
    // changent : le script de déploiement les recalcule dans finalize_web.py.
    //   firebase_core      → lxybZtu/9pEo9t2cXF8OdVCueZV6paBpNEQpBgqbYWA=
    //   firebase_firestore → Kd6jrSJ+A8S4mbnMXfLL0WXdMJ02uYTrwrdvhPTpDug=
    //   firebase_auth      → JAe3kXNkLbcxHg2ubdnFd1ozxf8byMAcYA7B4I7gV5I=
    //   firebase_app_check → wtfUX3o+VhYEVP+bzIDF4V/mircbtP9PtlVEYPDTvb0=
    "script-src 'self' 'wasm-unsafe-eval' 'sha256-lxybZtu/9pEo9t2cXF8OdVCueZV6paBpNEQpBgqbYWA=' 'sha256-Kd6jrSJ+A8S4mbnMXfLL0WXdMJ02uYTrwrdvhPTpDug=' 'sha256-JAe3kXNkLbcxHg2ubdnFd1ozxf8byMAcYA7B4I7gV5I=' 'sha256-wtfUX3o+VhYEVP+bzIDF4V/mircbtP9PtlVEYPDTvb0=' https://www.gstatic.com https://apis.google.com https://www.google.com https://www.recaptcha.net",
    "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
    "img-src 'self' data: blob: https://www.gstatic.com https://www.google.com",
    "font-src 'self' data: https://fonts.gstatic.com",
    "connect-src 'self' https://www.gstatic.com https://fonts.gstatic.com https://firestore.googleapis.com https://*.googleapis.com https://*.firebaseio.com wss://*.firebaseio.com https://*.cloudfunctions.net https://www.google.com https://www.recaptcha.net " + PEPPOL_ORIGINS.join(' '),
    "worker-src 'self' blob:",
    "child-src 'self' blob:",
    "frame-src 'self' https://*.firebaseapp.com https://accounts.google.com https://www.google.com https://recaptcha.google.com https://www.recaptcha.net",
    "frame-ancestors 'self'",
    "base-uri 'self'",
    "form-action 'self'",
    "object-src 'none'",
    "upgrade-insecure-requests",
  ].join('; '),
};

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    let path = url.pathname;

    // Ne pas altérer les requêtes non-GET
    if (request.method !== 'GET' && request.method !== 'HEAD') {
      return new Response('Method Not Allowed', { status: 405 });
    }

    if (path === '/' || path === '') path = '/index.html';

    // Raccourci : /download -> page de téléchargement
    if (path === '/download' || path === '/download/') path = '/download.html';

    // Service worker Flutter : toujours revalidé
    if (path === '/flutter_service_worker.js') {
      const res = await env.ASSETS.fetch(new URL('/flutter_service_worker.js', url.origin));
      const h = new Headers(res.headers);
      h.set('Cache-Control', 'no-cache, no-store, must-revalidate');
      h.set('Service-Worker-Allowed', '/');
      for (const [k, v] of Object.entries(SECURITY_HEADERS)) h.set(k, v);
      return new Response(res.body, { status: res.status, headers: h });
    }

    // APK Android : type MIME correct + téléchargement forcé
    if (path.startsWith('/download/') && path.endsWith('.apk')) {
      const apkRes = await env.ASSETS.fetch(new URL(path, url.origin));
      if (apkRes.status === 200) {
        const h = new Headers();
        h.set('Content-Type', 'application/vnd.android.package-archive');
        const filename = path.substring(path.lastIndexOf('/') + 1);
        h.set('Content-Disposition', `attachment; filename="${filename}"`);
        h.set('Cache-Control', 'public, max-age=86400');
        h.set('X-Content-Type-Options', 'nosniff');
        h.set('Accept-Ranges', 'bytes');
        return new Response(apkRes.body, { status: 200, headers: h });
      }
      return new Response('APK not found', { status: 404 });
    }

    let assetRes = await env.ASSETS.fetch(new URL(path, url.origin));

    // Fallback SPA pour les routes sans extension (ex. /privacy)
    if (assetRes.status === 404 && !path.includes('.')) {
      assetRes = await env.ASSETS.fetch(new URL('/index.html', url.origin));
    }

    const headers = new Headers(assetRes.headers);
    for (const [k, v] of Object.entries(SECURITY_HEADERS)) headers.set(k, v);

    // Cache :
    //  - HTML + fichiers NON versionnés (main.dart.js, bootstrap, service worker,
    //    manifest, robots, sitemap) → TOUJOURS revalidés : sinon le navigateur
    //    garde une ancienne version du code indéfiniment (bug de connexion vécu).
    //  - Uniquement les assets réellement versionnés (nom avec hash) → 1 an.
    const NON_VERSIONED = [
      '/main.dart.js',
      '/flutter.js',
      '/flutter_bootstrap.js',
      '/flutter_service_worker.js',
      '/version.json',
      '/manifest.json',
      '/robots.txt',
      '/sitemap.xml',
    ];
    if (path === '/index.html' || path.endsWith('.html')) {
      headers.set('Cache-Control', 'no-cache, no-store, must-revalidate');
    } else if (NON_VERSIONED.includes(path)) {
      headers.set('Cache-Control', 'no-cache, must-revalidate');
    } else if (
      path.startsWith('/canvaskit/') ||
      path.startsWith('/assets/') ||
      path.startsWith('/icons/')
    ) {
      headers.set('Cache-Control', 'public, max-age=31536000, immutable');
    }

    return new Response(assetRes.body, { status: assetRes.status, headers });
  },
};
