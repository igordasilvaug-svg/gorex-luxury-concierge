/* GOREX LUXURY CONCIERGE — Bannière de consentement cookies (FR / NL / EN)
 * Conforme à la directive ePrivacy (2002/58/CE) et au RGPD (UE 2016/679).
 *
 * L'application n'utilise QUE des cookies/traces strictement nécessaires
 * (aucun traceur publicitaire, aucune analytique tierce). La bannière informe
 * l'utilisateur et enregistre son choix localement (localStorage), sans
 * transmettre de données à un tiers.
 */
(function () {
  'use strict';
  var STORAGE_KEY = 'gorex_cookie_consent_v1';

  var STRINGS = {
    fr: {
      text:
        'Nous utilisons uniquement des traceurs <strong style="color:#F6F4EF">strictement n\u00e9cessaires</strong> ' +
        'au fonctionnement du service (aucune publicit\u00e9, aucune analytique tierce). ' +
        'En savoir plus : <a href="cookies.html" style="color:#C6A15B;text-decoration:none">Politique cookies</a> ' +
        '&middot; <a href="privacy.html" style="color:#C6A15B;text-decoration:none">Confidentialit\u00e9</a>.',
      accept: 'Accepter',
      decline: 'Continuer sans accepter',
    },
    nl: {
      text:
        'Wij gebruiken enkel <strong style="color:#F6F4EF">strikt noodzakelijke</strong> cookies ' +
        'voor de werking van de dienst (geen advertenties, geen tracking door derden). ' +
        'Meer info: <a href="cookies-nl.html" style="color:#C6A15B;text-decoration:none">Cookiebeleid</a> ' +
        '&middot; <a href="privacy-nl.html" style="color:#C6A15B;text-decoration:none">Privacy</a>.',
      accept: 'Accepteren',
      decline: 'Verder zonder accepteren',
    },
    en: {
      text:
        'We only use <strong style="color:#F6F4EF">strictly necessary</strong> cookies ' +
        'for the service to work (no advertising, no third-party analytics). ' +
        'Learn more: <a href="cookies-en.html" style="color:#C6A15B;text-decoration:none">Cookie policy</a> ' +
        '&middot; <a href="privacy-en.html" style="color:#C6A15B;text-decoration:none">Privacy</a>.',
      accept: 'Accept',
      decline: 'Continue without accepting',
    },
  };

  function detectLang() {
    var l = null;
    try {
      l = localStorage.getItem('gorex_web_lang');
    } catch (e) {}
    if (!l) {
      l = (document.documentElement.getAttribute('lang') || '').slice(0, 2);
    }
    return STRINGS[l] ? l : 'fr';
  }

  function alreadyChosen() {
    try {
      return localStorage.getItem(STORAGE_KEY) !== null;
    } catch (e) {
      return false;
    }
  }

  function save(value) {
    try {
      localStorage.setItem(
        STORAGE_KEY,
        JSON.stringify({ value: value, at: new Date().toISOString() })
      );
    } catch (e) {
      /* stockage indisponible : on ne bloque pas l'utilisateur */
    }
  }


  // ── Réservation d'espace ──────────────────────────────────────────────
  //
  // DÉFAUT CORRIGÉ. La bannière était un calque `position:fixed` posé sur le
  // bas de la page, sans réserver d'espace : elle recouvrait donc les
  // derniers éléments de CHAQUE écran (le bouton « COMPLÉTER MES
  // INFORMATIONS » devenait inatteignable sur un téléphone).
  //
  // Deux tentatives ont été mesurées avant d'aboutir, et sont documentées ici
  // pour ne pas les refaire :
  //   1. Mesure immédiate : le script est chargé en `defer` et s'exécute
  //      AVANT que Flutter n'ait créé `flutter-view` (bannière à 180 ms, vue
  //      à 1 469 ms sur le réseau réel) → mesure vide, échec silencieux.
  //   2. Style EN LIGNE avec `!important` : Flutter réécrit l'attribut style
  //      de la vue à chaque redimensionnement, ce qui efface la déclaration
  //      (mesuré : `height` revenu à 932px, chevauchement de 197px).
  //
  // Solution retenue : une RÈGLE DE FEUILLE DE STYLE. Une déclaration
  // `!important` d'une feuille de style l'emporte sur un style en ligne
  // ordinaire, donc Flutter ne peut plus l'écraser. La hauteur à réserver est
  // passée par une variable CSS, mise à jour quand la bannière apparaît, se
  // ferme ou que la fenêtre change de taille.
  var reserved = 0; // hauteur de bannière à réserver, en pixels
  var barRef = null;

  function flutterView() {
    return document.querySelector('flutter-view');
  }

  function installRule() {
    if (document.getElementById('gorex-cookie-space')) return;
    var el = document.createElement('style');
    el.id = 'gorex-cookie-space';
    el.textContent =
      ':root{--gorex-cookie-h:0px}' +
      'flutter-view{' +
      'height:calc(100vh - var(--gorex-cookie-h)) !important;' +
      'bottom:auto !important;' +
      '}';
    document.head.appendChild(el);
  }

  // DÉFAUT CORRIGÉ (mesuré en production, pas en théorie).
  //
  // `setReserved()` émettait un `resize` pour prévenir Flutter. Or
  // `dispatchEvent` est SYNCHRONE : l'écouteur `resize` plus bas appelle
  // `setReserved()`, qui ré-émettait un `resize`, qui rappelait l'écouteur…
  // La récursion ne s'arrêtait qu'à l'explosion de la pile. Constat sur le
  // site réel, à CHAQUE chargement de page :
  //
  //   RangeError: Maximum call stack size exceeded.
  //     at setReserved (cookie-consent.js:121:12)
  //     at <anonymous> (cookie-consent.js:160:5)
  //     at setReserved (cookie-consent.js:121:12)   ← ×des centaines
  //
  // Conséquences : une exception non rattrapée à chaque visite, ET la
  // notification de redimensionnement perdue pour Flutter (l'exception
  // interrompt la chaîne avant que la vue n'ait fini de se reconfigurer).
  //
  // Deux garde-fous, complémentaires :
  //   1. on n'émet un `resize` que si la hauteur réservée change VRAIMENT
  //      (l'écouteur mesure la même valeur → aucune ré-émission) ;
  //   2. l'émission est différée à la frame suivante et dédoublonnée, donc
  //      elle ne peut plus s'insérer dans sa propre pile d'appel.
  var resizePending = false;

  function scheduleResize() {
    if (resizePending) return;
    resizePending = true;
    requestAnimationFrame(function () {
      resizePending = false;
      window.dispatchEvent(new Event('resize'));
    });
  }

  function setReserved(px) {
    var next = px > 0 ? Math.round(px) : 0;
    var changed = next !== reserved;
    reserved = next;
    document.documentElement.style.setProperty(
      '--gorex-cookie-h', reserved + 'px');
    // Flutter dimensionne son canevas d'après la taille de la fenêtre : on le
    // prévient pour qu'il recalcule sa mise en page à la nouvelle hauteur.
    if (changed) scheduleResize();
  }

  // Attend que Flutter ait monté sa vue (abandonne au bout de ~10 s).
  function whenView(cb) {
    if (flutterView()) {
      cb();
      return;
    }
    var tries = 0;
    (function loop() {
      if (flutterView()) {
        cb();
        return;
      }
      if (++tries > 600) return;
      requestAnimationFrame(loop);
    })();
  }

  function measure() {
    if (!barRef) return 0;
    var h = Math.ceil(barRef.getBoundingClientRect().height);
    return h > 0 ? h : 0;
  }

  function reserveSpace(bar) {
    barRef = bar;
    installRule();
    setReserved(measure());
  }

  function releaseSpace() {
    barRef = null;
    setReserved(0);
  }

  // La bannière change de hauteur selon la largeur : on remesure. Grâce au
  // test `changed` de setReserved(), un même résultat n'émet aucun événement,
  // donc cet écouteur ne peut plus se rappeler lui-même indéfiniment.
  window.addEventListener('resize', function () {
    if (!barRef) return;
    setReserved(measure());
  });

  function build() {
    var lang = detectLang();
    var t = STRINGS[lang];

    var bar = document.createElement('div');
    bar.setAttribute('role', 'dialog');
    bar.setAttribute('aria-live', 'polite');
    bar.setAttribute('aria-label', 'Cookie consent');
    bar.style.cssText = [
      'position:fixed',
      'left:0',
      'right:0',
      'bottom:0',
      'z-index:9999',
      'background:#111114',
      'border-top:0.6px solid #2A2A2F',
      'box-shadow:0 -8px 32px rgba(0,0,0,0.5)',
      'padding:18px 20px',
      'display:flex',
      'flex-wrap:wrap',
      'align-items:center',
      'gap:14px',
      'justify-content:center',
      'font-family:Inter,-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif',
      'font-size:13px',
      'line-height:1.6',
      'color:#B5B5BA',
    ].join(';');

    var text = document.createElement('div');
    text.style.cssText = 'flex:1 1 420px;min-width:240px;max-width:680px;';
    text.innerHTML = t.text;

    function mkButton(label, primary) {
      var b = document.createElement('button');
      b.type = 'button';
      b.textContent = label;
      b.style.cssText = [
        'cursor:pointer',
        'padding:10px 20px',
        'border-radius:3px',
        'font-size:12px',
        'font-weight:600',
        'letter-spacing:2px',
        'text-transform:uppercase',
        'font-family:inherit',
        primary
          ? 'background:linear-gradient(135deg,#D8BC85,#C6A15B,#A98643);border:0;color:#0A0A0B'
          : 'background:transparent;border:1px solid #2A2A2F;color:#B5B5BA',
      ].join(';');
      return b;
    }

    var accept = mkButton(t.accept, true);
    var decline = mkButton(t.decline, false);

    function close(value) {
      save(value);
      releaseSpace();
      bar.style.transition = 'opacity .25s ease';
      bar.style.opacity = '0';
      setTimeout(function () {
        if (bar.parentNode) bar.parentNode.removeChild(bar);
      }, 260);
    }

    accept.addEventListener('click', function () {
      close('accepted');
    });
    decline.addEventListener('click', function () {
      close('necessary_only');
    });

    bar.appendChild(text);
    bar.appendChild(decline);
    bar.appendChild(accept);
    return bar;
  }

  function init() {
    if (alreadyChosen()) return;
    var bar = build();
    document.body.appendChild(bar);
    // Mesure après insertion (la hauteur dépend du texte), puis application
    // dès que Flutter a monté sa vue.
    whenView(function () {
      reserveSpace(bar);
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
