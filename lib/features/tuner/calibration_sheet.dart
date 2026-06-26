import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:dranyen/features/tuner/tuner_controller.dart';

const _surface = Color(0xFF181A22);
const _ink = Color(0xFFE8E6E1);
const _muted = Color(0xFF9AA0AB);
const _faint = Color(0xFF7C828E);
const _amber = Color(0xFFF0A93C);
const _green = Color(0xFF34D399);

/// Bottom sheet for concert-pitch calibration and "tune to your own La".
void showCalibrationSheet(BuildContext context, TunerController controller) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _CalibrationSheet(controller),
  );
}

class _CalibrationSheet extends StatelessWidget {
  final TunerController c;
  const _CalibrationSheet(this.c);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF20222C), _surface],
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(22, 12, 22, 24 + MediaQuery.of(context).padding.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 18),
              const Text('Calibration', style: TextStyle(color: _ink, fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              const Text('Set the reference the whole dramnyen tunes to.',
                  style: TextStyle(color: _muted, fontSize: 13, height: 1.4)),
              const SizedBox(height: 22),

              _label('Concert pitch'),
              const SizedBox(height: 10),
              _concertRow(),
              const SizedBox(height: 12),
              Row(children: [
                for (final p in const [432.0, 440.0, 442.0]) ...[
                  _preset(p),
                  const SizedBox(width: 8),
                ],
              ]),

              const SizedBox(height: 26),
              const Divider(color: Color(0xFF2A2D38), height: 1),
              const SizedBox(height: 22),

              _label('Tune to your own La'),
              const SizedBox(height: 6),
              const Text(
                'Prefer to match a La you already play — your own ear, or a group? '
                'Pluck your La string, then capture it. Re and So follow from it.',
                style: TextStyle(color: _muted, fontSize: 13, height: 1.45),
              ),
              const SizedBox(height: 14),
              _captureButton(context),

              const SizedBox(height: 18),
              Center(
                child: AnimatedOpacity(
                  opacity: c.calibrated ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: TextButton(
                    onPressed: c.calibrated ? c.resetCalibration : null,
                    child: const Text('Reset to A = 440 Hz', style: TextStyle(color: _faint, fontSize: 13)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _label(String t) =>
      Text(t.toUpperCase(), style: const TextStyle(color: _faint, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.1));

  Widget _concertRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _stepButton(Icons.remove, () => c.setReferenceA(c.referenceA - 0.5)),
        Column(children: [
          Text(c.referenceA.toStringAsFixed(1),
              style: const TextStyle(color: _ink, fontSize: 34, fontWeight: FontWeight.w600, height: 1)),
          const SizedBox(height: 2),
          const Text('A  (Hz)', style: TextStyle(color: _muted, fontSize: 12)),
        ]),
        _stepButton(Icons.add, () => c.setReferenceA(c.referenceA + 0.5)),
      ],
    );
  }

  Widget _stepButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Icon(icon, color: _ink, size: 24),
      ),
    );
  }

  Widget _preset(double hz) {
    final active = (c.referenceA - hz).abs() < 0.05;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          c.setReferenceA(hz);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? _amber.withValues(alpha: 0.16) : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: active ? _amber : Colors.transparent, width: 1.5),
          ),
          child: Text(hz.toStringAsFixed(0),
              style: TextStyle(color: active ? _amber : _muted, fontSize: 14, fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }

  Widget _captureButton(BuildContext context) {
    final ready = c.listening && c.reading != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: ready
              ? () {
                  if (c.captureLaFromCurrent()) {
                    HapticFeedback.mediumImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: const Color(0xFF22252F),
                        content: Text('La set to ${c.laHz.toStringAsFixed(1)} Hz  ·  A = ${c.referenceA.toStringAsFixed(1)} Hz',
                            style: const TextStyle(color: _green)),
                      ),
                    );
                  }
                }
              : null,
          icon: const Icon(Icons.my_location, size: 18),
          style: FilledButton.styleFrom(
            backgroundColor: ready ? _amber : Colors.white.withValues(alpha: 0.06),
            foregroundColor: ready ? Colors.white : _faint,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          label: const Text('Use the La I’m playing', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            ready ? 'Currently hearing ${c.reading!.freq.toStringAsFixed(1)} Hz' : 'Start tuning and pluck your La string first',
            style: const TextStyle(color: _faint, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
