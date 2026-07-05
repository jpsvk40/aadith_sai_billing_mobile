import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/assistant_model.dart';
import '../../router/route_guards.dart';
import '../auth/providers/auth_provider.dart';
import '../reports/report_registry.dart';

/// Open a destination the AI assistant returned — with client-side RBAC/vertical
/// guards so a stale or over-eager suggestion never dumps the user on the
/// /unauthorized screen or a router error page.
///
/// Returns true when navigation actually happened (callers use this to decide
/// whether to announce "Opening …" in voice mode).
bool openAssistantDestination(BuildContext context, WidgetRef ref, AssistantNavigate nav) {
  final route = nav.mobileRoute;
  if (route == null || route.isEmpty) return false; // web-only — the note is already shown

  final user = ref.read(authProvider).user;
  final messenger = ScaffoldMessenger.of(context);

  // Named report deep link → validate the key + its module before navigating.
  final reportMatch = RegExp(r'^/reports/view/([^/?]+)').firstMatch(route);
  if (reportMatch != null) {
    final key = reportMatch.group(1)!;
    if (ReportRegistry.forKey(key) == null) {
      messenger.showSnackBar(const SnackBar(content: Text('That report isn\'t available in this app version.')));
      return false;
    }
    final module = ReportRegistry.moduleForKey(key);
    if (module != null && user?.hasModule(module) != true) {
      messenger.showSnackBar(SnackBar(content: Text('Your role doesn\'t have access to ${nav.label}.')));
      return false;
    }
  } else if (!canAccessLocation(user, route)) {
    // Same module gate the router redirect enforces — but with a friendly message
    // instead of bouncing to /unauthorized.
    messenger.showSnackBar(SnackBar(content: Text('Your role doesn\'t have access to ${nav.label}.')));
    return false;
  }

  context.go(route);
  return true;
}
