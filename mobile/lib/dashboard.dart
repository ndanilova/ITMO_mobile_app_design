import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'design.dart';
import 'figma_icons.dart';
import 'forms.dart';
import 'import_screen.dart';
import 'local_store.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key, required this.store});
  final LocalStore store;
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  LocalStore get store => widget.store;
  int tab = 2, accountFilter = 0, categoryFilter = 0, statsFilter = 0;
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  String? broker;
  bool hidden = false;
  String search = '';

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

  Future<void> showForm(Widget form) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: saldoBackground,
    builder: (_) => form,
  );
  Future<void> operation() async {
    final date = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: saldoBackground,
      builder: (_) => OperationForm(store: store),
    );
    if (date != null && mounted)
      setState(() => month = DateTime(date.year, date.month));
  }

  void importReport() => Navigator.push<void>(
    context,
    MaterialPageRoute(builder: (_) => ImportScreen(store: store)),
  );
  Account? get selectedBroker {
    final accounts = store.accounts.where((a) => a.kind == 'Инвестиции');
    return accounts.where((a) => a.id == broker).firstOrNull ??
        accounts.firstOrNull;
  }

  Future<void> demo() async {
    try {
      await store.seed();
    } catch (e) {
      if (mounted) message(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: store.accounts.isEmpty
          ? onboarding()
          : ListView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, tab == 2 ? 90 : 20),
              children: switch (tab) {
                0 => accounts(),
                1 => categoryPage(),
                2 => operations(),
                3 => portfolio(),
                _ => statistics(),
              },
            ),
    ),
    floatingActionButton: tab == 2 && store.accounts.isNotEmpty
        ? FloatingActionButton.extended(
            onPressed: operation,
            backgroundColor: saldoGreen,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('Добавить'),
          )
        : null,
    bottomNavigationBar: Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: line)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: List.generate(
            tabs.length,
            (i) => Expanded(
              child: InkWell(
                onTap: () => setState(() => tab = i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: tab == i ? tint : null,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: FigmaIcon(
                          tabIcons[i],
                          size: 22,
                          color: tab == i ? saldoGreen : muted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tabs[i],
                        style: TextStyle(
                          fontSize: 11,
                          color: tab == i ? saldoGreen : muted,
                          fontWeight: tab == i
                              ? FontWeight.bold
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  Widget onboarding() => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.account_balance_wallet_outlined,
          size: 60,
          color: saldoGreen,
        ),
        const SizedBox(height: 20),
        const Text(
          'Сальдо',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Text(
          'Доходы, расходы и инвестиции на вашем устройстве.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: () => showForm(AccountForm(store: store)),
          child: const Text('Добавить первый счёт'),
        ),
        TextButton(onPressed: demo, child: const Text('Посмотреть на примере')),
      ],
    ),
  );
  Widget balance({IconData? action, VoidCallback? onPressed}) => SizedBox(
    height: 75,
    child: Stack(
      alignment: Alignment.topRight,
      children: [
        Center(
          child: Column(
            children: [
              InkWell(
                onTap: () => setState(() => hidden = !hidden),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Text(
                    'Общий баланс',
                    style: TextStyle(fontSize: 14, color: muted),
                  ),
                ),
              ),
              Text(
                hidden ? '••••••' : money(store.capital),
                style: const TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        if (action != null) CircleAction(icon: action, onPressed: onPressed!),
      ],
    ),
  );
  Widget period() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      IconButton(
        onPressed: () =>
            setState(() => month = DateTime(month.year, month.month - 1)),
        icon: const Icon(Icons.chevron_left),
      ),
      TextButton(
        onPressed: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: month,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (date != null)
            setState(() => month = DateTime(date.year, date.month));
        },
        child: Text(
          monthLabel(month),
          style: const TextStyle(
            color: ink,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      IconButton(
        onPressed: () =>
            setState(() => month = DateTime(month.year, month.month + 1)),
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );
  int accountValue(Account a) =>
      store.balance(a.id) +
      (a.kind == 'Инвестиции'
          ? store.positions(a.id).fold(0, (sum, p) => sum + p.value)
          : 0);

  Entry accountEntry(Account a) {
    final value = accountValue(a);
    final icon = a.kind == 'Инвестиции'
        ? Icons.trending_up
        : a.currency != 'RUB'
        ? Icons.attach_money
        : a.kind == 'Сбережения'
        ? (a.name.contains('Вклад') ? Icons.lock_outline : Icons.percent)
        : a.name.toLowerCase().contains('карт')
        ? Icons.credit_card
        : Icons.account_balance_wallet_outlined;
    return (
      title: a.name,
      note: a.kind == 'Инвестиции'
          ? 'Деньги: ${money(store.balance(a.id), a.currency)}'
          : a.currency == 'RUB'
          ? a.kind
          : '≈ ${money(store.rub(value, a.id))}',
      amount: money(value, a.currency),
      icon: icon,
      color: a.kind == 'Инвестиции'
          ? saldoGreen
          : a.currency != 'RUB'
          ? const Color(0xff6941c6)
          : a.kind == 'Сбережения'
          ? const Color(0xffa84d07)
          : icon == Icons.credit_card
          ? const Color(0xff3155c7)
          : teal,
    );
  }

  List<Widget> accounts() => [
    balance(
      action: Icons.add,
      onPressed: () => showForm(AccountForm(store: store)),
    ),
    Segments(
      labels: const ['Счета', 'Долги', 'Всего'],
      selected: accountFilter,
      change: (i) => setState(() => accountFilter = i),
    ),
    const SizedBox(height: 8),
    for (final kind in ['Счета', 'Сбережения', 'Инвестиции', 'Долги'])
      if ((accountFilter == 2 ||
              (accountFilter == 1 ? kind == 'Долги' : kind != 'Долги')) &&
          store.accounts.any((a) => a.kind == kind)) ...[
        SectionTitle(
          kind,
          money(
            store.accounts
                .where((a) => a.kind == kind)
                .fold(0, (sum, a) => sum + store.rub(accountValue(a), a.id)),
          ),
        ),
        for (final a in store.accounts.where((a) => a.kind == kind))
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: EntryTile(
              accountEntry(a),
              onTap: () => showForm(AccountForm(store: store, existing: a)),
            ),
          ),
      ],
    if (accountFilter == 1 && !store.accounts.any((a) => a.kind == 'Долги'))
      const EmptyState('Долгов пока нет'),
  ];

  Entry operationEntry(Operation o) {
    final a = store.account(o.account);
    final style = categoryStyle(o.category);
    return (
      title: o.type == 'transfer' ? 'Перевод' : o.category,
      note:
          '${o.note.isEmpty ? '' : '${o.note} · '}${a.name}${o.type == 'transfer' ? ' → ${store.account(o.target).name}' : ''}',
      amount:
          '${o.type == 'expense'
              ? '−'
              : o.type == 'income'
              ? '+'
              : ''}${money(o.amount, a.currency)}',
      icon: o.type == 'transfer' ? Icons.swap_horiz : style.icon,
      color: style.color,
    );
  }

  List<Widget> operations() {
    final items = store
        .monthOperations(month)
        .where(
          (o) => '${o.category} ${o.note} ${store.account(o.account).name}'
              .toLowerCase()
              .contains(search.toLowerCase()),
        )
        .toList();
    final dates = items.map((o) => o.date).toSet();
    final start = store.accounts.fold(
      0,
      (sum, a) => sum + store.rub(store.balance(a.id, month), a.id),
    );
    final end = store.accounts.fold(
      0,
      (sum, a) =>
          sum +
          store.rub(
            store.balance(a.id, DateTime(month.year, month.month + 1)),
            a.id,
          ),
    );
    return [
      balance(
        action: Icons.search,
        onPressed: () async {
          final query = await textDialog(
            context,
            'Поиск операций',
            initial: search,
          );
          if (query != null) setState(() => search = query);
        },
      ),
      period(),
      Panel(
        child: Row(
          children: [
            Expanded(child: Metric('Начальный баланс', money(start))),
            Expanded(child: Metric('Конечный баланс', money(end))),
          ],
        ),
      ),
      if (search.isNotEmpty)
        TextButton(
          onPressed: () => setState(() => search = ''),
          child: Text('Сбросить поиск «$search»'),
        ),
      const SizedBox(height: 18),
      if (items.isEmpty) const EmptyState('Операций за этот период нет'),
      for (final date in dates) ...[
        Row(
          children: [
            Text(
              '${DateTime.parse(date).day}',
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                dateLabel(date),
                style: const TextStyle(color: muted, fontSize: 12),
              ),
            ),
            Text(
              money(
                items
                    .where((o) => o.date == date && o.type != 'transfer')
                    .fold(
                      0,
                      (s, o) =>
                          s +
                          (o.type == 'income' ? 1 : -1) *
                              store.rub(o.amount, o.account),
                    ),
              ),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const Divider(),
        for (final o in items.where((o) => o.date == date))
          EntryTile(
            operationEntry(o),
            onTap: () async {
              final remove = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(o.category),
                  content: Text(
                    '${dateLabel(o.date)}\n${o.note}\n${money(o.amount, store.account(o.account).currency)}',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Закрыть'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Удалить'),
                    ),
                  ],
                ),
              );
              if (remove == true) {
                try {
                  await store.deleteOperation(o.id);
                } catch (e) {
                  if (mounted) message(context, e);
                }
              }
            },
          ),
        const SizedBox(height: 12),
      ],
    ];
  }

  List<Widget> categoryPage() {
    final type = categoryFilter == 0 ? 'expense' : 'income';
    final names = categoryFilter == 0
        ? store.categories
        : store
              .monthOperations(month)
              .where((o) => o.type == 'income')
              .map((o) => o.category)
              .toSet()
              .toList();
    return [
      balance(
        action: Icons.edit_outlined,
        onPressed: () async {
          final name = await textDialog(context, 'Новая категория');
          if (name != null) {
            try {
              await store.addCategory(name);
            } catch (e) {
              if (mounted) message(context, e);
            }
          }
        },
      ),
      period(),
      Segments(
        labels: [
          'Расходы\n${money(store.total(month, 'expense'))}',
          'Доходы\n${money(store.total(month, 'income'))}',
        ],
        selected: categoryFilter,
        change: (i) => setState(() => categoryFilter = i),
      ),
      const SizedBox(height: 24),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: names.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisExtent: 104,
          mainAxisSpacing: 8,
          crossAxisSpacing: 10,
        ),
        itemBuilder: (_, i) {
          final name = names[i], style = categoryStyle(name);
          final amount = store.total(month, type, name),
              limit = store.budgets[name] ?? 0;
          return InkWell(
            onTap: () async {
              final result = await textDialog(
                context,
                'Лимит в месяц, ₽',
                initial: inputMoney(limit),
                numeric: true,
              );
              if (result != null) {
                try {
                  await store.saveBudget(name, decimal(result));
                } catch (e) {
                  if (mounted) message(context, e);
                }
              }
            },
            child: Panel(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      EntryIcon(style, size: 38),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            FittedBox(
                              child: Text(
                                money(amount),
                                style: TextStyle(
                                  color: type == 'expense' ? red : teal,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (limit > 0)
                    Text(
                      'из ${money(limit)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: amount > limit ? red : muted,
                      ),
                    ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: limit > 0 ? (amount / limit).clamp(0, 1) : 0,
                    color: amount > limit && limit > 0 ? red : style.color,
                    backgroundColor: line,
                    minHeight: 4,
                  ),
                ],
              ),
            ),
          );
        },
      ),
      TextButton(
        onPressed: () async {
          final name = await textDialog(context, 'Новая категория');
          if (name != null) {
            try {
              await store.addCategory(name);
            } catch (e) {
              if (mounted) message(context, e);
            }
          }
        },
        child: const Text('+ Категория'),
      ),
    ];
  }

  List<Widget> portfolio() {
    final a = selectedBroker;
    if (a == null)
      return [
        const EmptyState('Добавьте брокерский счёт для инвестиций'),
        FilledButton(
          onPressed: () =>
              showForm(AccountForm(store: store, kind: 'Инвестиции')),
          child: const Text('Добавить брокерский счёт'),
        ),
      ];
    final positions = store.positions(a.id);
    final value = positions.fold(0, (s, p) => s + p.value);
    final cost = positions.fold(0, (s, p) => s + p.cost);
    final gain = positions.fold(0, (s, p) => s + p.profit);
    final payouts = store.payouts
        .where((p) => p.account == a.id && p.paid)
        .fold(0, (s, p) => s + p.amount - p.tax);
    final totalGain = gain + payouts;
    final invested = store.trades
        .where((t) => t.account == a.id && t.side == 'buy')
        .fold(0, (sum, t) => sum + t.gross + t.fee + t.tax);
    return [
      Row(
        children: [
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: a.id,
                isExpanded: true,
                items: [
                  for (final b in store.accounts.where(
                    (a) => a.kind == 'Инвестиции',
                  ))
                    DropdownMenuItem(value: b.id, child: Text(b.name)),
                ],
                onChanged: (id) => setState(() => broker = id),
              ),
            ),
          ),
          const SizedBox(width: 10),
          CircleAction(
            icon: Icons.add,
            onPressed: () => showForm(TradeForm(store: store, account: a.id)),
          ),
          CircleAction(
            icon: Icons.file_upload_outlined,
            onPressed: importReport,
          ),
        ],
      ),
      const SizedBox(height: 12),
      Panel(
        color: saldoGreen,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Стоимость портфеля', style: TextStyle(color: tint)),
            Text(
              money(value, a.currency),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            Text(
              '${totalGain >= 0 ? '+' : ''}${money(totalGain, a.currency)} (${invested == 0 ? '0' : (totalGain * 100 / invested).toStringAsFixed(2)}%) · за всё время',
              style: const TextStyle(color: tint, fontSize: 13),
            ),
            const Divider(height: 28, color: Colors.white24),
            Row(
              children: [
                Expanded(
                  child: Metric(
                    'Вложено',
                    money(cost, a.currency),
                    light: true,
                  ),
                ),
                Expanded(
                  child: Metric(
                    'Выплачено',
                    money(payouts, a.currency),
                    light: true,
                  ),
                ),
                Expanded(
                  child: Metric(
                    'Деньги',
                    money(store.balance(a.id), a.currency),
                    light: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Структура',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Allocation(positions: positions),
          ],
        ),
      ),
      const SizedBox(height: 20),
      if (positions.every((p) => p.units == 0))
        const EmptyState('Добавьте сделку или импортируйте CSV'),
      Panel(
        child: Column(
          children: [
            for (final p in positions.where((p) => p.units > 0))
              PositionTile(
                position: p,
                currency: a.currency,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => AssetPage(
                      store: store,
                      account: a.id,
                      symbol: p.symbol,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      TextButton.icon(
        onPressed: () => showForm(CalendarPage(store: store, account: a.id)),
        icon: const Icon(Icons.calendar_month_outlined),
        label: const Text('Календарь выплат'),
      ),
      TextButton.icon(
        onPressed: () => showForm(TradeHistory(store: store, account: a.id)),
        icon: const Icon(Icons.receipt_long_outlined),
        label: const Text('История сделок'),
      ),
    ];
  }

  List<Widget> statistics() {
    final type = statsFilter == 0 ? 'expense' : 'income';
    final total = store.total(month, type);
    final names = store
        .monthOperations(month)
        .where((o) => o.type == type)
        .map((o) => o.category)
        .toSet();
    final values = [
      for (final name in names)
        (
          name: name,
          value: store.total(month, type, name),
          color: categoryStyle(name).color,
        ),
    ]..sort((a, b) => b.value.compareTo(a.value));
    return [
      period(),
      Segments(
        labels: const ['Расходы', 'Доходы'],
        selected: statsFilter,
        change: (i) => setState(() => statsFilter = i),
      ),
      const SizedBox(height: 14),
      Panel(
        child: Column(
          children: [
            const SizedBox(height: 12),
            SizedBox(
              width: 180,
              height: 180,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    painter: DonutPainter(
                      values: values
                          .map((e) => (value: e.value, color: e.color))
                          .toList(),
                    ),
                  ),
                  Center(
                    child: Metric(
                      statsFilter == 0 ? 'Расходы' : 'Доходы',
                      money(total),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (values.isEmpty) const EmptyState('Нет операций за этот период'),
            for (final item in values) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.square_rounded, size: 14, color: item.color),
                    const SizedBox(width: 8),
                    Expanded(child: Text(item.name)),
                    Text(
                      '${(item.value * 100 / total).round()}%',
                      style: const TextStyle(color: muted),
                    ),
                    const SizedBox(width: 20),
                    Text(
                      money(item.value),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: Panel(
              child: Metric(
                'Отложено',
                money(
                  store.total(month, 'income') - store.total(month, 'expense'),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Panel(
              child: Metric(
                'В среднем в день',
                money(total ~/ DateTime(month.year, month.month + 1, 0).day),
              ),
            ),
          ),
        ],
      ),
    ];
  }
}

String monthLabel(DateTime month) {
  const names = [
    'Январь',
    'Февраль',
    'Март',
    'Апрель',
    'Май',
    'Июнь',
    'Июль',
    'Август',
    'Сентябрь',
    'Октябрь',
    'Ноябрь',
    'Декабрь',
  ];
  return '${names[month.month - 1]} ${month.year}';
}

Entry categoryStyle(String name) =>
    categories.where((e) => e.title == name).firstOrNull ??
    (title: name, note: '', amount: '', icon: Icons.label_outline, color: teal);
void message(BuildContext context, Object error) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error
              .toString()
              .replaceFirst('FormatException: ', '')
              .replaceFirst('Bad state: ', ''),
        ),
      ),
    );
Future<String?> textDialog(
  BuildContext context,
  String title, {
  String initial = '',
  bool numeric = false,
}) async {
  final controller = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: numeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: const Text('Сохранить'),
        ),
      ],
    ),
  );
  // Dispose after the dialog's closing animation completes.
  Future<void>.delayed(const Duration(seconds: 1), controller.dispose);
  return result;
}

class EmptyState extends StatelessWidget {
  const EmptyState(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(28),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(color: muted),
    ),
  );
}

const assetColors = [
  saldoGreen,
  Color(0xffbd680e),
  Color(0xff5c7ccc),
  Color(0xffb6b9ae),
];

class Allocation extends StatelessWidget {
  const Allocation({super.key, required this.positions});
  final List<Position> positions;
  @override
  Widget build(BuildContext context) {
    const kinds = ['Акции', 'Облигации', 'Фонды'];
    final values = [
      for (final kind in kinds)
        positions.where((p) => p.kind == kind).fold(0, (s, p) => s + p.value),
    ];
    final total = values.fold(0, (a, b) => a + b);
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 12,
            child: Row(
              children: [
                if (total == 0) Expanded(child: Container(color: line)),
                for (var i = 0; i < 3; i++)
                  if (values[i] > 0)
                    Expanded(
                      flex: values[i],
                      child: Container(color: assetColors[i]),
                    ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 18,
          runSpacing: 6,
          children: [
            for (var i = 0; i < 3; i++)
              Text(
                '${kinds[i]}  ${total == 0 ? 0 : (values[i] * 100 / total).round()}%',
                style: TextStyle(color: assetColors[i], fontSize: 12),
              ),
          ],
        ),
      ],
    );
  }
}

class DonutPainter extends CustomPainter {
  DonutPainter({required this.values});
  final List<({int value, Color color})> values;
  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold(0, (s, e) => s + e.value);
    final rect = (Offset.zero & size).deflate(13);
    if (total == 0) {
      canvas.drawOval(
        rect,
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 24,
      );
      return;
    }
    var start = -math.pi / 2;
    for (final item in values) {
      final sweep = 2 * math.pi * item.value / total;
      canvas.drawArc(
        rect,
        start,
        math.max(0, sweep - .018),
        false,
        Paint()
          ..color = item.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 24,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(DonutPainter oldDelegate) => true;
}

class PositionTile extends StatelessWidget {
  const PositionTile({
    super.key,
    required this.position,
    required this.currency,
    required this.onTap,
  });
  final Position position;
  final String currency;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = position;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: tint,
              child: Text(
                p.symbol.substring(0, math.min(4, p.symbol.length)),
                style: const TextStyle(
                  fontSize: 10,
                  color: saldoGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${quantity(p.units)} шт. × ${money(p.quote, currency)}',
                    style: const TextStyle(fontSize: 12, color: muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  money(p.value, currency),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  '${p.profit >= 0 ? '+' : ''}${money(p.profit, currency)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: p.profit >= 0 ? teal : red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
