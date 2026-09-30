import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/util/time_ago.dart';
import '../../admin/data/admin_system_repository.dart';
import '../../weather/data/weather_alerts_repository.dart';
import '../data/notifications_repository.dart';

/// Farmer-facing announcements inbox. Opening it marks everything seen, which
/// clears the badge on the dashboard bell.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  DateTime? _lastSeen;

  @override
  void initState() {
    super.initState();
    // Capture the previous last-seen for highlighting, then mark all seen.
    final repo = ref.read(notificationsRepositoryProvider);
    _lastSeen = repo.lastSeen();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await repo.markAllSeen();
      ref.invalidate(unreadNotificationsProvider);
    });
  }

  bool _isNew(DateTime t) => _lastSeen == null || t.isAfter(_lastSeen!);

  @override
  Widget build(BuildContext context) {
    final inbox = ref.watch(myNotificationsProvider);
    final weather = ref.watch(myWeatherAlertsProvider);

    final broadcasts = inbox.valueOrNull ?? const <Broadcast>[];
    // Weather alerts are best-effort: an error (e.g. table not migrated yet) is
    // treated as "none" so the inbox never breaks.
    final alerts = weather.valueOrNull ?? const <WeatherAlertRecord>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppColors.background,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myNotificationsProvider);
          ref.invalidate(myWeatherAlertsProvider);
        },
        child: Builder(builder: (_) {
          final children = <Widget>[];

          if (alerts.isNotEmpty) {
            children.add(const _SectionLabel('Weather alerts'));
            for (final a in alerts) {
              children.add(Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _WeatherAlertCard(alert: a, isNew: _isNew(a.createdAt)),
              ));
            }
          }

          if (broadcasts.isNotEmpty) {
            if (children.isNotEmpty) children.add(const SizedBox(height: 8));
            children.add(const _SectionLabel('Announcements'));
            for (final b in broadcasts) {
              children.add(Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _Card(b: b, isNew: _isNew(b.createdAt)),
              ));
            }
          }

          if (children.isEmpty) {
            if (inbox.isLoading || weather.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            return ListView(children: [
              const SizedBox(height: 140),
              const Icon(Symbols.notifications_off,
                  size: 56, color: AppColors.outline),
              const SizedBox(height: 12),
              Center(
                  child: Text('Nothing here yet', style: AppText.headlineSm)),
            ]);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: children,
          );
        }),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text.toUpperCase(),
          style: AppText.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6)),
    );
  }
}

class _WeatherAlertCard extends StatelessWidget {
  const _WeatherAlertCard({required this.alert, required this.isNew});
  final WeatherAlertRecord alert;
  final bool isNew;

  static const _icons = <String, IconData>{
    'flood': Symbols.flood,
    'river_flood': Symbols.tsunami,
    'heavy_rain': Symbols.rainy_heavy,
    'heat': Symbols.thermometer,
    'wind': Symbols.air,
    'dry': Symbols.water_drop,
  };

  @override
  Widget build(BuildContext context) {
    final colour = alert.isDanger ? AppColors.error : AppColors.tertiary;
    final icon = _icons[alert.hazard] ?? Symbols.warning;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colour.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 20, color: colour),
            const SizedBox(width: 8),
            Expanded(
                child: Text(alert.title,
                    style: AppText.labelMd
                        .copyWith(color: colour, fontWeight: FontWeight.w800))),
            if (isNew)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: colour, borderRadius: BorderRadius.circular(20)),
                child: Text('New',
                    style:
                        AppText.labelSm.copyWith(color: AppColors.onPrimary)),
              ),
          ]),
          const SizedBox(height: 8),
          Text(alert.body, style: AppText.bodyMd),
          const SizedBox(height: 8),
          Text(timeAgo(alert.createdAt),
              style:
                  AppText.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.b, required this.isNew});
  final Broadcast b;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isNew ? AppColors.primary : AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Symbols.campaign, size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(b.title, style: AppText.labelMd)),
            if (isNew)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20)),
                child: Text('New',
                    style: AppText.labelSm.copyWith(color: AppColors.onPrimary)),
              ),
          ]),
          const SizedBox(height: 8),
          Text(b.body, style: AppText.bodyMd),
          const SizedBox(height: 8),
          Text(timeAgo(b.createdAt),
              style: AppText.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }
}
