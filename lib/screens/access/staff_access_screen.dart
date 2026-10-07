import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/app_user.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import 'member_form_screen.dart';

/// Gestion des accès personnel & clients — réservé à la Direction / Manager
class StaffAccessScreen extends StatefulWidget {
  const StaffAccessScreen({super.key});

  @override
  State<StaffAccessScreen> createState() => _StaffAccessScreenState();
}

class _StaffAccessScreenState extends State<StaffAccessScreen> {
  String _query = '';
  String _filter = 'Tous'; // Tous | Actifs | Inactifs

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();

    if (!s.can('user_access')) {
      return const SafeArea(
        child: EmptyState(
          icon: Icons.lock_outline,
          title: 'Accès restreint',
          message:
              'La gestion des accès est réservée à la Direction et au Luxury Concierge Manager.',
        ),
      );
    }

    var list = [...s.staffUsers, ...s.clientUsers];
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list
          .where(
            (u) =>
                u.fullName.toLowerCase().contains(q) ||
                u.email.toLowerCase().contains(q) ||
                u.role.label.toLowerCase().contains(q),
          )
          .toList();
    }
    if (_filter == 'Actifs') {
      list = list.where((u) => u.active).toList();
    } else if (_filter == 'Inactifs') {
      list = list.where((u) => !u.active).toList();
    }

    final activeCount = s.users.where((u) => u.active).length;
    final staffCount = s.staffUsers.length;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
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
                            'Accès personnel',
                            style: AppTypography.displayMedium,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '$staffCount collaborateurs · $activeCount accès actifs',
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                    ),
                    GoldButton(
                      label: 'Nouvel accès',
                      icon: Icons.person_add_alt,
                      onPressed: () => _openForm(context),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const GoldDivider(width: 60),
                const SizedBox(height: 16),
                TextField(
                  onChanged: (v) => setState(() => _query = v),
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.white,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Rechercher un collaborateur ou un client...',
                    prefixIcon: Icon(
                      Icons.search,
                      size: 18,
                      color: AppColors.grey,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: ['Tous', 'Actifs', 'Inactifs']
                      .map(
                        (f) => FilterChipLux(
                          label: f,
                          selected: _filter == f,
                          onTap: () => setState(() => _filter = f),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? const EmptyState(
                    icon: Icons.no_accounts_outlined,
                    title: 'Aucun accès',
                    message:
                        'Créez le premier accès personnel pour votre équipe.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 6, 24, 24),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _AccessCard(
                      user: list[i],
                      onEdit: () => _openForm(context, existing: list[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _openForm(BuildContext context, {AppUser? existing}) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MemberFormScreen(existing: existing),
      ),
    );
    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existing == null ? 'Accès créé avec succès.' : 'Accès mis à jour.',
          ),
        ),
      );
    }
  }
}

