import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/journey_event.dart';
import '../data/crop_journey_export.dart';
import '../data/crop_journey_repository.dart';

/// Crop Journey — one chronological timeline of a crop's whole lifecycle,
/// aggregated from the farm's existing records.
class CropJourneyScreen extends ConsumerStatefulWidget {
  const CropJourneyScreen({super.key, required this.cropId});
  final String cropId;

  @override
  ConsumerState<CropJourneyScreen> createState() => _CropJourneyScreenState();
}

class _CropJourneyScreenState extends ConsumerState<CropJourneyScreen> {
  String _filter = 'all';
  String _search = '';
  bool _busy = false;

  static final _dayFmt = DateFormat('MMM d');

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(cropJourneyProvider(widget.cropId));
    return Scaffold(
      backgroundColor: AppColors.background,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorBody(error: e.toString()),
        data: (j) => _content(j),
      ),
      bottomNavigationBar: async.maybeWhen(
        data: (j) => _footer(j),
        orElse: () => null,
      ),
    );
  }

  List<JourneyEvent> _visible(CropJourney j) {
    final q = _search.trim().toLowerCase();
    return j.events
        .where((e) => e.matches(_filter))
        .where((e) => q.isEmpty || e.searchText.contains(q))
        .toList()
        .reversed // newest first for reading
        .toList();
  }

  Widget _content(CropJourney j) {
    final events = _visible(j);
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _Hero(journey: j),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: _infoGrid(j),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: _SummaryCard(text: j.aiSummary),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: _searchField(),
        ),
        _filterChips(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Row(
            children: [
              const Icon(Symbols.timeline, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Journey Timeline', style: AppText.headlineSm),
              const Spacer(),
              if (events.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${events.length}',
                      style: AppText.labelSm
                          .copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
        ),
        if (events.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
                child: Text('No events match this filter.',
                    style: AppText.labelSm)),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              children: [
                for (var i = 0; i < events.length; i++)
                  _TimelineTile(
                    event: events[i],
                    isLast: i == events.length - 1,
                    onAction: () => context.push('/ai-analytics'),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _infoGrid(CropJourney j) {
    final profitOk = j.netProfit >= 0;
    final cards = <_StatData>[
      _StatData(Symbols.event, 'Days Planted',
          j.daysPlanted == null ? '—' : '${j.daysPlanted}d',
          const Color(0xFF2E7D32), const Color(0xFFE7F3E8)),
      _StatData(Symbols.eco, 'Stage', _cap(j.stage),
          const Color(0xFF00796B), const Color(0xFFE0F2F1)),
      _StatData(Symbols.calendar_month, 'Est. Harvest',
          j.expectedHarvest == null ? '—' : _dayFmt.format(j.expectedHarvest!),
          const Color(0xFFE65100), const Color(0xFFFFF1E3)),
      _StatData(Symbols.payments, 'Est. Profit', formatMoney(j.netProfit),
          profitOk ? const Color(0xFF1B5E20) : AppColors.error,
          profitOk ? const Color(0xFFE7F3E8) : const Color(0xFFFFEAE7),
          valueColor: profitOk ? const Color(0xFF1B5E20) : AppColors.error),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.05,
      children: [for (final c in cards) _StatCard(data: c)],
    );
  }

  Widget _searchField() {
    return TextField(
      onChanged: (v) => setState(() => _search = v),
      decoration: InputDecoration(
        hintText: 'Search events…',
        prefixIcon: const Icon(Symbols.search, size: 20),
        isDense: true,
        filled: true,
        fillColor: AppColors.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: const BorderSide(color: AppColors.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: const BorderSide(color: AppColors.outlineVariant),
        ),
      ),
    );
  }

  Widget _filterChips() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          for (final f in journeyFilters)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(f.$2),
                selected: _filter == f.$1,
                onSelected: (_) => setState(() => _filter = f.$1),
              ),
            ),
        ],
      ),
    );
  }

  Widget _footer(CropJourney j) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border(
            top: BorderSide(
                color: AppColors.outlineVariant.withValues(alpha: 0.6))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () =>
                          _run(() => CropJourneyExport.savePdf(j), 'PDF exported'),
                  icon: const Icon(Symbols.picture_as_pdf, size: 18),
                  label: const Text('Export PDF'),
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _run(() => CropJourneyExport.saveText(j),
                          'Timeline exported'),
                  icon: const Icon(Symbols.share, size: 18),
                  label: const Text('Share Timeline'),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _run(Future<void> Function() op, String ok) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await op();
      messenger.showSnackBar(SnackBar(content: Text(ok)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ----------------------------------------------------------------- stat cards

class _StatData {
  const _StatData(this.icon, this.label, this.value, this.accent, this.tint,
      {this.valueColor});
  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final Color tint;
  final Color? valueColor;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.data});
  final _StatData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: data.tint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(data.icon, size: 22, color: data.accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(data.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.labelSm
                        .copyWith(color: AppColors.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(data.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.headlineSm.copyWith(
                        color: data.valueColor ?? AppColors.onSurface,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------- hero

class _Hero extends StatelessWidget {
  const _Hero({required this.journey});
  final CropJourney journey;

  @override
  Widget build(BuildContext context) {
    final j = journey;
    final topPad = MediaQuery.of(context).padding.top;
    final healthy = j.healthStatus == 'HEALTHY';
    return SizedBox(
      height: 230 + topPad,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if ((j.photoUrl ?? '').isNotEmpty)
            Image.network(j.photoUrl!, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const _HeroGradient())
          else
            const _HeroGradient(),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black26, Colors.transparent, Colors.black87],
                stops: [0, 0.4, 1],
              ),
            ),
          ),
          // top controls
          Positioned(
            top: topPad + 4,
            left: 4,
            right: 4,
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Symbols.arrow_back, color: Colors.white),
                ),
                const Spacer(),
              ],
            ),
          ),
          // bottom content
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: healthy
                                ? AppColors.primary
                                : AppColors.error,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(healthy ? Symbols.check_circle : Symbols.warning,
                                size: 13, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(j.healthStatus,
                                style: AppText.labelSm
                                    .copyWith(color: Colors.white)),
                          ]),
                        ),
                        if ((j.plotName ?? '').isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(j.plotName!,
                              style: AppText.labelSm
                                  .copyWith(color: Colors.white70)),
                        ],
                      ]),
                      const SizedBox(height: 8),
                      Text(j.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.headlineLg
                              .copyWith(color: Colors.white)),
                      Text(
                          j.isGreenhouse
                              ? 'Greenhouse${j.plotName != null ? '' : ''}'
                              : (j.variety ?? 'Open field'),
                          style:
                              AppText.labelMd.copyWith(color: Colors.white70)),
                    ],
                  ),
                ),
                _HealthRing(score: j.healthScore),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroGradient extends StatelessWidget {
  const _HeroGradient();
  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
        ),
      ),
    );
  }
}

