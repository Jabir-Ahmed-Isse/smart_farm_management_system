import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/farm.dart';
import '../../../models/weather.dart';
import '../../profile/data/profile_repository.dart';
import '../data/somali_places.dart';
import '../data/weather_repository.dart';

/// Live weather for the farm, with farmer-facing advisories.
class WeatherScreen extends ConsumerWidget {
  const WeatherScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farm = ref.watch(activeFarmProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Weather'),
        actions: [
          if (farm != null && farm.hasLocation)
            IconButton(
              tooltip: 'Change location',
              icon: const Icon(Symbols.edit_location_alt),
              onPressed: () => _editLocation(context, ref, farm),
            ),
        ],
      ),
      body: farm == null
          ? const Center(child: Text('Create a farm to see its weather.'))
          : farm.hasLocation
              ? _WeatherBody(farm: farm)
              : _SetLocationPrompt(farm: farm),
    );
  }

  Future<void> _editLocation(
      BuildContext context, WidgetRef ref, Farm farm) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _LocationSheet(farm: farm),
    );
    if (saved == true) ref.invalidate(myFarmsProvider);
  }
}

class _WeatherBody extends ConsumerWidget {
  const _WeatherBody({required this.farm});
  final Farm farm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coords = (lat: farm.latitude!, lng: farm.longitude!);
    final weather = ref.watch(weatherForFarmProvider(coords));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(weatherForFarmProvider(coords)),
      child: weather.when(
        loading: () => ListView(children: const [
          SizedBox(height: 240, child: Center(child: CircularProgressIndicator())),
        ]),
        error: (e, _) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 80),
            const Icon(Symbols.cloud_off, size: 56, color: AppColors.outline),
            const SizedBox(height: 12),
            Text('Could not load the weather.',
                textAlign: TextAlign.center, style: AppText.headlineSm),
            const SizedBox(height: 8),
            Text('Check your connection and pull down to try again.',
                textAlign: TextAlign.center,
                style: AppText.bodyMd
                    .copyWith(color: AppColors.onSurfaceVariant)),
          ],
        ),
        data: (report) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _CurrentCard(farm: farm, report: report),
            if (report.alerts.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('Advisories', style: AppText.headlineSm),
              const SizedBox(height: 8),
              for (final alert in report.alerts) _AlertCard(alert: alert),
            ],
            const SizedBox(height: 20),
            Text('7-day outlook', style: AppText.headlineSm),
            const SizedBox(height: 8),
            for (final day in report.daily) _DailyRow(day: day),
          ],
        ),
      ),
    );
  }
}

class _CurrentCard extends StatelessWidget {
  const _CurrentCard({required this.farm, required this.report});
  final Farm farm;
  final WeatherReport report;

  @override
  Widget build(BuildContext context) {
    final c = report.current;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryContainer],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(farm.name,
                        style: AppText.labelMd
                            .copyWith(color: AppColors.onPrimary)),
                    const SizedBox(height: 2),
                    Text(c.condition.label,
                        style: AppText.bodyMd.copyWith(
                            color: AppColors.onPrimary,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Icon(c.condition.icon, size: 56, color: AppColors.onPrimary),
            ],
          ),
          const SizedBox(height: 8),
          Text('${c.temperature.round()}°',
              style: AppText.headlineLg.copyWith(
                  color: AppColors.onPrimary,
                  fontSize: 56,
                  fontWeight: FontWeight.w700)),
          Text('Feels like ${c.apparentTemperature.round()}°',
              style: AppText.labelMd
                  .copyWith(color: AppColors.onPrimary.withValues(alpha: 0.9))),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Stat(icon: Symbols.humidity_percentage, label: 'Humidity',
                  value: '${c.humidity}%'),
              _Stat(icon: Symbols.rainy, label: 'Rain now',
                  value: '${c.precipitation.toStringAsFixed(1)} mm'),
              _Stat(icon: Symbols.air, label: 'Wind',
                  value: '${c.windSpeed.round()} km/h'),
            ],
          ),
          if (report.stale) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Symbols.cloud_off,
                    size: 14, color: AppColors.onPrimary.withValues(alpha: 0.8)),
                const SizedBox(width: 6),
                Text('Offline — last updated ${_ago(report.fetchedAt)}',
                    style: AppText.labelSm.copyWith(
                        color: AppColors.onPrimary.withValues(alpha: 0.8))),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.onPrimary, size: 22),
        const SizedBox(height: 4),
        Text(value,
            style: AppText.bodyMd.copyWith(
                color: AppColors.onPrimary, fontWeight: FontWeight.w700)),
        Text(label,
            style: AppText.labelSm
                .copyWith(color: AppColors.onPrimary.withValues(alpha: 0.85))),
      ],
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert});
  final WeatherAlert alert;

  @override
  Widget build(BuildContext context) {
    final colour = switch (alert.severity) {
      AlertSeverity.danger => AppColors.error,
      AlertSeverity.warning => AppColors.tertiary,
      AlertSeverity.info => AppColors.primary,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colour.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(alert.icon, color: colour, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert.title,
                    style: AppText.bodyMd.copyWith(
                        fontWeight: FontWeight.w700, color: colour)),
                const SizedBox(height: 2),
                Text(alert.message,
                    style: AppText.labelMd
                        .copyWith(color: AppColors.onSurface)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyRow extends StatelessWidget {
  const _DailyRow({required this.day});
  final DailyForecast day;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(_weekday(day.date),
                style: AppText.labelMd.copyWith(fontWeight: FontWeight.w600)),
          ),
          Icon(day.condition.icon,
              color: AppColors.onSurfaceVariant, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                const Icon(Symbols.rainy,
                    size: 14, color: AppColors.primary),
                const SizedBox(width: 3),
                Text('${day.precipitationProbability}%',
                    style: AppText.labelSm
                        .copyWith(color: AppColors.onSurfaceVariant)),
                if (day.precipitationSum >= 1) ...[
                  const SizedBox(width: 6),
                  Text('${day.precipitationSum.round()}mm',
                      style: AppText.labelSm
                          .copyWith(color: AppColors.onSurfaceVariant)),
                ],
              ],
            ),
          ),
          Text('${day.tempMax.round()}°',
              style: AppText.bodyMd.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
          Text('${day.tempMin.round()}°',
              style: AppText.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }

  static String _weekday(DateTime d) {
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return 'Today';
    }
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[(d.weekday - 1) % 7];
  }
}