class _AccessCard extends StatelessWidget {
  final AppUser user;
  final VoidCallback onEdit;
  const _AccessCard({required this.user, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final client = s.clientById(user.clientId);
    final isMe = s.currentUser?.id == user.id;

    return LuxuryCard(
      onTap: () => _showDetail(context, s),
      borderColor: user.active ? null : AppColors.divider,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialsAvatar(
                initials: user.initials,
                size: 44,
                color: user.active ? AppColors.champagne : AppColors.grey,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.fullName,
                            style: AppTypography.title.copyWith(fontSize: 15),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 8),
                          const StatusPill(
                            label: 'Vous',
                            color: AppColors.champagne,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.title ?? user.role.label,
                      style: AppTypography.caption,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
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
                    label: user.active ? 'Actif' : 'Désactivé',
                    color: user.active
                        ? AppColors.statusConfirmed
                        : AppColors.statusCancelled,
                    icon: user.active
                        ? Icons.check_circle_outline
                        : Icons.block,
                  ),
                  const SizedBox(height: 6),
                  StatusPill(
                    label: user.role.label,
                    color: AppColors.greyLight,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _meta(Icons.apartment_outlined, user.role.department),
              if (user.phone != null) _meta(Icons.phone_outlined, user.phone!),
              if (client != null)
                _meta(Icons.link, 'Client · ${client.code}'),
              if (user.mustChangePassword)
                _meta(
                  Icons.key_outlined,
                  'Mot de passe à changer',
                ),
              if (user.lastLogin != null)
                _meta(Icons.login, 'Dernière connexion : ${_fmt(user.lastLogin!)}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String t) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: AppColors.grey),
      const SizedBox(width: 5),
      Text(t, style: AppTypography.caption.copyWith(fontSize: 10.5)),
    ],
  );

  static String _fmt(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  void _showDetail(BuildContext context, AppState s) {
    final client = s.clientById(user.clientId);
    final isMe = s.currentUser?.id == user.id;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceElevated,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.78,
        maxChildSize: 0.95,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  InitialsAvatar(
                    initials: user.initials,
                    size: 52,
                    color: user.active ? AppColors.champagne : AppColors.grey,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.fullName, style: AppTypography.headline),
                        Text(user.role.label, style: AppTypography.caption),
                      ],
                    ),
                  ),
                  StatusPill(
                    label: user.active ? 'Actif' : 'Désactivé',
                    color: user.active
                        ? AppColors.statusConfirmed
                        : AppColors.statusCancelled,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              LuxuryCard(
                child: Column(
                  children: [
                    InfoRow(label: 'E-mail', value: user.email),
                    const Divider(height: 1),
                    InfoRow(label: 'Rôle', value: user.role.label),
                    const Divider(height: 1),
                    InfoRow(label: 'Département', value: user.role.department),
                    if (user.title != null) ...[
                      const Divider(height: 1),
                      InfoRow(label: 'Fonction', value: user.title!),
                    ],
                    if (user.phone != null) ...[
                      const Divider(height: 1),
                      InfoRow(label: 'Téléphone', value: user.phone!),
                    ],
                    if (client != null) ...[
                      const Divider(height: 1),
                      InfoRow(
                        label: 'Client lié',
                        value: '${client.fullName} · ${client.code}',
                      ),
                    ],
                    const Divider(height: 1),
                    InfoRow(
                      label: 'Créé le',
                      value: user.createdAt != null
                          ? _fmt(user.createdAt!)
                          : '—',
                    ),
                    const Divider(height: 1),
                    InfoRow(
                      label: 'Dernière connexion',
                      value: user.lastLogin != null
                          ? _fmt(user.lastLogin!)
                          : 'Jamais',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SectionHeader(title: 'Gestion du compte'),
              const SizedBox(height: 12),
              GoldButton(
                label: 'Modifier l\'accès',
                icon: Icons.edit_outlined,
                fullWidth: true,
                onPressed: () {
                  Navigator.of(context).pop();
                  onEdit();
                },
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _resetPassword(context, s),
                icon: const Icon(Icons.key_outlined, size: 15),
                label: const Text('RÉINITIALISER LE MOT DE PASSE'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: isMe ? null : () => _toggleActive(context, s),
                icon: Icon(
                  user.active
                      ? Icons.block
                      : Icons.check_circle_outline,
                  size: 15,
                ),
                label: Text(
                  user.active ? 'DÉSACTIVER L\'ACCÈS' : 'RÉACTIVER L\'ACCÈS',
                ),
              ),
              if (!isMe) ...[
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: () => _confirmDelete(context, s),
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 15,
                    color: AppColors.urgent,
                  ),
                  label: const Text(
                    'SUPPRIMER DÉFINITIVEMENT',
                    style: TextStyle(color: AppColors.urgent),
                  ),
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleActive(BuildContext context, AppState s) async {
    Navigator.of(context).pop();
    await s.setUserActive(user.id, !user.active);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            user.active
                ? 'Accès désactivé pour ${user.fullName}.'
                : 'Accès réactivé pour ${user.fullName}.',
          ),
        ),
      );
    }
  }

  Future<void> _resetPassword(BuildContext context, AppState s) async {
    final controller = TextEditingController(text: _genPassword());
    final newPass = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Réinitialiser le mot de passe'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Un nouveau mot de passe temporaire sera défini. ${user.fullName} devra le changer à sa prochaine connexion.',
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.white,
              ),
              decoration: const InputDecoration(labelText: 'Nouveau mot de passe'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (newPass == null || newPass.length < 6) return;
    await s.resetUserPassword(user.id, newPass);
    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mot de passe réinitialisé pour ${user.fullName}.'),
        ),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, AppState s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer l\'accès'),
        content: Text(
          'Confirmez-vous la suppression définitive de l\'accès de ${user.fullName} ? Cette action est irréversible.',
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.urgent,
              foregroundColor: AppColors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await s.deleteUser(user.id);
    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Accès supprimé : ${user.fullName}.')),
      );
    }
  }

  static String _genPassword() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';
    final rnd = DateTime.now().microsecondsSinceEpoch;
    final sb = StringBuffer();
    var x = rnd;
    for (var i = 0; i < 10; i++) {
      sb.write(chars[x % chars.length]);
      x = x ~/ 3 + 7 * (i + 1);
    }
    return sb.toString();
  }
}
