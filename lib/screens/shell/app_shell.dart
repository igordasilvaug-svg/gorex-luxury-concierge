import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import 'client_shell.dart';
import 'staff_shell.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (state.isClient) return const ClientShell();
    return const StaffShell();
  }
}

/// Élément de navigation commun
class NavDestination {
  final String label;
  final IconData icon;
  final String permission;
  const NavDestination(this.label, this.icon, {this.permission = ''});
}

/// Logo de barre latérale
class SidebarBrand extends StatelessWidget {
  final VoidCallback? onTap;
  const SidebarBrand({super.key, this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: GorexBrand(compact: true),
      ),
    );
  }
}

/// Bloc utilisateur
class UserBlock extends StatelessWidget {
  final bool expanded;
  const UserBlock({super.key, this.expanded = true});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.currentUser!;
    return Row(
      children: [
        InitialsAvatar(initials: user.initials, size: 36),
        if (expanded) ...[
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.title.copyWith(fontSize: 13.5),
                ),
                const SizedBox(height: 2),
                Text(
                  user.role.label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.eyebrow.copyWith(fontSize: 9),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Déconnexion',
            icon: const Icon(Icons.logout, size: 18, color: AppColors.grey),
            onPressed: () => state.logout(),
          ),
        ],
      ],
    );
  }
}
