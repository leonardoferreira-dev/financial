import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MonthPicker extends StatelessWidget {
  final String monthRef; // YYYY-MM
  final Function(String) onMonthChanged;
  final bool showYear;
  final Color? textColor;
  final Color? iconColor;
  final Color? backgroundColor;

  const MonthPicker({
    super.key,
    required this.monthRef,
    required this.onMonthChanged,
    this.showYear = true,
    this.textColor,
    this.iconColor,
    this.backgroundColor,
  });

  String _formatMonth(String monthRef) {
    final parts = monthRef.split('-');
    if (parts.length != 2) return monthRef;
    
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final date = DateTime(year, month);
    
    final monthName = DateFormat('MMMM', 'pt_BR').format(date);
    final capitalizedMonth = monthName[0].toUpperCase() + monthName.substring(1);
    
    if (showYear) {
      return '$capitalizedMonth/$year';
    }
    return capitalizedMonth;
  }

  String _previousMonth(String monthRef) {
    final parts = monthRef.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    
    DateTime date = DateTime(year, month);
    date = DateTime(date.year, date.month - 1);
    
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';
  }

  String _nextMonth(String monthRef) {
    final parts = monthRef.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    
    DateTime date = DateTime(year, month);
    date = DateTime(date.year, date.month + 1);
    
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';
  }

  Future<void> _selectMonth(BuildContext context) async {
    final parts = monthRef.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(year, month),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('pt', 'BR'),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Selecione o mês',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final newMonthRef = '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}';
      onMonthChanged(newMonthRef);
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTextColor = textColor ?? Theme.of(context).colorScheme.primary;
    final effectiveIconColor = iconColor ?? effectiveTextColor;
    final effectiveBackgroundColor = backgroundColor ?? 
        Theme.of(context).colorScheme.primary.withValues(alpha: 0.1);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(Icons.chevron_left, color: effectiveIconColor),
          onPressed: () => onMonthChanged(_previousMonth(monthRef)),
          tooltip: 'Mês anterior',
        ),
        GestureDetector(
          onTap: () => _selectMonth(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: effectiveBackgroundColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _formatMonth(monthRef),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: effectiveTextColor,
                  ),
            ),
          ),
        ),
        IconButton(
          icon: Icon(Icons.chevron_right, color: effectiveIconColor),
          onPressed: () => onMonthChanged(_nextMonth(monthRef)),
          tooltip: 'Próximo mês',
        ),
      ],
    );
  }
}

