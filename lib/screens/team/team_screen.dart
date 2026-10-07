import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/enums.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../access/staff_access_screen.dart';

class TeamScreen extends StatelessWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final staff = s.users.where((u) => u.role.isStaff).toList();
    final grouped = <String, List>{};
    for (final u in staff) {
      grouped.putIfAbsent(u.role.department, () => []).add(u);
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Équipe & permissions',
                        style: AppTypography.displayMedium,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${staff.length} membres · rôles différenciés et permissions',
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
                if (s.can('user_access'))
                  GoldButton(
                    label: 'Gérer les accès',
                    icon: Icons.admin_panel_settings_outlined,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const Scaffold(
                          body: StaffAccessScreen(),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            const GoldDivider(width: 60),
            const SizedBox(height: 22),
            ...grouped.entries.map(
              (e) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 12),
                    child: Text(
                      e.key.toUpperCase(),
                      style: AppTypography.eyebrow.copyWith(fontSize: 9.5),
                    ),
                  ),
                  ...e.value.map(
                    (u) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: LuxuryCard(
                        child: Row(
                          children: [
                            InitialsAvatar(initials: u.initials, size: 44),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    u.fullName,
                                    style: AppTypography.title.copyWith(
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    u.title ?? u.role.label,
                                    style: AppTypography.caption,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    u.email,
                                    style: AppTypography.caption.copyWith(
                                      fontSize: 10.5,
                                      color: AppColors.champagne,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                StatusPill(
                                  label: u.role.label,
                                  color: AppColors.greyLight,
                                ),
                                if (u.role == UserRole.ceo) ...[
                                  const SizedBox(height: 6),
                                  const StatusPill(
                                    label: 'Accès total',
                                    color: AppColors.champagne,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SectionHeader(title: 'Matrice de permissions'),
            const SizedBox(height: 12),
            LuxuryCard(
              child: Column(
                children: [
                  _permRow('Finance & facturation', ['CEO', 'Finance']),
                  const Divider(height: 1),
                  _permRow('Gestion équipe', ['CEO', 'Concierge Manager']),
                  const Divider(height: 1),
                  _permRow('Abonnements', ['CEO']),
                  const Divider(height: 1),
                  _permRow('Sécurité / GOREX SECURITY', [
                    'CEO',
                    'Security Coordinator',
                    'Concierge Manager',
                  ]),
                  const Divider(height: 1),
                  _permRow('CRM', [
                    'CEO',
                    'Concierge Manager',
                    'Senior Concierge',
                    'Travel/Lifestyle Manager',
                  ]),
                  const Divider(height: 1),
                  _permRow('Demandes & réservations', [
                    'Toute l\'équipe conciergerie',
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _permRow(String label, List<String> roles) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.offWhite,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: roles
                  .map((r) => StatusPill(label: r, color: AppColors.champagne))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
