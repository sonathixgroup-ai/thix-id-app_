import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/models/app_user.dart';
import 'package:thix_id/models/news_item.dart';
import 'package:thix_id/services/news_service.dart';
import 'package:thix_id/supabase/supabase_config.dart';
import 'package:thix_id/theme.dart';

/// ALERT INFO
///
/// Feed d'informations institutionnelles/verified.
/// Publication réservée aux comptes Entreprise autorisés + Admins.
class AlertInfoSheet extends StatelessWidget {
  const AlertInfoSheet({super.key});

  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints.tightFor(height: MediaQuery.sizeOf(context).height),
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      enableDrag: false,
      builder: (context) => const _AlertInfoSheetBody(),
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _AlertInfoSheetBody extends StatefulWidget {
  const _AlertInfoSheetBody();

  @override
  State<_AlertInfoSheetBody> createState() => _AlertInfoSheetBodyState();
}

class _AlertInfoSheetBodyState extends State<_AlertInfoSheetBody> {
  final _pageController = PageController(viewportFraction: 0.92);
  Timer? _auto;
  int _page = 0;

  RealtimeChannel? _newsRealtimeChannel;
  Timer? _realtimeDebounce;

  String _selectedCategory = 'À la Une';
  String _query = '';

  bool _loading = true;
  List<NewsItem> _news = const [];
  String? _error;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await NewsService().listNews(limit: 200);
      if (!mounted) return;
      setState(() => _news = items);
    } catch (e) {
      debugPrint('AlertInfoSheet: load news failed err=$e');
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reloadFromRealtime() async {
    try {
      final items = await NewsService().listNews(limit: 200);
      if (!mounted) return;
      setState(() {
        _news = items;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      debugPrint('AlertInfoSheet: realtime reload failed err=$e');
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  void _scheduleRealtimeReload() {
    _realtimeDebounce?.cancel();
    _realtimeDebounce = Timer(const Duration(milliseconds: 250), _reloadFromRealtime);
  }

  void _startRealtime() {
    try {
      final channel = SupabaseConfig.client.channel('realtime:${NewsService.table}');
      _newsRealtimeChannel = channel;

      channel
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: NewsService.table,
          callback: (payload) {
            debugPrint('THIX INFO realtime: ${payload.eventType} on ${payload.table}');
            _scheduleRealtimeReload();
          },
        )
        ..subscribe((status, err) {
          if (err != null) debugPrint('THIX INFO realtime subscribe error: $err');
          debugPrint('THIX INFO realtime status: $status');
        });
    } catch (e) {
      debugPrint('AlertInfoSheet: start realtime failed err=$e');
    }
  }

  void _stopRealtime() {
    try {
      _realtimeDebounce?.cancel();
      _realtimeDebounce = null;
      final ch = _newsRealtimeChannel;
      _newsRealtimeChannel = null;
      if (ch != null) SupabaseConfig.client.removeChannel(ch);
    } catch (e) {
      debugPrint('AlertInfoSheet: stop realtime failed err=$e');
    }
  }

  bool _isAdmin(AppUser? user) {
    const admins = <String>{'admin@thix.id', 'security@thix.id'};
    final email = (user?.email ?? '').toLowerCase().trim();
    return admins.contains(email);
  }

  List<_AlertInfoItem> _applyFilters(List<_AlertInfoItem> all) {
    final q = _query.trim().toLowerCase();
    Iterable<_AlertInfoItem> res = all;

    if (_selectedCategory == 'À la Une') {
      res = res.where((e) => e.featured);
    } else if (_selectedCategory != 'Actualités') {
      res = res.where((e) => e.category == _selectedCategory);
    }

    if (q.isNotEmpty) {
      res = res.where((e) {
        return e.title.toLowerCase().contains(q) || e.subtitle.toLowerCase().contains(q) || e.source.toLowerCase().contains(q);
      });
    }

    return res.toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _load();
    _startRealtime();
    _auto = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_pageController.hasClients) return;
      _pageController.nextPage(duration: const Duration(milliseconds: 520), curve: Curves.easeOutCubic);
    });
  }

  @override
  void dispose() {
    _auto?.cancel();
    _stopRealtime();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final gold = isDark ? DarkModeColors.metalGold : LightModeColors.metalGold;
    final cyberBg = isDark ? DarkModeColors.cyberDarkBlue : LightModeColors.background;
    final divider = isDark ? Colors.white.withValues(alpha: 0.10) : LightModeColors.divider;

    final auth = context.watch<AuthController>();
    final me = auth.currentUser;
    final canPublish = (me?.accountType == AccountType.enterprise) || _isAdmin(me);

    final allItems = _loading
        ? _AlertInfoDemoData.institutionalFeed
        : (_news.isEmpty ? _AlertInfoDemoData.institutionalFeed : _mapNewsToUi(_news));
    final items = _applyFilters(allItems);
    final featured = allItems.where((e) => e.featured).toList(growable: false);
    final categories = _AlertInfoDemoData.categories;

    return BackdropFilter(
      // Blur is kept for a premium feel, but the sheet itself must stay light in light-mode.
      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
      child: Container(
        // Full-screen sheet: no outer margin, no "floating" card effect.
        margin: EdgeInsets.zero,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(0),
          border: Border.all(color: isDark ? gold.withValues(alpha: 0.32) : divider),
          color: isDark ? cyberBg.withValues(alpha: 0.86) : Colors.white.withValues(alpha: 0.96),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.08), blurRadius: 36, offset: const Offset(0, 18))],
        ),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints.tightFor(height: MediaQuery.sizeOf(context).height),
          child: Column(
            children: [
              _ThixInfoTopBar(canPublish: canPublish, email: me?.email, gold: gold),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
                child: _ThixInfoSearchBar(
                  hintText: 'Rechercher une information…',
                  onChanged: (v) => setState(() => _query = v),
                  onFilterTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Filtres: à connecter.'))),
                ),
              ),
              _CategoryTabs(
                categories: categories,
                selected: _selectedCategory,
                onSelected: (c) => setState(() => _selectedCategory = c),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
                  children: [
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
                          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.10) : LightModeColors.divider),
                        ),
                        child: Text(
                          'Supabase: ${NewsService.table} • ${_error!}',
                          style: context.textStyles.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.75), height: 1.35),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    if (_selectedCategory == 'À la Une' || _selectedCategory == 'Actualités') ...[
                      const _SectionTitle(title: 'À la une', subtitle: 'Informations prioritaires', icon: Icons.auto_awesome_rounded),
                      const SizedBox(height: AppSpacing.sm),
                      _FeaturedCarousel(
                        pageController: _pageController,
                        featured: featured,
                        gold: gold,
                        onIndexChanged: (idx) => setState(() => _page = idx),
                      ),
                      if (featured.length > 1) ...[
                        const SizedBox(height: AppSpacing.sm),
                        _DotsIndicator(count: featured.length, index: _page, activeColor: gold),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const _SectionTitleInline(title: 'Dernières actualités'),
                        TextButton(
                          onPressed: () => setState(() => _selectedCategory = 'Actualités'),
                          style: TextButton.styleFrom(foregroundColor: gold, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                          child: const Text('Voir tout  ›', style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (items.isEmpty)
                      _EmptyResultsCard(query: _query, gold: gold)
                    else
                      for (final item in items) ...[
                        _NewsListTile(item: item),
                        const SizedBox(height: AppSpacing.md),
                      ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_AlertInfoItem> _mapNewsToUi(List<NewsItem> items) {
    String relTime(DateTime dt) {
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes} min';
      if (diff.inHours < 24) return '${diff.inHours} h';
      return '${diff.inDays} j';
    }

    IconData iconFor(String category) {
      final c = category.toLowerCase();
      if (c.contains('sécur') || c.contains('security')) return Icons.shield_rounded;
      if (c.contains('alerte') || c.contains('urgent')) return Icons.warning_amber_rounded;
      if (c.contains('évén')) return Icons.event_rounded;
      if (c.contains('institution')) return Icons.account_balance_rounded;
      return Icons.campaign_rounded;
    }

    return items
        .map(
          (e) => _AlertInfoItem(
            icon: iconFor(e.category),
            title: e.title,
            subtitle: e.subtitle,
            tag: e.category,
            time: relTime(e.createdAt),
            source: e.source,
            severity: e.severity,
            category: e.category,
            featured: e.featured,
            imageAssetPath: e.imageUrl,
          ),
        )
        .toList(growable: false);
  }
}

class _ThixInfoTopBar extends StatelessWidget {
  final bool canPublish;
  final String? email;
  final Color gold;
  const _ThixInfoTopBar({required this.canPublish, required this.email, required this.gold});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // In light mode we want a strong institutional header (like the reference): solid blue + thin gold underline.
    final headerBg = isDark ? DarkModeColors.cyberDarkBlue : LightModeColors.primary;
    final fg = Colors.white.withValues(alpha: 0.95);

    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
      decoration: BoxDecoration(
        color: headerBg,
        border: Border(bottom: BorderSide(color: gold.withValues(alpha: 0.85), width: 2)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: Icon(Icons.arrow_back_rounded, color: fg),
            tooltip: 'Retour',
          ),
          Expanded(
            child: Center(
              child: RichText(
                text: TextSpan(
                  style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 0.4),
                  children: [
                    TextSpan(text: 'THIX ', style: TextStyle(color: fg)),
                    TextSpan(text: 'INFO', style: TextStyle(color: gold)),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recherche: à connecter.'))),
            icon: Icon(Icons.search_rounded, color: fg.withValues(alpha: 0.92)),
            tooltip: 'Rechercher',
          ),
          _BellButton(gold: gold, fg: fg.withValues(alpha: 0.92), isDark: isDark, cyberBg: headerBg),
          if (canPublish)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: fg.withValues(alpha: 0.86)),
              onSelected: (v) {
                if (v == 'publish') {
                  debugPrint('ThixInfo: publish tapped by ${email ?? 'unknown'}');
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Publication: à connecter au back-office.')));
                }
                if (v == 'refresh') {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Actualisation…')));
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'publish', child: Text('Publier')),
                PopupMenuItem(value: 'refresh', child: Text('Actualiser')),
              ],
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _BellButton extends StatelessWidget {
  final Color gold;
  final Color fg;
  final bool isDark;
  final Color cyberBg;
  const _BellButton({required this.gold, required this.fg, required this.isDark, required this.cyberBg});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notifications THIX INFO.'))),
          icon: Icon(Icons.notifications_none_rounded, color: fg),
          tooltip: 'Notifications',
        ),
        Positioned(
          right: 10,
          top: 10,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: gold,
              borderRadius: BorderRadius.circular(AppRadius.full),
              border: Border.all(color: isDark ? Colors.black.withValues(alpha: 0.25) : cyberBg, width: 1.5),
            ),
            alignment: Alignment.center,
            child: const Text('3', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black)),
          ),
        ),
      ],
    );
  }
}

class _ThixInfoSearchBar extends StatelessWidget {
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback onFilterTap;
  const _ThixInfoSearchBar({required this.hintText, required this.onChanged, required this.onFilterTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white;
    final border = isDark ? Colors.white.withValues(alpha: 0.10) : LightModeColors.divider;
    final iconFg = isDark ? Colors.white.withValues(alpha: 0.82) : LightModeColors.secondaryText;
    final textFg = isDark ? Colors.white.withValues(alpha: 0.92) : LightModeColors.primaryText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: bg,
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 18, color: iconFg),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              style: context.textStyles.bodyMedium?.copyWith(color: textFg, fontWeight: FontWeight.w700),
              cursorColor: cs.primary,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: hintText,
                hintStyle: context.textStyles.bodyMedium?.copyWith(color: isDark ? Colors.white.withValues(alpha: 0.55) : LightModeColors.hint),
              ),
            ),
          ),
          IconButton(
            onPressed: onFilterTap,
            icon: Icon(Icons.tune_rounded, size: 18, color: isDark ? Colors.white.withValues(alpha: 0.86) : LightModeColors.accent),
            tooltip: 'Filtres',
          ),
        ],
      ),
    );
  }
}

