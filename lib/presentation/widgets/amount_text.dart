import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AmountText extends StatelessWidget {
  final double amount;
  final TextStyle? style;
  final bool showPositiveSign;
  final Color? positiveColor;
  final Color? negativeColor;

  const AmountText({
    super.key,
    required this.amount,
    this.style,
    this.showPositiveSign = false,
    this.positiveColor,
    this.negativeColor,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
      decimalDigits: 2,
    );

    final formattedAmount = formatter.format(amount.abs());
    final isPositive = amount >= 0;
    final prefix = isPositive && showPositiveSign ? '+' : '';
    final displayText = '$prefix$formattedAmount';

    Color? textColor;
    if (isPositive && positiveColor != null) {
      textColor = positiveColor;
    } else if (!isPositive && negativeColor != null) {
      textColor = negativeColor;
    } else if (!isPositive) {
      textColor = Colors.red.shade700;
    }

    return Text(
      displayText,
      style: (style ?? const TextStyle()).copyWith(
        color: textColor,
      ),
    );
  }
}

