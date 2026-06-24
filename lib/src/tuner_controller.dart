import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'notes.dart';
import 'tuner_engine.dart';

/// Drives the tuner: streams mic PCM, runs the engine on overlapping windows,
/// and exposes the latest reading to the UI.
class TunerController extends ChangeNotifier {
  static const int sampleRate = 44100;
  static const int _frame = 2048; // analysis window
  static const int _hop = 1024; // step between windows (50% overlap → smooth)

  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _sub;
  TunerEngine _engine = TunerEngine(sampleRate: sampleRate.toDouble());

  final List<double> _buf = <double>[];
  int _consumed = 0;

  bool listening = false;
  String? error;
  TunerReading? reading;
  DramnyenNote? locked; // null = auto-detect nearest
  double level = 0;
  bool inTune = false;
  bool _wasInTune = false;

  /// After a pluck decays we keep the last reading on screen briefly (needle
  /// frozen, dimmed) so the player can actually read it instead of it vanishing.
  bool holding = false;
  double _lastReadingT = -100;
  static const double _holdSeconds = 1.6;

  /// Concert-pitch reference. 440 Hz is standard; "tune to your own La" and the
  /// A= stepper both move this. Everything else scales from it.
  double referenceA = 440.0;
  static const double _defaultA = 440.0;
  bool get calibrated => (referenceA - _defaultA).abs() > 0.05;

  double get _scale => referenceA / _defaultA;

  /// The pitch La sounds at under the current calibration (for display).
  double get laHz => _laBaseHz * _scale;
  static final double _laBaseHz = tuning.firstWhere((n) => n.solfege == 'La').hz;

  void setReferenceA(double a) {
    referenceA = a.clamp(415.0, 466.0);
    _engine.tuningScale = _scale;
    notifyListeners();
  }

  void resetCalibration() => setReferenceA(_defaultA);

  /// Adopt whatever is being played right now as the La reference, folding it
  /// into La's octave. Lets a player tune the rest of the dramnyen to a La they
  /// already like (or that a group is playing) instead of strict A440.
  bool captureLaFromCurrent() {
    final f = reading?.freq;
    if (f == null || f <= 0) return false;
    var folded = f;
    while (folded > _laBaseHz * math.sqrt2) {
      folded /= 2;
    }
    while (folded < _laBaseHz / math.sqrt2) {
      folded *= 2;
    }
    setReferenceA(_defaultA * (folded / _laBaseHz));
    return true;
  }

  Future<void> start() async {
    error = null;
    try {
      if (!await _recorder.hasPermission()) {
        error = 'Microphone permission is needed to tune. Please allow mic access.';
        notifyListeners();
        return;
      }
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: sampleRate,
          numChannels: 1,
          echoCancel: false,
          noiseSuppress: false,
          autoGain: true, // boosts soft/distant playing — the sensitivity ask
        ),
      );
      _engine = TunerEngine(sampleRate: sampleRate.toDouble())..tuningScale = _scale;
      _buf.clear();
      _consumed = 0;
      listening = true;
      WakelockPlus.enable();
      _sub = stream.listen(_onPcm, onError: (_) {
        error = 'Audio capture error.';
        stop();
      });
      notifyListeners();
    } catch (_) {
      error = 'Could not access the microphone.';
      notifyListeners();
    }
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    await _recorder.stop();
    await WakelockPlus.disable();
    listening = false;
    reading = null;
    inTune = false;
    _wasInTune = false;
    holding = false;
    _lastReadingT = -100;
    level = 0;
    notifyListeners();
  }

  void setLocked(DramnyenNote? note) {
    locked = note;
    notifyListeners();
  }

  void _onPcm(Uint8List bytes) {
    final bd = ByteData.sublistView(bytes);
    final count = bytes.length ~/ 2;
    for (var i = 0; i < count; i++) {
      _buf.add(bd.getInt16(i * 2, Endian.little) / 32768.0);
    }
    var processed = false;
    while (_buf.length >= _frame) {
      final window = Float32List.fromList(_buf.sublist(0, _frame));
      _consumed += _hop;
      final t = _consumed / sampleRate;
      final r = _engine.process(window, t, lockedTarget: locked);
      level = _engine.level;
      if (r != null) {
        reading = r;
        _lastReadingT = t;
        holding = false;
        inTune = r.cents.abs() <= 5;
        if (inTune && !_wasInTune) HapticFeedback.mediumImpact();
        _wasInTune = inTune;
      } else if (reading != null) {
        // Pluck decayed: hold the last reading (and its needle) for a moment,
        // then let it clear. inTune is left frozen so the glow lingers too.
        if (t - _lastReadingT <= _holdSeconds) {
          holding = true;
        } else {
          reading = null;
          holding = false;
          inTune = false;
          _wasInTune = false;
        }
      }
      _buf.removeRange(0, _hop);
      processed = true;
    }
    if (processed) notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _recorder.dispose();
    WakelockPlus.disable();
    super.dispose();
  }
}