class _CategoryTabs extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelected;
  const _CategoryTabs({required this.categories, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gold = isDark ? DarkModeColors.metalGold : LightModeColors.metalGold;
    final chipBg = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white;
    final chipBorder = isDark ? Colors.white.withValues(alpha: 0.10) : LightModeColors.divider;
    final fg = isDark ? Colors.white.withValues(alpha: 0.86) : LightModeColors.primaryText;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, i) {
          final c = categories[i];
          final selectedNow = c == selected;
          return GestureDetector(
            onTap: () => onSelected(c),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.full),
                color: selectedNow ? gold.withValues(alpha: 0.92) : chipBg,
                border: Border.all(color: selectedNow ? gold.withValues(alpha: 0.55) : chipBorder),
              ),
              child: Text(
                c,
                style: context.textStyles.labelLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: selectedNow ? Colors.black : fg,
                ),
              ),
            ),
          );
        },
        separatorBuilder: (context, i) => const SizedBox(width: 10),
        itemCount: categories.length,
      ),
    );
  }
}

class _FeaturedCarousel extends StatelessWidget {
  final PageController pageController;
  final List<_AlertInfoItem> featured;
  final Color gold;
  final ValueChanged<int> onIndexChanged;
  const _FeaturedCarousel({required this.pageController, required this.featured, required this.gold, required this.onIndexChanged});

