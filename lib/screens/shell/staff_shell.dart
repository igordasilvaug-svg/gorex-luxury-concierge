import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';

import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/language_selector.dart';
import '../dashboard/ceo_dashboard.dart';
import '../dashboard/concierge_dashboard.dart';
import '../requests/requests_screen.dart';
import '../services/services_screen.dart';
import '../itineraries/itineraries_screen.dart';
import '../bookings/bookings_screen.dart';
import '../providers/providers_screen.dart';
import '../finance/finance_screen.dart';
import '../finance/accounting_screen.dart';
import '../crm/crm_screen.dart';
import '../agenda/agenda_screen.dart';
import '../communication/communication_screen.dart';
import '../team/team_screen.dart';
import '../access/staff_access_screen.dart';
import '../audit/audit_log_screen.dart';
import '../backup/backup_screen.dart';
import '../security/security_dashboard_screen.dart';
import '../clients/clients_screen.dart';
import '../settings/company_settings_screen.dart';
import '../settings/peppol_settings_screen.dart';
import '../settings/reminder_settings_screen.dart';
import '../legal/privacy_policy_screen.dart';
import '../legal/user_guide_screen.dart';
import '../legal/legal_hub_screen.dart';
import '../about/about_screen.dart';
import '../subscriptions/subscriptions_screen.dart';
import 'app_shell.dart';

class StaffShell extends StatefulWidget {
  const StaffShell({super.key});

  @override
  State<StaffShell> createState() => _StaffShellState();
}

class _StaffShellState extends State<StaffShell> {
  int _index = 0;

