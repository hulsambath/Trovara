# notemyminds Testing Guidelines

## Widget Testing

### Basic Widget Test Structure

```dart
void main() {
  testWidgets('Widget test description', (tester) async {
    // Build widget
    await tester.pumpWidget(
      MaterialApp(
        home: YourWidget(),
      ),
    );

    // Find widgets
    final titleFinder = find.text('Expected Text');
    final buttonFinder = find.byType(ElevatedButton);

    // Verify
    expect(titleFinder, findsOneWidget);
    expect(buttonFinder, findsOneWidget);
  });
}
```

### Testing with ViewModels

```dart
void main() {
  late MockRepository mockRepository;
  late ViewModel viewModel;

  setUp(() {
    mockRepository = MockRepository();
    viewModel = ViewModel(repository: mockRepository);
  });

  testWidgets('ViewModel integration test', (tester) async {
    await tester.pumpWidget(
      ViewModelProvider<ViewModel>(
        create: (context) => viewModel,
        builder: (context, vm, child) => YourWidget(),
      ),
    );

    // Test implementation
  });
}
```

### Testing Async Operations

```dart
testWidgets('Async operation test', (tester) async {
  // Initial pump
  await tester.pumpWidget(widget);

  // Trigger async operation
  await tester.tap(find.byType(Button));

  // Wait for operation
  await tester.pump();

  // Verify loading state
  expect(find.byType(CircularProgressIndicator), findsOneWidget);

  // Wait for completion
  await tester.pumpAndSettle();

  // Verify final state
  expect(find.text('Success'), findsOneWidget);
});
```

## ViewModel Testing

### Basic ViewModel Test

```dart
void main() {
  group('ViewModel Tests', () {
    late MockRepository mockRepository;
    late ViewModel viewModel;

    setUp(() {
      mockRepository = MockRepository();
      viewModel = ViewModel(repository: mockRepository);
    });

    test('initial state', () {
      expect(viewModel.isLoading, false);
      expect(viewModel.items, isEmpty);
    });

    test('load items', () async {
      when(mockRepository.getItems())
          .thenAnswer((_) async => [Item(id: 1)]);

      await viewModel.loadItems();

      expect(viewModel.items.length, 1);
      verify(mockRepository.getItems()).called(1);
    });
  });
}
```

### Testing Error Scenarios

```dart
test('handles error', () async {
  when(mockRepository.getItems())
      .thenThrow(Exception('Test error'));

  await viewModel.loadItems();

  expect(viewModel.hasError, true);
  expect(viewModel.errorMessage, 'Test error');
});
```

## Integration Testing

### Network Integration

```dart
testWidgets('Google Drive sync test', (tester) async {
  // Mock network service
  final mockNetwork = MockNetworkService();
  when(mockNetwork.isOnline).thenReturn(true);

  // Build widget with mocked service
  await tester.pumpWidget(
    ViewModelProvider<SyncViewModel>(
      create: (context) => SyncViewModel(network: mockNetwork),
      builder: (context, vm, child) => SyncWidget(),
    ),
  );

  // Test sync operation
  await tester.tap(find.byIcon(Icons.sync));
  await tester.pumpAndSettle();

  // Verify sync completed
  verify(mockNetwork.sync()).called(1);
});
```

### Database Integration

```dart
testWidgets('ObjectBox integration test', (tester) async {
  // Setup test database
  final testDb = await setupTestDatabase();

  // Build widget with test database
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(testDb),
      ],
      child: YourWidget(),
    ),
  );

  // Test database operations
  await tester.tap(find.byType(SaveButton));
  await tester.pumpAndSettle();

  // Verify data saved
  final savedItem = await testDb.getItem(1);
  expect(savedItem, isNotNull);
});
```

## Test Coverage

Aim for high test coverage in:

1. ViewModels
2. Repository implementations
3. Service classes
4. Complex UI widgets
5. Navigation logic

Run coverage:

```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```