  @override
  Widget build(BuildContext context) {
    final list = featured;
    return SizedBox(
      height: 260,
      child: PageView.builder(
        controller: pageController,
        itemCount: list.isEmpty ? 1 : (list.length * 2000),
        itemBuilder: (context, i) {
          final item = list.isEmpty ? _AlertInfoDemoData.fallbackFeatured : list[i % list.length];
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: _FeaturedNewsCard(item: item, gold: gold),
          );
        },
        onPageChanged: (i) {
          if (list.isEmpty) return;
          onIndexChanged(i % list.length);
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  const _SectionTitle({required this.title, required this.subtitle, required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: cs.onSurface.withValues(alpha: 0.06),
            border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: cs.onSurface.withValues(alpha: 0.80)),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(subtitle, style: context.textStyles.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.70), height: 1.25)),
            ],
          ),
        ),
      ],
    );
  }
}

class _AlertInfoItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final String tag;
  final String time;
  final String source;
  final String severity;
  final bool featured;
  final String category;
  final String? imageAssetPath;

  const _AlertInfoItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.time,
    required this.source,
    required this.severity,
    required this.category,
    this.imageAssetPath,
    this.featured = false,
  });
}

class _FeaturedNewsCard extends StatelessWidget {
  final _AlertInfoItem item;
  final Color gold;
  const _FeaturedNewsCard({required this.item, required this.gold});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cyberBg = isDark ? DarkModeColors.cyberDarkBlue : LightModeColors.cyberDarkBlue;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _ThixNewsImage(
            url: item.imageAssetPath,
            fit: BoxFit.cover,
            placeholder: _ThixNewsPlaceholder(gold: gold, variant: _ThixNewsPlaceholderVariant.hero),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                // Navy overlay (no black) so it stays THIX-brand (bleu marine/or).
                colors: isDark
                    ? [cyberBg.withValues(alpha: 0.08), cyberBg.withValues(alpha: 0.40), cyberBg.withValues(alpha: 0.72)]
                    : [cyberBg.withValues(alpha: 0.05), cyberBg.withValues(alpha: 0.18), cyberBg.withValues(alpha: 0.36)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        color: gold.withValues(alpha: 0.92),
                      ),
                      child: const Text('À LA UNE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.black)),
                    ),
                    const Spacer(),
                    Icon(Icons.arrow_forward_rounded, color: Colors.white.withValues(alpha: 0.88)),
                  ],
                ),
                const Spacer(),
                Text(
                  item.title,
                  style: context.textStyles.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900, height: 1.15),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _GlassPill(text: item.source),
                    const SizedBox(width: 10),
                    Icon(Icons.schedule_rounded, size: 14, color: Colors.white.withValues(alpha: 0.75)),
                    const SizedBox(width: 6),
                    Text(item.time, style: context.textStyles.labelSmall?.copyWith(color: Colors.white.withValues(alpha: 0.78), fontWeight: FontWeight.w800)),
                  ],
                ),
              ],
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitleInline extends StatelessWidget {
  final String title;
  const _SectionTitleInline({required this.title});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(title, style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: cs.onSurface));
  }
}

