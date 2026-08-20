import 'package:showcaseview/showcaseview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'screens/login_screen.dart';
import 'services/notification_service.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'widgets/showcase_next_button.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await NotificationService.init();
  runApp(const PrintServiceApp());
}

class PrintServiceApp extends StatelessWidget {
  const PrintServiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: ShowCaseWidget(
        disableBarrierInteraction: true,
        // Without this the package never scrolls, and every coach mark past
        // the fold is drawn over whatever happens to be on screen.
        enableAutoScroll: true,
        scrollDuration: const Duration(milliseconds: 300),
        onFinish: () => TourCoordinator.onFinish?.call(),
        builder: (context) => MaterialApp(
          title: 'PrintEase',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: const LoginScreen(),
        ),
      ),
    );
  }
}