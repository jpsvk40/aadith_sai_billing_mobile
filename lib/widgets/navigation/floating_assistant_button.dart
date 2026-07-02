import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/providers/auth_provider.dart';

/// A persistent, draggable "Ask AI" bubble that floats over every tabbed screen
/// (mirrors the website's always-on assistant launcher). Gently breathes/glows so
/// it reads as "alive", and can be dragged anywhere; tap opens the assistant.
class FloatingAssistantButton extends ConsumerStatefulWidget {
  const FloatingAssistantButton({super.key});
  @override
  ConsumerState<FloatingAssistantButton> createState() => _FloatingAssistantButtonState();
}

class _FloatingAssistantButtonState extends ConsumerState<FloatingAssistantButton> with SingleTickerProviderStateMixin {
  static const double _size = 58;
  late final AnimationController _pulse;
  double? _dx; // null → default (snaps to bottom-right)
  double? _dy;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1700))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final user = ref.watch(authProvider).user;
    // Show only when the user has assistant access (admin-controlled; technicians default OFF),
    // and hide on the assistant screen itself and when signed out.
    if (user == null || user.aiAssistantAccess != true || location.startsWith('/ask-business')) {
      return const SizedBox.shrink();
    }

    final media = MediaQuery.of(context).size;
    final maxX = media.width - _size - 12;
    final maxY = media.height - _size - 170; // keep clear of the bottom nav
    final x = (_dx ?? maxX).clamp(8.0, maxX);
    final y = (_dy ?? maxY).clamp(90.0, maxY);

    return Positioned(
      left: x,
      top: y,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.go('/ask-business'),
        onPanStart: (_) => setState(() => _dragging = true),
        onPanUpdate: (d) => setState(() {
          _dx = x + d.delta.dx;
          _dy = y + d.delta.dy;
        }),
        onPanEnd: (_) => setState(() {
          _dragging = false;
          // Snap horizontally to the nearest edge.
          _dx = (x + _size / 2) < media.width / 2 ? 8.0 : maxX;
        }),
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (ctx, child) {
            final t = _dragging ? 1.0 : _pulse.value; // 0..1
            return Transform.scale(
              scale: 1.0 + 0.05 * t,
              child: Container(
                width: _size,
                height: _size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.35 + 0.30 * t),
                      blurRadius: 12 + 10 * t,
                      spreadRadius: 1 + 2 * t,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
                ),
                child: child,
              ),
            );
          },
          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 26),
        ),
      ),
    );
  }
}
