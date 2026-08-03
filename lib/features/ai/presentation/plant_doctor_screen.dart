import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/ai_credit.dart';
import '../../../models/farm.dart';
import '../../../models/plant_diagnosis.dart';
import '../../profile/data/profile_repository.dart';
import '../data/ai_service.dart';
import '../data/plant_doctor_repository.dart';
import 'diagnosis_report_screen.dart';

/// AI Plant Doctor — capture a plant photo, get a structured diagnosis, and
/// revisit past scans.
class PlantDoctorScreen extends ConsumerStatefulWidget {
  const PlantDoctorScreen({super.key});

  @override
  ConsumerState<PlantDoctorScreen> createState() => _PlantDoctorScreenState();
}

class _PlantDoctorScreenState extends ConsumerState<PlantDoctorScreen> {
  bool _busy = false;
  Uint8List? _preview;

  String get _language =>
      ui.PlatformDispatcher.instance.locale.languageCode == 'so' ? 'so' : 'en';

  @override
  Widget build(BuildContext context) {
    final farms = ref.watch(myFarmsProvider);
    final farm =
        farms.valueOrNull?.isNotEmpty == true ? farms.value!.first : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('AI Plant Doctor'),
        backgroundColor: AppColors.background,
      ),
      body: Stack(
        children: [
          if (farm == null)
            const Center(child: Text('Create a farm to use the Plant Doctor.'))
          else
            _Body(farm: farm, onScan: (src) => _scan(farm, src)),
          if (_busy) _DiagnosingOverlay(preview: _preview),
        ],
      ),
    );
  }

  Future<void> _scan(Farm farm, ImageSource source) async {
    final picker = ImagePicker();
    final XFile? file;
    try {
      file = await picker.pickImage(
        source: source,
        maxWidth: 2200,
        imageQuality: 92,
      );
    } catch (_) {
      if (mounted) _snack('Could not open the camera.');
      return;
    }
    if (file == null) return;

    final bytes = await file.readAsBytes();
    setState(() {
      _busy = true;
      _preview = bytes;
    });

    final outcome = await ref.read(plantDoctorRepositoryProvider).runDiagnosis(
          bytes: bytes,
          farmId: farm.id,
          language: _language,
        );

    if (!mounted) return;
    setState(() => _busy = false);

    switch (outcome) {
      case DiagnoseSuccess(:final diagnosis):
        ref.invalidate(diagnosesForFarmProvider(farm.id));
        ref.invalidate(diagnosisCreditProvider);
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              DiagnosisReportScreen(diagnosis: diagnosis, localImage: bytes),
        ));
      case DiagnoseImageRejected(:final message):
        await _retakeDialog(message);
      case DiagnoseCreditLimit(:final credits):
        await _creditLimitSheet(credits);
      case DiagnoseError(:final message, :final code):
        if (code == 'no_key') {
          await _infoDialog(
            'AI not switched on yet',
            'The Plant Doctor needs its AI key configured on the server before '
                'it can analyse photos. Everything else is ready.',
          );
        } else {
          _snack(message);
        }
    }
  }

  Future<void> _retakeDialog(String message) => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Symbols.no_photography,
              size: 40, color: AppColors.tertiary),
          title: const Text('Retake the photo'),
          content: Text(message, textAlign: TextAlign.center),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK')),
          ],
        ),
      );

  Future<void> _infoDialog(String title, String body) => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Got it')),
          ],
        ),
      );

  Future<void> _creditLimitSheet(AiCredit? credits) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Symbols.bolt, size: 44, color: AppColors.tertiary),
              const SizedBox(height: 12),
              Text('Monthly limit reached', style: AppText.headlineSm),
              const SizedBox(height: 8),
              Text(
                "You've used all ${credits?.limit ?? kFreeDiagnosisLimit} free "
                'plant diagnoses this month. They reset on the 1st. Upgrade to '
                'Premium for unlimited scans.',
                textAlign: TextAlign.center,
                style: AppText.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _snack('Premium plans are coming soon.');
                  },
                  icon: const Icon(Symbols.workspace_premium),
                  label: const Text('Upgrade to Premium'),
                ),
              ),
            ],
          ),
        ),
      );

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));
}

// ============================================================ body

