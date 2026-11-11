import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'saldo_api.dart';

const saldoGreen = Color(0xff1f5f4a);
const saldoBackground = Color(0xfff4f5f1);
const muted = Color(0xff5d6359);
const line = Color(0xffe3e5de);
const tint = Color(0xffdcebe3);
const red = Color(0xffb42318);
const teal = Color(0xff13795b);
const ink = Color(0xff15181c);

const tabs = ['Счета', 'Категории', 'Операции', 'Портфель', 'Статистика'];
const tabIcons = [
  Icons.account_balance_wallet_outlined,
  Icons.category_outlined,
  Icons.receipt_long_outlined,
  Icons.trending_up,
  Icons.bar_chart_outlined,
];

typedef Entry = ({
  String title,
  String note,
  String amount,
  IconData icon,
  Color color,
});

const categories = <Entry>[
  (
    title: 'Продукты',
    note: '',
    amount: '12 480',
    icon: Icons.kitchen_outlined,
    color: Color(0xff6941c6),
  ),
  (
    title: 'Кафе',
    note: '',
    amount: '3 150',
    icon: Icons.restaurant,
    color: Color(0xffae2878),
  ),
  (
    title: 'Развлечения',
    note: '',
    amount: '1 990',
    icon: Icons.movie_outlined,
    color: Color(0xff3155c7),
  ),
  (
    title: 'Транспорт',
    note: '',
    amount: '2 340',
    icon: Icons.directions_bus_outlined,
    color: Color(0xff106e86),
  ),
  (
    title: 'Здоровье',
    note: '',
    amount: '0',
    icon: Icons.favorite_border,
    color: teal,
  ),
  (
    title: 'Подписки',
    note: '',
    amount: '899',
    icon: Icons.repeat,
    color: Color(0xff507027),
  ),
  (
    title: 'Подарки',
    note: '',
    amount: '0',
    icon: Icons.card_giftcard,
    color: red,
  ),
  (
    title: 'Покупки',
    note: '',
    amount: '6 200',
    icon: Icons.checkroom,
    color: Color(0xffa84d07),
  ),
  (
    title: 'Жильё',
    note: '',
    amount: '28 000',
    icon: Icons.home_outlined,
    color: Color(0xff106e86),
  ),
  (
    title: 'Прочее',
    note: '',
    amount: '0',
    icon: Icons.help_outline,
    color: muted,
  ),
];

class Dashboard extends StatefulWidget {
  const Dashboard({super.key, required this.importScreen});
  final Widget importScreen;

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int tab = 2;
  int accountsFilter = 0;
  int categoryFilter = 0;
  int statsFilter = 0;
  bool showBalance = true;
  DateTime month = DateTime(2026, 10);
  final operations = <Entry>[];

  final api = SaldoApi();
  String? operationsError;

  @override
  void initState() {
    super.initState();
    loadOperations();
  }

  @override
  void dispose() {
    api.close();
    super.dispose();
  }

  Future<void> loadOperations() async {
    try {
      final response = await api.requestJson('GET', '/operations');
      final items = (response['operations'] as List<dynamic>).map((item) {
        final title = item['title'] as String;
        final style = categories.firstWhere(
          (entry) => entry.title == title,
          orElse: () => categories.last,
        );
        return (
          title: title,
          note: item['note'] as String,
          amount: item['amount'] as String,
          icon: style.icon,
          color: style.color,
        );
      }).toList();
      if (!mounted) return;
      setState(() {
        operationsError = null;
        operations.clear();
        operations.addAll(items);
      });
    } catch (_) {
      if (mounted)
        setState(() => operationsError = 'Не удалось загрузить операции');
    }
  }

  Future<void> persistOperation(Entry entry) async {
    await api.requestJson(
      'POST',
      '/operations',
      utf8.encode(
        jsonEncode({
          'title': entry.title,
          'note': entry.note,
          'amount': entry.amount,
        }),
      ),
      ContentType.json,
    );
  }

