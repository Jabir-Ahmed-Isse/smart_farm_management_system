import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/plant_diagnosis.dart';
import '../data/plant_doctor_repository.dart';

/// The full AI Plant Doctor report. Used for a fresh diagnosis (with the local
/// [localImage] bytes) and when revisiting one from history (image fetched via
/// a signed URL).
class DiagnosisReportScreen extends ConsumerStatefulWidget {
  const DiagnosisReportScreen({
    super.key,
    required this.diagnosis,
    this.localImage,
  });

  final PlantDiagnosis diagnosis;
  final Uint8List? localImage;

  @override
  ConsumerState<DiagnosisReportScreen> createState() =>
      _DiagnosisReportScreenState();
}

class _DiagnosisReportScreenState extends ConsumerState<DiagnosisReportScreen> {
  late PlantDiagnosis _dx = widget.diagnosis;

  @override
  Widget build(BuildContext context) {
    final dx = _dx;
    final t = ref.watch(stringsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _hero(context, dx, t),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _confidenceRow(dx, t),
                  if (dx.needsExpert) ...[
                    const SizedBox(height: 12),
                    _ExpertBanner(text: t.expertBannerText),
                  ],
                  const SizedBox(height: 16),
                  if (dx.isDiseased || dx.diseaseName != null)
                    _diseaseCard(dx, t),
                  if (dx.symptoms.isNotEmpty)
                    _Section(
                      icon: Symbols.coronavirus,
                      title: t.symptomsDetected,
                      child: _Bullets(dx.symptoms),
                    ),
                  if (dx.cause != null || dx.environmentalFactors != null)
                    _Section(
                      icon: Symbols.help,
                      title: t.causeLabel,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (dx.cause != null) _para(dx.cause!),
                          if (dx.environmentalFactors != null) ...[
                            const SizedBox(height: 8),
                            _para('${t.environmentalPrefix}${dx.environmentalFactors}',
                                muted: true),
                          ],
                        ],
                      ),
                    ),
                  if (dx.recommendedActions.isNotEmpty)
                    _Section(
                      icon: Symbols.checklist,
                      title: t.recommendedActionsLabel,
                      child: _Bullets(dx.recommendedActions, numbered: true),
                    ),
                  if (dx.medicineOptions.isNotEmpty)
                    _MedicineOptions(options: dx.medicineOptions, t: t),
                  if (dx.organicTreatment.isNotEmpty)
                    _Section(
                      icon: Symbols.compost,
                      title: t.organicTreatmentLabel,
                      accent: AppColors.primaryContainer,
                      child: _Bullets(dx.organicTreatment),
                    ),
                  if (dx.safetyInstructions.isNotEmpty ||
                      dx.protectiveEquipment.isNotEmpty)
                    _Section(
                      icon: Symbols.health_and_safety,
                      title: t.safetyLabel,
                      accent: AppColors.error,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (dx.safetyInstructions.isNotEmpty)
                            _Bullets(dx.safetyInstructions),
                          if (dx.protectiveEquipment.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text('${t.wearPrefix}${dx.protectiveEquipment.join(', ')}',
                                style: AppText.labelMd),
                          ],
                        ],
                      ),
                    ),
                  if (dx.preventionTips.isNotEmpty)
                    _Section(
                      icon: Symbols.shield,
                      title: t.preventionLabel,
                      child: _Bullets(dx.preventionTips),
                    ),
                  if (dx.expectedRecoveryTime != null ||
                      dx.weatherRecommendation != null)
                    _Section(
                      icon: Symbols.schedule,
                      title: t.recoveryTimingLabel,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (dx.expectedRecoveryTime != null)
                            _kv(t.expectedRecoveryLabel, dx.expectedRecoveryTime!),
                          if (dx.weatherRecommendation != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Symbols.rainy,
                                    size: 18, color: AppColors.tertiary),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(dx.weatherRecommendation!,
                                        style: AppText.bodyMd)),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  _diseaseTimeline(dx, t),
                  const SizedBox(height: 8),
                  _recoveryTracker(dx, t),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Healthy → Detected → Treatment → Recovered, filled to the current stage.
  Widget _diseaseTimeline(PlantDiagnosis dx, AppStrings t) {
    // Index of the furthest stage reached (0-based over the 4 nodes).
    final reached = dx.isHealthy
        ? 0
        : switch (dx.recoveryStatus) {
            'recovered' => 3,
            'recovering' => 2,
            'failed' => 1,
            _ => 1, // pending → detected
          };
    final failed = dx.recoveryStatus == 'failed';
    final stages = dx.isHealthy
        ? [t.healthyLabel]
        : [t.stageDetected, t.stageTreatment, t.stageRecovering, t.stageRecovered];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.diseaseTimelineLabel, style: AppText.labelMd),
          const SizedBox(height: 14),
          Row(
            children: [
              for (var i = 0; i < stages.length; i++) ...[
                _timelineNode(
                  label: stages[i],
                  done: i <= reached,
                  isLast: i == reached && !dx.isHealthy && i < stages.length - 1,
                  failed: failed && i == reached,
                ),
                if (i < stages.length - 1)
                  Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.only(bottom: 20),
                      color: i < reached
                          ? AppColors.primary
                          : AppColors.outlineVariant,
                    ),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _timelineNode({
    required String label,
    required bool done,
    required bool isLast,
    required bool failed,
  }) {
    final color = failed
        ? AppColors.error
        : (done ? AppColors.primary : AppColors.outline);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: done ? color : AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Icon(
            failed ? Symbols.close : (done ? Symbols.check : Symbols.circle),
            size: 15,
            color: done ? AppColors.onPrimary : color,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 62,
          child: Text(label,
              textAlign: TextAlign.center,
              style: AppText.labelSm.copyWith(
                  color: done
                      ? AppColors.onSurface
                      : AppColors.onSurfaceVariant)),
        ),
      ],
    );
  }

  // ------------------------------------------------------------- hero

  Widget _hero(BuildContext context, PlantDiagnosis dx, AppStrings t) {
    final health = _healthMeta(dx, t);
    return SliverAppBar(
      pinned: true,
      expandedHeight: 260,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 56, bottom: 14, right: 16),
        title: Text(dx.plantName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.labelMd.copyWith(color: Colors.white)),
        background: Stack(
          fit: StackFit.expand,
          children: [
            _heroImage(dx),
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
            Positioned(
              left: 16,
              right: 16,
              bottom: 44,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: health.$2,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(health.$3, size: 16, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(health.$1,
                            style: AppText.labelSm.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  if (dx.plantVariety != null) ...[
                    const SizedBox(height: 8),
                    Text(dx.plantVariety!,
                        style: AppText.bodyMd.copyWith(color: Colors.white70)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroImage(PlantDiagnosis dx) {
    if (widget.localImage != null) {
      return Image.memory(widget.localImage!, fit: BoxFit.cover);
    }
    return FutureBuilder<String?>(
      future: ref.read(plantDoctorRepositoryProvider).signedImageUrl(dx.imageUrl),
      builder: (context, snap) {
        final url = snap.data;
        if (url == null) {
          return Container(
            color: AppColors.primaryContainer,
            child: const Center(
                child: Icon(Symbols.potted_plant, size: 72, color: Colors.white70)),
          );
        }
        return Image.network(url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
                color: AppColors.primaryContainer,
                child: const Center(
                    child: Icon(Symbols.hide_image,
                        size: 56, color: Colors.white70))));
      },
    );
  }

  // ------------------------------------------------------------- pieces

  Widget _confidenceRow(PlantDiagnosis dx, AppStrings t) {
    final pct = dx.confidencePct;
    final color = pct >= 70
        ? AppColors.primary
        : pct >= 40
            ? AppColors.tertiary
            : AppColors.error;
    return Row(
      children: [
        SizedBox(
          width: 58,
          height: 58,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 58,
                height: 58,
                child: CircularProgressIndicator(
                  value: pct / 100,
                  strokeWidth: 6,
                  backgroundColor: AppColors.surfaceContainerHigh,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
              Text('$pct%',
                  style: AppText.labelMd.copyWith(color: color, fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.aiConfidence, style: AppText.labelMd),
              const SizedBox(height: 2),
              Text(
                pct >= 70 ? t.highConfidence : t.uncertainDiagnosis,
                style: AppText.labelSm,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _diseaseCard(PlantDiagnosis dx, AppStrings t) {
    final sev = _severityMeta(dx.severity);
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: sev.$2.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(dx.diseaseName ?? t.possibleIssue,
                    style: AppText.headlineSm),
              ),
              if (dx.severity != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: sev.$2.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(sev.$1,
                      style: AppText.labelSm.copyWith(
                          color: sev.$2, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (dx.affectedPart != null)
                _chip(Symbols.eco, _pretty(dx.affectedPart!)),
              if (dx.diseaseStage != null)
                _chip(Symbols.timeline, '${_pretty(dx.diseaseStage!)} stage'),
              if (dx.spreadRisk != null)
                _chip(Symbols.share, '${_pretty(dx.spreadRisk!)} spread risk'),
              if (dx.estimatedYieldLoss != null)
                _chip(Symbols.trending_down, dx.estimatedYieldLoss!),
              if (dx.recoveryProbability != null)
                _chip(Symbols.healing, '${dx.recoveryProbability} recovery'),
            ],
          ),
          if (dx.possibleDiseases.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('${t.alsoConsiderPrefix}${dx.possibleDiseases.join(', ')}',
                style: AppText.labelSm),
          ],
        ],
      ),
    );
  }

  Widget _recoveryTracker(PlantDiagnosis dx, AppStrings t) {
    const options = ['pending', 'recovering', 'recovered', 'failed'];
    final labels = {
      'pending': t.recNotStarted,
      'recovering': t.stageRecovering,
      'recovered': t.stageRecovered,
      'failed': t.recLost,
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.recoveryStatusLabel, style: AppText.labelMd),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              for (final o in options)
                ChoiceChip(
                  label: Text(labels[o]!),
                  selected: dx.recoveryStatus == o,
                  onSelected: (_) => _setRecovery(o),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _setRecovery(String status) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _dx = _copyWithStatus(status));
    try {
      await ref
          .read(plantDoctorRepositoryProvider)
          .updateRecovery(_dx.id, status);
      ref.invalidate(diagnosesForFarmProvider(_dx.farmId));
    } catch (_) {
      messenger.showSnackBar(
          SnackBar(content: Text(ref.read(stringsProvider).couldNotUpdateStatus)));
    }
  }

  PlantDiagnosis _copyWithStatus(String status) => PlantDiagnosis(
        id: _dx.id,
        farmId: _dx.farmId,
        cropId: _dx.cropId,
        plotId: _dx.plotId,
        imageUrl: _dx.imageUrl,
        plantName: _dx.plantName,
        healthStatus: _dx.healthStatus,
        confidence: _dx.confidence,
        diseaseName: _dx.diseaseName,
        severity: _dx.severity,
        needsExpert: _dx.needsExpert,
        language: _dx.language,
        recoveryStatus: status,
        notes: _dx.notes,
        report: _dx.report,
        createdAt: _dx.createdAt,
      );

  // ------------------------------------------------------------- small bits

  Widget _para(String text, {bool muted = false}) => Text(text,
      style: muted
          ? AppText.bodyMd.copyWith(color: AppColors.onSurfaceVariant)
          : AppText.bodyMd);

  Widget _kv(String k, String v) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$k: ', style: AppText.labelMd),
          Expanded(child: Text(v, style: AppText.bodyMd)),
        ],
      );

  Widget _chip(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: AppColors.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(label, style: AppText.labelSm),
          ],
        ),
      );

  static String _pretty(String token) =>
      token.replaceAll('_', ' ').replaceFirstMapped(
          RegExp(r'^\w'), (m) => m.group(0)!.toUpperCase());

  (String, Color, IconData) _healthMeta(PlantDiagnosis dx, AppStrings t) {
    if (dx.isHealthy) {
      return (t.healthyLabel, AppColors.primaryContainer, Symbols.check_circle);
    }
    if (dx.isDiseased) return (t.diseasedLabel, AppColors.error, Symbols.warning);
    return (t.unclearLabel, AppColors.tertiary, Symbols.help);
  }

  (String, Color) _severityMeta(String? s) => switch (s) {
        'critical' => ('CRITICAL', AppColors.error),
        'high' => ('HIGH', AppColors.error),
        'medium' => ('MEDIUM', AppColors.tertiary),
        'low' => ('LOW', AppColors.primary),
        _ => ('—', AppColors.outline),
      };
}

// ============================================================ shared widgets

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.child,
    this.accent,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppColors.primary;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Text(title, style: AppText.labelMd.copyWith(color: color)),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _Bullets extends StatelessWidget {
  const _Bullets(this.items, {this.numbered = false});
  final List<String> items;
  final bool numbered;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 22,
                  child: numbered
                      ? Text('${i + 1}.',
                          style: AppText.labelMd
                              .copyWith(color: AppColors.primary))
                      : const Padding(
                          padding: EdgeInsets.only(top: 7),
                          child: Icon(Symbols.fiber_manual_record,
                              size: 7, color: AppColors.primary),
                        ),
                ),
                Expanded(child: Text(items[i], style: AppText.bodyMd)),
              ],
            ),
          ),
      ],
    );
  }
}

