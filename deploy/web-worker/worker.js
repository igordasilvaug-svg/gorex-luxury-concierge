// GOREX LUXURY CONCIERGE — Worker Cloudflare (Assets + en-têtes de sécurité)
// Sert le build Flutter Web (dossier d'assets) avec :
//  - routage SPA (fallback index.html)
//  - en-têtes de sécurité HTTP renforcés (CSP, HSTS, anti-sniff, referrer, permissions)
//  - page de téléchargement /download + APK Android publics (/download/*.apk)
//
// Note CSP : Flutter Web (CanvasKit / Skwasm) charge le moteur de rendu depuis
// https://www.gstatic.com. Les directives autorisent donc gstatic en script-src
// et connect-src, et l'exécution WASM (wasm-unsafe-eval). Aucune origine tierce
// n'est autorisée en dehors de gstatic.

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
  'Content-Security-Policy': [
    "default-src 'self'",
    "script-src 'self' 'wasm-unsafe-eval' https://www.gstatic.com https://apis.google.com",
    "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
    "img-src 'self' data: blob:",
    "font-src 'self' data: https://fonts.gstatic.com",
    "connect-src 'self' https://www.gstatic.com https://fonts.gstatic.com https://firestore.googleapis.com https://*.googleapis.com https://*.firebaseio.com wss://*.firebaseio.com https://*.cloudfunctions.net",
    "worker-src 'self' blob:",
    "child-src 'self' blob:",
    "frame-src 'self' https://*.firebaseapp.com https://accounts.google.com",
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

    // Cache : HTML jamais mis en cache, assets versionnés 1 an
    if (path === '/index.html' || path.endsWith('.html')) {
      headers.set('Cache-Control', 'no-cache, no-store, must-revalidate');
    } else if (
      path.startsWith('/canvaskit/') ||
      path === '/main.dart.js' ||
      path.startsWith('/assets/') ||
      path.startsWith('/icons/')
    ) {
      headers.set('Cache-Control', 'public, max-age=31536000, immutable');
    }

    return new Response(assetRes.body, { status: assetRes.status, headers });
  },
};