  String get period {
    const months = [
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
    return '${months[month.month - 1]} ${month.year}';
  }

  void openImport() => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => widget.importScreen));

  Future<void> addOperation() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: saldoBackground,
      builder: (_) => OperationSheet(persist: persistOperation),
    );
    if (saved == true && mounted) {
      setState(() => tab = 2);
      await loadOperations();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          key: PageStorageKey(tab),
          padding: EdgeInsets.fromLTRB(16, 12, 16, tab == 2 ? 80 : 12),
          children: switch (tab) {
            0 => accounts(),
            1 => categoryPage(),
            2 => operationPage(),
            3 => portfolio(),
            _ => statistics(),
          },
        ),
      ),
      floatingActionButton: tab == 2
          ? FloatingActionButton.extended(
              backgroundColor: saldoGreen,
              foregroundColor: Colors.white,
              onPressed: addOperation,
              icon: const Icon(Icons.add),
              label: const Text('Добавить'),
            )
          : null,
      bottomNavigationBar: ColoredBox(
        color: Colors.white,
        child: SafeArea(
          top: false,
          child: Row(
            children: List.generate(tabs.length, (index) {
              final selected = index == tab;
              return Expanded(
                child: InkWell(
                  onTap: () => setState(() => tab = index),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 56,
                          height: 30,
                          decoration: BoxDecoration(
                            color: selected ? tint : null,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Icon(
                            tabIcons[index],
                            size: 20,
                            color: selected ? saldoGreen : muted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tabs[index],
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 11,
                            color: selected ? saldoGreen : muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget balance({
    IconData? action,
    VoidCallback? onPressed,
    bool canHide = false,
  }) => Stack(
    alignment: Alignment.topRight,
    children: [
      Center(
        child: Column(
          children: [
            GestureDetector(
              onTap: canHide
                  ? () => setState(() => showBalance = !showBalance)
                  : null,
              child: Text(
                canHide
                    ? 'Общий баланс  ${showBalance ? "◉" : "○"}'
                    : 'Общий баланс',
                style: const TextStyle(color: muted),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              showBalance ? '646 720,15 ₽' : '••••••',
              style: const TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
          ],
        ),
      ),
      if (action != null) CircleAction(icon: action, onPressed: onPressed!),
    ],
  );

  Widget monthBar() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      IconButton(
        onPressed: () =>
            setState(() => month = DateTime(month.year, month.month - 1)),
        icon: const Icon(Icons.chevron_left),
      ),
      Text(
        period,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      IconButton(
        onPressed: () =>
            setState(() => month = DateTime(month.year, month.month + 1)),
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );

  List<Widget> operationPage() => [
    balance(
      action: Icons.search,
      onPressed: () => showSearch<void>(
        context: context,
        delegate: OperationSearch([...operations, ...demoOperations]),
      ),
    ),
    monthBar(),
    const Panel(
      child: Row(
        children: [
          Expanded(child: Metric('Начальный баланс', '612 340,25 ₽')),
          Expanded(child: Metric('Конечный баланс', '646 720,15 ₽')),
        ],
      ),
    ),
    const SizedBox(height: 22),
    if (operationsError != null)
      TextButton(
        onPressed: loadOperations,
        child: Text('$operationsError · Повторить'),
      ),
    if (operations.isNotEmpty) ...[
      const SectionTitle('Добавленные операции', ''),
      for (final entry in operations) EntryTile(entry),
    ],
    if (month.year == 2026 && month.month == 10) ...[
      const DayTitle('31', 'суббота', '−2 820,60 ₽', red),
      for (final entry in demoOperations.take(2)) EntryTile(entry),
      const DayTitle('30', 'пятница', '+47 500 ₽', teal),
      for (final entry in demoOperations.skip(2)) EntryTile(entry),
      const DayTitle('29', 'четверг', '', muted),
    ] else
      const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('За этот месяц операций нет'),
        ),
      ),
  ];

  List<Widget> accounts() => [
    balance(canHide: true),
    const SizedBox(height: 16),
    Segments(
      labels: const ['Счета', 'Долги', 'Всего'],
      selected: accountsFilter,
      change: (i) => setState(() => accountsFilter = i),
    ),
    if (accountsFilter == 1)
      const Padding(padding: EdgeInsets.all(20), child: Text('Долгов пока нет'))
    else ...[
      const SectionTitle('Счета', '87 970,15 ₽'),
      for (final entry in demoAccounts.take(3)) Panel(child: EntryTile(entry)),
      const SectionTitle('Сбережения', '320 000 ₽'),
      for (final entry in demoAccounts.skip(3).take(2))
        Panel(child: EntryTile(entry)),
      const SectionTitle('Инвестиции', '238 750 ₽'),
      Panel(
        child: EntryTile(
          demoAccounts.last,
          onTap: () => setState(() => tab = 3),
        ),
      ),
    ],
  ];

  List<Widget> categoryPage() {
    final entries = categoryFilter == 0
        ? categories
        : demoOperations.where((item) => item.title == 'Зарплата').toList();
    return [
      balance(),
      monthBar(),
      Segments(
        labels: const ['Расходы\n55 059 ₽', 'Доходы\n100 755,50 ₽'],
        selected: categoryFilter,
        change: (i) => setState(() => categoryFilter = i),
      ),
      const SizedBox(height: 24),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: entries.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisExtent: 84,
          mainAxisSpacing: 8,
          crossAxisSpacing: 10,
        ),
        itemBuilder: (_, i) {
          final entry = entries[i];
          return Panel(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Row(
                  children: [
                    EntryIcon(entry, size: 38),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            categoryFilter == 0
                                ? '${entry.amount} ₽'
                                : entry.amount,
                            style: TextStyle(
                              color: categoryFilter == 0 ? red : teal,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                LinearProgressIndicator(
                  value: entry.amount == '0'
                      ? 0
                      : i == 8
                      ? 1
                      : .25,
                  color: entry.color,
                  backgroundColor: line,
                ),
              ],
            ),
          );
        },
      ),
    ];
  }

  List<Widget> portfolio() => [
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Chip(label: Text('Брокерский счёт')),
        CircleAction(icon: Icons.add, onPressed: openImport),
      ],
    ),
    const SizedBox(height: 8),
    const Panel(
      color: saldoGreen,
      padding: EdgeInsets.all(19),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Стоимость портфеля', style: TextStyle(color: tint)),
          Text(
            '186 450 ₽',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '+6 897 ₽ (+4,4%) · за всё время',
            style: TextStyle(color: tint),
          ),
          Divider(height: 28, color: Colors.white24),
          Row(
            children: [
              Expanded(child: Metric('Вложено', '179 553 ₽', light: true)),
              Expanded(
                child: Metric('Выплаты за год', '+8 412 ₽', light: true),
              ),
              Expanded(child: Metric('Сегодня', '+0,3%', light: true)),
            ],
          ),
        ],
      ),
    ),
    const SizedBox(height: 16),
    const Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Структура', style: TextStyle(fontWeight: FontWeight.w700)),
          SizedBox(height: 10),
          AllocationBar(),
          SizedBox(height: 10),
          Text('Акции  38%     Облигации  27%\nФонды  23%     Рубли  13%'),
        ],
      ),
    ),
    const SizedBox(height: 20),
    Panel(
      child: Column(
        children: [
          const SectionTitle('Демонстрационные позиции', ''),
          for (final entry in holdings)
            EntryTile(
              entry,
              onTap: entry.title.startsWith('ОФЗ')
                  ? () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AssetPage(addOperation: addOperation),
                      ),
                    )
                  : null,
            ),
        ],
      ),
    ),
    TextButton.icon(
      onPressed: openImport,
      icon: const Icon(Icons.upload_file),
      label: const Text('Импорт и подтверждённые сделки'),
    ),
  ];

  List<Widget> statistics() => [
    monthBar(),
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
            width: 176,
            height: 176,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(painter: DonutPainter(income: statsFilter == 1)),
                Center(
                  child: Metric(
                    statsFilter == 0 ? 'Расходы' : 'Доходы',
                    statsFilter == 0 ? '55 059 ₽' : '100 755,50 ₽',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          for (final entry
              in (statsFilter == 0
                  ? [8, 0, 7, 1, 3, 2, 5].map((i) => categories[i])
                  : [demoOperations[2]]))
            Column(
              children: [
                const Divider(height: 1, color: line),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.square_rounded, color: entry.color, size: 14),
                      const SizedBox(width: 8),
                      Expanded(child: Text(entry.title)),
                      Text(
                        statsFilter == 0 ? '${entry.amount} ₽' : entry.amount,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    ),
    const SizedBox(height: 14),
    const Row(
      children: [
        Expanded(child: Panel(child: Metric('Отложено', '45 697 ₽'))),
        SizedBox(width: 10),
        Expanded(child: Panel(child: Metric('В среднем в день', '873 ₽'))),
      ],
    ),
  ];
}

const demoOperations = <Entry>[
  (
    title: 'Продукты',
    note: '«Перекрёсток» · Т-Банк карта',
    amount: '−2 140,60 ₽',
    icon: Icons.kitchen_outlined,
    color: Color(0xff6941c6),
  ),
  (
    title: 'Кафе',
    note: 'Кофейня · Наличные',
    amount: '−680 ₽',
    icon: Icons.restaurant,
    color: Color(0xffae2878),
  ),
  (
    title: 'Зарплата',
    note: 'Вторая часть · Т-Банк карта',
    amount: '+47 500 ₽',
    icon: Icons.work_outline,
    color: teal,
  ),
  (
    title: 'Перевод',
    note: 'Т-Банк карта → Накопительный счёт',
    amount: '20 000 ₽',
    icon: Icons.swap_horiz,
    color: muted,
  ),
  (
    title: 'Пополнение брокерского',
    note: 'Т-Банк карта → Брокерский счёт',
    amount: '15 000 ₽',
    icon: Icons.swap_horiz,
    color: muted,
  ),
];
const demoAccounts = <Entry>[
  (
    title: 'Т-Банк карта',
    note: 'Основной счёт',
    amount: '48 320,15 ₽',
    icon: Icons.credit_card,
    color: Color(0xff3155c7),
  ),
  (
    title: 'Наличные',
    note: 'Кошелёк',
    amount: '3 200 ₽',
    icon: Icons.account_balance_wallet_outlined,
    color: teal,
  ),
  (
    title: 'Доллары',
    note: '≈ 36 450 ₽',
    amount: r'450 $',
    icon: Icons.attach_money,
    color: Color(0xff6941c6),
  ),
  (
    title: 'Накопительный счёт',
    note: '16% годовых',
    amount: '120 000 ₽',
    icon: Icons.percent,
    color: Color(0xffa84d07),
  ),
  (
    title: 'Вклад на 6 месяцев',
    note: '18% · до 14.03.2027',
    amount: '200 000 ₽',
    icon: Icons.lock_outline,
    color: Color(0xff106e86),
  ),
  (
    title: 'Брокерский счёт',
    note: '+4,4% за всё время',
    amount: '186 450 ₽',
    icon: Icons.trending_up,
    color: saldoGreen,
  ),
];
const holdings = <Entry>[
  (
    title: 'Фонд на индекс МосБиржи',
    note: '6000 шт. × 7,12 ₽',
    amount: '42 720 ₽',
    icon: Icons.stacked_line_chart,
    color: Color(0xff3155c7),
  ),
  (
    title: 'Сбербанк',
    note: '120 шт. × 302,40 ₽',
    amount: '36 288 ₽',
    icon: Icons.show_chart,
    color: teal,
  ),
  (
    title: 'Лукойл',
    note: '5 шт. × 6 850 ₽',
    amount: '34 250 ₽',
    icon: Icons.show_chart,
    color: red,
  ),
  (
    title: 'ОФЗ 26238',
    note: '40 шт. × 612,30 ₽',
    amount: '24 492 ₽',
    icon: Icons.account_balance_outlined,
    color: Color(0xffa84d07),
  ),
];

class CircleAction extends StatelessWidget {
  const CircleAction({super.key, required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => IconButton.filled(
    style: IconButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: ink,
    ),
    onPressed: onPressed,
    icon: Icon(icon, size: 20),
  );
}

class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.padding = const EdgeInsets.all(15),
  });
  final Widget child;
  final Color color;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(21),
      border: Border.all(color: color == Colors.white ? line : color),
    ),
    child: child,
  );
}