class _ExpertBanner extends StatelessWidget {
  const _ExpertBanner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.tertiaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Symbols.support_agent, color: AppColors.tertiary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppText.labelSm
                  .copyWith(color: AppColors.onTertiaryFixedVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// A list of medicine choices, so the farmer can pick by what's available or
/// affordable rather than being given a single product.
class _MedicineOptions extends StatelessWidget {
  const _MedicineOptions({required this.options, required this.t});
  final List<ChemicalTreatment> options;
  final AppStrings t;

  @override
  Widget build(BuildContext context) {
    return _Section(
      icon: Symbols.science,
      title: t.medicineOptionsTitle,
      accent: AppColors.tertiary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (options.length > 1)
            Text(t.chooseOneHint,
                style: AppText.labelSm
                    .copyWith(color: AppColors.onSurfaceVariant)),
          for (var i = 0; i < options.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 8 : 12),
              child: _MedicineCard(
                number: i + 1,
                med: options[i],
                t: t,
                showNumber: options.length > 1,
              ),
            ),
        ],
      ),
    );
  }
}

/// One medicine option with the built-in sprayer-dose calculator (15/20/25 L).
class _MedicineCard extends StatelessWidget {
  const _MedicineCard({
    required this.number,
    required this.med,
    required this.t,
    required this.showNumber,
  });

