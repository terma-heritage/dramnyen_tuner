import 'package:dranyen/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app builds and shows the start control', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const DranyenApp());

    expect(find.text('Start tuning'), findsOneWidget);
    expect(find.text('A = 440 Hz'), findsOneWidget);
    expect(find.text('Auto'), findsOneWidget);
  });
}
