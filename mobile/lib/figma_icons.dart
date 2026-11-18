import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

final figmaIcons = <int, String>{
  Icons.credit_card.codePoint: 'assets/icons/fc685.svg',
  Icons.account_balance_wallet_outlined.codePoint: 'assets/icons/b684b.svg',
  Icons.attach_money.codePoint: 'assets/icons/461a4.svg',
  Icons.percent.codePoint: 'assets/icons/a5a22.svg',
  Icons.lock_outline.codePoint: 'assets/icons/d99e6.svg',
  Icons.trending_up.codePoint: 'assets/icons/ea1d0.svg',
  Icons.account_balance_wallet.codePoint: 'assets/icons/dc612.svg',
  Icons.category_outlined.codePoint: 'assets/icons/b96b3.svg',
  Icons.receipt_long_outlined.codePoint: 'assets/icons/b06ae.svg',
  Icons.stacked_line_chart.codePoint: 'assets/icons/836ba.svg',
  Icons.bar_chart_outlined.codePoint: 'assets/icons/432b7.svg',
  Icons.kitchen_outlined.codePoint: 'assets/icons/390b7.svg',
  Icons.restaurant.codePoint: 'assets/icons/4ea85.svg',
  Icons.movie_outlined.codePoint: 'assets/icons/90efe.svg',
  Icons.directions_bus_outlined.codePoint: 'assets/icons/568a7.svg',
  Icons.favorite_border.codePoint: 'assets/icons/3ac0f.svg',
  Icons.repeat.codePoint: 'assets/icons/25748.svg',
  Icons.card_giftcard.codePoint: 'assets/icons/6d251.svg',
  Icons.checkroom.codePoint: 'assets/icons/a5467.svg',
  Icons.home_outlined.codePoint: 'assets/icons/3cd38.svg',
  Icons.help_outline.codePoint: 'assets/icons/adf31.svg',
};

class FigmaIcon extends StatelessWidget {
  const FigmaIcon(this.icon, {super.key, this.size = 22, this.color});
  final IconData icon;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final asset = figmaIcons[icon.codePoint];
    if (asset == null) return Icon(icon, size: size, color: color);
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: color == null
          ? null
          : ColorFilter.mode(color!, BlendMode.srcIn),
    );
  }
}