class _EmptyResultsCard extends StatelessWidget {
  final String query;
  final Color gold;
  const _EmptyResultsCard({required this.query, required this.gold});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.10) : LightModeColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: gold.withValues(alpha: 0.14),
              border: Border.all(color: gold.withValues(alpha: 0.30)),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.search_off_rounded, color: gold),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Aucun résultat', style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: cs.onSurface)),
                const SizedBox(height: 4),
                Text(
                  query.trim().isEmpty ? 'Essaie une autre catégorie.' : 'Aucun contenu ne correspond à “$query”.',
                  style: context.textStyles.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.70), height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NewsListTile extends StatelessWidget {
  final _AlertInfoItem item;
  const _NewsListTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final gold = isDark ? DarkModeColors.metalGold : LightModeColors.metalGold;
    final subtitle = item.subtitle.trim();

    return GestureDetector(
      onTap: () => _NewsDetailsSheet.show(context, item: item),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.10) : LightModeColors.divider),
          color: isDark ? cs.surface.withValues(alpha: 0.18) : Colors.white,
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 64,
                height: 64,
                child: _ThixNewsImage(
                  url: item.imageAssetPath,
                  fit: BoxFit.cover,
                  placeholder: _ThixNewsPlaceholder(gold: gold, icon: item.icon, variant: _ThixNewsPlaceholderVariant.tile),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.category.toUpperCase(), style: context.textStyles.labelSmall?.copyWith(color: gold.withValues(alpha: 0.95), fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  Text(item.title, style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.w900, color: cs.onSurface), maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: context.textStyles.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.78), height: 1.35),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _GlassPill(text: item.source),
                      const SizedBox(width: 10),
                      Icon(Icons.schedule_rounded, size: 14, color: cs.onSurface.withValues(alpha: 0.55)),
                      const SizedBox(width: 6),
                      Text(item.time, style: context.textStyles.labelSmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.65), fontWeight: FontWeight.w800)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _NewsDetailsSheet.show(context, item: item),
                        style: TextButton.styleFrom(
                          foregroundColor: gold,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          textStyle: context.textStyles.labelLarge?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        icon: Icon(Icons.open_in_new_rounded, size: 16, color: gold),
                        label: const Text('Lire plus'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enregistré.'))),
              icon: Icon(Icons.bookmark_border_rounded, color: isDark ? Colors.white.withValues(alpha: 0.76) : LightModeColors.secondaryText),
              tooltip: 'Enregistrer',
            ),
          ],
        ),
      ),
    );
  }
}