class Metric extends StatelessWidget {
  const Metric(this.label, this.value, {super.key, this.light = false});
  final String label, value;
  final bool light;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: light ? tint : muted),
      ),
      const SizedBox(height: 3),
      Text(
        value,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: light ? Colors.white : ink,
        ),
      ),
    ],
  );
}

class Segments extends StatelessWidget {
  const Segments({
    super.key,
    required this.labels,
    required this.selected,
    required this.change,
  });
  final List<String> labels;
  final int selected;
  final ValueChanged<int> change;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: const Color(0xffe8eae3),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Row(
      children: List.generate(
        labels.length,
        (i) => Expanded(
          child: Material(
            color: i == selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            child: InkWell(
              borderRadius: BorderRadius.circular(11),
              onTap: () => change(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(labels[i], textAlign: TextAlign.center),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, this.amount, {super.key});
  final String title, amount;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(title), Text(amount)],
    ),
  );
}

class EntryIcon extends StatelessWidget {
  const EntryIcon(this.entry, {super.key, this.size = 45});
  final Entry entry;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Color.lerp(Colors.white, entry.color, .15),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Icon(entry.icon, color: entry.color, size: 20),
  );
}

class EntryTile extends StatelessWidget {
  const EntryTile(this.entry, {super.key, this.onTap});
  final Entry entry;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 3),
      child: Row(
        children: [
          EntryIcon(entry),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (entry.note.isNotEmpty)
                  Text(
                    entry.note,
                    style: const TextStyle(fontSize: 12, color: muted),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          Text(
            entry.amount,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: entry.amount.startsWith('−')
                  ? red
                  : entry.amount.startsWith('+')
                  ? teal
                  : ink,
            ),
          ),
        ],
      ),
    ),
  );
}

