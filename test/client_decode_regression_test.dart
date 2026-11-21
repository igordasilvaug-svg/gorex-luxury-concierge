import 'package:flutter_test/flutter_test.dart';
import 'package:gorex_concierge/models/client.dart';
import 'package:gorex_concierge/models/enums.dart';

/// RÉGRESSION : une fiche client incomplète faisait disparaître le dossier.
///
/// CONTEXTE VÉCU
/// -------------
/// Un compte de test dont la fiche Firestore omettait `createdAt`, `category`
/// et `confidentiality` s'est connecté avec succès… et n'a vu AUCUNE de ses
/// données : pas de nom, badge de confidentialité par défaut, « Cher membre »
/// au lieu du prénom. L'appelant avalait l'exception de décodage, donc rien
/// ne signalait le problème.
///
/// Ces tests verrouillent la tolérance des champs non essentiels : un dossier
/// dépourvu d'un champ facultatif doit rester CONSULTABLE.
void main() {
  /// Fiche MINIMALE : seuls les champs sans lesquels un dossier n'a pas de
  /// sens (identité, coordonnées) sont fournis.
  Map<String, dynamic> minimal() => <String, dynamic>{
    'id': 'cli-001',
    'code': 'GRX-VIP-0001',
    'fullName': 'Camille Delacroix',
    'email': 'camille@example.invalid',
    'phone': '+32470000002',
    'country': 'Belgique',
    'city': 'Bruxelles',
  };

  /// Fiche COMPLÈTE, telle que `Client.toMap()` l'écrit.
  Map<String, dynamic> complete() => <String, dynamic>{
    ...minimal(),
    'companyName': null,
    'category': 'executive',
    'secondaryContact': null,
    'language': 'Français',
    'personalAssistant': null,
    'assistantPhone': null,
    'confidentiality': 'restricted',
    'subscriptionTierId': '',
    'assignedConciergeId': null,
    'preferredHotels': <String>[],
    'preferredRestaurants': <String>[],
    'preferredDrivers': <String>[],
    'travelPreferences': <String>[],
    'dietaryPreferences': <String>[],
    'interests': <String>[],
    'notes': null,
    'active': true,
    'approvalStatus': 'approved',
    'createdAt': '2026-01-15T10:00:00.000',
    'isBusiness': false,
    'companyNumber': null,
    'vatNumber': null,
    'billingAddress': null,
    'billingEmail': null,
    'peppolEnabled': false,
  };

  group('Décodage d\'une fiche client incomplète', () {
    test('une fiche minimale est décodable (ne lève plus)', () {
      expect(() => Client.fromMap(minimal()), returnsNormally);
    });

    test('l\'identité est préservée même sans champs facultatifs', () {
      final c = Client.fromMap(minimal());
      expect(c.id, 'cli-001');
      expect(c.fullName, 'Camille Delacroix');
      expect(c.email, 'camille@example.invalid');
    });

    test('`createdAt` absent donne la sentinelle d\'époque, pas une exception',
        () {
      final c = Client.fromMap(minimal());
      expect(c.createdAt.millisecondsSinceEpoch, 0);
      expect(c.createdAt.isUtc, isTrue);
    });

    test('`createdAt` illisible ne fait pas échouer le décodage', () {
      final c = Client.fromMap({...minimal(), 'createdAt': 'pas une date'});
      expect(c.createdAt.millisecondsSinceEpoch, 0);
    });

    test('`category` null retombe sur la valeur par défaut', () {
      final c = Client.fromMap({...minimal(), 'category': null});
      expect(c.category, ClientCategory.individualVip);
    });

    test('`confidentiality` null retombe sur « standard », jamais « elevated »',
        () {
      final c = Client.fromMap({...minimal(), 'confidentiality': null});
      // Point de sécurité : une fiche incomplète ne doit pas s'auto-promouvoir
      // à un niveau de confidentialité supérieur.
      expect(c.confidentiality, ConfidentialityLevel.standard);
    });

    test('une valeur d\'énumération inconnue retombe sur la valeur par défaut',
        () {
      final c = Client.fromMap({...minimal(), 'category': 'inconnue-xyz'});
      expect(c.category, ClientCategory.individualVip);
    });
  });

  group('Décodage d\'une fiche complète : pas de régression', () {
    test('les valeurs explicites sont respectées', () {
      final c = Client.fromMap(complete());
      expect(c.category, ClientCategory.executive);
      expect(c.confidentiality, ConfidentialityLevel.restricted);
      expect(c.createdAt.year, 2026);
      expect(c.approvalStatus, ClientApprovalStatus.approved);
    });

    test('un palier vide reste vide (aucune formule attribuée d\'office)', () {
      final c = Client.fromMap(complete());
      expect(c.subscriptionTierId, isEmpty);
    });
  });

  group('Aller-retour toMap / fromMap', () {
    test('une fiche complète survit à l\'aller-retour', () {
      final original = Client.fromMap(complete());
      final round = Client.fromMap(original.toMap());
      expect(round.id, original.id);
      expect(round.fullName, original.fullName);
      expect(round.category, original.category);
      expect(round.confidentiality, original.confidentiality);
      expect(round.createdAt, original.createdAt);
    });
  });
}
