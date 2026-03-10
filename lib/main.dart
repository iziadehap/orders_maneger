import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moamen_project/core/services/connectivity/connectivity_widget.dart';
import 'package:moamen_project/core/services/location/location_widget.dart';
import 'core/theme/app_theme.dart';
import 'core/services/supabase_service.dart';
import 'features/splash/presentation/splash_screen.dart';
import 'features/splash/presentation/update_screen.dart';
import 'features/settings/data/settings_provider.dart';
// flutter build apk --split-per-abi

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  // Initialize Supabase
  await SupabaseService.initialize();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(themeProvider);

    return MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) {
        return UpdateGate(
          child: ConnectivityWrapper(child: LocationWidget(child: child!)),
        );
      },
      home: const SplashScreen(),
    );
  }
}