class DayTitle extends StatelessWidget {
  const DayTitle(this.day, this.weekday, this.amount, this.color, {super.key});
  final String day, weekday, amount;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      const SizedBox(height: 10),
      Row(
        children: [
          SizedBox(
            width: 54,
            child: Text(
              day,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 29),
            ),
          ),
          Expanded(
            child: Text(
              '$weekday\nоктября 2026',
              style: const TextStyle(fontSize: 12, color: muted),
            ),
          ),
          Text(
            amount,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      const Divider(color: line),
    ],
  );
}

const allocationColors = [
  saldoGreen,
  Color(0xffbd680e),
  Color(0xff5c7ccc),
  Color(0xffb6b9ae),
];

class AllocationBar extends StatelessWidget {
  const AllocationBar({super.key});
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: SizedBox(
      height: 12,
      child: Row(
        children: [
          for (final (i, value) in [38, 27, 23, 13].indexed)
            Expanded(
              flex: value,
              child: Container(
                margin: EdgeInsets.only(right: i == 3 ? 0 : 2),
                color: allocationColors[i],
              ),
            ),
        ],
      ),
    ),
  );
}

class DonutPainter extends CustomPainter {
  const DonutPainter({required this.income});
  final bool income;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(12);
    final segments = income ? [100] : [51, 23, 11, 6, 4, 4, 2];
    final entries = [8, 0, 7, 1, 3, 2, 5];
    final sum = segments.reduce((a, b) => a + b);
    var start = -math.pi / 2;
    for (final (i, value) in segments.indexed) {
      final sweep = 2 * math.pi * value / sum;
      canvas.drawArc(
        rect,
        start,
        sweep - .025,
        false,
        Paint()
          ..color = income ? teal : categories[entries[i]].color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 23,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(DonutPainter oldDelegate) => income != oldDelegate.income;
}

class OperationSearch extends SearchDelegate<void> {
  OperationSearch(this.entries) : super(searchFieldLabel: 'Поиск операций');
  final List<Entry> entries;
  @override
  List<Widget> buildActions(BuildContext context) => [
    IconButton(onPressed: () => query = '', icon: const Icon(Icons.clear)),
  ];
  @override
  Widget buildLeading(BuildContext context) =>
      BackButton(onPressed: () => close(context, null));
  @override
  Widget buildResults(BuildContext context) => buildSuggestions(context);
  @override
  Widget buildSuggestions(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      for (final entry in entries)
        if ('${entry.title} ${entry.note}'.toLowerCase().contains(
          query.trim().toLowerCase(),
        ))
          EntryTile(entry),
    ],
  );
}

class OperationSheet extends StatefulWidget {
  const OperationSheet({super.key, required this.persist});
  final Future<void> Function(Entry) persist;
  @override
  State<OperationSheet> createState() => _OperationSheetState();
}

class _OperationSheetState extends State<OperationSheet> {
  int type = 0;
  int account = 0;
  int category = 0;
  String digits = '0';
  DateTime day = DateTime.now();
  static const types = ['Расход', 'Доход', 'Перевод', 'Сделка'];

