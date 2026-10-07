import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/common.dart';
import '../client/ask_gorex_screen.dart';
import '../client/client_home_screen.dart';
import '../client/client_requests_screen.dart';
import '../client/client_bookings_screen.dart';
import '../client/client_profile_screen.dart';
import '../client/client_messages_screen.dart';
import '../client/client_invoices_screen.dart';

class ClientShell extends StatefulWidget {
  const ClientShell({super.key});

  @override
  State<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends State<ClientShell> {
  int _index = 0;

  final _screens = const [
    ClientHomeScreen(),
    ClientRequestsScreen(),
    ClientBookingsScreen(),
    ClientMessagesScreen(),
    ClientProfileScreen(),
  ];

  final _destinations = const [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Accueil',
    ),
    NavigationDestination(
      icon: Icon(Icons.inbox_outlined),
      selectedIcon: Icon(Icons.inbox),
      label: 'Demandes',
    ),
    NavigationDestination(
      icon: Icon(Icons.event_available_outlined),
      selectedIcon: Icon(Icons.event_available),
      label: 'Réservations',
    ),
    NavigationDestination(
      icon: Icon(Icons.forum_outlined),
      selectedIcon: Icon(Icons.forum),
      label: 'Concierge',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: 'Profil',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const GorexBrand(compact: true),
        actions: [
          IconButton(
            tooltip: 'Factures & documents',
            icon: const Icon(Icons.receipt_long_outlined, size: 20),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ClientInvoicesScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Agenda',
            icon: const Icon(Icons.calendar_month_outlined, size: 20),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ClientAgendaScreen()),
            ),
          ),
        ],
      ),
      body: _screens[_index],
      floatingActionButton: _index == 0
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.champagne,
              foregroundColor: AppColors.black,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AskGorexScreen()),
              ),
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text(
                'ASK GOREX',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: _destinations,
      ),
    );
  }
}
