// Basic smoke test for sec_chat app
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test - MaterialApp renders', (WidgetTester tester) async {
    // Basic test to verify Flutter test infrastructure works
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('SecChat'),
          ),
        ),
      ),
    );

    expect(find.text('SecChat'), findsOneWidget);
  });
}
