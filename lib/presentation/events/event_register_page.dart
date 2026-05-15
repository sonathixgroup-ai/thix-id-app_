import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/services/event_service.dart';
import 'package:thix_id/services/profile_service.dart';
import 'package:thix_id/services/thix_id_service.dart';
import 'package:thix_id/theme.dart';

class EventRegisterPage extends StatefulWidget {
  final String eventId;
  const EventRegisterPage({super.key, required this.eventId});

  @override
  State<EventRegisterPage> createState() => _EventRegisterPageState();
}

class _EventRegisterPageState extends State<EventRegisterPage> {
  final _eventService = EventService();
  final _profileService = ProfileService();
  final _thixCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  int _tickets = 1;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _thixCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthController>();
    final thixId = auth.currentUser?.thixId ?? '';
    if (_thixCtrl.text.trim().isEmpty && thixId.trim().isNotEmpty) {
      _thixCtrl.text = thixId;
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      final canonical = ThixIdService.canonicalizeOrNull(_thixCtrl.text);
      if (canonical == null || !ThixIdService.isValid(canonical)) {
        setState(() => _error = 'THIX ID invalide. Exemple: ${ThixIdService.exampleV2}');
        return;
      }

      final profile = await _profileService.fetchPublicProfileByThixId(canonical);
      if (profile == null) {
        setState(() => _error = 'Aucun profil trouvé pour ce THIX ID.');
        return;
      }

      final reg = await _eventService.register(eventId: widget.eventId, attendeeThixId: canonical, tickets: _tickets, note: _noteCtrl.text);
      if (!mounted) return;
      context.go('/events/${widget.eventId}/ticket/${reg.id}');
    } catch (e) {
      debugPrint('EventRegisterPage.submit failed err=$e');
      if (!mounted) return;
      setState(() => _error = 'Erreur lors de l’inscription. Réessaie.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EventsCyberColors.bg0,
      body: SafeArea(
        child: FutureBuilder(
          future: _eventService.fetchEvent(widget.eventId),
          builder: (context, snap) {
            final event = snap.data;
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (event == null) {
              return Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    _TopBar(eventId: widget.eventId),
                    const Spacer(),
                    Text('Événement introuvable.', style: context.textStyles.titleMedium?.copyWith(color: context.theme.colorScheme.onSurface)),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => context.popOrGo(AppRoutes.events),
                        child: const Text('Retour'),
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TopBar(eventId: widget.eventId),
                  const SizedBox(height: AppSpacing.md),
                  Text('Inscription', style: context.textStyles.titleLarge?.copyWith(color: EventsCyberColors.text, fontWeight: FontWeight.w900)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(event.title, style: context.textStyles.titleMedium?.copyWith(color: EventsCyberColors.textDim, fontWeight: FontWeight.w700)),
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: EventsCyberColors.panel.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      border: Border.all(color: EventsCyberColors.stroke.withValues(alpha: 0.9), width: 1.2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.verified_user_rounded, color: EventsCyberColors.success),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text('THIX ID requis', style: context.textStyles.titleSmall?.copyWith(color: EventsCyberColors.text, fontWeight: FontWeight.w800)),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextField(
                          controller: _thixCtrl,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            labelText: 'THIX ID',
                            hintText: ThixIdService.exampleV2,
                            prefixIcon: const Icon(Icons.badge_rounded),
                          ),
                          onChanged: (_) {
                            if (_error != null) setState(() => _error = null);
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Expanded(
                              child: Text('Billets', style: context.textStyles.titleSmall?.copyWith(color: EventsCyberColors.text, fontWeight: FontWeight.w800)),
                            ),
                            IconButton(
                              onPressed: _loading || _tickets <= 1 ? null : () => setState(() => _tickets -= 1),
                              icon: const Icon(Icons.remove_circle_outline_rounded),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(AppRadius.full),
                                border: Border.all(color: EventsCyberColors.stroke.withValues(alpha: 0.9)),
                                color: Colors.black.withValues(alpha: 0.18),
                              ),
                              child: Text('$_tickets', style: context.textStyles.titleSmall?.copyWith(color: EventsCyberColors.text, fontWeight: FontWeight.w900)),
                            ),
                            IconButton(
                              onPressed: _loading ? null : () => setState(() => _tickets += 1),
                              icon: const Icon(Icons.add_circle_outline_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextField(
                          controller: _noteCtrl,
                          minLines: 2,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            labelText: 'Note (optionnel)',
                            hintText: 'Allergies, besoins spécifiques, entreprise…',
                            prefixIcon: Icon(Icons.edit_note_rounded),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          Text(_error!, style: context.textStyles.bodyMedium?.copyWith(color: EventsCyberColors.danger, fontWeight: FontWeight.w700)),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        SizedBox(
                          height: 52,
                          child: FilledButton.icon(
                            onPressed: _loading ? null : _submit,
                            icon: _loading
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.lock_open_rounded),
                            label: Text(_loading ? 'Validation…' : 'Confirmer mon inscription'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String eventId;
  const _TopBar({required this.eventId});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => context.popOrGo('/events/$eventId'),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: EventsCyberColors.text),
        ),
        Expanded(
          child: Text('THIX Register', style: context.textStyles.titleLarge?.copyWith(color: EventsCyberColors.text, fontWeight: FontWeight.w900)),
        ),
      ],
    );
  }
}

extension _ThemeX on BuildContext {
  ThemeData get theme => Theme.of(this);
}