  final int number;
  final ChemicalTreatment med;
  final AppStrings t;
  final bool showNumber;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppColors.tertiary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (showNumber) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.tertiary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${t.option} $number',
                      style: AppText.labelSm.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(med.medicineName ?? med.activeIngredient ?? '—',
                    style: AppText.bodyMd
                        .copyWith(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          if (med.activeIngredient != null && med.medicineName != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(med.activeIngredient!,
                  style: AppText.labelSm.copyWith(fontStyle: FontStyle.italic)),
            ),
          if (med.dosePerLiter != null) ...[
            const SizedBox(height: 12),
            Text(t.mixPerSprayer, style: AppText.labelMd),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final l in [15, 20, 25])
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.tertiaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text('${l}L',
                              style: AppText.labelSm.copyWith(
                                  color: AppColors.onTertiaryFixedVariant)),
                          const SizedBox(height: 4),
                          Text(med.doseFor(l) ?? '—',
                              textAlign: TextAlign.center,
                              style: AppText.labelMd.copyWith(
                                  color: AppColors.tertiary,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(t.doseLine(med.dosePerLiter!), style: AppText.labelSm),
          ],
          const SizedBox(height: 8),
          if (med.mixingRatio != null) _line(t.mixingRatioLabel, med.mixingRatio!),
          if (med.repeatInterval != null) _line(t.repeatLabel, med.repeatInterval!),
          if (med.maxApplications != null)
            _line(t.maxApplicationsLabel, med.maxApplications!),
          if (med.preHarvestInterval != null)
            _line(t.preHarvestLabel, med.preHarvestInterval!),
        ],
      ),
    );
  }

  Widget _line(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 150, child: Text(k, style: AppText.labelSm)),
            Expanded(child: Text(v, style: AppText.bodyMd)),
          ],
        ),
      );
}
