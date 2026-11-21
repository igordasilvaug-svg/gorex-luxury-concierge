// GOREX LUXURY CONCIERGE — Circuit d'abonnement : les garanties qui comptent.
//
// Ces tests ne vérifient pas du code de présentation : ils vérifient que
// l'application ne peut PAS affirmer ni enregistrer un abonnement qui n'existe
// pas, et qu'aucun montant ne peut devenir exigible tant que l'ouverture
// commerciale n'est pas décidée.
//
// C'est exactement le défaut qui a motivé ce travail : tout nouvel inscrit
// recevait un palier attribué d'office et son profil l'affichait comme un
// « Contrat annuel » de plusieurs milliers d'euros, alors qu'il n'avait rien
// demandé, rien signé et rien payé.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:gorex_concierge/core/billing/subscription_policy.dart';
import 'package:gorex_concierge/core/theme/app_theme.dart';
import 'package:gorex_concierge/models/app_user.dart';
import 'package:gorex_concierge/models/client.dart';
import 'package:gorex_concierge/models/enums.dart';
import 'package:gorex_concierge/models/subscription.dart';
import 'package:gorex_concierge/screens/client/client_profile_screen.dart';
import 'package:gorex_concierge/state/app_state.dart';

Client _client({
  String tierId = '',
  ClientApprovalStatus approval = ClientApprovalStatus.approved,
}) => Client(
  id: 'c1',
  code: 'GRX-VIP-0001',
  fullName: 'Camille Dupont',
  email: 'camille@example.com',
  phone: '+32470000000',
  country: 'Belgique',
  city: 'Bruxelles',
  subscriptionTierId: tierId,
  confidentiality: ConfidentialityLevel.elevated,
  category: ClientCategory.individualVip,
  createdAt: DateTime.now(),
  approvalStatus: approval,
  active: true,
);

AppUser _clientUser() => const AppUser(
  id: 'u1',
  fullName: 'Camille Dupont',
  email: 'camille@example.com',
  password: '',
  role: UserRole.vipClient,
  clientId: 'c1',
);

/// Prépare un état avec un client validé et une session cliente ouverte.
AppState _stateWithClient({
  String tierId = '',
  ClientApprovalStatus approval = ClientApprovalStatus.approved,
}) {
  final s = AppState();
  s.clients = [_client(tierId: tierId, approval: approval)];
  s.currentUser = _clientUser();
  return s;
}

Widget _wrapProfile(AppState state) => ChangeNotifierProvider<AppState>.value(
  value: state,
  child: MaterialApp(
    theme: AppTheme.dark,
    home: const Scaffold(body: ClientProfileScreen()),
  ),
);