class _SetLocationPrompt extends StatelessWidget {
  const _SetLocationPrompt({required this.farm});
  final Farm farm;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Symbols.wrong_location,
                size: 56, color: AppColors.outline),
            const SizedBox(height: 12),
            Text('Set your farm location',
                style: AppText.headlineSm, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('Weather needs to know where ${farm.name} is. Add its '
                'coordinates once and the forecast follows.',
                style: AppText.bodyMd
                    .copyWith(color: AppColors.onSurfaceVariant),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Consumer(
              builder: (context, ref, _) => FilledButton.icon(
                onPressed: () async {
                  final saved = await showModalBottomSheet<bool>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: AppColors.surfaceContainerLowest,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    builder: (_) => _LocationSheet(farm: farm),
                  );
                  if (saved == true) ref.invalidate(myFarmsProvider);
                },
                icon: const Icon(Symbols.add_location_alt),
                label: const Text('Set location'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pick the farm's location — search a town or, for precision, type exact
/// coordinates. Pops true when saved.
class _LocationSheet extends ConsumerStatefulWidget {
  const _LocationSheet({required this.farm});
  final Farm farm;

  @override
  ConsumerState<_LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends ConsumerState<_LocationSheet> {
  final _searchCtrl = TextEditingController();
  late final TextEditingController _latCtrl;
  late final TextEditingController _lngCtrl;

  Place? _selected;
  bool _manual = false;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _latCtrl =
        TextEditingController(text: widget.farm.latitude?.toString() ?? '');
    _lngCtrl =
        TextEditingController(text: widget.farm.longitude?.toString() ?? '');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchCtrl.text;
    final results = somaliPlaces.where((p) => p.matches(query)).toList();
    final maxHeight = MediaQuery.of(context).size.height * 0.8;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Where is ${widget.farm.name}?', style: AppText.headlineSm),
            const SizedBox(height: 4),
            Text('Choose your nearest town — the forecast follows.',
                style: AppText.labelSm
                    .copyWith(color: AppColors.onSurfaceVariant)),
            const SizedBox(height: 16),
            if (!_manual) ...[
              TextField(
                controller: _searchCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Symbols.search),
                  hintText: 'Search your town…',
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: results.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text('No town matches "$query".',
                            textAlign: TextAlign.center,
                            style: AppText.bodyMd.copyWith(
                                color: AppColors.onSurfaceVariant)),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: results.length,
                        itemBuilder: (_, i) {
                          final p = results[i];
                          final selected = identical(p, _selected);
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              selected
                                  ? Symbols.check_circle
                                  : Symbols.location_on,
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.onSurfaceVariant,
                            ),
                            title: Text(p.name, style: AppText.bodyMd),
                            subtitle: Text(p.region, style: AppText.labelSm),
                            selected: selected,
                            selectedTileColor:
                                AppColors.primaryContainer.withValues(alpha: 0.15),
                            onTap: () => setState(() {
                              _selected = p;
                              _error = null;
                            }),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _manual = true),
                  icon: const Icon(Symbols.edit_location_alt, size: 18),
                  label: const Text('Enter exact coordinates instead'),
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _latCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]'))
                      ],
                      decoration: const InputDecoration(
                          labelText: 'Latitude', hintText: '2.0469'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _lngCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]'))
                      ],
                      decoration: const InputDecoration(
                          labelText: 'Longitude', hintText: '45.3182'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _manual = false),
                  icon: const Icon(Symbols.arrow_back, size: 18),
                  label: const Text('Back to town list'),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: AppText.labelMd.copyWith(color: AppColors.error)),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.onPrimary))
                  : Text(_selected != null && !_manual
                      ? 'Use ${_selected!.name.split(' (').first}'
                      : 'Save location'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    double? lat;
    double? lng;
    if (_manual) {
      lat = double.tryParse(_latCtrl.text.trim());
      lng = double.tryParse(_lngCtrl.text.trim());
      if (lat == null || lng == null) {
        setState(() => _error = 'Enter both a latitude and a longitude.');
        return;
      }
      if (lat < -90 || lat > 90) {
        setState(() => _error = 'Latitude must be between -90 and 90.');
        return;
      }
      if (lng < -180 || lng > 180) {
        setState(() => _error = 'Longitude must be between -180 and 180.');
        return;
      }
    } else {
      if (_selected == null) {
        setState(() => _error = 'Pick your town from the list.');
        return;
      }
      lat = _selected!.latitude;
      lng = _selected!.longitude;
    }

    final nav = Navigator.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(weatherRepositoryProvider).setFarmLocation(
            farmId: widget.farm.id,
            latitude: lat,
            longitude: lng,
          );
      nav.pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save the location.';
        });
      }
    }
  }
}
