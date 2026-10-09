import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gorex_concierge/core/firebase/firebase_bootstrap.dart';
import 'package:gorex_concierge/core/firebase/firestore_service.dart';
import 'package:gorex_concierge/core/firebase/firebase_options.dart';
import 'package:gorex_concierge/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DefaultFirebaseOptions', () {
    test('expose une configuration non vide (Android & Web)', () {
      expect(DefaultFirebaseOptions.android.projectId, 'gorex-concierge');
      expect(DefaultFirebaseOptions.android.appId, isNotEmpty);
      expect(DefaultFirebaseOptions.android.apiKey, isNotEmpty);
      expect(DefaultFirebaseOptions.web.projectId, 'gorex-concierge');
      expect(DefaultFirebaseOptions.web.authDomain, isNotEmpty);
      expect(DefaultFirebaseOptions.currentPlatform.projectId, 'gorex-concierge');
    });

    test('le package Android correspond à google-services.json', () {
      // Le appId Android encode le package_name : 1:724339415341:android:...
      expect(
        DefaultFirebaseOptions.android.appId.startsWith(
          '1:724339415341:android:',
        ),
        isTrue,
      );
    });
  });

  group('FirestoreService (défensif, sans Firebase)', () {
    test('expose les 11 collections du backend GOREX', () {
      expect(FirestoreService.collections.length, 11);
      expect(FirestoreService.collections, contains('clients'));
      expect(FirestoreService.collections, contains('requests'));
      expect(FirestoreService.collections, contains('audit_log'));
    });

    test('available reflète l\'état du bootstrap', () {
      expect(FirestoreService.available, FirebaseBootstrap.available);
    });

    test('ping retourne false sans Firebase', () async {
      final ok = await FirestoreService.ping();
      expect(ok, false);
    });

    test('pushState lève CloudException sans Firebase', () async {
      if (FirebaseBootstrap.available) return; // skip si Firebase actif
      expect(
        () => FirestoreService.pushState(const {}),
        throwsA(isA<CloudException>()),
      );
    });

    test('pullState lève CloudException sans Firebase', () async {
      if (FirebaseBootstrap.available) return;
      expect(
        () => FirestoreService.pullState(),
        throwsA(isA<CloudException>()),
      );
    });

    test('collectionCounts lève CloudException sans Firebase', () async {
      if (FirebaseBootstrap.available) return;
      expect(
        () => FirestoreService.collectionCounts(),
        throwsA(isA<CloudException>()),
      );
    });

    test('watchState émet un flux vide sans Firebase', () async {
      final events = await FirestoreService.watchState().toList();
      expect(events, isEmpty);
    });

    test('watchCollectionCount émet un flux vide sans Firebase', () async {
      final events = await FirestoreService.watchCollectionCount(
        'clients',
      ).toList();
      expect(events, isEmpty);
    });

    test('watchCollection émet un flux vide sans Firebase', () async {
      final events = await FirestoreService.watchCollection('clients').toList();
      expect(events, isEmpty);
    });
  });

  group('FirebaseBootstrap', () {
    test('init ne lève jamais d\'exception', () async {
      // En environnement de test, l'init doit échouer proprement.
      await FirebaseBootstrap.init();
      expect(FirebaseBootstrap.available, isA<bool>());
    });
  });

  group('AppState — synchronisation temps réel (défensif)', () {
    test('startLiveSync retourne false sans Firebase', () {
      final s = AppState();
      expect(s.liveSyncEnabled, isFalse);
      final ok = s.startLiveSync();
      expect(ok, isFalse); // Firebase indisponible en test
      expect(s.liveSyncEnabled, isFalse);
    });

    test('stopLiveSync est sûr même sans abonnement', () async {
      final s = AppState();
      await s.stopLiveSync();
      expect(s.liveSyncEnabled, isFalse);
    });

    test('importMap closeSession=false conserve la session', () async {
      final s = AppState();
      await s.init();
      final user = s.users.firstWhere((u) => u.role.isStaff);
      s.currentUser = user;
      final snap = s.exportState();
      await s.importMap(snap, closeSession: false);
      expect(s.currentUser, isNotNull);
      expect(s.currentUser!.id, user.id);
    });

    test('importMap closeSession=true clôt la session', () async {
      final s = AppState();
      await s.init();
      s.currentUser = s.users.first;
      final snap = s.exportState();
      await s.importMap(snap);
      expect(s.currentUser, isNull);
    });
  });
}
