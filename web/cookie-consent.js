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
    document.body.appendChild(build());
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
