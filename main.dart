import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'services/service_locator.dart';
import 'ui/legacy_app.dart';
import 'ui/splash_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // AdMob SDK — uygulama açılışında yükle
  // Android APPLICATION_ID AndroidManifest'te tanımlanır (CI / lokal).
  // Birim ID'leri AppConfig (dart-define veya Google test ID).
  try {
    await MobileAds.instance.initialize();
  } catch (_) {
    // Emülatör / eksik manifest: ServiceLocator demo reklama düşer
  }

  await ServiceLocator.I.init();
  runApp(const HakPayApp());
}

class HakPayApp extends StatelessWidget {
  const HakPayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()..bootstrap()),
      ],
      child: MaterialApp(
        title: 'HakPay',
        debugShowCheckedModeBanner: false,
        theme: HakTheme.dark(),
        home: const SplashScreen(),
      ),
    );
  }
}
