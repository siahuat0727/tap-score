import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'state/score_notifier.dart';
import 'screens/score_editor_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TapScoreApp());
}

class TapScoreApp extends StatelessWidget {
  const TapScoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ScoreNotifier(),
      child: MaterialApp(
        title: 'Tap Score',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const ScoreEditorScreen(),
      ),
    );
  }
}
