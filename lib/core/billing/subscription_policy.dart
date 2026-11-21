// GOREX LUXURY CONCIERGE — Politique d'ouverture commerciale.
//
// ── POURQUOI CE FICHIER EXISTE ────────────────────────────────────────────
// Le circuit d'abonnement est entièrement construit : demande du client,
// décision de Gorex Group, signature du mandat SEPA, activation, prélèvement.
// Mais un circuit prêt n'est pas un circuit OUVERT. Tant que les conditions
// commerciales et légales ne sont pas arrêtées, proposer « souscrire un
// abonnement » serait une promesse que l'entreprise ne peut pas encore tenir.
//
// Cette politique est donc un INTERRUPTEUR UNIQUE, DÉSACTIVÉ PAR DÉFAUT.
// Aucune activation automatique, aucune détection d'environnement : c'est un
// choix explicite, tracé, réversible.
//
// Ce qui est FERMÉ quand l'interrupteur est à false :
//   • l'écran client n'affiche aucun bouton « souscrire » ;
//   • `requestSubscription()` refuse toute demande ;
//   • `activateSubscriptionIfReady()` refuse d'activer, donc rien n'est
//     facturable — le prélèvement SEPA exige un abonnement `active`.
//
// Ce qui reste possible : le personnel peut toujours consulter l'état, et le
// code est prêt à être ouvert d'un seul changement.

/// Interrupteur d'ouverture commerciale des abonnements.
class SubscriptionPolicy {
  SubscriptionPolicy._();

  /// Les abonnements sont-ils proposés aux clients ?
  ///
  /// ── OUVERT LE 21/11/2026, SUR DÉCISION EXPLICITE DE LA DIRECTION ───────
  ///
  /// Chacun des cinq prérequis a été VÉRIFIÉ en base avant l'ouverture, et non
  /// simplement supposé :
  ///  1. Grille tarifaire : quatre formules en base (`subscription_tiers`),
  ///     actives et ordonnées — ESSENTIAL 4 800 €, EXECUTIVE 14 400 €,
  ///     ELITE 36 000 €, PRIVATE 96 000 € par an. Direction : accord donné.
  ///  2. Conditions générales publiées (FR/NL/EN), avec une clause de
  ///     rétractation de 14 jours et son formulaire type (section 2bis).
  ///  3. TVA : numéro BE1009679037, cohérent avec le numéro d'entreprise.
  ///  4. Créancier SEPA : numéro d'entreprise 1009679037, contrôle modulo 97
  ///     VALIDE ; ICS dérivé par l'algorithme de l'application :
  ///     BE32ZZZ1009679037, dont le contrôle modulo 97 vaut 1 (valide).
  ///  5. Compte bancaire : IBAN BE97001980531549 (BNP Paribas Fortis),
  ///     contrôle modulo 97 valide, au nom de Gorex Group.
  ///
  /// Ce qui s'ouvre exactement :
  ///   • le client peut déposer une demande d'abonnement ;
  ///   • Gorex peut accepter puis ACTIVER, ce qui rend l'abonnement facturable ;
  ///   • un mandat SEPA signé par le client peut alors être prélevé.
  ///
  /// Ce qui NE change pas : un client ne peut toujours ni s'auto-attribuer un
  /// abonnement actif, ni fixer son montant, ni décider de l'activation. Ces
  /// verrous sont dans les règles Firestore, pas dans cet interrupteur.
  static const bool subscriptionsOpen = true;

  /// Message affiché au client tant que l'ouverture n'est pas décidée.
  ///
  /// On ne masque pas l'existence de l'offre : on dit la vérité sur son état.
  /// La première rédaction promettait « vous pouvez déjà déposer vos
  /// demandes », alors que `requestSubscription()` refuse justement toute
  /// demande dans cet état. Une phrase qui annonce ce que le code interdit est
  /// un mensonge, même bien intentionné : elle est corrigée.
  static const String closedNotice =
      'Les formules Gorex sont en cours de finalisation et la souscription '
      'n\'est pas encore ouverte. Aucun montant ne peut être demandé ni '
      'prélevé à ce stade. Vous serez informé dès l\'ouverture officielle.';

  /// Libellé court affiché à la place de tout bouton de souscription.
  static const String closedBadge = 'Souscription non ouverte';

  /// Message affiché au client lorsque l'offre EST ouverte et qu'il n'a pas
  /// encore de contrat.
  ///
  /// ── POURQUOI CETTE CONSTANTE EXISTE ─────────────────────────────────────
  /// La carte du Profil affichait `closedNotice` SANS CONDITION dès qu'aucun
  /// abonnement n'existait. À l'ouverture de l'interrupteur, un client lisait
  /// donc « la souscription n'est pas encore ouverte » sur son profil, puis,
  /// un écran plus loin, « DEMANDER CETTE FORMULE » avec ses tarifs. Deux
  /// affirmations contradictoires dans la même application : l'une des deux
  /// mentait forcément. Ce texte-ci est celui qui dit vrai quand l'offre est
  /// ouverte, et il ne promet rien que le code n'autorise : la demande est
  /// bien déposée, mais rien n'est dû avant l'acceptation de Gorex Group.
  static const String openNotice =
      'Aucune formule souscrite à ce jour. Les formules Gorex sont ouvertes : '
      'vous pouvez déposer une demande, sans aucun engagement et sans aucun '
      'montant dû avant l\'acceptation de Gorex Group.';

  /// L'activation d'un abonnement (donc la facturation) est-elle possible ?
  ///
  /// Verrou unique : même si un abonnement était accepté par erreur alors que
  /// l'offre est fermée, il ne pourrait pas devenir facturable.
  static bool get canActivateBilling => subscriptionsOpen;
}
