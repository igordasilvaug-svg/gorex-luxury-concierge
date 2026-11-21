import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:gorex_concierge/models/app_user.dart';
import 'package:gorex_concierge/models/client.dart';
import 'package:gorex_concierge/models/enums.dart';
import 'package:gorex_concierge/screens/clients/client_approvals_screen.dart';
import 'package:gorex_concierge/state/app_state.dart';
import 'package:gorex_concierge/core/theme/app_theme.dart';

Client _client({
  required String id,
  required String code,
  required String name,
  required ClientApprovalStatus status,
  bool active = true,
}) =>
    Client(
      id: id,
      code: code,
      fullName: name,
      email: '${code.toLowerCase()}@example.com',
      phone: '+32470000000',
      country: 'BE',
      city: 'Bruxelles',
      subscriptionTierId: 't1',
      confidentiality: ConfidentialityLevel.elevated,
      category: ClientCategory.individualVip,
      createdAt: DateTime.now(),
      approvalStatus: status,
      active: active,
    );

AppUser _ceo() => const AppUser(
      id: 'u1',
      fullName: 'Igor Da Silva',
      email: 'ceo@gorex-group.eu',
      password: '',
      role: UserRole.ceo,
    );

Widget _wrap(AppState state) => ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: ClientApprovalsScreen()),
      ),
    );

