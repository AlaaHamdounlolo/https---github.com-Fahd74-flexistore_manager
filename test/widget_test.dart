import 'package:flutter_test/flutter_test.dart';
import 'package:flexistore_manager/main.dart';

void main() {
  testWidgets('App should render login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Verify the login screen is shown
    expect(find.text('FlexiStore Manager'), findsOneWidget);
    expect(find.text('Sign in to continue'), findsOneWidget);
  });
}
