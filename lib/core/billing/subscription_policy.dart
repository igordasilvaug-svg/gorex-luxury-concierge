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
  /// ── POUR PASSER À true, IL FAUT QUE CES ÉLÉMENTS EXISTENT ──────────────
  ///  1. Grille tarifaire validée par la direction (elle est en base : quatre
  ///     formules, cf. `publish_subscription_tiers.py`, mais les montants
  ///     n'ont pas été approuvés explicitement).
  ///  2. Conditions générales de vente publiées, avec le droit de rétractation
  ///     applicable aux contrats à distance (livre VI du Code de droit
  ///     économique belge).
  ///  3. Mentions TVA : numéro valide et régime applicable aux services.
  ///  4. Créancier SEPA identifié : numéro d'entreprise et ICS vérifiés
  ///     (l'ICS se dérive du numéro d'entreprise ; un ICS faux fait rejeter
  ///     tous les prélèvements par la banque).
  ///  5. Compte bancaire professionnel au nom de Gorex Group confirmé.
  ///
  /// Aucun de ces cinq points ne relève du logiciel : ils sont juridiques et
  /// bancaires. C'est pourquoi cet interrupteur ne peut pas être activé par
  /// le code seul.
  static const bool subscriptionsOpen = false;

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

  /// L'activation d'un abonnement (donc la facturation) est-elle possible ?
  ///
  /// Verrou unique : même si un abonnement était accepté par erreur alors que
  /// l'offre est fermée, il ne pourrait pas devenir facturable.
  static bool get canActivateBilling => subscriptionsOpen;
}
