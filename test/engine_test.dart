import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dranyen/shared/notes.dart';
import 'package:dranyen/shared/pitch/one_euro_filter.dart';
import 'package:dranyen/shared/pitch/pitch_detector.dart';
import 'package:dranyen/features/tuner/tuner_engine.dart';
import 'package:flutter_test/flutter_test.dart';

const sr = 48000.0;
const n = 2048;

Float32List tone(double freq, {double amp = 0.5, double noise = 0, int seed = 1}) {
  final rnd = math.Random(seed);
  final b = Float32List(n);
  for (var i = 0; i < n; i++) {
    b[i] = amp * (0.7 * math.sin(2 * math.pi * freq * i / sr) + 0.2 * math.sin(2 * math.pi * 2 * freq * i / sr)) +
        noise * (rnd.nextDouble() * 2 - 1);
  }
  return b;
}

void main() {
  group('detectPitch (YIN)', () {
    for (final note in tuning) {
      test('detects ${note.solfege} (${note.pitch}, ${note.hz} Hz)', () {
        final r = detectPitch(tone(note.hz), sr);
        expect(r.found, isTrue);
        expect((r.freq - note.hz).abs(), lessThan(1.0));
        expect(r.clarity, greaterThan(0.9));
      });
    }

    test('detects a QUIET signal (amp 0.03) — the sensitivity fix', () {
      final r = detectPitch(tone(110, amp: 0.03), sr);
      expect((r.freq - 110).abs(), lessThan(1.5));
    });

    test('pure noise is not confident', () {
      final r = detectPitch(tone(0, amp: 0, noise: 0.05), sr);
      expect(r.found && r.clarity > 0.85, isFalse);
    });
  });

  group('centsFromTarget', () {
    test('+20 cents reads ~+20', () {
      final f = 110 * math.pow(2, 20 / 1200);
      expect((centsFromTarget(f.toDouble(), 110) - 20).abs(), lessThan(1.5));
    });
    test('octave-folds (220 Hz vs So 110) to ~0', () {
      expect(centsFromTarget(220, 110).abs(), lessThan(1.0));
    });
  });

  group('OneEuroFilter', () {
    test('passes through then settles', () {
      final f = OneEuroFilter();
      var t = 0.0;
      var v = f.filter(110, t);
      expect(v, 110);
      for (var i = 0; i < 30; i++) {
        t += 1 / 60;
        v = f.filter(110, t);
      }
      expect((v - 110).abs(), lessThan(0.5));
    });
  });

  group('TunerEngine', () {
    test('maps a played A2 to So, near 0 cents', () {
      final e = TunerEngine(sampleRate: sr);
      TunerReading? r;
      var t = 0.0;
      for (var i = 0; i < 10; i++) {
        t += 1 / 60;
        r = e.process(tone(110), t);
      }
      expect(r, isNotNull);
      expect(r!.note!.solfege, 'So');
      expect(r.cents.abs(), lessThan(5));
      expect(r.level, greaterThan(0));
    });

    test('silence returns null', () {
      final e = TunerEngine(sampleRate: sr);
      expect(e.process(Float32List(n), 0.1), isNull);
    });

    test('locked target overrides nearest', () {
      final e = TunerEngine(sampleRate: sr);
      final la = tuning.firstWhere((x) => x.solfege == 'La');
      final r = e.process(tone(110), 0.1, lockedTarget: la); // playing A2 (So)
      expect(r!.note!.solfege, 'La'); // forced to La target
    });

    test('tuningScale shifts targets — scaled So reads ~0 cents', () {
      final e = TunerEngine(sampleRate: sr)..tuningScale = 1.02; // A ≈ 448.8
      TunerReading? r;
      var t = 0.0;
      for (var i = 0; i < 10; i++) {
        t += 1 / 60;
        r = e.process(tone(110 * 1.02), t); // a So sharpened to match the new reference
      }
      expect(r!.note!.solfege, 'So');
      expect(r.cents.abs(), lessThan(5));
    });

    test('without calibration, that same sharp So reads sharp', () {
      final e = TunerEngine(sampleRate: sr); // scale 1.0
      TunerReading? r;
      var t = 0.0;
      for (var i = 0; i < 10; i++) {
        t += 1 / 60;
        r = e.process(tone(110 * 1.02), t);
      }
      expect(r!.cents, greaterThan(10)); // ~34 cents sharp at A440
    });
  });
}
