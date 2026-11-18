import 'package:flutter/material.dart';

import 'dashboard.dart';
import 'design.dart';
import 'local_store.dart';

class FormShell extends StatelessWidget {
  const FormShell({
    super.key,
    required this.title,
    required this.children,
    required this.save,
    this.busy = false,
    this.error,
  });
  final String title;
  final List<Widget> children;
  final VoidCallback save;
  final bool busy;
  final String? error;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      16,
      16,
      16,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: line,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        for (final child in children) ...[child, const SizedBox(height: 12)],
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(error!, style: const TextStyle(color: red)),
          ),
        FilledButton(
          onPressed: busy ? null : save,
          child: Text(busy ? 'Сохранение…' : 'Сохранить'),
        ),
      ],
    ),
  );
}

Widget field(
  TextEditingController controller,
  String label, {
  bool numeric = false,
  int lines = 1,
}) => TextField(
  controller: controller,
  maxLines: lines,
  keyboardType: numeric
      ? const TextInputType.numberWithOptions(decimal: true, signed: true)
      : TextInputType.text,
  decoration: InputDecoration(
    labelText: label,
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: line),
    ),
  ),
);
Widget select<T>(
  String label,
  T value,
  List<T> items,
  ValueChanged<T> change, {
  String Function(T)? name,
}) => DropdownButtonFormField<T>(
  initialValue: value,
  isExpanded: true,
  decoration: InputDecoration(
    labelText: label,
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
  ),
  items: [
    for (final item in items)
      DropdownMenuItem(
        value: item,
        child: Text(
          name?.call(item) ?? item.toString(),
          overflow: TextOverflow.ellipsis,
        ),
      ),
  ],
  onChanged: (v) {
    if (v != null) change(v);
  },
);

