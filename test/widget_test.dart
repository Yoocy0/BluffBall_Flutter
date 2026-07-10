import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bluffball_flutter/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const BluffBallApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
