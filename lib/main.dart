import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:untitled/adminLogin.dart';
import 'package:untitled/bookingManagement.dart';
import 'package:untitled/discountManagement.dart';
import 'package:untitled/hotelManagement.dart';
import 'package:untitled/roomManagement.dart';
import 'package:untitled/report.dart';
import 'adminDashboard.dart';
import 'userManagement.dart';
import 'services/firebase_service.dart';
import 'providers/auth_provider.dart';
import 'providers/hotel_provider.dart';
import 'providers/booking_provider.dart';
import 'providers/language_provider.dart';
import 'login.dart';
import 'homePage.dart';
import 'register.dart';
import 'reviewManagement.dart';
import 'providers/theme_provider.dart';
import 'utils/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:untitled/sales_report.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Initialize Firebase first
    await Firebase.initializeApp();
    
    // Initialize our Firebase service
    final firebaseService = FirebaseService();
    await firebaseService.initializeFirebase();
    
    print('Firebase initialized successfully'); // Debug log
  } catch (e) {
    print('Error initializing Firebase: $e'); // Debug log
  }
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => HotelProvider()),
        ChangeNotifierProvider(create: (_) => BookingProvider()),
      ],
      child: Consumer2<ThemeProvider, LanguageProvider>(
        builder: (context, themeProvider, languageProvider, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'EzyStay',
            theme: themeProvider.getTheme(),
            locale: languageProvider.currentLocale,
            supportedLocales: const [
              Locale('en'), // English
              Locale('zh'), // Chinese
            ],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            initialRoute: '/login',
            routes: {
              '/login': (context) => const LoginPage(),
              '/register': (context) => RegisterPage(),
              '/home': (context) => const HomePage(),
              '/adminLogin': (context) => AdminLoginPage(),
              '/adminDashboard': (context) => AdminDashboard(),
              '/hotelManagement': (context) => HotelManagement(),
              '/roomManagement': (context) => RoomManagement(),
              '/userManagement': (context) => UserManagement(),
              '/discountManagement': (context) => DiscountManagement(),
              '/bookingManagement': (context) => BookingManagement(),
              '/salesReport': (context) => SalesReportPage(),
              '/reviewManagement': (context) => ReviewManagement(),
            },
          );
        },
      ),
    ),
  );
}
