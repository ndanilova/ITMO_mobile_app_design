import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'dashboard.dart';
import 'saldo_api.dart';

void main() => runApp(
  MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: saldoGreen),
      scaffoldBackgroundColor: saldoBackground,
      useMaterial3: true,
    ),
    home: const Dashboard(importScreen: ImportScreen()),
  ),
);

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final api = SaldoApi();
  Map<String, dynamic>? preview;
  String? error;
  bool busy = false;

  Future<void> run(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (exception) {
      error = exception.toString();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> chooseReport() => run(() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result == null) return;
    preview = null;
    final file = result.files.single;
    if (file.size > 1024 * 1024) {
      throw const FormatException('Максимальный размер файла — 1 МиБ');
    }
    final bytes = await File(file.path!).readAsBytes();
    preview = await api.requestJson('POST', '/imports', bytes);
  });

  Future<void> confirm() => run(() async {
    final result = await api.requestJson(
      'POST',
      '/imports/${preview!['id']}/confirm',
    );
    preview!['confirmed'] = result['confirmed'];
  });

  void openPortfolio() {
    final trades = api.requestJson('GET', '/portfolio/trades');
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PortfolioScreen(trades: trades),
      ),
    );
  }

  @override
  void dispose() {
    api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trades = preview?['trades'] as List<dynamic>? ?? [];
    final confirmed = preview?['confirmed'] == true;
    return Scaffold(
      appBar: AppBar(title: const Text('Сальдо · Импорт')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton(
            onPressed: busy ? null : chooseReport,
            child: const Text('Выбрать CSV'),
          ),
          OutlinedButton(
            onPressed: openPortfolio,
            child: const Text('Открыть портфель'),
          ),
          if (busy) const LinearProgressIndicator(),
          if (error != null) Text(error!),
          if (preview != null) ...[
            Text('Сделок: ${trades.length}'),
            for (final trade in trades)
              ListTile(
                title: Text(trade['id'] as String),
                trailing: Text(trade['amount'] as String),
              ),
            if (confirmed)
              const Text('Импорт подтверждён')
            else
              FilledButton(
                onPressed: busy ? null : confirm,
                child: const Text('Подтвердить импорт'),
              ),
          ],
        ],
      ),
    );
  }
}

class PortfolioScreen extends StatelessWidget {
  const PortfolioScreen({super.key, required this.trades});

  final Future<Map<String, dynamic>> trades;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Портфель')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: trades,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Не удалось загрузить сделки. Откройте портфель снова.',
              ),
            );
          }
          final items = snapshot.requireData['trades'] as List<dynamic>;
          if (items.isEmpty) {
            return const Center(child: Text('Подтверждённых сделок пока нет'));
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final trade = items[index] as Map<String, dynamic>;
              return ListTile(
                title: Text(trade['id'] as String),
                trailing: Text(trade['amount'] as String),
              );
            },
          );
        },
      ),
    );
  }
}