class _HealthRing extends StatelessWidget {
  const _HealthRing({required this.score});
  final int score;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: 58,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 58,
            height: 58,
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: 5,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          Text('$score%',
              style: AppText.labelMd.copyWith(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ summary

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFE7F3E8),
            AppColors.primaryContainer.withValues(alpha: 0.18),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Symbols.auto_awesome,
                  size: 17, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Text('AI Season Summary',
                style: AppText.labelMd.copyWith(
                    color: AppColors.primary, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 10),
          Text(text,
              style: AppText.bodyMd
                  .copyWith(height: 1.5, color: AppColors.onSurface)),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- timeline

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.event,
    required this.isLast,
    required this.onAction,
  });
  final JourneyEvent event;
  final bool isLast;
  final VoidCallback onAction;

  static final _dayFmt = DateFormat('MMM d');

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = _accent(event.type);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                  child: Icon(icon, size: 18, color: fg),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                        width: 2, color: AppColors.outlineVariant),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: _EventCard(
                  event: event, accent: fg, onAction: onAction),
            ),
          ),
        ],
      ),
    );
  }

  static (Color, Color, IconData) _accent(JEventType t) => switch (t) {
        JEventType.planted =>
          (const Color(0xFFFCE4EC), const Color(0xFFC2185B), Symbols.compost),
        JEventType.irrigation =>
          (const Color(0xFFE3F2FD), const Color(0xFF1976D2), Symbols.water_drop),
        JEventType.fertilizer =>
          (const Color(0xFFE8F5E9), const Color(0xFF2E7D32), Symbols.science),
        JEventType.disease || JEventType.ai =>
          (const Color(0xFFFDECEA), const Color(0xFFD32F2F), Symbols.bug_report),
        JEventType.treatment =>
          (const Color(0xFFFFF3E0), const Color(0xFFE65100), Symbols.medication),
        JEventType.harvest =>
          (const Color(0xFFFFF3E0), const Color(0xFFE65100), Symbols.agriculture),
        JEventType.sale =>
          (const Color(0xFFE8F5E9), const Color(0xFF1B5E20), Symbols.payments),
        JEventType.expense =>
          (const Color(0xFFFBE9E7), const Color(0xFFBF360C), Symbols.receipt_long),
        JEventType.task =>
          (const Color(0xFFEDE7F6), const Color(0xFF5E35B1), Symbols.task_alt),
        JEventType.weather =>
          (const Color(0xFFECEFF1), const Color(0xFF455A64), Symbols.cloud),
      };
}

