import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dranyen/shared/notes.dart';
import 'package:dranyen/shared/pitch/one_euro_filter.dart';
import 'package:dranyen/shared/pitch/pitch_detector.dart';

/// A single tuner reading, ready for the UI.
class TunerReading {
  final DramnyenNote? note; // nearest of the 7 notes (or locked target)
  final double cents; // deviation from [note]
  final double freq; // smoothed Hz
  final double level; // 0..1 input level

  const TunerReading({this.note, this.cents = 0, this.freq = 0, this.level = 0});

  static const silent = TunerReading();
}

/// Turns raw mic frames into a steady [TunerReading].
///
/// Pipeline: YIN → clarity gate → One-Euro filter (snappy + steady) → nearest
/// of the 7 notes (or a locked target). The clarity gate plus a low RMS floor
/// is what makes it sensitive to soft playing without chasing noise.
class TunerEngine {
  final double sampleRate;

  /// Below this RMS it's treated as silence. Low, because YIN copes with quiet.
  double rmsFloor;

  /// Reject readings less periodic than this (0..1).
  double clarityGate;

  final OneEuroFilter _freqFilter;
  double _level = 0;

  /// Multiplies every target frequency. 1.0 = standard A440; calibration and
  /// "tune to your own La" both move this single factor.
  double tuningScale = 1.0;

  TunerEngine({
    required this.sampleRate,
    this.rmsFloor = 0.006,
    this.clarityGate = 0.80,
    OneEuroFilter? filter,
  }) : _freqFilter = filter ?? OneEuroFilter(minCutoff: 1.2, beta: 0.5);

  double get level => _level;

  /// Process one frame at time [tSeconds]. Returns a reading, or null if there's
  /// no confident pitch (the UI should keep showing "listening").
  TunerReading? process(Float32List frame, double tSeconds, {DramnyenNote? lockedTarget}) {
    var sumSq = 0.0;
    for (var i = 0; i < frame.length; i++) {
      sumSq += frame[i] * frame[i];
    }
    final rms = math.sqrt(sumSq / frame.length);
    // Smooth the visible level a touch; scale so soft playing still shows.
    _level = (_level * 0.6 + math.min(1.0, rms * 14) * 0.4);

    if (rms < rmsFloor) {
      _freqFilter.reset();
      return null;
    }

    final p = detectPitch(frame, sampleRate);
    if (!p.found || p.clarity < clarityGate) {
      _freqFilter.reset();
      return null;
    }

    final smoothed = _freqFilter.filter(p.freq, tSeconds);
    final target = lockedTarget ?? _nearest(smoothed);
    return TunerReading(
      note: target,
      cents: centsFromTarget(smoothed, target.hz * tuningScale),
      freq: smoothed,
      level: _level,
    );
  }

  DramnyenNote _nearest(double freq) {
    DramnyenNote best = tuning.first;
    var bestAbs = double.infinity;
    for (final n in tuning) {
      final c = centsFromTarget(freq, n.hz * tuningScale).abs();
      if (c < bestAbs) {
        bestAbs = c;
        best = n;
      }
    }
    return best;
  }
}