  List<_NavItem> _items(AppState s) {
    final all = <_NavItem>[
      _NavItem(
        s.tr('nav.dashboard'),
        Icons.dashboard_outlined,
        Icons.dashboard,
        s.isCeo ? const CeoDashboard() : const ConciergeDashboard(),
      ),
      _NavItem(
        s.tr('nav.requests'),
        Icons.inbox_outlined,
        Icons.inbox,
        const RequestsScreen(),
        permission: 'staff',
      ),
      _NavItem(
        s.tr('nav.services'),
        Icons.room_service_outlined,
        Icons.room_service,
        const ServicesScreen(),
        permission: 'staff',
      ),
      _NavItem(
        s.tr('nav.itineraries'),
        Icons.map_outlined,
        Icons.map,
        const ItinerariesScreen(),
        permission: 'staff',
      ),
      _NavItem(
        s.tr('nav.bookings'),
        Icons.event_available_outlined,
        Icons.event_available,
        const BookingsScreen(),
        permission: 'staff',
      ),
      _NavItem(
        s.tr('nav.providers'),
        Icons.handshake_outlined,
        Icons.handshake,
        const ProvidersScreen(),
        permission: 'staff',
      ),
      _NavItem(
        s.tr('nav.clients'),
        Icons.people_outline,
        Icons.people,
        const ClientsScreen(),
        permission: 'staff',
      ),
      _NavItem(
        s.tr('nav.finance'),
        Icons.account_balance_outlined,
        Icons.account_balance,
        const FinanceScreen(),
        permission: 'finance',
      ),
      _NavItem(
        s.tr('nav.accounting'),
        Icons.receipt_long_outlined,
        Icons.receipt_long,
        const AccountingScreen(),
        permission: 'finance',
      ),
      _NavItem(
        s.tr('nav.company_settings'),
        Icons.apartment_outlined,
        Icons.apartment,
        const CompanySettingsScreen(),
        permission: 'finance',
      ),
      _NavItem(
        s.tr('nav.peppol'),
        Icons.cloud_outlined,
        Icons.cloud,
        const PeppolSettingsScreen(),
        permission: 'finance',
      ),
      _NavItem(
        s.tr('nav.reminders'),
        Icons.notifications_active_outlined,
        Icons.notifications_active,
        const ReminderSettingsScreen(),
        permission: 'finance',
      ),
      _NavItem(
        s.tr('nav.crm'),
        Icons.trending_up_outlined,
        Icons.trending_up,
        const CrmScreen(),
        permission: 'crm',
      ),
      _NavItem(
        s.tr('nav.agenda'),
        Icons.calendar_month_outlined,
        Icons.calendar_month,
        const AgendaScreen(),
        permission: 'staff',
      ),
      _NavItem(
        s.tr('nav.communication'),
        Icons.forum_outlined,
        Icons.forum,
        const CommunicationScreen(),
        permission: 'staff',
      ),
      _NavItem(
        s.tr('nav.team'),
        Icons.badge_outlined,
        Icons.badge,
        const TeamScreen(),
        permission: 'team',
      ),
      _NavItem(
        s.tr('nav.access'),
        Icons.admin_panel_settings_outlined,
        Icons.admin_panel_settings,
        const StaffAccessScreen(),
        permission: 'user_access',
      ),
      _NavItem(
        s.tr('nav.subscriptions'),
        Icons.workspace_premium_outlined,
        Icons.workspace_premium,
        const SubscriptionsScreen(),
        permission: 'subscriptions',
      ),
      _NavItem(
        s.tr('nav.audit'),
        Icons.history_outlined,
        Icons.history,
        const AuditLogScreen(),
        permission: 'user_access',
      ),
      _NavItem(
        s.tr('nav.security'),
        Icons.shield_outlined,
        Icons.shield,
        const SecurityDashboardScreen(),
        permission: 'security',
      ),
      _NavItem(
        s.tr('nav.backup'),
        Icons.cloud_sync_outlined,
        Icons.cloud_sync,
        const BackupScreen(),
        permission: 'user_access',
      ),
      _NavItem(
        s.tr('nav.guide'),
        Icons.menu_book_outlined,
        Icons.menu_book,
        const UserGuideScreen(),
      ),
      _NavItem(
        s.tr('nav.legal'),
        Icons.gavel_outlined,
        Icons.gavel,
        const LegalHubScreen(),
      ),
      _NavItem(
        s.tr('nav.privacy'),
        Icons.privacy_tip_outlined,
        Icons.privacy_tip,
        const PrivacyPolicyScreen(),
      ),
      _NavItem(
        s.tr('nav.about'),
        Icons.info_outline,
        Icons.info,
        const AboutScreen(),
      ),
    ];
    return all
        .where((e) => e.permission.isEmpty || s.can(e.permission))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final items = _items(state);
    if (_index >= items.length) _index = 0;

    final wide = MediaQuery.of(context).size.width >= 900;

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            _Sidebar(
              items: items,
              index: _index,
              onSelect: (i) => setState(() => _index = i),
            ),
            const VerticalDivider(width: 1, color: AppColors.divider),
            Expanded(child: items[_index].screen),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const GorexBrand(compact: true),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.logout, size: 18),
              onPressed: () => state.logout(),
            ),
          ],
        ),
      ),
      drawer: Drawer(
        backgroundColor: AppColors.blackSoft,
        child: SafeArea(
          child: Column(
            children: [
              const Padding(padding: EdgeInsets.all(16), child: SidebarBrand()),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: items.asMap().entries.map((e) {
                    final selected = e.key == _index;
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        e.value.icon,
                        size: 19,
                        color: selected ? AppColors.champagne : AppColors.grey,
                      ),
                      title: Text(
                        e.value.label,
                        style: TextStyle(
                          fontSize: 13,
                          color: selected
                              ? AppColors.champagne
                              : AppColors.greyLight,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                      onTap: () {
                        setState(() => _index = e.key);
                        Navigator.pop(context);
                      },
                    );
                  }).toList(),
                ),
              ),
              const Divider(height: 1),
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: LanguageSelector(),
              ),
              const Padding(padding: EdgeInsets.all(12), child: UserBlock()),
            ],
          ),
        ),
      ),
      body: items[_index].screen,
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Widget screen;
  final String permission;
  _NavItem(
    this.label,
    this.icon,
    this.activeIcon,
    this.screen, {
    this.permission = '',
  });
}

class _Sidebar extends StatelessWidget {
  final List<_NavItem> items;
  final int index;
  final ValueChanged<int> onSelect;
  const _Sidebar({
    required this.items,
    required this.index,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      color: AppColors.blackSoft,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 22, 20, 18),
              child: SidebarBrand(),
            ),
            const GoldDivider(width: 210),
            const SizedBox(height: 6),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final it = items[i];
                  final selected = i == index;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 1,
                    ),
                    child: InkWell(
                      onTap: () => onSelect(i),
                      borderRadius: BorderRadius.circular(3),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.champagne.withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(3),
                          border: Border(
                            left: BorderSide(
                              color: selected
                                  ? AppColors.champagne
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selected ? it.activeIcon : it.icon,
                              size: 18,
                              color: selected
                                  ? AppColors.champagne
                                  : AppColors.grey,
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Text(
                                it.label,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  letterSpacing: 0.3,
                                  color: selected
                                      ? AppColors.champagne
                                      : AppColors.greyLight,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: LanguageSelector(),
            ),
            const Padding(padding: EdgeInsets.all(14), child: UserBlock()),
          ],
        ),
      ),
    );
  }
}
