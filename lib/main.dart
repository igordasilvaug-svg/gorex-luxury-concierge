import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'widgets/animations.dart';
import 'state/app_state.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/force_password_change_screen.dart';
import 'screens/shell/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize French (Belgium) locale data so DateFormat('...', 'fr_BE')
  // works on every platform (web, Android, tests).
  await initializeDateFormatting('fr_BE', null);
  runApp(const GorexApp());
}

class GorexApp extends StatelessWidget {
  const GorexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()..init(),
      child: Consumer<AppState>(
        builder: (context, state, _) {
          return MaterialApp(
            title: 'GOREX LUXURY CONCIERGE',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.dark,
            locale: _localeFor(state.language),
            supportedLocales: const [
              Locale('fr', 'BE'),
              Locale('fr'),
              Locale('nl', 'BE'),
              Locale('nl'),
              Locale('en'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const _Root(),
          );
        },
      ),
    );
  }
}

class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  bool _splashDone = false;
  bool _remindersChecked = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    // Moteur de relance automatique : exécution au démarrage (une seule fois).
    if (state.ready && !_remindersChecked) {
      _remindersChecked = true;
      if (state.reminderConfig.enabled && state.reminderConfig.runOnStartup) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          state.runAutoReminders();
        });
      }
    }

    // Séquence d'ouverture cinématographique (une seule fois par lancement)
    if (!_splashDone) {
      return SplashScreen(
        onFinished: () {
          if (mounted) setState(() => _splashDone = true);
        },
      );
    }

    if (!state.ready) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0A0B),
        body: DashboardSkeleton(),
      );
    }
    if (state.currentUser == null) return const LoginScreen();
    if (state.currentUser!.mustChangePassword) {
      return const ForcePasswordChangeScreen();
    }
    return const AppShell();
  }
}

/// Convertit un code de langue (fr/nl/en) en Locale adaptée (BE pour fr & nl).
Locale _localeFor(String code) {
  switch (code) {
    case 'nl':
      return const Locale('nl', 'BE');
    case 'en':
      return const Locale('en');
    case 'fr':
    default:
      return const Locale('fr', 'BE');
  }
}