  void keyTap(String key) {
    setState(() {
      if (key == '⌫') {
        digits = digits.length > 1
            ? digits.substring(0, digits.length - 1)
            : '0';
      } else if (key == ',') {
        if (!digits.contains(',')) digits += ',';
      } else if (digits.length < 12 &&
          (!digits.contains(',') || digits.split(',').last.length < 2)) {
        digits = digits == '0' ? key : digits + key;
      }
    });
  }

  bool saving = false;
  String? saveError;

  Future<void> save() async {
    final amount = digits.endsWith(',')
        ? digits.substring(0, digits.length - 1)
        : digits;
    if ((double.tryParse(amount.replaceAll(',', '.')) ?? 0) <= 0) {
      setState(() => saveError = 'Введите сумму больше нуля');
      return;
    }
    final entry = categories[category];
    setState(() {
      saving = true;
      saveError = null;
    });
    try {
      await widget.persist((
        title: type == 0 ? entry.title : types[type],
        note:
            '${day.day}.${day.month}.${day.year} · ${demoAccounts[account].title}',
        amount:
            '${type == 0
                ? '−'
                : type == 1
                ? '+'
                : ''}$amount ₽',
        icon: entry.icon,
        color: entry.color,
      ));
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted)
        setState(() {
          saving = false;
          saveError =
              'Не удалось сохранить операцию. Проверьте подключение к API.';
        });
    }
  }

  Widget selector(
    String title,
    List<Entry> entries,
    int selected,
    ValueChanged<int> change,
  ) {
    final entry = entries[selected];
    return Panel(
      color: Color.lerp(Colors.white, entry.color, .15)!,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12)),
          DropdownButton<int>(
            isExpanded: true,
            isDense: true,
            underline: const SizedBox.shrink(),
            value: selected,
            onChanged: (i) {
              if (i != null) setState(() => change(i));
            },
            items: [
              for (final (i, item) in entries.indexed)
                DropdownMenuItem(
                  value: i,
                  child: Text(item.title, overflow: TextOverflow.ellipsis),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
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
          const SizedBox(height: 8),
          Segments(
            labels: types,
            selected: type,
            change: (i) => setState(() => type = i),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => setState(
                  () => day = DateTime(day.year, day.month, day.day - 1),
                ),
                icon: const Icon(Icons.chevron_left),
              ),
              Text('${day.day}.${day.month}.${day.year}'),
              IconButton(
                onPressed: () => setState(
                  () => day = DateTime(day.year, day.month, day.day + 1),
                ),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: selector(
                  'Счёт',
                  demoAccounts,
                  account,
                  (i) => account = i,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: selector(
                  'Категория',
                  categories,
                  category,
                  (i) => category = i,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              '$digits ₽',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 42),
            ),
          ),
          const Divider(color: line),
          if (saveError != null)
            Text(saveError!, style: const TextStyle(color: red)),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.15,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              for (final key in [
                '7',
                '8',
                '9',
                '⌫',
                '4',
                '5',
                '6',
                '1',
                '2',
                '3',
                '0',
                ',',
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
                  onPressed: () => keyTap(key),
                  child: Text(key, style: const TextStyle(fontSize: 22)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: saldoGreen),
              onPressed: saving ? null : save,
              child: const Icon(Icons.check),
            ),
          ),
        ],
      ),
    ),
  );
}

