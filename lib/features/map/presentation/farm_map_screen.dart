import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/farm.dart';
import '../../../models/plot.dart';
import '../../expenses/data/expense_repository.dart';
import '../../profile/data/profile_repository.dart';

/// Writes plot coordinates back to public.plots (RLS is_farm_member).
final plotLocationRepositoryProvider = Provider<PlotLocationRepository>((ref) {
  return PlotLocationRepository(ref.watch(supabaseClientProvider));
});

class PlotLocationRepository {
  PlotLocationRepository(this._client);

  final SupabaseClient _client;

  Future<void> setLocation({
    required String plotId,
    double? latitude,
    double? longitude,
  }) async {
    await _client.from('plots').update({
      'latitude': latitude,
      'longitude': longitude,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', plotId);
  }
}

/// Which plot is selected on the map, if any.
final _selectedPlotProvider = StateProvider<String?>((ref) => null);

/// Farm map — every located plot drawn to scale against the others.
///
/// This is a schematic, not a satellite map: the app ships no map SDK or API
/// key, so plots are laid out from their own latitude/longitude relative to
/// each other. That works offline, which matters more here than tiles.
class FarmMapScreen extends ConsumerWidget {
  const FarmMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farms = ref.watch(myFarmsProvider);
    final farm =
        farms.valueOrNull?.isNotEmpty == true ? farms.value!.first : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(ref.watch(stringsProvider).farmMap)),
      body: farm == null
          ? const Center(child: Text('Create a farm to map your plots.'))
          : _Body(farm: farm),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.farm});
  final Farm farm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plots = ref.watch(plotsForFarmProvider(farm.id));
    final selectedId = ref.watch(_selectedPlotProvider);

    return plots.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Could not load plots.\n$e',
              textAlign: TextAlign.center,
              style:
                  AppText.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Symbols.map, size: 56, color: AppColors.outline),
                  const SizedBox(height: 12),
                  Text('No plots to map',
                      style: AppText.headlineSm, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text('Add plots under Farms first, then pin each one here.',
                      style: AppText.bodyMd
                          .copyWith(color: AppColors.onSurfaceVariant),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        }

        final located = list.where((p) => p.hasLocation).toList();
        final unlocated = list.where((p) => !p.hasLocation).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                clipBehavior: Clip.antiAlias,
                child: located.isEmpty
                    ? _MapPlaceholder(count: list.length)
                    : LayoutBuilder(
                        builder: (context, constraints) => GestureDetector(
                          onTapUp: (details) => _handleTap(
                              ref, located, details.localPosition, constraints),
                          child: CustomPaint(
                            painter: _FarmMapPainter(
                              plots: located,
                              selectedId: selectedId,
                            ),
                            size: Size(constraints.maxWidth,
                                constraints.maxHeight),
                          ),
                        ),
                      ),
              ),
            ),
            if (located.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Positions are relative — each plot is placed from its own '
                'coordinates. Circle size follows plot area.',
                style: AppText.labelSm
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              Text('Pinned plots', style: AppText.headlineSm),
              const SizedBox(height: 8),
              for (final plot in located)
                _PlotRow(
                  plot: plot,
                  selected: plot.id == selectedId,
                  onTap: () => ref.read(_selectedPlotProvider.notifier).state =
                      plot.id == selectedId ? null : plot.id,
                  onEdit: () => _editLocation(context, ref, plot),
                ),
            ],
            if (unlocated.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('Not pinned yet', style: AppText.headlineSm),
              const SizedBox(height: 8),
              for (final plot in unlocated)
                _PlotRow(
                  plot: plot,
                  selected: false,
                  onTap: () => _editLocation(context, ref, plot),
                  onEdit: () => _editLocation(context, ref, plot),
                ),
            ],
          ],
        );
      },
    );
  }

  /// Select whichever pinned plot was tapped closest to.
  void _handleTap(WidgetRef ref, List<Plot> located, Offset position,
      BoxConstraints constraints) {
    final points = _FarmMapPainter.layout(
        located, Size(constraints.maxWidth, constraints.maxHeight));
    String? nearest;
    double best = 40; // only count taps within 40px of a pin
    for (final entry in points.entries) {
      final d = (entry.value - position).distance;
      if (d < best) {
        best = d;
        nearest = entry.key;
      }
    }
    ref.read(_selectedPlotProvider.notifier).state =
        nearest == ref.read(_selectedPlotProvider) ? null : nearest;
  }

  Future<void> _editLocation(
      BuildContext context, WidgetRef ref, Plot plot) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _LocationSheet(plot: plot),
    );
    if (saved == true) ref.invalidate(plotsForFarmProvider(farm.id));
  }
}

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Symbols.location_off, size: 48, color: AppColors.outline),
            const SizedBox(height: 12),
            Text('No plot is pinned yet',
                style: AppText.bodyMd.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              'Add coordinates to any of your $count plots and they will '
              'appear here.',
              style: AppText.labelSm.copyWith(color: AppColors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Lays plots out by latitude/longitude and draws them as area-scaled circles.
class _FarmMapPainter extends CustomPainter {
  _FarmMapPainter({required this.plots, required this.selectedId});

  final List<Plot> plots;
  final String? selectedId;

  static const _pad = 40.0;

  /// Screen position for each plot id. Shared with hit-testing so a tap lands
  /// on the same spot the pin was drawn.
  static Map<String, Offset> layout(List<Plot> plots, Size size) {
    final result = <String, Offset>{};
    if (plots.isEmpty) return result;

    final lats = plots.map((p) => p.latitude!).toList();
    final lngs = plots.map((p) => p.longitude!).toList();
    final minLat = lats.reduce(math.min), maxLat = lats.reduce(math.max);
    final minLng = lngs.reduce(math.min), maxLng = lngs.reduce(math.max);
    final latSpan = maxLat - minLat, lngSpan = maxLng - minLng;

    final w = size.width - _pad * 2;
    final h = size.height - _pad * 2;

    for (final p in plots) {
      // A single plot (or all plots on one line) sits centred on that axis.
      final fx = lngSpan == 0 ? 0.5 : (p.longitude! - minLng) / lngSpan;
      // Latitude grows north, screen y grows down — so flip it.
      final fy = latSpan == 0 ? 0.5 : 1 - (p.latitude! - minLat) / latSpan;
      result[p.id] = Offset(_pad + fx * w, _pad + fy * h);
    }
    return result;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final points = layout(plots, size);

    final grid = Paint()
      ..color = AppColors.outlineVariant.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final dx = size.width * i / 4;
      final dy = size.height * i / 4;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), grid);
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), grid);
    }

    // Biggest plot sets the top of the size scale.
    final maxArea = plots
        .map((p) => (p.area ?? 0).toDouble())
        .fold<double>(0, math.max);

    for (final plot in plots) {
      final centre = points[plot.id]!;
      final area = (plot.area ?? 0).toDouble();
      final radius = maxArea > 0
          ? 14 + 18 * math.sqrt(area / maxArea)
          : 18.0;
      final selected = plot.id == selectedId;
      final colour = plot.type == 'greenhouse'
          ? AppColors.tertiary
          : AppColors.primary;

      canvas.drawCircle(
        centre,
        radius,
        Paint()..color = colour.withValues(alpha: selected ? 0.35 : 0.18),
      );
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..color = colour
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 3 : 1.5,
      );

      final label = TextPainter(
        text: TextSpan(
          text: plot.name,
          style: TextStyle(
            color: AppColors.onSurface,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: 90);
      label.paint(
        canvas,
        Offset(centre.dx - label.width / 2, centre.dy + radius + 4),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FarmMapPainter old) =>
      old.plots != plots || old.selectedId != selectedId;
}

class _PlotRow extends StatelessWidget {
  const _PlotRow({
    required this.plot,
    required this.selected,
    required this.onTap,
    required this.onEdit,
  });

  final Plot plot;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      plot.type == 'greenhouse' ? 'Greenhouse' : 'Open field',
      if (plot.area != null) '${plot.area} ${plot.areaUnit}',
      if (plot.hasLocation)
        '${plot.latitude!.toStringAsFixed(5)}, ${plot.longitude!.toStringAsFixed(5)}',
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: selected ? AppColors.primaryContainer.withValues(alpha: 0.12)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color:
                selected ? AppColors.primary : AppColors.outlineVariant),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
            child: Row(
              children: [
                Icon(
                  plot.hasLocation ? Symbols.location_on : Symbols.location_off,
                  size: 20,
                  color: plot.hasLocation
                      ? AppColors.primary
                      : AppColors.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(plot.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.bodyMd
                              .copyWith(fontWeight: FontWeight.w600)),
                      Text(meta.join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.labelSm
                              .copyWith(color: AppColors.onSurfaceVariant)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Symbols.edit_location_alt, size: 20),
                  color: AppColors.onSurfaceVariant,
                  onPressed: onEdit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Enter or clear a plot's coordinates. Pops true when saved.
class _LocationSheet extends ConsumerStatefulWidget {
  const _LocationSheet({required this.plot});
  final Plot plot;

  @override
  ConsumerState<_LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends ConsumerState<_LocationSheet> {
  late final TextEditingController _latCtrl;
  late final TextEditingController _lngCtrl;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _latCtrl =
        TextEditingController(text: widget.plot.latitude?.toString() ?? '');
    _lngCtrl =
        TextEditingController(text: widget.plot.longitude?.toString() ?? '');
  }

  @override
  void dispose() {
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${widget.plot.name} — location', style: AppText.headlineSm),
          const SizedBox(height: 8),
          Text(
            'Enter the coordinates of the plot centre. You can read them off '
            'any maps app by long-pressing the spot.',
            style: AppText.labelSm.copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
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
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: AppText.labelMd.copyWith(color: AppColors.error)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.onPrimary))
                : const Text('Save location'),
          ),
          if (widget.plot.hasLocation)
            TextButton(
              onPressed: _saving ? null : _clear,
              child: const Text('Remove pin'),
            ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final lat = double.tryParse(_latCtrl.text.trim());
    final lng = double.tryParse(_lngCtrl.text.trim());
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
    await _write(lat, lng);
  }

  Future<void> _clear() => _write(null, null);

  Future<void> _write(double? lat, double? lng) async {
    final nav = Navigator.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(plotLocationRepositoryProvider).setLocation(
            plotId: widget.plot.id,
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
