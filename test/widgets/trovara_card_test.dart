import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trovara/widgets/trovara_card.dart';

void main() {
  group('TrovaraCard', () {
    testWidgets('renders child', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TrovaraCard(child: Text('hello')),
          ),
        ),
      );
      expect(find.text('hello'), findsOneWidget);
    });

    testWidgets('applies padding when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TrovaraCard(
              padding: EdgeInsets.all(20),
              child: Text('padded'),
            ),
          ),
        ),
      );
      final padding = tester.widget<Padding>(
        find.ancestor(of: find.text('padded'), matching: find.byType(Padding)).first,
      );
      expect(padding.padding, const EdgeInsets.all(20));
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrovaraCard(
              onTap: () => tapped = true,
              child: const Text('tap me'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('tap me'));
      expect(tapped, isTrue);
    });

    testWidgets('calls onLongPress when long pressed', (tester) async {
      var pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrovaraCard(
              onLongPress: () => pressed = true,
              child: const Text('hold me'),
            ),
          ),
        ),
      );
      await tester.longPress(find.text('hold me'));
      expect(pressed, isTrue);
    });

    testWidgets('renders without tap handlers', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TrovaraCard(child: Text('static')),
          ),
        ),
      );
      expect(find.text('static'), findsOneWidget);
    });
  });
}
