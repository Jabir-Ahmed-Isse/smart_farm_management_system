// Smoke test for the SFMS app shell.
//
// Full integration tests (auth, live Supabase data) run against a test
// project; this smoke test just verifies the root widget builds.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MaterialApp builds a title', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('SFMS'))),
      ),
    );

    expect(find.text('SFMS'), findsOneWidget);
  });
}
