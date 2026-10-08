/* GOREX LUXURY CONCIERGE — Bannière de consentement cookies
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
    var bar = document.createElement('div');
    bar.setAttribute('role', 'dialog');
    bar.setAttribute('aria-live', 'polite');
    bar.setAttribute('aria-label', 'Consentement cookies');
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
    text.innerHTML =
      'Nous utilisons uniquement des traceurs <strong style="color:#F6F4EF">strictement n\u00e9cessaires</strong> ' +
      'au fonctionnement du service (aucune publicit\u00e9, aucune analytique tierce). ' +
      'En savoir plus : <a href="cookies.html" style="color:#C6A15B;text-decoration:none">Politique cookies</a> ' +
      '&middot; <a href="privacy.html" style="color:#C6A15B;text-decoration:none">Confidentialit\u00e9</a>.';

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

    var accept = mkButton('Accepter', true);
    var decline = mkButton('Continuer sans accepter', false);

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