class _Body extends ConsumerWidget {
  const _Body({required this.farm, required this.onScan});
  final Farm farm;
  final void Function(ImageSource) onScan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(diagnosesForFarmProvider(farm.id));
    final credit = ref.watch(diagnosisCreditProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(diagnosesForFarmProvider(farm.id));
        ref.invalidate(diagnosisCreditProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          _CreditMeter(credit: credit.valueOrNull),
          const SizedBox(height: 16),
          _ScanCard(onScan: onScan),
          const SizedBox(height: 24),
          Text('Recent scans', style: AppText.headlineSm),
          const SizedBox(height: 8),
          history.when(
            loading: () => const _HistorySkeleton(),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Could not load history.\n$e',
                  style: AppText.labelSm),
            ),
            data: (list) => list.isEmpty
                ? _empty()
                : Column(
                    children: [
                      for (final dx in list)
                        _HistoryTile(farm: farm, diagnosis: dx),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _empty() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            const Icon(Symbols.photo_camera, size: 48, color: AppColors.outline),
            const SizedBox(height: 10),
            Text('No scans yet', style: AppText.labelMd),
            const SizedBox(height: 4),
            Text('Your plant diagnoses will appear here.',
                style: AppText.labelSm, textAlign: TextAlign.center),
          ],
        ),
      );
}

class _ScanCard extends StatelessWidget {
  const _ScanCard({required this.onScan});
  final void Function(ImageSource) onScan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryContainer],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Symbols.center_focus_strong, color: Colors.white, size: 30),
          const SizedBox(height: 12),
          Text('Scan a plant',
              style: AppText.headlineSm.copyWith(color: Colors.white)),
          const SizedBox(height: 4),
          Text('Take a clear photo of the affected leaf or plant.',
              style: AppText.bodyMd.copyWith(color: Colors.white70)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                  ),
                  onPressed: () => onScan(ImageSource.camera),
                  icon: const Icon(Symbols.photo_camera),
                  label: const Text('Camera'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                  ),
                  onPressed: () => onScan(ImageSource.gallery),
                  icon: const Icon(Symbols.photo_library),
                  label: const Text('Gallery'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CreditMeter extends StatelessWidget {
  const _CreditMeter({this.credit});
  final AiCredit? credit;

  @override
  Widget build(BuildContext context) {
    final c = credit;
    final premium = c?.isPremium ?? false;
    final remaining = c?.remaining ?? kFreeDiagnosisLimit;
    final low = !premium && c != null && remaining <= 2;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: low ? AppColors.tertiaryContainer : AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(premium ? Symbols.workspace_premium : Symbols.bolt,
              color: low ? AppColors.tertiary : AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  premium
                      ? 'Premium — unlimited scans'
                      : '$remaining of ${c?.limit ?? kFreeDiagnosisLimit} free scans left',
                  style: AppText.labelMd,
                ),
                if (!premium) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: 1 - (c?.fraction ?? 0),
                      minHeight: 6,
                      backgroundColor: AppColors.surfaceContainerHigh,
                      valueColor: AlwaysStoppedAnimation(
                          low ? AppColors.tertiary : AppColors.primary),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends ConsumerWidget {
  const _HistoryTile({required this.farm, required this.diagnosis});
  final Farm farm;
  final PlantDiagnosis diagnosis;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dx = diagnosis;
    final (label, color, icon) = dx.isHealthy
        ? ('Healthy', AppColors.primary, Symbols.check_circle)
        : dx.isDiseased
            ? (dx.diseaseName ?? 'Diseased', AppColors.error, Symbols.warning)
            : ('Unclear', AppColors.tertiary, Symbols.help);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.outlineVariant),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.14),
          child: Icon(icon, color: color),
        ),
        title: Text(dx.plantName, style: AppText.labelMd),
        subtitle: Text('$label · ${dx.confidencePct}% · ${_ago(dx.createdAt)}',
            style: AppText.labelSm),
        trailing: const Icon(Symbols.chevron_right),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => DiagnosisReportScreen(diagnosis: dx),
        )),
      ),
    );
  }

  static String _ago(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}

class _HistorySkeleton extends StatelessWidget {
  const _HistorySkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 3; i++)
          Container(
            height: 64,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
      ],
    );
  }
}

// ============================================================ overlay

class _DiagnosingOverlay extends StatefulWidget {
  const _DiagnosingOverlay({this.preview});
  final Uint8List? preview;

  @override
  State<_DiagnosingOverlay> createState() => _DiagnosingOverlayState();
}

class _DiagnosingOverlayState extends State<_DiagnosingOverlay> {
  static const _messages = [
    'Checking photo quality…',
    'Looking at the leaves…',
    'Identifying the plant…',
    'Checking for disease…',
    'Preparing treatment advice…',
  ];
  int _i = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 1600), (_) {
      if (mounted) setState(() => _i = (_i + 1) % _messages.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.72),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.preview != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.memory(widget.preview!,
                    width: 150, height: 150, fit: BoxFit.cover),
              ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 3),
            ),
            const SizedBox(height: 20),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _messages[_i],
                key: ValueKey(_i),
                style: AppText.bodyMd.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
