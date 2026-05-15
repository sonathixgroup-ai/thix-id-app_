import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/presentation/admin/admin_routes.dart';
import 'package:thix_id/services/admin_rbac_service.dart';
import 'package:thix_id/theme.dart';

/// Responsive Admin layout (web-first): sidebar + topbar + content.
///
/// - Mobile: Drawer navigation
/// - Tablet/Desktop: NavigationRail sidebar
class AdminShell extends StatefulWidget {
  final AdminModule module;
  final Widget child;
  final String? role;

  const AdminShell({super.key, required this.module, required this.child, required this.role});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 1000;
    final isTablet = width >= 720;

    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: AdminCyberColors.black,
        cardTheme: Theme.of(context).cardTheme.copyWith(
              color: AdminCyberColors.panel,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                side: const BorderSide(color: AdminCyberColors.stroke, width: 1),
              ),
            ),
      ),
      child: Scaffold(
        drawer: (!isTablet) ? Drawer(child: _AdminDrawer(module: widget.module, role: widget.role)) : null,
        body: Stack(
          children: [
            const _AdminBackground(),
            SafeArea(
              child: Row(
                children: [
                  if (isTablet) _AdminSidebarRail(module: widget.module, role: widget.role),
                  Expanded(
                    child: Column(
                      children: [
                        AdminTopBar(
                          isDesktop: isDesktop,
                          role: widget.role,
                          searchController: _searchController,
                          searchFocus: _searchFocus,
                        ),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            child: KeyedSubtree(
                              key: ValueKey(widget.module.slug),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
                                child: widget.child,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminBackground extends StatelessWidget {
  const _AdminBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: const BoxDecoration(color: AdminCyberColors.black),
        child: Stack(
          children: [
            Positioned(
              left: -180,
              top: -120,
              child: _GlowBlob(color: AdminCyberColors.electricBlue, size: 420),
            ),
            Positioned(
              right: -220,
              bottom: -160,
              child: _GlowBlob(color: AdminCyberColors.neonViolet, size: 520),
            ),
            Positioned(
              right: 120,
              top: 80,
              child: _GlowBlob(color: AdminCyberColors.neonCyan, size: 240),
            ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
                child: Container(color: Colors.transparent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.22),
              color.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminTopBar extends StatelessWidget {
  final bool isDesktop;
  final String? role;
  final TextEditingController searchController;
  final FocusNode searchFocus;

  const AdminTopBar({
    super.key,
    required this.isDesktop,
    required this.role,
    required this.searchController,
    required this.searchFocus,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.currentUser;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
      child: Row(
        children: [
          if (!isDesktop)
            Builder(
              builder: (context) => _GlassIconButton(
                icon: Icons.menu_rounded,
                tooltip: 'Menu',
                onTap: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          if (!isDesktop) const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _GlassSearchField(controller: searchController, focusNode: searchFocus),
          ),
          const SizedBox(width: AppSpacing.sm),
          _GlassIconButton(
            icon: Icons.notifications_none_rounded,
            tooltip: 'Notifications',
            onTap: () {
              // Hook later: real-time notification center.
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notification center (coming soon)')));
            },
          ),
          const SizedBox(width: AppSpacing.sm),
          _GlassPill(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [AdminCyberColors.neonCyan, AdminCyberColors.electricBlue])),
                  child: const Icon(Icons.shield_rounded, size: 16, color: Colors.white),
                ),
                const SizedBox(width: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(user?.displayName ?? 'Admin', maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AdminCyberColors.text)),
                      Text((role ?? 'No role').toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AdminCyberColors.textDim)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _GlassIconButton(
                  icon: Icons.logout_rounded,
                  tooltip: 'Déconnexion',
                  onTap: () async {
                    await auth.signOut();
                    if (!context.mounted) return;
                    context.go(AppRoutes.home);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassSearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;

  const _GlassSearchField({required this.controller, required this.focusNode});

  @override
  Widget build(BuildContext context) {
    return _GlassSurface(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: AdminCyberColors.textDim, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AdminCyberColors.text),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Search users, THIX UID, documents, alerts…',
                hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AdminCyberColors.textDim.withValues(alpha: 0.85)),
              ),
              onSubmitted: (v) {
                final q = v.trim();
                if (q.isEmpty) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Global search: "$q" (coming soon)')));
              },
            ),
          ),
          if (controller.text.trim().isNotEmpty)
            _GlassIconButton(
              icon: Icons.close_rounded,
              tooltip: 'Clear',
              onTap: () {
                controller.clear();
                focusNode.requestFocus();
              },
            ),
        ],
      ),
    );
  }
}

class _AdminSidebarRail extends StatelessWidget {
  final AdminModule module;
  final String? role;

  const _AdminSidebarRail({required this.module, required this.role});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.sm, AppSpacing.md),
      child: ConstrainedBox(
        constraints: const BoxConstraints.tightFor(width: 280),
        child: _GlassSurface(
          padding: const EdgeInsets.all(12),
          child: _AdminNavList(module: module, role: role, isDrawer: false),
        ),
      ),
    );
  }
}

class _AdminDrawer extends StatelessWidget {
  final AdminModule module;
  final String? role;

  const _AdminDrawer({required this.module, required this.role});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AdminCyberColors.black),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: _GlassSurface(
            padding: const EdgeInsets.all(12),
            child: _AdminNavList(module: module, role: role, isDrawer: true),
          ),
        ),
      ),
    );
  }
}

class _AdminNavList extends StatelessWidget {
  final AdminModule module;
  final String? role;
  final bool isDrawer;

  const _AdminNavList({required this.module, required this.role, required this.isDrawer});

  @override
  Widget build(BuildContext context) {
    final isSuperAdmin = AdminRbacService.roleLevel(role ?? '') >= AdminRbacService.roleLevel('super_admin');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: AdminCyberGradients.glowViolet(),
                ),
                child: const Icon(Icons.security_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('THIX ID Admin', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AdminCyberColors.text)),
                    Text('Digital Trust • Cybersecurity', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdminCyberColors.textDim)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            children: [
              _NavItem(module: module, target: AdminModule.overview, icon: Icons.dashboard_rounded, label: 'Global Overview'),
              _NavItem(module: module, target: AdminModule.accessRequests, icon: Icons.admin_panel_settings_rounded, label: 'Account Access Requests'),
              _NavItem(module: module, target: AdminModule.users, icon: Icons.people_alt_rounded, label: 'User Management'),
              _NavItem(module: module, target: AdminModule.verification, icon: Icons.verified_user_rounded, label: 'Verification Center'),
              _NavItem(module: module, target: AdminModule.events, icon: Icons.event_available_rounded, label: 'Events'),
              _NavItem(module: module, target: AdminModule.trainings, icon: Icons.school_rounded, label: 'Trainings'),
              _NavItem(module: module, target: AdminModule.uid, icon: Icons.badge_rounded, label: 'THIX UID'),
              _NavItem(module: module, target: AdminModule.jobs, icon: Icons.work_rounded, label: 'Jobs & Opportunities'),
              _NavItem(module: module, target: AdminModule.news, icon: Icons.campaign_rounded, label: 'Info / News'),
              _NavItem(module: module, target: AdminModule.chat, icon: Icons.forum_rounded, label: 'THIX Chat Admin'),
              _NavItem(module: module, target: AdminModule.sos, icon: Icons.sos_rounded, label: 'SOS Emergency'),
              _NavItem(module: module, target: AdminModule.institutions, icon: Icons.account_balance_rounded, label: 'Institutions'),
              _NavItem(module: module, target: AdminModule.analytics, icon: Icons.query_stats_rounded, label: 'Analytics'),
              if (isSuperAdmin) _NavItem(module: module, target: AdminModule.cybersecurity, icon: Icons.shield_rounded, label: 'Cybersecurity'),
              if (isSuperAdmin) _NavItem(module: module, target: AdminModule.api, icon: Icons.api_rounded, label: 'API & Integrations'),
              const SizedBox(height: 8),
              _NavItem(module: module, target: AdminModule.audit, icon: Icons.manage_history_rounded, label: 'Audit & Activity'),
              if (isSuperAdmin) _NavItem(module: module, target: AdminModule.settings, icon: Icons.tune_rounded, label: 'Settings'),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _GlassSurface(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.lock_outline_rounded, color: AdminCyberColors.textDim, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  (role == null)
                      ? 'Access restricted. No admin role.'
                      : 'RBAC role: ${role!.toUpperCase()} • Session protected',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdminCyberColors.textDim),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  final AdminModule module;
  final AdminModule target;
  final IconData icon;
  final String label;

  const _NavItem({required this.module, required this.target, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final selected = module == target;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () {
          context.go('/admin/${target.slug}');
          final scaffold = Scaffold.maybeOf(context);
          if (scaffold?.isDrawerOpen ?? false) scaffold?.closeDrawer();
        },
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: selected ? AdminCyberColors.panelHi.withValues(alpha: 0.9) : Colors.transparent,
            border: Border.all(color: selected ? AdminCyberColors.neonCyan.withValues(alpha: 0.35) : AdminCyberColors.stroke.withValues(alpha: 0.25), width: 1),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: selected ? AdminCyberColors.neonCyan : AdminCyberColors.textDim),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: selected ? AdminCyberColors.text : AdminCyberColors.textDim),
                ),
              ),
              if (selected)
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: AdminCyberColors.neonCyan),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const _GlassSurface({required this.child, required this.padding});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AdminCyberColors.panel.withValues(alpha: 0.74),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AdminCyberColors.stroke.withValues(alpha: 0.9), width: 1),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  final Widget child;
  const _GlassPill({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AdminCyberColors.panelHi.withValues(alpha: 0.62),
            border: Border.all(color: AdminCyberColors.stroke.withValues(alpha: 0.9), width: 1),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: child),
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _GlassIconButton({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AdminCyberColors.stroke.withValues(alpha: 0.9), width: 1),
            color: AdminCyberColors.panelHi.withValues(alpha: 0.55),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: AdminCyberColors.text, size: 18),
          ),
        ),
      ),
    );
  }
}
