import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulsecast/features/auth/presentation/providers/auth_notifier.dart';
import 'package:pulsecast/features/auth/presentation/providers/auth_providers.dart';
import 'package:pulsecast/features/auth/presentation/providers/auth_state.dart';
import 'package:pulsecast/features/auth/presentation/screens/login_screen.dart';
import 'package:pulsecast/features/auth/presentation/screens/register_screen.dart';

class TestAuthNotifier extends AuthNotifier {
  final AuthState _initialState;

  TestAuthNotifier([this._initialState = const AuthState.initial()]);

  @override
  AuthState build() => _initialState;
}

void main() {
  group('LoginScreen Widget Tests', () {
    testWidgets('renders all essential elements (branding, inputs, submit button)', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith(() => TestAuthNotifier()),
          ],
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      expect(find.text('PULSECAST'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Continue as Guest Listener'), findsOneWidget);
    });

    testWidgets('triggers client-side validation errors on empty submission', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith(() => TestAuthNotifier()),
          ],
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      // Tap Sign In button without entering credentials
      await tester.tap(find.text('Sign In'));
      await tester.pump();

      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('displays session expired alert banner when sessionExpired is true', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith(
              () => TestAuthNotifier(
                const AuthState.unauthenticated(sessionExpired: true),
              ),
            ),
          ],
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      expect(
        find.text('Your session has expired. Please sign in again.'),
        findsOneWidget,
      );
    });

    testWidgets('displays API error banner when auth state is in error', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith(
              () => TestAuthNotifier(
                const AuthState.error(
                  message: 'Invalid email or password.',
                  errors: ['Please check your credentials.'],
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      expect(find.text('Invalid email or password.'), findsOneWidget);
      expect(find.text('• Please check your credentials.'), findsOneWidget);
    });
  });

  group('RegisterScreen Widget Tests', () {
    testWidgets('renders all registration fields and validates mismatched passwords', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith(() => TestAuthNotifier()),
          ],
          child: const MaterialApp(
            home: RegisterScreen(),
          ),
        ),
      );

      expect(find.text('Create Account'), findsWidgets);
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);

      // Enter mismatched passwords
      final fields = find.byType(TextFormField);
      expect(fields, findsNWidgets(4));

      await tester.enterText(fields.at(0), 'Alex Rivera');
      await tester.enterText(fields.at(1), 'alex@pulsecast.com');
      await tester.enterText(fields.at(2), 'Password123!');
      await tester.enterText(fields.at(3), 'MismatchPass!');

      final submitButton = find.widgetWithText(ElevatedButton, 'Create Account');
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pump();

      expect(find.text('Passwords do not match'), findsOneWidget);
    });
  });
}
