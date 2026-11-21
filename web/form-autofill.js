/* GOREX LUXURY CONCIERGE — Compatibilité avec les gestionnaires de mots de passe.
 *
 * ── LE DÉFAUT, MESURÉ ────────────────────────────────────────────────────
 * Le formulaire Flutter est correctement écrit (AutofillGroup, autofillHints
 * username/email et password). Mais ce que le NAVIGATEUR reçoit réellement
 * n'a plus rien à voir. Mesure faite en production sur l'écran de connexion :
 *
 *   [0] type=email    name="" id="" autocomplete="off" aria-label="ADRESSE E-MAIL"
 *   [1] type=password name="" id="" autocomplete="off" aria-label="MOT DE PASSE"
 *   conteneur <form> : absent
 *
 * Trois signaux qui empêchent un gestionnaire de mots de passe de proposer
 * l'enregistrement du couple identifiant / mot de passe :
 *
 *  1. `autocomplete="off"` — Flutter applique cette valeur PAR DÉFAUT à tous
 *     ses champs, quels que soient les `autofillHints` fournis en Dart.
 *  2. aucun `name` ni `id` — un gestionnaire n'a aucun nom de champ à
 *     rattacher au couple qu'il enregistre.
 *  3. aucun `<form>` — certains gestionnaires s'en servent pour délimiter
 *     l'unité « formulaire de connexion ».
 *
 * ── CE QUE FAIT CE SCRIPT ────────────────────────────────────────────────
 * Il rétablit les deux premiers signaux, qui sont les signaux NORMALISÉS
 * (attributs HTML standard) : `autocomplete="username"` sur le champ
 * identifiant, `autocomplete="current-password"` sur le champ mot de passe,
 * plus des `name`/`id` explicites.
 *
 * Pourquoi `current-password` et non `new-password` : il s'agit du mot de
 * passe EXISTANT. C'est cette valeur qui déclenche la proposition
 * d'enregistrement ; `new-password` sert aux écrans de création de compte.
 *
 * ── CE QU'IL NE FAIT PAS, VOLONTAIREMENT ─────────────────────────────────
 * Il n'insère PAS de `<form>`. Un `<form>` natif déclenche la soumission
 * implicite du navigateur sur la touche Entrée : la page se rechargerait au
 * lieu de connecter, ce qui casserait la connexion pour gagner un signal
 * facultatif. On ne remplace pas un défaut par une régression.
 *
 * Il n'envoie AUCUN événement clavier ou `input` sur ces champs : le champ
 * est piloté par Flutter, et simuler une frappe corromprait la valeur saisie.
 *
 * ── MESURE ATTENDUE APRÈS CORRECTION ─────────────────────────────────────
 *   [0] type=email    name="gorex-username" autocomplete="username"
 *   [1] type=password name="gorex-password" autocomplete="current-password"
 */
(function () {
  'use strict';

  // Attributs à appliquer selon le type de champ.
  var SPECS = {
    email: { name: 'gorex-username', autocomplete: 'username' },
    password: { name: 'gorex-password', autocomplete: 'current-password' },
  };

  // Noms stables et explicites : deux champs distincts ne doivent pas se
  // retrouver avec le même `name`, sinon le gestionnaire écrase l'un avec
  // l'autre dans le couple qu'il enregistre.
  function applyAttributes(input) {
    if (!input || input.tagName !== 'INPUT') return;
    var type = (input.getAttribute('type') || '').toLowerCase();
    // Un champ de NOUVEAU mot de passe (création de compte) ne doit pas être
    // traité comme un mot de passe existant : il perdrait sa proposition de
    // génération. On respecte donc ce que Flutter a déjà indiqué.
    var existing = (input.getAttribute('autocomplete') || '').toLowerCase();
    if (type === 'password' && existing === 'new-password') return;

    var spec = SPECS[type];
    if (!spec) return;

    var changed = false;

    if (input.getAttribute('autocomplete') !== spec.autocomplete) {
      input.setAttribute('autocomplete', spec.autocomplete);
      changed = true;
    }
    if (!input.getAttribute('name')) {
      input.setAttribute('name', spec.name);
      changed = true;
    }
    if (!input.getAttribute('id')) {
      input.setAttribute('id', spec.name);
      changed = true;
    }
    // `inputmode` aide les claviers mobiles à proposer l'autocomplétion.
    if (type === 'email' && input.getAttribute('inputmode') !== 'email') {
      input.setAttribute('inputmode', 'email');
      changed = true;
    }
    // Marqueur de diagnostic : permet de vérifier depuis les tests que la
    // correction a bien été appliquée, sans deviner.
    if (changed) input.setAttribute('data-gorex-autofill', '1');
  }

  function scan(root) {
    if (!root || !root.querySelectorAll) return;
    root.querySelectorAll('input').forEach(applyAttributes);
  }

  function init() {
    scan(document);

    // Flutter crée ses champs d'édition à la demande (au premier focus
    // parfois). Un observateur garantit que les champs apparus PLUS TARD
    // reçoivent aussi les attributs, sans avoir à deviner le bon moment.
    if (typeof MutationObserver === 'undefined') return;
    var observer = new MutationObserver(function (mutations) {
      for (var i = 0; i < mutations.length; i++) {
        var m = mutations[i];
        if (m.type === 'attributes' && m.target && m.target.tagName === 'INPUT') {
          applyAttributes(m.target);
          continue;
        }
        for (var j = 0; j < m.addedNodes.length; j++) {
          var node = m.addedNodes[j];
          if (node && node.nodeType === 1) {
            if (node.tagName === 'INPUT') applyAttributes(node);
            else scan(node);
          }
        }
      }
    });
    observer.observe(document.body, {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ['type', 'autocomplete'],
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init, { once: true });
  } else {
    init();
  }
})();
