/// A single push-notification preference (one alert type) for the logged-in user.
class NotificationPref {
  final String key;
  final String label;
  final String group;
  final bool enabled;

  const NotificationPref({
    required this.key,
    required this.label,
    required this.group,
    required this.enabled,
  });

  factory NotificationPref.fromJson(Map<String, dynamic> j) => NotificationPref(
        key: (j['key'] ?? '').toString(),
        label: (j['label'] ?? '').toString(),
        group: (j['group'] ?? 'General').toString(),
        enabled: j['enabled'] != false,
      );

  NotificationPref copyWith({bool? enabled}) =>
      NotificationPref(key: key, label: label, group: group, enabled: enabled ?? this.enabled);
}