class AccountForm extends StatefulWidget {
  const AccountForm({
    super.key,
    required this.store,
    this.existing,
    this.kind = 'Счета',
  });
  final LocalStore store;
  final Account? existing;
  final String kind;
  @override
  State<AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends State<AccountForm> {
  late final name = TextEditingController(text: widget.existing?.name ?? '');
  late final opening = TextEditingController(
    text: inputMoney(widget.existing?.opening ?? 0),
  );
  late final rate = TextEditingController(
    text: quantity(widget.existing?.rate ?? 1000000),
  );
  late String kind = widget.existing?.kind ?? widget.kind;
  late String currency = widget.existing?.currency ?? 'RUB';
  bool busy = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    opening.dispose();
    rate.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.store.saveAccount(
        Account(
          id: widget.existing?.id ?? newId(),
          name: name.text.trim(),
          kind: kind,
          currency: currency,
          opening: decimal(opening.text),
          rate: currency == 'RUB' ? 1000000 : decimal(rate.text, 6),
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted)
        setState(() {
          error = e.toString();
          busy = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) => FormShell(
    title: widget.existing == null ? 'Новый счёт' : 'Настройка счёта',
    busy: busy,
    error: error,
    save: save,
    children: [
      field(name, 'Название'),
      select('Тип', kind, [
        'Счета',
        'Сбережения',
        'Инвестиции',
        'Долги',
      ], (v) => setState(() => kind = v)),
      if (widget.existing == null)
        select('Валюта', currency, [
          'RUB',
          'USD',
          'EUR',
        ], (v) => setState(() => currency = v)),
      field(opening, 'Начальный остаток, $currency', numeric: true),
      if (kind == 'Долги') const Text('Укажите долг отрицательным числом.'),
      if (currency != 'RUB')
        field(rate, 'Курс в рублях за 1 $currency', numeric: true),
      const Text(
        'Курс задаётся вручную. Изменение начального остатка корректирует баланс счёта.',
        style: TextStyle(color: muted, fontSize: 12),
      ),
    ],
  );
}

class OperationForm extends StatefulWidget {
  const OperationForm({super.key, required this.store});
  final LocalStore store;
  @override
  State<OperationForm> createState() => _OperationFormState();
}

class _OperationFormState extends State<OperationForm> {
  int type = 0;
  late String account = widget.store.accounts.first.id;
  String? target;
  late String category = widget.store.categories.first;
  String digits = '0';
  DateTime date = DateTime.now();
  final note = TextEditingController();
  final received = TextEditingController();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    note.dispose();
    received.dispose();
    super.dispose();
  }

  void tap(String key) => setState(() {
    if (key == '⌫') {
      digits = digits.length > 1 ? digits.substring(0, digits.length - 1) : '0';
    } else if (key == ',') {
      if (!digits.contains(',')) digits += ',';
    } else if (digits.length < 13 &&
        (!digits.contains(',') || digits.split(',').last.length < 2)) {
      digits = digits == '0' ? key : digits + key;
    }
  });
  Future<void> save() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final value = decimal(
        digits.endsWith(',') ? digits.substring(0, digits.length - 1) : digits,
      );
      final a = widget.store.account(account);
      final b = target == null ? null : widget.store.account(target!);
      await widget.store.saveOperation(
        Operation(
          id: newId(),
          date: date.toIso8601String().substring(0, 10),
          type: ['expense', 'income', 'transfer'][type],
          account: account,
          amount: value,
          category: category,
          note: note.text.trim(),
          target: target ?? '',
          received: type == 2
              ? (a.currency == b?.currency ? value : decimal(received.text))
              : 0,
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted)
        setState(() {
          error = e.toString();
          busy = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final a = store.account(account);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        12,
        10,
        12,
        MediaQuery.viewInsetsOf(context).bottom + 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: line,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 10),
          Segments(
            labels: const ['Расход', 'Доход', 'Перевод', 'Сделка'],
            selected: type,
            change: (i) {
              if (i == 3) {
                Navigator.pop(context);
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (_) => TradeForm(store: store),
                );
              } else {
                setState(() => type = i);
              }
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => setState(
                  () => date = date.subtract(const Duration(days: 1)),
                ),
                icon: const Icon(Icons.chevron_left),
              ),
              TextButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => date = picked);
                },
                icon: const Icon(Icons.calendar_month_outlined, size: 18),
                label: Text(dateLabel(date.toIso8601String())),
              ),
              IconButton(
                onPressed: () =>
                    setState(() => date = date.add(const Duration(days: 1))),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: select(
                  'Счёт',
                  account,
                  store.accounts.map((a) => a.id).toList(),
                  (v) => setState(() {
                    account = v;
                    if (target == v) target = null;
                  }),
                  name: (id) => store.account(id).name,
                ),
              ),
              const SizedBox(width: 10),
              if (type != 2)
                Expanded(
                  child: select(
                    'Категория',
                    category,
                    store.categories,
                    (v) => setState(() => category = v),
                  ),
                ),
            ],
          ),
          if (type == 2) ...[
            const SizedBox(height: 10),
            if (store.accounts.length < 2)
              const Text('Для перевода добавьте второй счёт'),
            if (store.accounts.length >= 2)
              DropdownButtonFormField<String>(
                key: ValueKey(account),
                initialValue: target,
                decoration: const InputDecoration(labelText: 'На счёт'),
                items: [
                  for (final b in store.accounts.where((b) => b.id != account))
                    DropdownMenuItem(value: b.id, child: Text(b.name)),
                ],
                onChanged: (v) => setState(() => target = v),
              ),
            if (target != null && store.account(target!).currency != a.currency)
              field(
                received,
                'Сумма зачисления, ${store.account(target!).currency}',
                numeric: true,
              ),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              '$digits ${a.currency == 'RUB' ? '₽' : a.currency}',
              style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w800),
            ),
          ),
          TextField(
            controller: note,
            decoration: const InputDecoration(
              hintText: 'Комментарий',
              prefixIcon: Icon(Icons.chat_bubble_outline, size: 18),
            ),
          ),
          const SizedBox(height: 10),
          if (error != null) Text(error!, style: const TextStyle(color: red)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.25,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: [
                    for (final key in [
                      '7',
                      '8',
                      '9',
                      '4',
                      '5',
                      '6',
                      '1',
                      '2',
                      '3',
                      '0',
                      ',',
                      '⌫',
                    ])
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: ink,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(17),
                          ),
                        ),
                        onPressed: busy ? null : () => tap(key),
                        child: Text(
                          key,
                          style: const TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 62,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(62, 210),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ),
                  onPressed: busy ? null : save,
                  child: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : const Icon(Icons.check),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class TradeForm extends StatefulWidget {
  const TradeForm({
    super.key,
    required this.store,
    this.account,
    this.symbol,
    this.side = 'buy',
  });
  final LocalStore store;
  final String? account, symbol;
  final String side;
  @override
  State<TradeForm> createState() => _TradeFormState();
}

