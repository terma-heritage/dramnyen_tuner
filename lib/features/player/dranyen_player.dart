import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

/// Playable dranyen. Reached from the music-note icon on the tuner screen.
/// Three courses (La · Re · So); two fret bars lift La/Re to
/// ti/mi (×200¢) and do/fa (×300¢); So is a fretless drone. Strum-required —
/// fretting a ringing string bends its pitch live (subtle glide). Open samples
/// are Tenzin Norbu's recordings; fretted notes are pitch-shifted from the open
/// string (physically what fretting does). Audio via flutter_soloud, whose
/// playback speed pitch-shifts reliably on iOS (soundpool's rate did not).
class DranyenPlayerScreen extends StatefulWidget {
  const DranyenPlayerScreen({super.key});
  @override
  State<DranyenPlayerScreen> createState() => _DranyenPlayerScreenState();
}

class _Str {
  final String course;
  final double xFrac;
  final int side; // 0 or 1 (the two strings of a course)
  double amp0 = 0, t = 0, py = 0.6;
  bool active = false;
  _Str(this.course, this.xFrac, this.side);
}

class _DranyenPlayerScreenState extends State<DranyenPlayerScreen>
    with SingleTickerProviderStateMixin {
  // Right-aligned so the left edge is free to grip the device like a neck.
  static const Map<String, double> _courseX = {'la': 0.34, 're': 0.63, 'so': 0.90};
  static const double _pairGap = 12;
  static const List<double> _fretCents = [0, 200, 300]; // by fret level, for la & re

  final SoLoud _soloud = SoLoud.instance;
  final Map<String, AudioSource> _src = {};
  final Map<String, SoundHandle?> _handle = {'la': null, 're': null, 'so': null};
  final Map<String, int> _fretLevel = {'la': 0, 're': 0}; // per-string fret; So is fretless
  bool _ready = false;
  bool _audioOk = true;

  late final AnimationController _ctrl;
  final List<_Str> _strings = [];
  final Stopwatch _clock = Stopwatch();
  double _lastSec = 0;

  String? _lastC;
  double _lastX = 0;
  int _lastMs = 0;

  @override
  void initState() {
    super.initState();
    for (final c in ['la', 're', 'so']) {
      for (final side in [0, 1]) {
        _strings.add(_Str(c, _courseX[c]!, side));
      }
    }
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..addListener(_tick)
      ..repeat();
    _clock.start();
    _loadAudio();
  }

  Future<void> _loadAudio() async {
    try {
      if (!_soloud.isInitialized) await _soloud.init();
      for (final c in ['la', 're', 'so']) {
        _src[c] = await _soloud.loadAsset('assets/audio/$c.mp3');
      }
    } catch (_) {
      // Audio runtime unavailable (e.g. an unconfigured web build) — show the
      // instrument anyway; the strings still respond visually, just silently.
      _audioOk = false;
    }
    if (!mounted) return;
    setState(() => _ready = true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    if (_soloud.isInitialized) _soloud.deinit();
    super.dispose();
  }

  void _tick() {
    final s = _clock.elapsedMicroseconds / 1e6;
    double dt = s - _lastSec;
    _lastSec = s;
    if (dt > 0.05) dt = 0.05;
    for (final str in _strings) {
      if (!str.active) continue;
      str.t += dt;
      if (str.amp0 * math.exp(-str.t * 3.1) < 0.5) str.active = false;
    }
  }

  double _speedFor(String c) =>
      c == 'so' ? 1.0 : math.pow(2, _fretCents[_fretLevel[c] ?? 0] / 1200).toDouble();

  void _pluck(String c, double strength, double py) {
    if (!_ready) return;
    _excite(c, strength, py); // visual response first — works even without audio
    if (!_audioOk || _src[c] == null) return;
    final old = _handle[c];
    if (old != null && _soloud.getIsValidVoiceHandle(old)) _soloud.stop(old);
    final sp = _speedFor(c);
    final h = _soloud.play(_src[c]!);
    _soloud.setRelativePlaySpeed(h, sp);
    _handle[c] = h;
  }

  void _excite(String c, double strength, double py) {
    final amp = 13.0 * math.min(strength, 1.6);
    for (final str in _strings) {
      if (str.course != c) continue;
      str.amp0 = amp;
      str.t = 0;
      str.py = py;
      str.active = true;
    }
  }

  // Holding a fret sets the note the next strum of THAT string will play. No
  // live bend/slide — a strum sounds the fretted pitch directly, and releasing
  // a fret leaves any ringing note untouched (it just decays).
  void _setFret(String course, int level) {
    setState(() => _fretLevel[course] = level);
  }

  String _courseAtX(double dx, double w) {
    final f = dx / w;
    return f < 0.485 ? 'la' : (f < 0.765 ? 're' : 'so');
  }

  void _sweep(Offset local, double w, double h, double zoneTop) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final speed =
        math.min((local.dx - _lastX).abs() / math.max(now - _lastMs, 1) * 6, 1.5) + 0.5;
    _lastX = local.dx;
    _lastMs = now;
    final c = _courseAtX(local.dx, w);
    if (c != _lastC) {
      _lastC = c;
      final py = ((zoneTop + local.dy) / h).clamp(0.45, 0.9).toDouble();
      _pluck(c, speed, py);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth, h = constraints.maxHeight;
          final zoneTop = h * 0.53;
          return Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(-1, -0.35),
                    end: Alignment(1, 0.35),
                    colors: [Color(0xFF7C4F17), Color(0xFF9C6A22), Color(0xFFAD7B2C), Color(0xFF925F1D)],
                    stops: [0, 0.34, 0.6, 1],
                  ),
                ),
              ),
              Positioned.fill(
                child: CustomPaint(painter: _StringsPainter(_strings, _pairGap, _ctrl)),
              ),
              // Open-course labels across the top.
              _openLabel(w, h, 'La', 'B2 · top', 0.34),
              _openLabel(w, h, 'Re', 'E3 · middle', 0.63),
              _openLabel(w, h, 'So', 'A2 · bottom', 0.90),
              // Large fret notes — Thi·Mi on top (fret 1), Do·Fa below (fret 2).
              _fretButton(w, h, 'la', 1, 'Thi', 0.34, 0.135),
              _fretButton(w, h, 're', 1, 'Mi', 0.63, 0.135),
              _fretButton(w, h, 'la', 2, 'Do', 0.34, 0.29),
              _fretButton(w, h, 're', 2, 'Fa', 0.63, 0.29),
              _droneTag(w, h, 0.90, 0.205),
              Positioned(
                left: 14, right: 14, top: zoneTop,
                child: SizedBox(height: 2, child: CustomPaint(painter: _DashedLine())),
              ),
              Positioned(
                left: 0, right: 0, top: zoneTop + 8,
                child: const Center(child: Text('strum below the line',
                    style: TextStyle(color: Color(0x8CFFF6E4), fontSize: 11))),
              ),
              Positioned(
                left: 0, right: 0, top: zoneTop, bottom: 0,
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (e) { _lastC = null; _lastX = e.localPosition.dx; _lastMs = DateTime.now().millisecondsSinceEpoch; _sweep(e.localPosition, w, h, zoneTop); },
                  onPointerMove: (e) => _sweep(e.localPosition, w, h, zoneTop),
                  onPointerUp: (_) => _lastC = null,
                  onPointerCancel: (_) => _lastC = null,
                ),
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 4, left: 4,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xCCFFF6E4)),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
              if (!_ready)
                Positioned.fill(
                  child: Container(
                    color: const Color(0xCC140F09),
                    alignment: Alignment.center,
                    child: const Text('tuning the strings…',
                        style: TextStyle(color: Color(0xFFF7EAD2), fontSize: 16)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // One large, separate fret note button on a single string. Press-and-hold
  // sets that string's fret; strum below to sound the fretted note.
  Widget _fretButton(double w, double h, String course, int level, String note, double cx, double topFrac) {
    final on = _fretLevel[course] == level;
    const bw = 90.0, bh = 90.0; // large, tall target for an easier press
    return Positioned(
      left: w * cx - bw / 2,
      top: h * topFrac,
      width: bw,
      height: bh,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => _setFret(course, level),
        onPointerUp: (_) { if (_fretLevel[course] == level) _setFret(course, 0); },
        onPointerCancel: (_) { if (_fretLevel[course] == level) _setFret(course, 0); },
        child: Container(
          decoration: BoxDecoration(
            color: on ? const Color(0xFFFFF7E6) : const Color(0xF2F7EAD2),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: on ? Colors.white : const Color(0x66FFF6E4), width: 1.5),
            boxShadow: on
                ? const [BoxShadow(color: Color(0x40FFF7E6), blurRadius: 14, spreadRadius: 3)]
                : const [BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 3))],
          ),
          alignment: Alignment.center,
          child: Text(note,
              style: const TextStyle(color: Color(0xFF6A4408), fontSize: 30, fontWeight: FontWeight.w600, height: 1)),
        ),
      ),
    );
  }

  Widget _openLabel(double w, double h, String course, String sub, double cx) {
    return Positioned(
      left: w * cx - 45,
      top: h * 0.045,
      width: 90,
      child: Column(
        children: [
          Text(course,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xECFFF6E4), fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          const SizedBox(height: 2),
          Text(sub, textAlign: TextAlign.center, style: const TextStyle(color: Color(0x8CFFF6E4), fontSize: 10)),
        ],
      ),
    );
  }

  Widget _droneTag(double w, double h, double cx, double topFrac) {
    return Positioned(
      left: w * cx - 45,
      top: h * topFrac,
      width: 90,
      child: const Text('fretless\ndrone',
          textAlign: TextAlign.center, style: TextStyle(color: Color(0x8CFFF6E4), fontSize: 11, height: 1.3)),
    );
  }
}

