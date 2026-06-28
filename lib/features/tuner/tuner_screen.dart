import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:google_fonts/google_fonts.dart';

import 'package:dranyen/features/tuner/arc_gauge.dart';
import 'package:dranyen/features/tuner/calibration_sheet.dart';
import 'package:dranyen/features/learn/learn_screen.dart';
import 'package:dranyen/features/player/dranyen_player.dart';
import 'package:dranyen/features/tuner/info_page.dart';
import 'package:dranyen/features/tuner/strobe_bar.dart';
import 'package:dranyen/shared/notes.dart';
import 'package:dranyen/features/tuner/tuner_controller.dart';
import 'package:dranyen/features/tuner/tuner_engine.dart';

const _bg = Color(0xFF0F1117);
const _green = Color(0xFF34D399);
const _amber = Color(0xFFF0A93C);
const _red = Color(0xFFEF4444);
const _idle = Color(0xFF9AA0AB);
const _muted = Color(0xFF7C828E);
const _gold = Color(0xFFD4A853);
const _ink = Color(0xFFE8EAED);

class TunerScreen extends StatefulWidget {
  const TunerScreen({super.key});
  @override
  State<TunerScreen> createState() => _TunerScreenState();
}

class _TunerScreenState extends State<TunerScreen> with SingleTickerProviderStateMixin {
  final TunerController _c = TunerController();
  late final AnimationController _pulse;
  bool _wasInTune = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _c.addListener(_onReading);
  }

  // Fire the lock-pulse ring + a firmer haptic the instant we land in tune.
  void _onReading() {
    final now = _c.inTune;
    if (now && !_wasInTune) {
      _pulse.forward(from: 0);
      HapticFeedback.mediumImpact();
    }
    _wasInTune = now;
  }

  @override
  void dispose() {
    _c.removeListener(_onReading);
    _pulse.dispose();
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
                        _readoutWithPulse(r, color, _c.inTune),
                        const SizedBox(height: 6),
                        _centsLine(r),
                        const SizedBox(height: 14),
                        ArcGauge(cents: r?.cents ?? 0, color: color, active: has, inTune: _c.inTune),
                        const SizedBox(height: 14),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 36),
                          child: StrobeBar(cents: r?.cents ?? 0, active: has, inTune: _c.inTune, color: color),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _status(r, color),
                  if (!_c.listening) ...[
                    const SizedBox(height: 6),
                    Text('Then tap La · Re · So to tune your dranyen',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.spaceGrotesk(color: _muted, fontSize: 12, letterSpacing: 0.2)),
                  ],
                  const Spacer(flex: 2),
                  Text('Tibetan Standard Tuning',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.spaceGrotesk(color: _muted, fontSize: 11, letterSpacing: 0.4)),
                  const SizedBox(height: 8),
                  _coursePills(r),
                  const SizedBox(height: 16),
                  if (_c.listening) _levelBar(),
                  const SizedBox(height: 12),
                  _micButton(),
                  if (_c.error != null) ...[
                    const SizedBox(height: 10),
                    Text(_c.error!, textAlign: TextAlign.center, style: const TextStyle(color: _red, fontSize: 12)),
                  ],
                  _footer(),
                ],
              ),
            );
          },
            ),
          ),
        ],
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
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DranyenPlayerScreen())),
            behavior: HitTestBehavior.opaque,
            child: const Icon(Icons.music_note_outlined, size: 19, color: _muted),
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

  // The hero readout with an expanding green ring that fires on lock.
  Widget _readoutWithPulse(TunerReading? r, Color color, bool inTune) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        AnimatedBuilder(
          animation: _pulse,
          builder: (_, _) {
            final t = _pulse.value;
            if (t == 0.0 || t == 1.0) return const SizedBox.shrink();
            return Opacity(
              opacity: (1 - t) * 0.5,
              child: Transform.scale(
                scale: 0.6 + t * 0.9,
                child: Container(
                  width: 132,
                  height: 132,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _green, width: 2),
                  ),
                ),
              ),
            );
          },
        ),
        // Idle shows the brand lockup; tapping Start crossfades to the readout.
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 450),
          child: _c.listening
              ? KeyedSubtree(key: const ValueKey('readout'), child: _bigReadout(r, color, inTune))
              : KeyedSubtree(key: const ValueKey('brand'), child: _brandLockup()),
        ),
      ],
    );
  }

  // The cold-open brand mark, shown in the hero area before tuning starts.
  Widget _brandLockup() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('assets/branding/main-logo-gold.png',
            width: 66, errorBuilder: (_, _, _) => const SizedBox(height: 66)),
        const SizedBox(height: 16),
        Text('Dranyen Tuner',
            style: GoogleFonts.spaceGrotesk(color: _ink, fontSize: 30, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        const SizedBox(height: 6),
        Text('སྒྲ་སྙན་སྒྲ་བསྒྲིག', style: const TextStyle(color: _gold, fontSize: 22, height: 1.4)),
      ],
    );
  }

  // Persistent, quiet Foundation credit at the foot of the screen.
  Widget _footer() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Opacity(
            opacity: 0.6,
            child: Image.asset('assets/branding/main-logo-gold.png',
                width: 13, errorBuilder: (_, _, _) => const SizedBox.shrink()),
          ),
          const SizedBox(width: 6),
          Text('Terma Heritage Foundation',
              style: GoogleFonts.spaceGrotesk(color: _muted, fontSize: 11, letterSpacing: 0.3)),
        ],
      ),
    );
  }

  Widget _bigReadout(TunerReading? r, Color color, bool inTune) {
    final note = r?.note;
    final locked = _c.locked != null;
    // Master's guidance: in free play (no course locked), show the absolute
    // pitch (A2, E3 …) and NOT the Do·Re·Mi solfège — solfège only appears once
    // the player locks a La · Re · So course to tune toward it.
    final hero = note == null ? '—' : (locked ? note.solfege : note.pitch);
    final beside = (note != null && locked) ? note.pitch : null;
    return AnimatedScale(
      scale: inTune ? 1.05 : 1.0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      child: Column(
        children: [
          // Numbered-notation digit — only meaningful once a course is locked.
          SizedBox(
            height: 20,
            child: Text(locked ? (note?.number ?? '') : '',
                style: GoogleFonts.spaceGrotesk(color: _muted, fontSize: 16, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                hero,
                style: GoogleFonts.spaceGrotesk(
                  color: color,
                  fontSize: 74,
                  fontWeight: FontWeight.w600,
                  height: 1,
                  shadows: inTune ? [Shadow(color: color.withValues(alpha: 0.55), blurRadius: 28)] : null,
                ),
              ),
              if (beside != null) ...[
                const SizedBox(width: 10),
                Text(beside, style: GoogleFonts.spaceGrotesk(color: _idle, fontSize: 22)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _centsLine(TunerReading? r) {
    final text = r == null ? (_c.listening ? 'listening…' : '') : '${r.freq.toStringAsFixed(1)} Hz';
    return SizedBox(
      height: 18,
      child: Text(text, style: GoogleFonts.spaceMono(color: _muted, fontSize: 13, letterSpacing: 0.5)),
    );
  }

  Widget _status(TunerReading? r, Color color) {
    String text;
    if (!_c.listening) {
      text = 'Tap Start to begin';
    } else if (_c.locked == null) {
      // Free mode: tell the player exactly how to choose a course to tune.
      text = 'Tap La · Re · So to tune a string';
    } else if (r == null) {
      text = 'Play the ${_c.locked!.solfege} string';
    } else if (_c.inTune) {
      text = '✓  In tune';
    } else {
      text = r.cents < 0 ? 'Tighten a little' : 'Loosen a little';
    }
    final showColor = (r != null && (_c.inTune || _c.locked != null)) || !_c.listening;
    return SizedBox(
      height: 20,
      child: Text(text,
          style: GoogleFonts.spaceGrotesk(color: showColor ? color : _muted, fontSize: 15, fontWeight: FontWeight.w500)),
    );
  }

  Widget _coursePills(TunerReading? r) {
    const pos = ['top', 'middle', 'bottom']; // La · Re · So → string position
    return Row(
      children: openStrings.asMap().entries.map((entry) {
        final i = entry.key;
        final n = entry.value;
        final isLocked = _c.locked?.solfege == n.solfege;
        final isDetected = _c.locked == null && _c.listening && r?.note?.solfege == n.solfege;
        final highlight = isLocked || isDetected;
        final accent = _c.inTune && highlight ? _green : _amber;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _Pressable(
              onTap: () => _c.setLocked(isLocked ? null : n),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: highlight
                        ? [accent.withValues(alpha: 0.20), accent.withValues(alpha: 0.10)]
                        : [Colors.white.withValues(alpha: 0.06), Colors.white.withValues(alpha: 0.03)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: highlight ? accent : Colors.transparent, width: 1.5),
                ),
                child: Column(children: [
                  Text(n.solfege,
                      style: GoogleFonts.spaceGrotesk(
                          color: highlight ? accent : const Color(0xFFB6BAC2), fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text('${pos[i]} · ${n.pitch}',
                      style: GoogleFonts.spaceGrotesk(color: _muted, fontSize: 10.5, letterSpacing: 0.2)),
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
    final glow = on ? _red : _amber;
    return _Pressable(
      onTap: () => on ? _c.stop() : _c.start(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: on
                ? [const Color(0xFFF26464), const Color(0xFFD83B3B)]
                : [const Color(0xFFF4B452), const Color(0xFFEC9A26)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: glow.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 6))],
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Center(
          child: Text(
            on ? 'Stop' : 'Start tuning',
            style: GoogleFonts.spaceGrotesk(
                fontSize: 16, fontWeight: FontWeight.w600, color: on ? Colors.white : const Color(0xFF3A2606)),
          ),
        ),
      ),
    );
  }
}

/// A press wrapper: subtle scale-down on touch + a selection haptic on release.
/// Gives the flat fills a hardware-button feel.
class _Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _Pressable({required this.child, required this.onTap});

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) {
        setState(() => _down = false);
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _down ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
