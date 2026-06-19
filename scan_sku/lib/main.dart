import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'screens/scanner_sku_screen.dart';
import 'screens/login_screen.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  WakelockPlus.enable();
  await dotenv.load(fileName: ".env");
  
  final token = await ApiService.getToken();
  
  runApp(MyApp(initialRouteIsScanner: token != null));
}

class MyApp extends StatelessWidget {
  final bool initialRouteIsScanner;
  const MyApp({super.key, required this.initialRouteIsScanner});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scanner SKU App',
      theme: AppTheme.lightTheme,
      home: initialRouteIsScanner ? const ScannerSkuScreen() : const LoginScreen(),
    );
  }
}