class _StringsPainter extends CustomPainter {
  final List<_Str> strings;
  final double pairGap;
  _StringsPainter(this.strings, this.pairGap, Listenable repaint) : super(repaint: repaint);

  double _shape(double yn, double py) =>
      math.sin(math.pi * yn) * (0.6 + 0.4 * math.exp(-math.pow((yn - py) * 3.2, 2)));

  @override
  void paint(Canvas canvas, Size size) {
    final H = size.height;
    const int N = 26;
    for (final s in strings) {
      // Each course is a double string — centre the pair on its course x.
      final x = size.width * s.xFrac + (s.side == 1 ? pairGap / 2 : -pairGap / 2);
      if (s.active) {
        final amp = s.amp0 * math.exp(-s.t * 3.1);
        final osc = math.sin(s.t * 2 * math.pi * 9);
        final spindle = Path();
        for (int i = 0; i <= N; i++) {
          final yn = i / N, y = yn * H, d = amp * _shape(yn, s.py);
          i == 0 ? spindle.moveTo(x + d, y) : spindle.lineTo(x + d, y);
        }
        for (int i = N; i >= 0; i--) {
          final yn = i / N, y = yn * H, d = amp * _shape(yn, s.py);
          spindle.lineTo(x - d, y);
        }
        spindle.close();
        canvas.drawPath(spindle, Paint()..color = const Color(0x1AFFF6E4));
        final line = Path();
        for (int i = 0; i <= N; i++) {
          final yn = i / N, y = yn * H, d = amp * _shape(yn, s.py) * osc;
          i == 0 ? line.moveTo(x + d, y) : line.lineTo(x + d, y);
        }
        canvas.drawPath(line, Paint()
          ..color = const Color(0x40FFF8E8)..style = PaintingStyle.stroke..strokeWidth = 4
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
        canvas.drawPath(line, Paint()
          ..color = const Color(0xF5FFF8E8)..style = PaintingStyle.stroke..strokeWidth = 2);
      } else {
        canvas.drawLine(Offset(x, 0), Offset(x, H), Paint()
          ..color = const Color(0xE6FFF8E8)..style = PaintingStyle.stroke..strokeWidth = 2);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StringsPainter oldDelegate) => true;
}

class _DashedLine extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0x80FFF6E4)..strokeWidth = 2;
    const dash = 7.0, gap = 6.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(math.min(x + dash, size.width), 0), p);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
