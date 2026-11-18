import 'package:flutter/material.dart';

import 'figma_icons.dart';

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
  Icons.account_balance_wallet,
  Icons.category_outlined,
  Icons.receipt_long_outlined,
  Icons.stacked_line_chart,
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
    child: FigmaIcon(entry.icon, color: entry.color, size: 20),
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
