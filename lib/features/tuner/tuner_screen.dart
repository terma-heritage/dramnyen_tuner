import 'package:flutter/material.dart';

import 'package:dranyen/features/tuner/arc_gauge.dart';
import 'package:dranyen/features/tuner/calibration_sheet.dart';
import 'package:dranyen/features/learn/learn_screen.dart';
import 'package:dranyen/features/player/dranyen_player.dart';
import 'package:dranyen/features/tuner/info_page.dart';
import 'package:dranyen/shared/notes.dart';
import 'package:dranyen/features/tuner/tuner_controller.dart';
import 'package:dranyen/features/tuner/tuner_engine.dart';

const _bg = Color(0xFF0F1117);
const _green = Color(0xFF34D399);
const _amber = Color(0xFFF0A93C);
const _red = Color(0xFFEF4444);
const _idle = Color(0xFF9AA0AB);
const _muted = Color(0xFF7C828E);

class TunerScreen extends StatefulWidget {
  const TunerScreen({super.key});
  @override
  State<TunerScreen> createState() => _TunerScreenState();
}

class _TunerScreenState extends State<TunerScreen> {
  final TunerController _c = TunerController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  // Smoothly blend red → amber → green as the pitch approaches in-tune, so the
  // needle and note glide through colour instead of snapping between states.
  Color _toneColor(double? cents, bool hasReading) {
    if (!hasReading) return _idle;
    final a = cents!.abs();
    if (a <= 5) return _green;
    if (a <= 18) return Color.lerp(_green, _amber, (a - 5) / 13)!;
    if (a <= 35) return Color.lerp(_amber, _red, (a - 18) / 17)!;
    return _red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          SafeArea(
            child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final r = _c.reading;
            final has = r != null;
            final color = _toneColor(r?.cents, has);
            return Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.5),
                  radius: 1.2,
                  colors: [Color(0xFF1B1B24), Color(0xFF0F1117)],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
              child: Column(
                children: [
                  _topBar(context),
                  const Spacer(flex: 2),
                  // Fade the note + needle while we hold the last pluck on screen.
                  AnimatedOpacity(
                    opacity: _c.holding ? 0.42 : 1.0,
                    duration: const Duration(milliseconds: 450),
                    child: Column(
                      children: [
                        _bigReadout(r, color, _c.inTune),
                        const SizedBox(height: 6),
                        _centsLine(r),
                        const SizedBox(height: 14),
                        ArcGauge(cents: r?.cents ?? 0, color: color, active: has, inTune: _c.inTune),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _status(r, color),
                  const Spacer(flex: 2),
                  _coursePills(r),
                  const SizedBox(height: 16),
                  if (_c.listening) _levelBar(),
                  const SizedBox(height: 12),
                  _micButton(),
                  if (_c.error != null) ...[
                    const SizedBox(height: 10),
                    Text(_c.error!, textAlign: TextAlign.center, style: const TextStyle(color: _red, fontSize: 12)),
                  ],
                ],
              ),
            );
          },
            ),
          ),
          Positioned(right: 8, bottom: 6, child: _easterDot(context)),
        ],
      ),
    );
  }

  // Quiet entry point to the in-progress dranyen player (easter egg).
  Widget _easterDot(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const DranyenPlayerScreen())),
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        child: Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: _amber.withValues(alpha: 0.35), shape: BoxShape.circle),
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    final locked = _c.locked;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () => _c.setLocked(null),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(locked == null ? Icons.mic_none : Icons.lock_outline, size: 15, color: _muted),
              const SizedBox(width: 5),
              Text(locked == null ? 'Auto' : 'Locked: ${locked.solfege}', style: const TextStyle(color: _muted, fontSize: 12)),
            ]),
          ),
        ),
        Row(mainAxisSize: MainAxisSize.min, children: [
          GestureDetector(
            onTap: () => showCalibrationSheet(context, _c),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(999),
                border: _c.calibrated ? Border.all(color: _amber.withValues(alpha: 0.5)) : null,
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.tune, size: 14, color: _c.calibrated ? _amber : _muted),
                const SizedBox(width: 5),
                Text('A = ${_c.referenceA.toStringAsFixed(_c.calibrated ? 1 : 0)} Hz',
                    style: TextStyle(color: _c.calibrated ? _amber : _muted, fontSize: 12)),
              ]),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LearnScreen())),
            behavior: HitTestBehavior.opaque,
            child: const Icon(Icons.menu_book_outlined, size: 19, color: _muted),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InfoPage())),
            behavior: HitTestBehavior.opaque,
            child: const Icon(Icons.info_outline, size: 19, color: _muted),
          ),
        ]),
      ],
    );
  }

  Widget _bigReadout(TunerReading? r, Color color, bool inTune) {
    return AnimatedScale(
      scale: inTune ? 1.05 : 1.0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      child: Column(
        children: [
          // Numbered-notation digit, small, on top.
          SizedBox(
            height: 20,
            child: Text(r?.note?.number ?? '', style: const TextStyle(color: _muted, fontSize: 16, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(height: 2),
          // Big solfège name is the hero, with the Western pitch beside it.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                r?.note?.solfege ?? '—',
                style: TextStyle(
                  color: color,
                  fontSize: 72,
                  fontWeight: FontWeight.w500,
                  height: 1,
                  shadows: inTune ? [Shadow(color: color.withValues(alpha: 0.55), blurRadius: 28)] : null,
                ),
              ),
              if (r?.note != null) ...[
                const SizedBox(width: 10),
                Text(r!.note!.pitch, style: const TextStyle(color: _idle, fontSize: 22)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _centsLine(TunerReading? r) {
    final text = r == null ? (_c.listening ? 'listening…' : '') : '${r.freq.toStringAsFixed(1)} Hz';
    return SizedBox(height: 18, child: Text(text, style: const TextStyle(color: _muted, fontSize: 13)));
  }

  Widget _status(TunerReading? r, Color color) {
    String text;
    if (!_c.listening) {
      text = 'Tap Start to begin';
    } else if (r == null) {
      text = 'Pluck a dramnyen string';
    } else if (_c.inTune) {
      text = '✓  In tune';
    } else if (_c.locked == null) {
      // Free mode: there's no chosen target, so don't bark tighten/loosen —
      // identify the note and point to the tuning action instead.
      text = 'Tap La · Re · So to tune this string';
    } else {
      text = r.cents < 0 ? 'Tighten a little' : 'Loosen a little';
    }
    final showColor = (r != null && (_c.inTune || _c.locked != null)) || !_c.listening;
    return SizedBox(
      height: 20,
      child: Text(text, style: TextStyle(color: showColor ? color : _muted, fontSize: 15, fontWeight: FontWeight.w500)),
    );
  }

  Widget _coursePills(TunerReading? r) {
    return Row(
      children: openStrings.map((n) {
        final isLocked = _c.locked?.solfege == n.solfege;
        final isDetected = _c.locked == null && _c.listening && r?.note?.solfege == n.solfege;
        final highlight = isLocked || isDetected;
        final accent = _c.inTune && highlight ? _green : _amber;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => _c.setLocked(isLocked ? null : n),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: highlight ? accent.withValues(alpha: 0.14) : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: highlight ? accent : Colors.transparent, width: 1.5),
                ),
                child: Column(children: [
                  Text(n.solfege, style: TextStyle(color: highlight ? accent : const Color(0xFFB6BAC2), fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(n.pitch, style: const TextStyle(color: _muted, fontSize: 11)),
                ]),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _levelBar() {
    return Column(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LinearProgressIndicator(
          value: _c.level.clamp(0.0, 1.0),
          minHeight: 4,
          backgroundColor: Colors.white.withValues(alpha: 0.08),
          valueColor: AlwaysStoppedAnimation(_c.level > 0.02 ? _green : _muted),
        ),
      ),
      const SizedBox(height: 4),
      Text(_c.level > 0.02 ? 'Mic input' : 'No sound — move closer', style: const TextStyle(color: _muted, fontSize: 10)),
    ]);
  }

  Widget _micButton() {
    final on = _c.listening;
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: () => on ? _c.stop() : _c.start(),
        style: FilledButton.styleFrom(
          backgroundColor: on ? _red : _amber,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(on ? 'Stop' : 'Start tuning', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white)),
      ),
    );
  }
}