void main() {
  // L'application appelle initializeDateFormatting('fr_BE') dans main().
  // Un test de widget qui monte un ecran directement doit le faire aussi,
  // sinon DateFormat leve « Locale data has not been initialized ».
  setUpAll(() async {
    await initializeDateFormatting('fr_BE', null);
  });

  group('Validation des inscriptions client', () {
    test('un dossier non renseigné est considéré comme validé', () {
      // Rétrocompatibilité : les fiches créées avant cette fonctionnalité
      // n'ont pas le champ. Elles ne doivent PAS tomber en attente.
      expect(ClientApprovalStatus.fromName(null),
          ClientApprovalStatus.approved);
      expect(ClientApprovalStatus.fromName('valeur-inconnue'),
          ClientApprovalStatus.approved);
      expect(ClientApprovalStatus.fromName('pending'),
          ClientApprovalStatus.pending);
    });

    test('hasServiceAccess exige validation ET activation', () {
      final pending = _client(
          id: 'c1', code: 'GX-1', name: 'En attente',
          status: ClientApprovalStatus.pending);
      final approved = _client(
          id: 'c2', code: 'GX-2', name: 'Validé',
          status: ClientApprovalStatus.approved);
      final suspended = _client(
          id: 'c3', code: 'GX-3', name: 'Suspendu',
          status: ClientApprovalStatus.approved, active: false);
      final rejected = _client(
          id: 'c4', code: 'GX-4', name: 'Refusé',
          status: ClientApprovalStatus.rejected);

      expect(pending.hasServiceAccess, isFalse);
      expect(approved.hasServiceAccess, isTrue);
      expect(suspended.hasServiceAccess, isFalse,
          reason: 'un compte validé mais désactivé ne doit pas ouvrir l\'accès');
      expect(rejected.hasServiceAccess, isFalse);
    });

    test('le statut survit à une sérialisation aller-retour', () {
      final c = _client(
          id: 'c5', code: 'GX-5', name: 'Aller-retour',
          status: ClientApprovalStatus.pending);
      final back = Client.fromMap(c.toMap());
      expect(back.approvalStatus, ClientApprovalStatus.pending);
      expect(back.isPending, isTrue);
    });

    testWidgets('la file de validation liste les dossiers en attente et rien '
        'd\'autre', (tester) async {
      final state = AppState();
      final pending = _client(
          id: 'c1', code: 'GX-100', name: 'Awa Diallo',
          status: ClientApprovalStatus.pending);
      final approved = _client(
          id: 'c2', code: 'GX-200', name: 'Marc Leroy',
          status: ClientApprovalStatus.approved);

      // On injecte directement : ce test porte sur l'AFFICHAGE, pas sur le
      // réseau (déjà couvert par les tests de règles Firestore).
      state.clients
        ..clear()
        ..addAll([pending, approved]);
      state.currentUser = _ceo();

      await tester.pumpWidget(_wrap(state));
      await tester.pumpAndSettle();

      // La file « À traiter » ne contient QUE les dossiers en attente.
      expect(state.pendingClientApprovals.length, 1);
      expect(state.pendingClientApprovals.single.fullName, 'Awa Diallo');
      expect(state.pendingApprovalsCount, 1);

      // Les deux clients sont affichés, mais dans des sections distinctes :
      // le validé part dans l'historique « Dossiers traités », il n'encombre
      // pas la file de travail.
      expect(find.textContaining('Awa Diallo'), findsWidgets,
          reason: 'le dossier en attente doit apparaître dans la file');
      expect(find.textContaining('Marc Leroy'), findsWidgets,
          reason: 'le dossier validé apparaît dans l\'historique');

      // La section d'historique est bien rendue (SectionLabel met le titre
      // en majuscules, d'ou la recherche insensible a la casse).
      expect(
        find.byWidgetPredicate((w) =>
            w is Text &&
            (w.data ?? '').toUpperCase().contains('DOSSIERS TRAIT')),
        findsOneWidget,
        reason: 'la section historique doit exister',
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('l\'écran vide ne casse pas et invite à revenir plus tard',
        (tester) async {
      final state = AppState();
      state.clients.clear();
      state.currentUser = _ceo();

      await tester.pumpWidget(_wrap(state));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('la carte affiche l\'adresse sans dupliquer le pays',
        (tester) async {      // Non-régression sur un défaut signalé à tort puis vérifié.
      //
      // Le formulaire d'inscription ne collecte qu'un champ libre « Adresse »
      // et le range dans `city`. La carte l'affichait sous l'étiquette
      // « Localité », ce qui laissait croire à une ville. Le rendu réel a été
      // observé : « Rue de la Loi 16, Belgique » — le pays n'est PAS dupliqué.
      // Ce test fige les deux points : bonne étiquette, pas de doublon.
      final state = AppState();
      state.clients
        ..clear()
        ..add(Client(
          id: 'c9',
          code: 'GRX-VIP-0009',
          fullName: 'Client Vérification',
          email: 'verif@example.com',
          phone: '+32470000009',
          country: 'Belgique',
          city: 'Rue de la Loi 16',
          subscriptionTierId: 't1',
          confidentiality: ConfidentialityLevel.elevated,
          category: ClientCategory.individualVip,
          createdAt: DateTime(2026, 11, 21, 13, 41),
          approvalStatus: ClientApprovalStatus.pending,
        ));
      state.currentUser = _ceo();

      await tester.pumpWidget(_wrap(state));
      await tester.pumpAndSettle();

      expect(find.text('Rue de la Loi 16, Belgique'), findsOneWidget,
          reason: 'adresse suivie du pays, une seule fois');
      expect(find.textContaining('BelgiqueBelgique'), findsNothing,
          reason: 'le pays ne doit jamais être collé deux fois');
      expect(find.text('ADRESSE'), findsOneWidget,
          reason: 'l\'étiquette doit décrire le contenu réel');
      expect(find.text('LOCALITÉ'), findsNothing,
          reason: 'l\'ancienne étiquette trompeuse doit avoir disparu');
      expect(tester.takeException(), isNull);
    });

    test('un numéro provisoire n\'est pas une référence de dossier', () {
      // Le numéro DÉFINITIF est réservé côté serveur à la validation. Avant
      // cela la fiche porte « GRX-ATTENTE-… », qui n'identifie rien : deux
      // dossiers peuvent le partager. L'application doit donc savoir faire la
      // différence, sous peine d'afficher un faux numéro au client.
      final pending = _client(
        id: 'c20',
        code: 'GRX-ATTENTE-20261121134100',
        name: 'En attente',
        status: ClientApprovalStatus.pending,
      );
      final approved = _client(
        id: 'c21',
        code: 'GRX-VIP-0007',
        name: 'Validé',
        status: ClientApprovalStatus.approved,
      );

      expect(pending.hasAssignedCode, isFalse);
      expect(approved.hasAssignedCode, isTrue);
      expect(Client.provisionalCodePrefix, 'GRX-ATTENTE-');
      expect(AppState.pendingCodePrefix, Client.provisionalCodePrefix,
          reason: 'une seule définition du préfixe provisoire');
    });

    testWidgets('la file annonce un numéro à attribuer, pas un faux numéro',
        (tester) async {
      // Le validateur ne doit pas lire « GRX-ATTENTE-2026… » et le prendre
      // pour la référence du dossier. L'écran doit annoncer l'attribution.
      final state = AppState();
      state.clients
        ..clear()
        ..add(_client(
          id: 'c22',
          code: 'GRX-ATTENTE-20261121134100',
          name: 'Sans Numéro',
          status: ClientApprovalStatus.pending,
        ));
      state.currentUser = _ceo();

      await tester.pumpWidget(_wrap(state));
      await tester.pumpAndSettle();

      expect(find.text('GRX-ATTENTE-20261121134100'), findsNothing,
          reason: 'un numéro provisoire ne doit jamais être présenté');
      expect(find.text('À attribuer à la validation'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