class _TradeFormState extends State<TradeForm> {
  late String? account =
      widget.account ??
      widget.store.accounts
          .where((a) => a.kind == 'Инвестиции')
          .firstOrNull
          ?.id;
  late String side = widget.side;
  String kind = 'Акции';
  late final symbol = TextEditingController(text: widget.symbol ?? '');
  final name = TextEditingController(),
      units = TextEditingController(text: '1'),
      price = TextEditingController(),
      fee = TextEditingController(text: '0'),
      tax = TextEditingController(text: '0');
  DateTime date = DateTime.now();
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    if (account != null && widget.symbol != null) {
      final p = widget.store
          .positions(account!)
          .where((p) => p.symbol == widget.symbol)
          .firstOrNull;
      if (p != null) {
        name.text = p.name;
        price.text = inputMoney(p.quote);
        kind = p.kind;
      }
    }
  }

  @override
  void dispose() {
    for (final c in [symbol, name, units, price, fee, tax]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (account == null ||
          symbol.text.trim().isEmpty ||
          name.text.trim().isEmpty)
        throw const FormatException('Заполните счёт, тикер и название');
      final t = Trade(
        id: newId(),
        date: date.toIso8601String().substring(0, 10),
        account: account!,
        symbol: symbol.text.trim().toUpperCase(),
        name: name.text.trim(),
        side: side,
        units: decimal(units.text, 6),
        price: decimal(price.text),
        fee: decimal(fee.text),
        tax: decimal(tax.text),
        kind: kind,
      );
      if (t.units <= 0 || t.price <= 0 || t.fee < 0 || t.tax < 0)
        throw const FormatException('Проверьте количество, цену и расходы');
      await widget.store.saveTrade(t);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted)
        setState(() {
          error = e.toString();
          busy = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (account == null)
      return const Padding(
        padding: EdgeInsets.all(30),
        child: Text('Сначала добавьте брокерский счёт во вкладке «Счета».'),
      );
    return FormShell(
      title: 'Записать сделку',
      busy: busy,
      error: error,
      save: save,
      children: [
        Segments(
          labels: const ['Покупка', 'Продажа'],
          selected: side == 'buy' ? 0 : 1,
          change: (i) => setState(() => side = i == 0 ? 'buy' : 'sell'),
        ),
        select(
          'Брокерский счёт',
          account!,
          widget.store.accounts
              .where((a) => a.kind == 'Инвестиции')
              .map((a) => a.id)
              .toList(),
          (v) => setState(() => account = v),
          name: (id) => widget.store.account(id).name,
        ),
        Row(
          children: [
            Expanded(child: field(symbol, 'Тикер')),
            const SizedBox(width: 10),
            Expanded(child: field(name, 'Название')),
          ],
        ),
        select('Тип актива', kind, [
          'Акции',
          'Облигации',
          'Фонды',
        ], (v) => setState(() => kind = v)),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Дата сделки'),
          trailing: Text(dateLabel(date.toIso8601String())),
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (d != null) setState(() => date = d);
          },
        ),
        Row(
          children: [
            Expanded(child: field(units, 'Количество', numeric: true)),
            const SizedBox(width: 10),
            Expanded(
              child: field(
                price,
                'Цена за шт., ${widget.store.account(account!).currency}',
                numeric: true,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(child: field(fee, 'Комиссия', numeric: true)),
            const SizedBox(width: 10),
            Expanded(child: field(tax, 'Налог', numeric: true)),
          ],
        ),
      ],
    );
  }
}

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key, required this.store, required this.account});
  final LocalStore store;
  final String account;
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  Future<void> add() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PayoutForm(store: widget.store, account: widget.account),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final rows =
        widget.store.payouts.where((p) => p.account == widget.account).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .8,
      child: Column(
        children: [
          ListTile(
            title: const Text(
              'Календарь выплат',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 21),
            ),
            trailing: IconButton(onPressed: add, icon: const Icon(Icons.add)),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Даты и суммы задаются вручную. Отметка «Получено» зачисляет выплату за вычетом налога на брокерский счёт.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (rows.isEmpty)
                  const EmptyState('Запланируйте купон или дивиденд'),
                for (final p in rows)
                  Panel(
                    child: CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: p.paid,
                      title: Text('${p.symbol} · ${p.type}'),
                      subtitle: Text(
                        '${dateLabel(p.date)} · ${money(p.amount - p.tax, widget.store.account(p.account).currency)} после налога\n${p.paid ? 'Получено' : 'Ожидается'}',
                      ),
                      onChanged: (_) async {
                        try {
                          await widget.store.togglePayout(p);
                          if (mounted) setState(() {});
                        } catch (e) {
                          if (context.mounted) message(context, e);
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PayoutForm extends StatefulWidget {
  const PayoutForm({super.key, required this.store, required this.account});
  final LocalStore store;
  final String account;
  @override
  State<PayoutForm> createState() => _PayoutFormState();
}

class _PayoutFormState extends State<PayoutForm> {
  String? symbol;
  String type = 'Купон';
  DateTime date = DateTime.now();
  final amount = TextEditingController(),
      tax = TextEditingController(text: '0');
  bool busy = false;
  String? error;
  @override
  void dispose() {
    amount.dispose();
    tax.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (symbol == null) throw const FormatException('Выберите инструмент');
      await widget.store.savePayout(
        Payout(
          id: newId(),
          account: widget.account,
          symbol: symbol!,
          date: date.toIso8601String().substring(0, 10),
          amount: decimal(amount.text),
          tax: decimal(tax.text),
          type: type,
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted)
        setState(() {
          error = e.toString();
          busy = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final positions = widget.store
        .positions(widget.account)
        .where((p) => p.units > 0)
        .toList();
    symbol ??= positions.firstOrNull?.symbol;
    return FormShell(
      title: 'Новая выплата',
      busy: busy,
      error: error,
      save: save,
      children: [
        if (symbol != null)
          select(
            'Инструмент',
            symbol!,
            positions.map((p) => p.symbol).toList(),
            (v) => setState(() => symbol = v),
          ),
        if (symbol == null) const Text('Сначала запишите покупку инструмента'),
        select('Выплата', type, [
          'Купон',
          'Дивиденд',
        ], (v) => setState(() => type = v)),
        ListTile(
          title: const Text('Дата'),
          trailing: Text(dateLabel(date.toIso8601String())),
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (d != null) setState(() => date = d);
          },
        ),
        field(amount, 'Общая сумма выплаты', numeric: true),
        field(tax, 'Удержанный налог', numeric: true),
      ],
    );
  }
}

class TradeHistory extends StatelessWidget {
  const TradeHistory({super.key, required this.store, required this.account});
  final LocalStore store;
  final String account;
  @override
  Widget build(BuildContext context) {
    final rows = store.trades.where((t) => t.account == account).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .8,
      child: Column(
        children: [
          const ListTile(
            title: Text(
              'История сделок',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final t in rows)
                  ListTile(
                    title: Text(
                      '${t.side == 'buy' ? 'Покупка' : 'Продажа'} · ${t.name}',
                    ),
                    subtitle: Text(
                      '${dateLabel(t.date)} · ${quantity(t.units)} шт.\nКомиссия ${money(t.fee)} · Налог ${money(t.tax)}',
                    ),
                    trailing: Text(
                      money(t.cash, store.account(account).currency),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AssetPage extends StatefulWidget {
  const AssetPage({
    super.key,
    required this.store,
    required this.account,
    required this.symbol,
  });
  final LocalStore store;
  final String account, symbol;
  @override
  State<AssetPage> createState() => _AssetPageState();
}

class _AssetPageState extends State<AssetPage> {
  LocalStore get store => widget.store;
  @override
  void initState() {
    super.initState();
    store.addListener(refresh);
  }

  @override
  void dispose() {
    store.removeListener(refresh);
    super.dispose();
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  Future<void> trade(String side) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => TradeForm(
      store: store,
      account: widget.account,
      symbol: widget.symbol,
      side: side,
    ),
  );
  @override
  Widget build(BuildContext context) {
    final p = store
        .positions(widget.account)
        .firstWhere((p) => p.symbol == widget.symbol);
    final currency = store.account(widget.account).currency;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              p.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            Text(p.kind, style: const TextStyle(fontSize: 12, color: muted)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  money(p.quote, currency),
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Текущая цена · задана вручную',
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: PriceChart(
                      values: [
                        ...store.trades
                            .where(
                              (t) =>
                                  t.account == widget.account &&
                                  t.symbol == p.symbol,
                            )
                            .map((t) => t.price),
                        p.quote,
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Цены ваших сделок и последняя оценка',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
                TextButton(
                  onPressed: () async {
                    final result = await textDialog(
                      context,
                      'Цена за штуку, $currency',
                      initial: inputMoney(p.quote),
                      numeric: true,
                    );
                    if (result != null) {
                      try {
                        await store.saveQuote(
                          widget.account,
                          p.symbol,
                          decimal(result),
                        );
                      } catch (e) {
                        if (context.mounted) message(context, e);
                      }
                    }
                  },
                  child: const Text('Обновить цену'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Panel(
            color: saldoGreen,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Metric(
                        'В портфеле',
                        '${quantity(p.units)} шт.',
                        light: true,
                      ),
                      const SizedBox(height: 16),
                      Metric(
                        'Средняя цена с расходами',
                        money(
                          p.units == 0 ? 0 : (p.cost * 1000000 ~/ p.units),
                          currency,
                        ),
                        light: true,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Metric(
                        'Стоимость',
                        money(p.value, currency),
                        light: true,
                      ),
                      const SizedBox(height: 16),
                      Metric(
                        'Результат с комиссиями',
                        money(p.profit, currency),
                        light: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Panel(
            child: Column(
              children: [
                SectionTitle(
                  'Затраты на открытую позицию',
                  money(p.cost, currency),
                ),
                const Divider(),
                SectionTitle(
                  'Реализованный результат',
                  money(p.realized, currency),
                ),
                TextButton.icon(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (_) =>
                        CalendarPage(store: store, account: widget.account),
                  ),
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: const Text('Календарь выплат'),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: p.units == 0 ? null : () => trade('sell'),
                  child: const Text('Записать продажу'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => trade('buy'),
                  child: const Text('Записать покупку'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PriceChart extends CustomPainter {
  PriceChart({required this.values});
  final List<int> values;
  @override
  void paint(Canvas canvas, Size size) {
    final minValue = values.reduce((a, b) => a < b ? a : b),
        maxValue = values.reduce((a, b) => a > b ? a : b);
    final span = maxValue - minValue;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1 ? 0.0 : size.width * i / (values.length - 1);
      final y = span == 0
          ? size.height / 2
          : size.height * .9 - (values[i] - minValue) * size.height * .8 / span;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fill, Paint()..color = tint.withValues(alpha: .5));
    canvas.drawPath(
      path,
      Paint()
        ..color = saldoGreen
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(PriceChart oldDelegate) => true;
}