class _EventCard extends StatelessWidget {
  const _EventCard(
      {required this.event, required this.accent, required this.onAction});
  final JourneyEvent event;
  final Color accent;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final danger = event.danger;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: danger
            ? const Color(0xFFFDECEA)
            : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: danger
                ? const Color(0xFFF3B4AE)
                : AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (danger) ...[
                const Icon(Symbols.warning,
                    size: 18, color: Color(0xFFD32F2F)),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(event.title,
                    style: AppText.labelMd.copyWith(
                        color: danger
                            ? const Color(0xFFD32F2F)
                            : AppColors.onSurface,
                        fontWeight: FontWeight.w700)),
              ),
              Text(_TimelineTile._dayFmt.format(event.date),
                  style: AppText.labelSm
                      .copyWith(color: AppColors.onSurfaceVariant)),
            ],
          ),
          if (event.description != null && event.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(event.description!, style: AppText.bodyMd),
          ],
          if (event.details.isNotEmpty) ...[
            const SizedBox(height: 10),
            _detailGrid(event.details),
          ],
          if (event.photos.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: event.photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(event.photos[i],
                      width: 56, height: 56, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                          width: 56,
                          height: 56,
                          color: AppColors.surfaceContainerHigh,
                          child: const Icon(Symbols.image, size: 20))),
                ),
              ),
            ),
          ],
          if (event.cost != null) ...[
            const SizedBox(height: 8),
            Text('-${formatMoney(event.cost!)}',
                style: AppText.labelMd.copyWith(color: AppColors.error)),
          ],
          if (event.actionLabel != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Symbols.description, size: 18),
                label: Text(event.actionLabel!),
                style: FilledButton.styleFrom(
                  backgroundColor:
                      danger ? const Color(0xFFD32F2F) : AppColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailGrid(List<(String, String)> details) {
    return Column(
      children: [
        for (var i = 0; i < details.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _cell(details[i])),
                if (i + 1 < details.length)
                  Expanded(child: _cell(details[i + 1]))
                else
                  const Spacer(),
              ],
            ),
          ),
      ],
    );
  }

  Widget _cell((String, String) d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(d.$1,
            style: AppText.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(d.$2, style: AppText.labelMd),
      ],
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.error});
  final String error;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Symbols.timeline, size: 48, color: AppColors.outline),
            const SizedBox(height: 12),
            Text('Could not load the journey', style: AppText.headlineSm),
            const SizedBox(height: 6),
            Text(error, textAlign: TextAlign.center, style: AppText.labelSm),
          ],
        ),
      ),
    );
  }
}
