import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:csv/csv.dart';

/// Money is stored in kopecks. Rates and security quantities use six decimals.
int decimal(String text, [int scale = 2]) {
  final normalized = text
      .trim()
      .replaceAll(' ', '')
      .replaceAll('\u00a0', '')
      .replaceAll(',', '.');
  if (!RegExp(r'^-?\d+(\.\d+)?$').hasMatch(normalized)) {
    throw const FormatException('Введите число');
  }
  final negative = normalized.startsWith('-');
  final parts = normalized.replaceFirst('-', '').split('.');
  final fraction = parts.length > 1 ? parts[1] : '';
  if (fraction.length > scale)
    throw FormatException('Не больше $scale знаков после запятой');
  final value =
      int.parse(parts[0]) * pow(10, scale).toInt() +
      int.parse(fraction.padRight(scale, '0'));
  if (value.abs() > 9000000000000000)
    throw const FormatException('Слишком большое число');
  return negative ? -value : value;
}

String number(int cents) {
  final sign = cents < 0 ? '−' : '';
  final value = cents.abs();
  final whole = (value ~/ 100).toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]} ',
  );
  return '$sign$whole${value % 100 == 0 ? '' : ',${(value % 100).toString().padLeft(2, '0')}'}';
}

String money(int cents, [String currency = 'RUB']) =>
    '${number(cents)} ${{'RUB': '₽', 'USD': r'$', 'EUR': '€'}[currency] ?? currency}';
String inputMoney(int cents) => (cents / 100).toStringAsFixed(2);
String quantity(int units) =>
    (units / 1000000).toStringAsFixed(6).replaceFirst(RegExp(r'\.?0+$'), '');
String newId() =>
    '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
String dateLabel(String value) {
  final d = DateTime.parse(value);
  return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}

DateTime strictDate(String text) {
  final date = DateTime.tryParse(text);
  if (date == null ||
      !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text) ||
      date.toIso8601String().substring(0, 10) != text) {
    throw const FormatException('Дата должна быть в формате ГГГГ-ММ-ДД');
  }
  return date;
}

class Account {
  Account({
    required this.id,
    required this.name,
    this.kind = 'Счета',
    this.currency = 'RUB',
    this.opening = 0,
    this.rate = 1000000,
  });
  final String id, name, kind, currency;
  final int opening, rate;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind,
    'currency': currency,
    'opening': opening,
    'rate': rate,
  };
  factory Account.fromJson(Map<String, dynamic> j) => Account(
    id: j['id'],
    name: j['name'],
    kind: j['kind'],
    currency: j['currency'],
    opening: j['opening'],
    rate: j['rate'],
  );
}

class Operation {
  Operation({
    required this.id,
    required this.date,
    required this.type,
    required this.account,
    required this.amount,
    this.category = 'Прочее',
    this.note = '',
    this.target = '',
    this.received = 0,
  });
  final String id, date, type, account, category, note, target;
  final int amount, received;
  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'type': type,
    'account': account,
    'amount': amount,
    'category': category,
    'note': note,
    'target': target,
    'received': received,
  };
  factory Operation.fromJson(Map<String, dynamic> j) => Operation(
    id: j['id'],
    date: j['date'],
    type: j['type'],
    account: j['account'],
    amount: j['amount'],
    category: j['category'],
    note: j['note'],
    target: j['target'],
    received: j['received'],
  );
}

class Trade {
  Trade({
    required this.id,
    required this.date,
    required this.account,
    required this.symbol,
    required this.name,
    required this.side,
    required this.units,
    required this.price,
    this.fee = 0,
    this.tax = 0,
    this.kind = 'Акции',
  });
  final String id, date, account, symbol, name, side, kind;
  final int units, price, fee, tax;
  int get gross =>
      (BigInt.from(units) * BigInt.from(price) ~/ BigInt.from(1000000)).toInt();
  int get cash => side == 'buy' ? -gross - fee - tax : gross - fee - tax;
  String get key => '$account|$id';
  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'account': account,
    'symbol': symbol,
    'name': name,
    'side': side,
    'units': units,
    'price': price,
    'fee': fee,
    'tax': tax,
    'kind': kind,
  };
  factory Trade.fromJson(Map<String, dynamic> j) => Trade(
    id: j['id'],
    date: j['date'],
    account: j['account'],
    symbol: j['symbol'],
    name: j['name'],
    side: j['side'],
    units: j['units'],
    price: j['price'],
    fee: j['fee'],
    tax: j['tax'],
    kind: j['kind'],
  );
}