void main() {
  // Le profil formate des dates en français : sans cette initialisation,
  // DateFormat lève « Locale data has not been initialized ».
  setUpAll(() async {
    await initializeDateFormatting('fr_BE', null);
  });

  group("Interrupteur d'ouverture commerciale", () {
    // NOTE : l'interrupteur est désormais OUVERT (décision de direction du
    // 21/11/2026). Les tests ne verrouillent donc plus la valeur `false` —
    // ce serait tester une décision commerciale, pas du code. Ils vérifient
    // les GARANTIES, qui doivent tenir dans les deux états : c'est cela qui
    // empêche un client de s'attribuer un abonnement facturable.
    test("l'interrupteur et le verrou de facturation ne divergent pas", () {
      // Deux verrous existent (souscription ouverte / activation possible).
      // S'ils divergeaient, un abonnement pourrait être déposé sans jamais
      // pouvoir être activé — ou l'inverse, ce qui serait pire.
      expect(
        SubscriptionPolicy.canActivateBilling,
        SubscriptionPolicy.subscriptionsOpen,
      );
    });

    test('le message de fermeture ne promet pas ce que le code interdit', () {
      // La première rédaction annonçait « vous pouvez déjà déposer vos
      // demandes » alors que requestSubscription() refusait. Une phrase qui
      // annonce ce que le code interdit est un mensonge.
      expect(
        SubscriptionPolicy.closedNotice.toLowerCase(),
        contains('n\'est pas encore ouverte'),
      );
      expect(
        SubscriptionPolicy.closedNotice.toLowerCase(),
        isNot(contains('vous pouvez déjà déposer')),
      );
    });

    test('une demande non approuvée ne devient JAMAIS facturable', () async {
      // Invariante indépendante de l'interrupteur : seul un abonnement
      // explicitement approuvé par Gorex peut être activé. Une demande
      // `requested` déposée par le client ne peut pas se transformer seule
      // en contrat prélevable.
      final s = _stateWithClient(tierId: 'tier_essential');
      s.subscriptions = [
        Subscription(
          id: 'sub-req',
          clientId: 'c1',
          clientEmail: 'camille@example.com',
          tierId: 'tier_essential',
          tierName: 'GOREX ESSENTIAL',
          cycle: BillingCycle.annual,
          amount: 4800,
          status: SubscriptionStatus.requested,
          requestedAt: DateTime.now(),
        ),
      ];
      final activated = await s.activateSubscriptionIfReady('c1');
      expect(activated, isFalse);
      expect(
        s.subscriptionForClient('c1')!.status,
        SubscriptionStatus.requested,
      );
      expect(s.subscriptionForClient('c1')!.isBillable, isFalse);
    });

    test('une demande déposée sans accès aux services est refusée', () async {
      // Invariante : même interrupteur ouvert, un dossier non validé ne peut
      // pas souscrire. Un refus qui laisserait une trace locale ferait croire
      // à l'utilisateur que sa demande est partie.
      final s = _stateWithClient(
        tierId: 'tier_essential',
        approval: ClientApprovalStatus.pending,
      );
      await expectLater(
        s.requestSubscription(
          clientId: 'c1',
          tierId: 'tier_essential',
          cycle: BillingCycle.annual,
        ),
        throwsA(isA<Exception>()),
      );
      expect(s.subscriptions, isEmpty);
    });
  });

  group('Un palier attribué d\'office n\'est pas un abonnement', () {
    test('un client sans contrat n\'a aucun abonnement', () {
      // Le cas réel : la fiche porte une formule de référence (choisie ou
      // héritée), mais aucun document `subscriptions` n'existe.
      final s = _stateWithClient(tierId: 'tier_essential');
      expect(s.mySubscription, isNull);
      expect(s.subscriptionForClient('c1'), isNull);
    });

    test('une formule de référence vide ne casse pas le décodage', () {
      // « À définir avec mon concierge » produit une chaîne vide. Un cast
      // direct aurait fait échouer le décodage de la fiche ENTIÈRE, donc
      // empêché la connexion pour un champ facultatif.
      final map = _client(tierId: '').toMap();
      map['subscriptionTierId'] = null;
      final decoded = Client.fromMap(map);
      expect(decoded.subscriptionTierId, '');
    });
  });

  group('États d\'un abonnement', () {
    test('un état inconnu ou absent retombe sur « demande », jamais « actif »', () {
      // Garde-fou de facturation : une donnée corrompue ou ancienne ne doit
      // jamais produire un abonnement facturable.
      expect(SubscriptionStatus.fromName(null), SubscriptionStatus.requested);
      expect(
        SubscriptionStatus.fromName('n-importe-quoi'),
        SubscriptionStatus.requested,
      );
      expect(
        SubscriptionStatus.fromName('n-importe-quoi').isBillable,
        isFalse,
      );
    });

    test('seul l\'état actif est facturable', () {
      for (final st in SubscriptionStatus.values) {
        expect(
          st.isBillable,
          st == SubscriptionStatus.active,
          reason: 'état ${st.name}',
        );
      }
    });

    test('le montant affiché porte le rythme réellement convenu', () {
      final annual = Subscription(
        id: 's',
        clientId: 'c1',
        clientEmail: 'a@b.c',
        tierId: 't',
        tierName: 'T',
        cycle: BillingCycle.annual,
        amount: 4800,
        requestedAt: DateTime.now(),
      );
      expect(annual.amountLabel, '4800 € / an');
      final monthly = annual.copyWith(cycle: BillingCycle.monthly, amount: 450);
      expect(monthly.amountLabel, '450 € / mois');
    });

    test('une demande refusée n\'est pas facturable', () {
      final s = _stateWithClient(tierId: 'tier_essential');
      s.subscriptions = [
        Subscription(
          id: 'sub1',
          clientId: 'c1',
          clientEmail: 'camille@example.com',
          tierId: 'tier_essential',
          tierName: 'GOREX ESSENTIAL',
          cycle: BillingCycle.annual,
          amount: 4800,
          status: SubscriptionStatus.ended,
          requestedAt: DateTime.now(),
        ),
      ];
      expect(s.mySubscription!.isBillable, isFalse);
    });
  });

  group('Mandat SEPA signé par le débiteur', () {
    test('la signature est refusée sans accord explicite', () async {
      final s = _stateWithClient();
      await expectLater(
        s.signMandateAsClient(
          accountHolder: 'Camille Dupont',
          iban: 'BE68539007547034',
          acceptedTerms: false,
        ),
        throwsA(isA<Exception>()),
      );
      expect(s.sepaMandates, isEmpty);
    });

    test('la signature est refusée si le dossier n\'est pas validé', () async {
      final s = _stateWithClient();
      s.clients = [
        Client(
          id: 'c1',
          code: 'GRX-ATTENTE-1',
          fullName: 'Camille Dupont',
          email: 'camille@example.com',
          phone: '+32470000000',
          country: 'Belgique',
          city: 'Bruxelles',
          subscriptionTierId: '',
          confidentiality: ConfidentialityLevel.elevated,
          category: ClientCategory.individualVip,
          createdAt: DateTime.now(),
          approvalStatus: ClientApprovalStatus.pending,
          active: true,
        ),
      ];
      await expectLater(
        s.signMandateAsClient(
          accountHolder: 'Camille Dupont',
          iban: 'BE68539007547034',
          acceptedTerms: true,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('un IBAN invalide est refusé', () async {
      final s = _stateWithClient();
      await expectLater(
        s.signMandateAsClient(
          accountHolder: 'Camille Dupont',
          iban: 'BE00 0000 0000 0000',
          acceptedTerms: true,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('sans mandat actif, aucun prélèvement n\'est possible', () {
      final s = _stateWithClient();
      expect(s.mandateForClient('c1'), isNull);
      expect(s.canDebitClient('c1'), isFalse);
    });
  });

  group('Le profil client ne ment plus', () {
    testWidgets('sans abonnement, le profil annonce « aucun abonnement »', (
      tester,
    ) async {
      // Le client porte une formule de référence (comme tout inscrit
      // aujourd'hui) mais n'a signé aucun contrat.
      final s = _stateWithClient(tierId: 'tier_essential');
      await tester.pumpWidget(_wrapProfile(s));
      await tester.pumpAndSettle();

      expect(find.textContaining('Aucun abonnement en cours'), findsOneWidget);
      expect(find.text('AUCUN ABONNEMENT'), findsOneWidget);
    });

    testWidgets('sans abonnement, aucun montant contractuel n\'est affiché', (
      tester,
    ) async {
      final s = _stateWithClient(tierId: 'tier_essential');
      await tester.pumpWidget(_wrapProfile(s));
      await tester.pumpAndSettle();

      // Le défaut d'origine : la mention « Contrat annuel » et un montant.
      expect(find.textContaining('Contrat annuel'), findsNothing);
      expect(find.textContaining('GOREX ESSENTIAL'), findsNothing);
    });

    testWidgets('avec un contrat réel, le montant affiché est celui convenu', (
      tester,
    ) async {
      final s = _stateWithClient(tierId: 'tier_essential');
      s.subscriptions = [
        Subscription(
          id: 'sub1',
          clientId: 'c1',
          clientEmail: 'camille@example.com',
          tierId: 'tier_essential',
          tierName: 'GOREX EXECUTIVE',
          cycle: BillingCycle.monthly,
          amount: 1350,
          status: SubscriptionStatus.requested,
          requestedAt: DateTime(2026, 1, 5),
        ),
      ];
      await tester.pumpWidget(_wrapProfile(s));
      await tester.pumpAndSettle();

      // Le nom apparaît deux fois volontairement : la pastille d'état en
      // majuscules et le titre de la carte. On vérifie donc sa présence, pas
      // son unicité.
      expect(find.textContaining('GOREX EXECUTIVE'), findsAtLeastNWidgets(1));
      expect(find.textContaining('1350 € / mois'), findsOneWidget);
      expect(find.textContaining('Aucun abonnement en cours'), findsNothing);
      // Une demande n'est pas une facturation : l'écran doit le dire.
      expect(find.textContaining('Demande envoyée'), findsOneWidget);
    });
  });
}
