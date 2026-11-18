import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'dashboard.dart';
import 'design.dart';
import 'local_store.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key, required this.store});
  final LocalStore store;
  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  late String? account = widget.store.accounts
      .where((a) => a.kind == 'Инвестиции')
      .firstOrNull
      ?.id;
  List<Trade> preview = [];
  String? error, filename;
  bool busy = false, confirmed = false;
  int get duplicates => preview
      .where((t) => widget.store.trades.any((old) => old.key == t.key))
      .length;
  Future<void> choose() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (file == null) return;
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in file.readAsByteStream()) {
        if (bytes.length + chunk.length > 1024 * 1024)
          throw const FormatException('Максимальный размер файла — 1 МиБ');
        bytes.add(chunk);
      }
      if (!mounted) return;
      parse(utf8.decode(bytes.takeBytes()), file.name);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void parse(String text, String name) {
    if (account == null) {
      setState(() => error = 'Добавьте брокерский счёт во вкладке «Счета»');
      return;
    }
    try {
      final rows = widget.store.parseReport(text, account!);
      setState(() {
        preview = rows;
        filename = name;
        error = null;
        confirmed = false;
      });
    } catch (e) {
      setState(() {
        preview = [];
        error = e.toString();
      });
    }
  }

  Future<void> confirm() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.store.importTrades(preview);
      if (mounted) setState(() => confirmed = true);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Импорт отчёта')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Panel(
          child: Text(
            'Загрузите CSV по шаблону Сальдо. Разбор и сохранение выполняются на устройстве. Для отчётов конкретных брокеров потребуется согласовать их форматы.',
          ),
        ),
        const SizedBox(height: 10),
        if (account != null)
          DropdownButtonFormField<String>(
            initialValue: account,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Брокерский счёт'),
            items: [
              for (final a in widget.store.accounts.where(
                (a) => a.kind == 'Инвестиции',
              ))
                DropdownMenuItem(value: a.id, child: Text(a.name)),
            ],
            onChanged: busy
                ? null
                : (id) => setState(() {
                    account = id;
                    preview = [];
                    confirmed = false;
                  }),
          ),
        if (account == null)
          const EmptyState('Сначала добавьте брокерский счёт'),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: busy || account == null ? null : choose,
          icon: const Icon(Icons.upload_file),
          label: const Text('Выбрать CSV'),
        ),
        TextButton(
          onPressed: busy || account == null
              ? null
              : () => parse(sampleReport, 'Образец Сальдо'),
          child: const Text('Проверить на образце'),
        ),
        TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Шаблон CSV'),
              content: SingleChildScrollView(
                child: SelectableText(sampleReport),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Закрыть'),
                ),
              ],
            ),
          ),
          child: const Text('Показать формат файла'),
        ),
        if (busy) const LinearProgressIndicator(),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(error!, style: const TextStyle(color: red)),
          ),
        if (preview.isNotEmpty) ...[
          const SizedBox(height: 12),
          SectionTitle(filename ?? 'Предпросмотр', '${preview.length} сделок'),
          Text(
            'Совпадающих ID на этом счёте: $duplicates. Повторные сделки пропускаются, различающиеся данные с тем же ID требуют исправления файла.',
            style: const TextStyle(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 12),
          for (final t in preview)
            Panel(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${t.side == 'buy' ? 'Покупка' : 'Продажа'} · ${t.name}',
                ),
                subtitle: Text(
                  '${dateLabel(t.date)} · ${quantity(t.units)} шт. × ${money(t.price)}\nКомиссия ${money(t.fee)} · Налог ${money(t.tax)}',
                ),
                isThreeLine: true,
              ),
            ),
          if (confirmed) ...[
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Импорт сохранён на устройстве',
                style: TextStyle(color: teal, fontWeight: FontWeight.w700),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Вернуться в портфель'),
            ),
          ] else
            FilledButton(
              onPressed: busy ? null : confirm,
              child: const Text('Подтвердить импорт'),
            ),
        ],
      ],
    ),
  );
}
