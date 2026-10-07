import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'state/app_state.dart';
import 'screens/login_screen.dart';
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
      child: MaterialApp(
        title: 'GOREX LUXURY CONCIERGE',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        locale: const Locale('fr', 'BE'),
        supportedLocales: const [Locale('fr', 'BE'), Locale('fr'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const _Root(),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (!state.ready) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(strokeWidth: 1.6),
              ),
              SizedBox(height: 22),
              Text(
                'GOREX',
                style: TextStyle(
                  letterSpacing: 8,
                  fontSize: 15,
                  color: Color(0xFFC6A15B),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return state.currentUser == null ? const LoginScreen() : const AppShell();
  }
}