class Payout {
  Payout({
    required this.id,
    required this.account,
    required this.symbol,
    required this.date,
    required this.amount,
    required this.type,
    this.tax = 0,
    this.paid = false,
  });
  final String id, account, symbol, date, type;
  final int amount, tax;
  final bool paid;
  Map<String, dynamic> toJson() => {
    'id': id,
    'account': account,
    'symbol': symbol,
    'date': date,
    'amount': amount,
    'type': type,
    'tax': tax,
    'paid': paid,
  };
  factory Payout.fromJson(Map<String, dynamic> j) => Payout(
    id: j['id'],
    account: j['account'],
    symbol: j['symbol'],
    date: j['date'],
    amount: j['amount'],
    type: j['type'],
    tax: j['tax'],
    paid: j['paid'],
  );
}

class Position {
  Position(this.symbol, this.name, this.kind);
  final String symbol, name, kind;
  int units = 0, cost = 0, realized = 0, quote = 0;
  int get value =>
      (BigInt.from(units) * BigInt.from(quote) ~/ BigInt.from(1000000)).toInt();
  int get profit => value - cost + realized;
}

class LocalStore extends ChangeNotifier {
  LocalStore(this.file);
  final File file;
  List<Account> accounts = [];
  List<Operation> operations = [];
  List<Trade> trades = [];
  List<Payout> payouts = [];
  List<String> categories = [
    'Продукты',
    'Кафе',
    'Развлечения',
    'Транспорт',
    'Здоровье',
    'Подписки',
    'Подарки',
    'Покупки',
    'Жильё',
    'Прочее',
  ];
  Map<String, int> quotes = {};
  Map<String, int> budgets = {};
  bool busy = false;

  Map<String, dynamic> snapshot() => {
    'version': 1,
    'accounts': accounts.map((e) => e.toJson()).toList(),
    'operations': operations.map((e) => e.toJson()).toList(),
    'trades': trades.map((e) => e.toJson()).toList(),
    'payouts': payouts.map((e) => e.toJson()).toList(),
    'categories': categories,
    'quotes': quotes,
    'budgets': budgets,
  };

