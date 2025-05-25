// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:untitled/main.dart';
import 'package:untitled/providers/theme_provider.dart';
import 'package:untitled/providers/auth_provider.dart';
import 'package:untitled/providers/hotel_provider.dart';
import 'package:untitled/providers/booking_provider.dart';
import 'package:untitled/login.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Initialize Firebase for testing
    await Firebase.initializeApp();

    // Build our app with required providers
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => HotelProvider()),
          ChangeNotifierProvider(create: (_) => BookingProvider()),
        ],
        child: Consumer<ThemeProvider>(
          builder: (context, themeProvider, child) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'EzyStay',
              theme: themeProvider.getTheme(),
              home: const LoginPage(),
            );
          },
        ),
      ),
    );

    // Verify that our app builds without errors
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(LoginPage), findsOneWidget);
  });
}
