import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:gorex_concierge/core/app_config.dart';
import 'package:gorex_concierge/core/security/password_policy.dart';
import 'package:gorex_concierge/core/theme/app_theme.dart';
import 'package:gorex_concierge/screens/password_reset_screen.dart';
import 'package:gorex_concierge/state/app_state.dart';

/// Vérifications de la réinitialisation de mot de passe par lien e-mail.
///
/// Aucun appel réseau n'est effectué : les tests portent sur ce qui est
/// déterministe, à savoir la reconnaissance du code dans l'URL, la politique
/// de robustesse appliquée, et l'absence de plantage de l'écran.
void main() {
  group('URL de réinitialisation', () {
    test('reconnaît oobCode (paramètre utilisé par Firebase)', () {
      final uri = Uri.parse(
        'https://gorex-luxury-concierge.eu/?mode=resetPassword&oobCode=ABC123',
      );
      expect(AppConfig.isPasswordResetUrl(uri), isTrue);
      expect(AppConfig.resetCodeFrom(uri), 'ABC123');
    });

    test('accepte aussi code et ticket', () {
      expect(AppConfig.resetCodeFrom(Uri.parse('https://x.eu/?code=Z9')), 'Z9');
      expect(
        AppConfig.resetCodeFrom(Uri.parse('https://x.eu/?ticket=T7')),
        'T7',
      );
    });

    test('aucun code sur l\'adresse d\'accueil', () {
      final uri = Uri.parse('https://gorex-luxury-concierge.eu/');
      expect(AppConfig.isPasswordResetUrl(uri), isFalse);
      expect(AppConfig.resetCodeFrom(uri), isNull);
    });

    test('un code vide n\'est pas un code', () {
      final uri = Uri.parse('https://x.eu/?oobCode=%20');
      expect(AppConfig.isPasswordResetUrl(uri), isFalse);
    });
  });

  group('Politique de mot de passe', () {
    test('refuse un mot de passe de 10 caractères contenant « gorex »', () {
      // Ce cas est celui constaté en production : un mot de passe défini via
      // la page générique de Firebase échappe à toute longueur minimale.
      final issues = PasswordPolicy.validate('gorex@1991');
      expect(issues, isNotEmpty);
      expect(issues.join(' '), contains('${PasswordPolicy.minLength}'));
    });

    test('accepte un mot de passe conforme', () {
      expect(PasswordPolicy.validate('Roeselare-2026#Koorn'), isEmpty);
    });

    test('refuse les mots familiers et les répétitions', () {
      expect(PasswordPolicy.validate('Gorex.Concierge1!'), isNotEmpty);
      expect(PasswordPolicy.validate('Aaaa1234567!x'), isNotEmpty);
    });
  });

  group('Écran de réinitialisation', () {
    testWidgets('s\'affiche sans exception sur un écran de téléphone', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(430, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>(
          create: (_) => AppState(),
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const PasswordResetScreen(oobCode: 'CODE-INVALIDE-TEST'),
          ),
        ),
      );
      // Le code est absent de Firebase : l'écran bascule sur « lien
      // inutilisable » sans lever d'exception.
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('RETOUR À LA CONNEXION'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
