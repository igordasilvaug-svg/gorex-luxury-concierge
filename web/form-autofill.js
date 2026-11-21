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

  // ── RÉGRESSION CORRIGÉE (trouvée par un test, pas par lecture de code) ──
  // La première version appliquait `current-password` et le nom
  // « gorex-password » à TOUT champ de type password. Sur l'écran de
  // changement obligatoire, qui en compte TROIS (temporaire, nouveau,
  // confirmer), cela produisait :
  //   [0] current-password  name="gorex-password"   (correct)
  //   [1] current-password  name="gorex-password"   (FAUX)
  //   [2] current-password  name="gorex-password"   (FAUX)
  // Deux défauts d'un coup :
  //   • les champs « nouveau mot de passe » n'auraient plus reçu la
  //     proposition de GÉNÉRATION, et le gestionnaire y aurait collé
  //     l'ancien mot de passe ;
  //   • trois `id` identiques dans la même page = HTML invalide, et un
  //     gestionnaire qui indexe par `id` écrase deux champs sur trois.
  //
  // Le rôle est donc déduit du LIBELLÉ du champ (que Flutter publie dans
  // `aria-label`), et les noms sont rendus uniques par un compteur.

  var LABEL_NEW = /nouveau|new|confirmer|confirm|r[ée]p[ée]ter|r[ée]p[ée]t/i;
  var LABEL_CURRENT = /temporaire|actuel|current|existant|ancien/i;

  /// Rôle d'un champ : 'username' | 'current-password' | 'new-password'.
  ///
  /// Le repli dépend du NOMBRE de champs de mot de passe présents :
  ///  • un seul → c'est un mot de passe existant (écran de connexion) ;
  ///  • plusieurs et aucun libellé exploitable → on ne devine pas : on
  ///    retourne null et on ne touche à rien. Mieux vaut ne rien faire que
  ///    marquer trois champs différenciés comme identiques.
  function roleOf(input, passwordCount) {
    var type = (input.getAttribute('type') || '').toLowerCase();
    var declared = (input.getAttribute('autocomplete') || '').toLowerCase();

    if (type === 'email') return 'username';
    if (type !== 'password') return null;

    // Si Flutter a déjà su dire « nouveau mot de passe », on le respecte.
    if (declared === 'new-password') return 'new-password';

    var label = (input.getAttribute('aria-label') || '') + ' ' +
                (input.getAttribute('placeholder') || '');
    if (LABEL_NEW.test(label)) return 'new-password';
    if (LABEL_CURRENT.test(label)) return 'current-password';

    // Libellé inutilisable : on ne se prononce que s'il n'y a qu'un champ.
    return passwordCount === 1 ? 'current-password' : null;
  }

  var NAME_BY_ROLE = {
    username: 'gorex-username',
    'current-password': 'gorex-password',
    'new-password': 'gorex-new-password',
  };

  /// Applique les attributs à tous les champs d'une racine.
  ///
  /// Le compteur de noms est recalculé à chaque passe à partir du document,
  /// ce qui rend l'opération IDEMPOTENTE : ré-exécuter le script (l'observateur
  /// le fait souvent) ne produit jamais « gorex-password-2-2-2 ».
  function applyAll(root) {
    if (!root || !root.querySelectorAll) return;
    var inputs = Array.prototype.slice.call(root.querySelectorAll('input'));
    if (!inputs.length) return;

    var passwordCount = inputs.filter(function (i) {
      return (i.getAttribute('type') || '').toLowerCase() === 'password';
    }).length;

    var used = {};

    inputs.forEach(function (input) {
      var role = roleOf(input, passwordCount);
      if (!role) return;

      var base = NAME_BY_ROLE[role];
      var name = base;
      if (used[name]) {
        used[name] += 1;
        name = base + '-' + used[name];
      } else {
        used[name] = 1;
      }

      var changed = false;

      if (input.getAttribute('autocomplete') !== role) {
        input.setAttribute('autocomplete', role);
        changed = true;
      }
      // On (re)nomme aussi les champs que NOUS avons nommés lors d'une passe
      // précédente : sinon un champ resterait bloqué sur un ancien suffixe.
      var currentName = input.getAttribute('name') || '';
      if (!currentName || currentName.indexOf('gorex-') === 0) {
        if (currentName !== name) {
          input.setAttribute('name', name);
          changed = true;
        }
      }
      var currentId = input.getAttribute('id') || '';
      if (!currentId || currentId.indexOf('gorex-') === 0) {
        if (currentId !== name) {
          input.setAttribute('id', name);
          changed = true;
        }
      }
      if (role === 'username' && input.getAttribute('inputmode') !== 'email') {
        input.setAttribute('inputmode', 'email');
        changed = true;
      }
      if (changed) input.setAttribute('data-gorex-autofill', '1');
    });
  }

  function init() {
    applyAll(document);

    // Flutter crée ses champs d'édition à la demande (au premier focus
    // parfois), et le NOMBRE de champs de mot de passe change d'un écran à
    // l'autre. Un observateur garantit que chaque nouvelle composition est
    // réévaluée — le rôle d'un champ dépend en effet de ce nombre.
    if (typeof MutationObserver === 'undefined') return;

    // Regroupement : les mutations arrivent par rafales. Sans ce drapeau, on
    // relancerait une passe complète des dizaines de fois par écran.
    var pending = false;
    function schedule() {
      if (pending) return;
      pending = true;
      requestAnimationFrame(function () {
        pending = false;
        applyAll(document);
      });
    }

    var observer = new MutationObserver(function (mutations) {
      for (var i = 0; i < mutations.length; i++) {
        var m = mutations[i];
        if (m.type === 'attributes') {
          schedule();
          return;
        }
        for (var j = 0; j < m.addedNodes.length; j++) {
          var node = m.addedNodes[j];
          if (node && node.nodeType === 1) {
            schedule();
            return;
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
