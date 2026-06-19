import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/scanner_tab.dart';
import '../widgets/data_sku_tab.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class ScannerSkuScreen extends StatelessWidget {
  const ScannerSkuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Scanner SKU'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await ApiService.logout();
                if (context.mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                }
              },
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(64),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.muted,
                borderRadius: BorderRadius.circular(10),
              ),
              child: TabBar(
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withAlpha((255 * 0.05).toInt()), blurRadius: 4, offset: const Offset(0, 2))
                  ],
                ),
                labelColor: AppColors.foreground,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                unselectedLabelColor: AppColors.mutedForeground,
                tabs: const [
                  Tab(text: 'Scanner'),
                  Tab(text: 'Data SKU'),
                ],
              ),
            ),
          ),
        ),
        body: const TabBarView(
          children: [
            ScannerTab(),
            DataSkuTab(),
          ],
        ),
      ),
    );
  }
}
