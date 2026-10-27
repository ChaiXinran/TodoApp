double goalNumber(String input, {required bool positive}) {
  final value = double.tryParse(input.trim());
  if (value == null || !value.isFinite || (positive ? value <= 0 : value < 0)) {
    throw FormatException(positive ? '目标值须为大于 0 的数字' : '当前进度须为不小于 0 的数字');
  }
  return value;
}

String goalNumberText(num value) {
  if (value != 0 && value.abs() < 0.000001) return value.toString();
  final text = value.toStringAsFixed(6);
  return text.contains(RegExp('[eE]'))
      ? text
      : text.replaceFirst(RegExp(r'\.?0+$'), '');
}

double goalFraction(num current, num target) =>
    target > 0 ? (current / target).clamp(0.0, 1.0).toDouble() : 0;