class _NewsDetailsSheet extends StatelessWidget {
  final _AlertInfoItem item;
  const _NewsDetailsSheet({required this.item});

  static Future<void> show(BuildContext context, {required _AlertInfoItem item}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (context) => _NewsDetailsSheet(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final gold = isDark ? DarkModeColors.metalGold : LightModeColors.metalGold;
    final bg = isDark ? DarkModeColors.cyberDarkBlue.withValues(alpha: 0.92) : Colors.white;
    final border = isDark ? Colors.white.withValues(alpha: 0.10) : LightModeColors.divider;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.92),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: border),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.14), blurRadius: 30, offset: const Offset(0, -10))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 10, AppSpacing.lg, 10),
              child: Row(
                children: [
                  Container(width: 44, height: 5, decoration: BoxDecoration(color: cs.onSurface.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.full))),
                  const Spacer(),
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: Icon(Icons.close_rounded, color: cs.onSurface.withValues(alpha: 0.78)),
                    tooltip: 'Fermer',
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: _ThixNewsImage(
                        url: item.imageAssetPath,
                        fit: BoxFit.cover,
                        placeholder: _ThixNewsPlaceholder(gold: gold, icon: item.icon, variant: _ThixNewsPlaceholderVariant.hero),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(item.category.toUpperCase(), style: context.textStyles.labelSmall?.copyWith(color: gold.withValues(alpha: 0.95), fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  Text(item.title, style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.w900, height: 1.12, color: cs.onSurface)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _GlassPill(text: item.source),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.schedule_rounded, size: 16, color: cs.onSurface.withValues(alpha: 0.60)),
                          const SizedBox(width: 6),
                          Text(item.time, style: context.textStyles.labelMedium?.copyWith(color: cs.onSurface.withValues(alpha: 0.72), fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      color: cs.onSurface.withValues(alpha: isDark ? 0.06 : 0.04),
                      border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
                    ),
                    child: Text(
                      item.subtitle.trim().isEmpty ? '—' : item.subtitle.trim(),
                      style: context.textStyles.bodyMedium?.copyWith(color: cs.onSurface.withValues(alpha: 0.88), height: 1.55),
                      textAlign: TextAlign.start,
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

enum _ThixNewsPlaceholderVariant { hero, tile }

class _ThixNewsImage extends StatelessWidget {
  final String? url;
  final BoxFit fit;
  final Widget placeholder;

  const _ThixNewsImage({required this.url, required this.fit, required this.placeholder});

  @override
  Widget build(BuildContext context) {
    final u = (url ?? '').trim();
    if (u.isEmpty) return placeholder;
    if (!u.startsWith('http')) return Image.asset(u, fit: fit);
    return Image.network(
      u,
      fit: fit,
      errorBuilder: (context, error, stack) {
        debugPrint('THIX INFO image load failed url=$u err=$error');
        return placeholder;
      },
    );
  }
}

class _ThixNewsPlaceholder extends StatelessWidget {
  final Color gold;
  final IconData? icon;
  final _ThixNewsPlaceholderVariant variant;
  const _ThixNewsPlaceholder({required this.gold, this.icon, required this.variant});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final navy = isDark ? DarkModeColors.primary : LightModeColors.primary;
    final navy2 = isDark ? DarkModeColors.cyberDarkBlue : LightModeColors.secondary;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [navy.withValues(alpha: 0.96), navy2.withValues(alpha: 0.90), gold.withValues(alpha: 0.14)],
        ),
      ),
      child: variant == _ThixNewsPlaceholderVariant.tile
          ? Center(child: Icon(icon ?? Icons.campaign_rounded, color: gold, size: 22))
          : Align(
              alignment: const Alignment(-0.90, -0.72),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(color: gold.withValues(alpha: 0.35)),
                  color: Colors.white.withValues(alpha: isDark ? 0.06 : 0.10),
                ),
                child: Text(
                  'THIX INFO',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white.withValues(alpha: 0.92), fontWeight: FontWeight.w900, letterSpacing: 0.4),
                ),
              ),
            ),
    );
  }
}

