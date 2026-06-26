String formatNaira(dynamic amount) {
  if (amount == null) return '';
  double value;
  if (amount is String) {
    value = double.tryParse(amount) ?? 0;
  } else if (amount is num) {
    value = amount.toDouble();
  } else {
    return '';
  }
  final parts = value.toStringAsFixed(0).split('.');
  final intPart = parts[0];
  final buffer = StringBuffer();
  for (int i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buffer.write(',');
    buffer.write(intPart[i]);
  }
  return '₦$buffer';
}
