import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'dashboard.dart';
import 'design.dart';
import 'local_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SaldoApp());
}

class SaldoApp extends StatefulWidget {
  const SaldoApp({super.key});
  @override
  State<SaldoApp> createState() => _SaldoAppState();
}

class _SaldoAppState extends State<SaldoApp> {
  LocalStore? store;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => error = null);
    try {
      final directory = await getApplicationDocumentsDirectory();
      final local = LocalStore(File('${directory.path}/saldo-v1.json'));
      await local.load();
      if (mounted) setState(() => store = local);
    } catch (_) {
      if (mounted)
        setState(
          () => error = 'Не удалось прочитать локальные данные. Повторите открытие приложения.',
        );
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      fontFamily: 'Manrope',
      scaffoldBackgroundColor: saldoBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: saldoGreen,
        primary: saldoGreen,
        surface: saldoBackground,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: saldoBackground,
        centerTitle: true,
      ),
      dividerTheme: const DividerThemeData(color: line),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(backgroundColor: saldoGreen),
      ),
      useMaterial3: true,
    ),
    home: store != null
        ? Dashboard(store: store!)
        : Scaffold(
            body: Center(
              child: error == null
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(error!),
                        ),
                        TextButton(
                          onPressed: load,
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
            ),
          ),
  );
}
