import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/session_catalog.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../models/pool_table.dart';
import '../../../models/promo.dart';
import '../../promo/data/promo_repository.dart';

class StartSessionResult {
  final SessionType sessionType;
  final int? promoId;
  final String? promo;
  final Duration? duration;

  const StartSessionResult({
    required this.sessionType,
    this.promoId,
    this.promo,
    this.duration,
  });
}

class StartSessionDialog extends StatefulWidget {
  final PoolTable table;

  const StartSessionDialog({super.key, required this.table});

  @override
  State<StartSessionDialog> createState() => _StartSessionDialogState();
}

class _StartSessionDialogState extends State<StartSessionDialog> {
  final _promoRepository = PromoRepository();

  SessionType _sessionType = SessionType.reguler;
  Promo? _selectedPromo;
  int _durationHours = 0;
  int _durationMinutes = 0;
  String? _durationError;

  late final _hourController = TextEditingController(text: "$_durationHours");
  late final _minuteController = TextEditingController(
    text: "$_durationMinutes",
  );

  bool _loading = true;
  String? _loadError;
  List<Promo> _promos = [];

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final promoResult = await _promoRepository.getPromos(
        page: 1,
        perPage: 1000,
      );
      if (!mounted) return;
      setState(() {
        _promos = promoResult.promos;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = "Gagal memuat data promo.";
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  static const _minDuration = Duration(minutes: 3);

  /// True when the selected promo is a fixed-hour promo — picking one
  /// auto-fills and locks the duration fields to that many hours.
  bool get _promoLocksDuration =>
      _selectedPromo?.type == PromoType.fixed &&
      _selectedPromo?.hourGained != null;

  bool get _durationFieldsEnabled => !_promoLocksDuration;

  void _selectPromo(Promo? promo) {
    final lockedHours = promo?.type == PromoType.fixed
        ? promo?.hourGained
        : null;

    setState(() {
      final wasLocked = _promoLocksDuration;
      _selectedPromo = promo;

      if (lockedHours != null) {
        _sessionType = SessionType.timer;
        _durationHours = lockedHours;
        _durationMinutes = 0;
        _durationError = null;
        _hourController.text = "$_durationHours";
        _minuteController.text = "$_durationMinutes";
      } else if (wasLocked) {
        _durationHours = 0;
        _durationMinutes = 0;
        _hourController.text = "0";
        _minuteController.text = "0";
      }
    });
  }

  void _submit() {
    final isTimer = _sessionType == SessionType.timer;
    final duration = Duration(
      hours: _durationHours,
      minutes: _durationMinutes,
    );

    if (isTimer && duration < _minDuration) {
      setState(
        () => _durationError =
            "Durasi sesi minimal ${_minDuration.inMinutes} menit",
      );
      return;
    }

    Navigator.of(context).pop(
      StartSessionResult(
        sessionType: _sessionType,
        promoId: _selectedPromo?.id,
        promo: _selectedPromo?.name,
        duration: isTimer ? duration : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusXL),
      ),
      backgroundColor: AppColors.card,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSizes.radiusXL),
          border: Border.all(color: AppColors.border),
        ),
        child: _loading
            ? const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              )
            : _loadError != null
            ? _buildLoadError()
            : _buildForm(),
      ),
    );
  }

  Widget _buildLoadError() {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 30,
              color: AppColors.danger,
            ),
            const SizedBox(height: 12),
            Text(
              _loadError!,
              style: AppText.bodySecondary,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _loadOptions,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text("Coba Lagi"),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.text,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          const Divider(color: AppColors.divider, height: 1),
          const SizedBox(height: 22),

          _label("Mode"),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _typeOption(
                  SessionType.reguler,
                  "Reguler",
                  "Bayar per jam",
                  Icons.schedule_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _typeOption(
                  SessionType.timer,
                  "Timer",
                  "Sesi dengan durasi",
                  Icons.timer_rounded,
                ),
              ),
            ],
          ),

          if (_sessionType == SessionType.timer) ...[
            const SizedBox(height: 20),
            _label("Durasi Sesi"),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _durationField(
                    controller: _hourController,
                    options: hourOptions,
                    suffix: "jam",
                    enabled: _durationFieldsEnabled,
                    onChanged: (value) => setState(() {
                      _durationHours = value;
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _durationField(
                    controller: _minuteController,
                    options: minuteOptions,
                    suffix: "menit",
                    enabled: _durationFieldsEnabled,
                    onChanged: (value) => setState(() {
                      _durationMinutes = value;
                    }),
                  ),
                ),
              ],
            ),
            if (_durationError != null) ...[
              const SizedBox(height: 6),
              Text(
                _durationError!,
                style: AppText.caption.copyWith(color: AppColors.danger),
              ),
            ],
          ],

          const SizedBox(height: 20),
          _label("Promo (Opsional)"),
          const SizedBox(height: 8),
          DropdownButtonFormField<Promo?>(
            initialValue: _selectedPromo,
            dropdownColor: AppColors.card,
            style: AppText.body,
            isExpanded: true,
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.textSecondary,
            ),
            decoration: _inputDecoration(
              hint: "Tanpa promo",
              prefixIcon: Icons.local_offer_outlined,
            ),
            items: [
              const DropdownMenuItem<Promo?>(
                value: null,
                child: Text("Tanpa Promo"),
              ),
              for (final promo in _promos)
                DropdownMenuItem<Promo?>(
                  value: promo,
                  child: Text(promo.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: _selectPromo,
          ),
          if (_promoLocksDuration) ...[
            const SizedBox(height: 8),
            Text(
              "Durasi timer otomatis mengikuti promo ini "
              "(${_selectedPromo!.hourGained} jam) dan tidak bisa diubah.",
              style: AppText.caption,
            ),
          ],

          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppSizes.radiusMedium,
                      ),
                    ),
                  ),
                  child: const Text("BATAL"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  label: const Text("MULAI SESI"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 48),
                    elevation: 0,
                    textStyle: AppText.button,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppSizes.radiusMedium,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          ),
          child: const Icon(
            Icons.sports_esports_rounded,
            color: AppColors.primary,
            size: 24,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Mulai Sesi",
                style: AppText.title.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                "Lengkapi detail untuk memulai permainan",
                style: AppText.caption,
              ),
            ],
          ),
        ),
        InkWell(
          onTap: () => Navigator.of(context).pop(),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.close_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _typeOption(
    SessionType type,
    String label,
    String subtitle,
    IconData icon,
  ) {
    final active = _sessionType == type;

    return InkWell(
      onTap: () => setState(() => _sessionType = type),
      borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary.withValues(alpha: .15)
              : AppColors.background,
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.border,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: active ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppText.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: active ? AppColors.primary : AppColors.text,
                    ),
                  ),
                  Text(subtitle, style: AppText.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _durationField({
    required TextEditingController controller,
    required List<int> options,
    required String suffix,
    required ValueChanged<int> onChanged,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: AppText.body,
      decoration: _inputDecoration().copyWith(
        suffixText: suffix,
        suffixStyle: AppText.caption,
        suffixIcon: PopupMenuButton<int>(
          enabled: enabled,
          tooltip: "",
          color: AppColors.card,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: enabled ? AppColors.textSecondary : AppColors.textHint,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          ),
          itemBuilder: (context) => [
            for (final option in options)
              PopupMenuItem(value: option, child: Text("$option $suffix")),
          ],
          onSelected: (selected) {
            controller.text = "$selected";
            onChanged(selected);
          },
        ),
      ),
      onChanged: (text) => onChanged(int.tryParse(text) ?? 0),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: AppText.bodySecondary.copyWith(fontWeight: FontWeight.w600),
    );
  }

  InputDecoration _inputDecoration({
    String? hint,
    String? errorText,
    IconData? prefixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppText.caption,
      errorText: errorText,
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, size: 20, color: AppColors.textSecondary)
          : null,
      filled: true,
      fillColor: AppColors.background,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
    );
  }
}