class AssetPage extends StatelessWidget {
  const AssetPage({super.key, required this.addOperation});
  final VoidCallback addOperation;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: saldoBackground,
      title: const Column(
        children: [
          Text(
            'ОФЗ 26238',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            'Облигация федерального займа',
            style: TextStyle(fontSize: 12, color: muted),
          ),
        ],
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '612,30 ₽',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 30),
              ),
              Text(
                '61,23% от номинала · +7,20% за полгода',
                style: TextStyle(color: muted),
              ),
              SizedBox(height: 16),
              SizedBox(
                height: 135,
                width: double.infinity,
                child: CustomPaint(painter: AssetChart()),
              ),
              SizedBox(height: 12),
              Center(
                child: Text(
                  '1Н          1М          6М          1Г          Всё',
                ),
              ),
            ],
          ),
        ),
        const Panel(
          color: saldoGreen,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Metric('В портфеле', '40 шт.', light: true),
                    SizedBox(height: 12),
                    Metric('Средняя цена покупки', '584,60 ₽', light: true),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Metric('Стоимость', '24 492 ₽', light: true),
                    SizedBox(height: 12),
                    Metric('Доход по цене', '+1 108 ₽ · +4,7%', light: true),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Panel(
          child: Column(
            children: [
              SectionTitle('Купон', '7,1% · 2 раза в год'),
              Divider(height: 1, color: line),
              SectionTitle('Номинал', '1 000 ₽'),
              Divider(height: 1, color: line),
              SectionTitle('Погашение', '15 мая 2041'),
              Divider(height: 1, color: line),
              SectionTitle('Доходность к погашению', '≈ 13,9%'),
              Divider(height: 1, color: line),
              SectionTitle('НКД', '33,07 ₽ за шт.'),
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
                onPressed: () {
                  Navigator.pop(context);
                  addOperation();
                },
                child: const Text('Записать продажу'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  addOperation();
                },
                child: const Text('Записать покупку'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class AssetChart extends CustomPainter {
  const AssetChart();
  @override
  void paint(Canvas canvas, Size size) {
    for (final fraction in [.1, .5, .9]) {
      final y = size.height * fraction;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()..color = line,
      );
    }
    const data = [
      .12,
      .24,
      .26,
      .22,
      .34,
      .35,
      .43,
      .29,
      .37,
      .32,
      .3,
      .5,
      .57,
      .64,
      .62,
      .54,
      .63,
      .6,
      .45,
      .63,
      .72,
      .57,
      .72,
      .84,
      .88,
      .7,
      .58,
      .65,
      .78,
      .67,
      .69,
      .81,
    ];
    final trend = Path()..moveTo(0, size.height * (1 - data.first));
    for (var i = 1; i < data.length; i++) {
      trend.lineTo(
        size.width * i / (data.length - 1),
        size.height * (1 - data[i]),
      );
    }
    final fill = Path.from(trend)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fill, Paint()..color = const Color(0xffe8f2ed));
    canvas.drawPath(
      trend,
      Paint()
        ..color = saldoGreen
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(AssetChart oldDelegate) => false;
}