class _DotsIndicator extends StatelessWidget {
  final int count;
  final int index;
  final Color activeColor;
  const _DotsIndicator({required this.count, required this.index, required this.activeColor});

  @override
  Widget build(BuildContext context) {
    final inactive = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.18);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == index ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == index ? activeColor : inactive,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
          ),
      ],
    );
  }
}

class _AlertInfoCard extends StatelessWidget {
  final _AlertInfoItem item;
  const _AlertInfoCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final gold = isDark ? DarkModeColors.metalGold : LightModeColors.metalGold;

    final severity = item.severity;
    final Color severityColor = switch (severity) {
      'Critique' => isDark ? const Color(0xFFFF6B6B) : LightModeColors.error,
      'Important' => gold,
      'Info' => cs.primary,
      _ => gold,
    };

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.10)),
        color: cs.surface.withValues(alpha: isDark ? 0.55 : 0.78),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(colors: [gold.withValues(alpha: 0.18), gold.withValues(alpha: 0.08)]),
              border: Border.all(color: gold.withValues(alpha: 0.30)),
            ),
            alignment: Alignment.center,
            child: Icon(item.icon, color: cs.onSurface, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(item.title, style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
                    const SizedBox(width: AppSpacing.sm),
                    _TagPill(text: item.tag),
                  ],
                ),
                const SizedBox(height: 6),
                Text(item.subtitle, style: context.textStyles.bodyMedium?.copyWith(color: cs.onSurface.withValues(alpha: 0.80), height: 1.45)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _MetaPill(icon: Icons.verified_user_rounded, text: item.source, color: cs.onSurface.withValues(alpha: 0.75)),
                    _MetaPill(icon: Icons.bolt_rounded, text: severity, color: severityColor),
                    _MetaPill(icon: Icons.schedule_rounded, text: item.time, color: cs.onSurface.withValues(alpha: 0.62)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  final String text;
  const _TagPill({required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gold = isDark ? DarkModeColors.metalGold : LightModeColors.metalGold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.full),
        color: gold.withValues(alpha: 0.16),
        border: Border.all(color: gold.withValues(alpha: 0.30)),
      ),
      child: Text(text, style: context.textStyles.labelSmall?.copyWith(fontWeight: FontWeight.w900)),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _MetaPill({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.full),
        color: cs.onSurface.withValues(alpha: 0.06),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(text, style: context.textStyles.labelSmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.80), fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  final String text;
  const _GlassPill({required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.full),
        color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.white,
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.16) : LightModeColors.divider),
      ),
      child: Text(
        text,
        style: context.textStyles.labelSmall?.copyWith(color: isDark ? Colors.white.withValues(alpha: 0.92) : LightModeColors.secondaryText, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _AlertInfoDemoData {
  static const categories = <String>['À la Une', 'Actualités', 'Économie', 'Politique', 'Technologie', 'Santé', 'Sécurité'];

  static const fallbackFeatured = _AlertInfoItem(
    icon: Icons.notifications_active_rounded,
    title: 'Aucune info à la une',
    subtitle: 'Les publications institutionnelles apparaîtront ici.',
    tag: 'Système',
    time: 'Maintenant',
    source: 'THIX',
    severity: 'Info',
    category: 'Actualités',
    featured: true,
  );

  static const institutionalFeed = <_AlertInfoItem>[
    _AlertInfoItem(
      icon: Icons.warning_rounded,
      title: 'Sécurité — Opération de contrôle renforcée',
      subtitle: 'Contrôles ciblés sur axes principaux (20h–01h). Gardez vos papiers à jour et évitez les zones à risque.',
      tag: 'Sécurité',
      time: 'Il y a 8 min',
      source: 'Police nationale',
      severity: 'Important',
      category: 'Sécurité',
      imageAssetPath: 'assets/images/Office_team_grayscale_1775574009745.jpg',
      featured: true,
    ),
    _AlertInfoItem(
      icon: Icons.water_drop_rounded,
      title: 'Service public — Coupure d’eau planifiée',
      subtitle: 'Travaux réseau: interruption possible (09h–14h) dans plusieurs quartiers. Prévoyez une réserve.',
      tag: 'Service public',
      time: 'Il y a 40 min',
      source: 'Société des eaux',
      severity: 'Info',
      category: 'Actualités',
      imageAssetPath: 'assets/images/Senior_professional_man_grayscale_1775573975687.jpg',
      featured: true,
    ),
    _AlertInfoItem(
      icon: Icons.health_and_safety_rounded,
      title: 'Santé — Campagne de vaccination mobile',
      subtitle: 'Unités mobiles aujourd’hui: Marché central & Gare. Priorité enfants et personnes vulnérables.',
      tag: 'Santé',
      time: 'Aujourd’hui',
      source: 'Ministère de la Santé',
      severity: 'Info',
      category: 'Santé',
      imageAssetPath: 'assets/images/African_businessman_in_suit_grayscale_1775573970767.jpg',
      featured: true,
    ),
    _AlertInfoItem(
      icon: Icons.shield_moon_rounded,
      title: 'Cybersécurité — Alerte phishing “compte THIX”',
      subtitle: 'Aucune institution ne demande vos codes OTP par SMS. Ne cliquez pas sur les liens suspects.',
      tag: 'Cybersécurité',
      time: 'Il y a 2 h',
      source: 'CERT / Équipe cyber',
      severity: 'Important',
      category: 'Technologie',
    ),
    _AlertInfoItem(
      icon: Icons.traffic_rounded,
      title: 'Mobilité — Déviation temporaire',
      subtitle: 'Travaux: route secondaire fermée. Suivez la déviation signalée (panneaux jaunes).',
      tag: 'Mobilité',
      time: 'Aujourd’hui',
      source: 'Mairie / Voirie',
      severity: 'Info',
      category: 'Actualités',
    ),
    _AlertInfoItem(
      icon: Icons.power_rounded,
      title: 'Électricité — Maintenance préventive',
      subtitle: 'Micro-coupures possibles dans certains secteurs (22h–23h). Rechargez vos appareils.',
      tag: 'Service public',
      time: 'Ce soir',
      source: 'Compagnie électrique',
      severity: 'Info',
      category: 'Actualités',
    ),
    _AlertInfoItem(
      icon: Icons.fire_truck_rounded,
      title: 'Prévention — Risque d’incendie (saison sèche)',
      subtitle: 'Évitez les feux en plein air. Signalez immédiatement toute fumée anormale.',
      tag: 'Prévention',
      time: 'Semaine en cours',
      source: 'Protection civile',
      severity: 'Important',
      category: 'Sécurité',
    ),
    _AlertInfoItem(
      icon: Icons.local_hospital_rounded,
      title: 'Santé — Don de sang: besoin O+',
      subtitle: 'Les centres collectent en priorité O+ et O−. Présentez une pièce d’identité.',
      tag: 'Santé',
      time: 'Cette semaine',
      source: 'Centre de transfusion',
      severity: 'Important',
      category: 'Santé',
    ),
  ];
}