  void restore(Map<String, dynamic> j) {
    if (j['version'] != 1)
      throw const FormatException('Неподдерживаемая версия данных');
    accounts = (j['accounts'] as List)
        .map((e) => Account.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    operations = (j['operations'] as List)
        .map((e) => Operation.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    trades = (j['trades'] as List)
        .map((e) => Trade.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    payouts = (j['payouts'] as List)
        .map((e) => Payout.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    categories = List<String>.from(j['categories']);
    quotes = Map<String, int>.from(j['quotes']);
    budgets = Map<String, int>.from(j['budgets']);
  }

  Future<void> load() async {
    if (await file.exists()) restore(jsonDecode(await file.readAsString()));
  }

  /// Persist a complete snapshot atomically. Roll back memory if writing fails.
  Future<void> change(VoidCallback edit) async {
    if (busy) throw StateError('Дождитесь завершения сохранения');
    busy = true;
    final before = jsonDecode(jsonEncode(snapshot())) as Map<String, dynamic>;
    try {
      edit();
      await file.parent.create(recursive: true);
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(jsonEncode(snapshot()), flush: true);
      await temp.rename(file.path);
    } catch (_) {
      restore(before);
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Account account(String id) => accounts.firstWhere((a) => a.id == id);
  int rub(int amount, String id) =>
      (BigInt.from(amount) *
              BigInt.from(account(id).rate) ~/
              BigInt.from(1000000))
          .toInt();
  int balance(String id, [DateTime? before]) {
    final a = account(id);
    var result = a.opening;
    bool included(String date) =>
        before == null || DateTime.parse(date).isBefore(before);
    for (final o in operations.where((o) => included(o.date))) {
      if (o.account == id) result += o.type == 'income' ? o.amount : -o.amount;
      if (o.target == id && o.type == 'transfer') result += o.received;
    }
    for (final t in trades.where((t) => t.account == id && included(t.date))) {
      result += t.cash;
    }
    for (final p in payouts.where(
      (p) => p.account == id && p.paid && included(p.date),
    )) {
      result += p.amount - p.tax;
    }
    return result;
  }

  int get capital =>
      accounts.fold(0, (sum, a) => sum + rub(balance(a.id), a.id)) +
      accounts
          .where((a) => a.kind == 'Инвестиции')
          .fold(
            0,
            (sum, a) =>
                sum + rub(positions(a.id).fold(0, (v, p) => v + p.value), a.id),
          );

  List<Operation> monthOperations(DateTime month) => operations.where((o) {
    final d = DateTime.parse(o.date);
    return d.year == month.year && d.month == month.month;
  }).toList()..sort((a, b) => b.date.compareTo(a.date));
  int total(DateTime month, String type, [String? category]) =>
      monthOperations(month)
          .where(
            (o) =>
                o.type == type && (category == null || o.category == category),
          )
          .fold(0, (sum, o) => sum + rub(o.amount, o.account));

  List<Position> positions(String id, [List<Trade>? source]) {
    final result = <String, Position>{};
    final items =
        (source ?? trades).indexed.where((e) => e.$2.account == id).toList()
          ..sort((a, b) {
            final date = a.$2.date.compareTo(b.$2.date);
            return date != 0 ? date : a.$1.compareTo(b.$1);
          });
    for (final (_, t) in items) {
      final p = result.putIfAbsent(
        t.symbol,
        () => Position(t.symbol, t.name, t.kind),
      );
      if (t.side == 'buy') {
        p.units += t.units;
        p.cost += t.gross + t.fee + t.tax;
      } else {
        if (t.units > p.units)
          throw FormatException(
            'Недостаточно позиции ${t.symbol} на ${dateLabel(t.date)}',
          );
        final removed =
            (BigInt.from(p.cost) * BigInt.from(t.units) ~/ BigInt.from(p.units))
                .toInt();
        p.realized += t.cash - removed;
        p.cost -= removed;
        p.units -= t.units;
      }
      p.quote = quotes['$id|${t.symbol}'] ?? t.price;
    }
    return result.values.toList();
  }

  Future<void> saveAccount(Account a) => change(() {
    if (a.name.trim().isEmpty || a.rate <= 0)
      throw const FormatException('Укажите название и положительный курс');
    final index = accounts.indexWhere((e) => e.id == a.id);
    if (index < 0) {
      accounts.add(a);
    } else {
      if (accounts[index].currency != a.currency ||
          (accounts[index].kind == 'Инвестиции' &&
              a.kind != 'Инвестиции' &&
              trades.any((t) => t.account == a.id))) {
        throw const FormatException(
          'Счёт со сделками должен оставаться брокерским, валюта счёта фиксирована',
        );
      }
      accounts[index] = a;
    }
  });
  Future<void> saveOperation(Operation o) => change(() {
    strictDate(o.date);
    account(o.account);
    if (o.amount <= 0)
      throw const FormatException('Сумма должна быть больше нуля');
    if (o.type == 'transfer') {
      account(o.target);
      if (o.target == o.account || o.received <= 0)
        throw const FormatException('Выберите другой счёт и сумму зачисления');
    }
    operations.add(o);
  });
  Future<void> deleteOperation(String id) =>
      change(() => operations.removeWhere((o) => o.id == id));
  Future<void> saveTrade(Trade t) => importTrades([t]);
  Future<void> importTrades(List<Trade> rows) => change(() {
    final candidate = [...trades];
    for (final row in rows) {
      strictDate(row.date);
      if (account(row.account).kind != 'Инвестиции' ||
          row.units <= 0 ||
          row.price <= 0 ||
          row.fee < 0 ||
          row.tax < 0 ||
          row.id.isEmpty ||
          !['buy', 'sell'].contains(row.side)) {
        throw const FormatException('Некорректная сделка');
      }
      final existing = candidate.where((t) => t.key == row.key).firstOrNull;
      if (existing != null) {
        if (jsonEncode(existing.toJson()) != jsonEncode(row.toJson()))
          throw FormatException('Конфликт сделки ${row.id}');
        continue;
      }
      candidate.add(row);
    }
    for (final a in accounts.where((a) => a.kind == 'Инвестиции')) {
      positions(a.id, candidate);
    }
    trades = candidate;
  });

  List<Trade> parseReport(String text, String accountId) {
    if (account(accountId).kind != 'Инвестиции')
      throw const FormatException('Выберите брокерский счёт');
    final rows = const CsvToListConverter(
      shouldParseNumbers: false,
      eol: '\n',
    ).convert(text.replaceAll('\r\n', '\n').replaceFirst('\ufeff', ''));
    if (rows.isEmpty) throw const FormatException('Файл пуст');
    const header = [
      'trade_id',
      'date',
      'symbol',
      'name',
      'side',
      'quantity',
      'price',
      'fee',
      'tax',
      'kind',
    ];
    if (jsonEncode(rows.first) != jsonEncode(header))
      throw const FormatException(
        'Формат CSV не совпадает с образцом. Нужны дата, инструмент, количество и цена.',
      );
    final result = <Trade>[];
    final ids = <String>{};
    for (var i = 1; i < rows.length; i++) {
      if (rows[i].every((v) => v.toString().trim().isEmpty)) continue;
      final row = rows[i].map((v) => v.toString().trim()).toList();
      if (row.length != header.length)
        throw FormatException('Строка ${i + 1}: ожидается 10 столбцов');
      strictDate(row[1]);
      if (row[0].isEmpty ||
          !ids.add(row[0]) ||
          row[2].isEmpty ||
          row[3].isEmpty ||
          !['buy', 'sell'].contains(row[4]) ||
          !['Акции', 'Облигации', 'Фонды'].contains(row[9])) {
        throw FormatException(
          'Строка ${i + 1}: проверьте ID, инструмент, тип и направление',
        );
      }
      final t = Trade(
        id: row[0],
        date: row[1],
        account: accountId,
        symbol: row[2].toUpperCase(),
        name: row[3],
        side: row[4],
        units: decimal(row[5], 6),
        price: decimal(row[6]),
        fee: decimal(row[7]),
        tax: decimal(row[8]),
        kind: row[9],
      );
      if (t.units <= 0 ||
          t.price <= 0 ||
          t.fee < 0 ||
          t.tax < 0 ||
          t.gross <= 0)
        throw FormatException('Строка ${i + 1}: неверная сумма');
      result.add(t);
    }
    if (result.isEmpty) throw const FormatException('В файле нет сделок');
    return result;
  }

  Future<void> saveQuote(String accountId, String symbol, int value) =>
      change(() {
        if (value <= 0)
          throw const FormatException('Цена должна быть больше нуля');
        quotes['$accountId|$symbol'] = value;
      });
  Future<void> saveBudget(String category, int value) => change(() {
    if (value < 0)
      throw const FormatException('Лимит не может быть отрицательным');
    budgets[category] = value;
  });
  Future<void> addCategory(String value) => change(() {
    final name = value.trim();
    if (name.isEmpty || categories.contains(name))
      throw const FormatException('Укажите новое название категории');
    categories.add(name);
  });
  Future<void> savePayout(Payout p) => change(() {
    strictDate(p.date);
    account(p.account);
    if (p.amount <= 0 || p.tax < 0 || p.tax > p.amount)
      throw const FormatException('Проверьте сумму и налог');
    payouts.add(p);
  });
  Future<void> togglePayout(Payout p) => change(() {
    final json = p.toJson()..['paid'] = !p.paid;
    payouts[payouts.indexWhere((v) => v.id == p.id)] = Payout.fromJson(json);
  });

  Future<void> seed() => change(() {
    if (accounts.isNotEmpty || operations.isNotEmpty || trades.isNotEmpty)
      throw StateError('Демо можно загрузить только в пустое приложение');
    final now = DateTime.now();
    final month = DateTime(now.year, now.month);
    accounts = [
      Account(id: 'card', name: 'Т-Банк карта', opening: 7000000),
      Account(id: 'cash', name: 'Наличные', opening: 388000),
      Account(
        id: 'usd',
        name: 'Доллары',
        currency: 'USD',
        opening: 45000,
        rate: 81000000,
      ),
      Account(
        id: 'savings',
        name: 'Накопительный счёт',
        kind: 'Сбережения',
        opening: 12000000,
      ),
      Account(
        id: 'deposit',
        name: 'Вклад на 6 месяцев',
        kind: 'Сбережения',
        opening: 20000000,
      ),
      Account(
        id: 'broker',
        name: 'Брокерский счёт',
        kind: 'Инвестиции',
        opening: 20000000,
      ),
    ];
    operations = [
      Operation(
        id: newId(),
        date: month.toIso8601String().substring(0, 10),
        type: 'income',
        account: 'card',
        amount: 4750000,
        category: 'Зарплата',
        note: 'Вторая часть',
      ),
      Operation(
        id: newId(),
        date: month.toIso8601String().substring(0, 10),
        type: 'expense',
        account: 'card',
        amount: 214060,
        category: 'Продукты',
        note: 'Перекрёсток',
      ),
      Operation(
        id: newId(),
        date: month.toIso8601String().substring(0, 10),
        type: 'expense',
        account: 'cash',
        amount: 68000,
        category: 'Кафе',
        note: 'Кофейня',
      ),
    ];
    trades = parseReport(sampleReport, 'broker');
    quotes = {
      'broker|TMOS': 712,
      'broker|SBER': 30240,
      'broker|LKOH': 685000,
      'broker|SU26238': 61230,
    };
    payouts = [
      Payout(
        id: newId(),
        account: 'broker',
        symbol: 'SU26238',
        date: DateTime(
          now.year,
          now.month,
          25,
        ).toIso8601String().substring(0, 10),
        amount: 142000,
        tax: 18460,
        type: 'Купон',
      ),
    ];
  });
}

const sampleReport =
    'trade_id,date,symbol,name,side,quantity,price,fee,tax,kind\n'
    'demo-1,2026-01-10,TMOS,Фонд на индекс МосБиржи,buy,6000,6.55,40,0,Фонды\n'
    'demo-2,2026-01-11,SBER,Сбербанк,buy,120,278.1,30,0,Акции\n'
    'demo-3,2026-01-12,LKOH,Лукойл,buy,5,7080,35,0,Акции\n'
    'demo-4,2026-01-13,SU26238,ОФЗ 26238,buy,40,584.6,24,0,Облигации\n';
