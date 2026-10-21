String? validateName(String? v) =>
    (v ?? '').trim().length < 2 ? 'Please enter your full name' : null;

String? validateEmail(String? v) =>
    RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$').hasMatch((v ?? '').trim())
        ? null
        : 'Enter a valid email address';

String? validatePassword(String? v) =>
    (v ?? '').length < 6 ? 'Password must be at least 6 characters' : null;

String? validateServiceName(String? v) {
  final name = (v ?? '').trim();
  if (name.isEmpty) return 'Enter a service name';
  if (name.length > 60) return 'Keep the name under 60 characters';
  return null;
}

/// Positive amount with at most 2 decimals, below 10 million.
String? validatePrice(String? v) {
  final text = (v ?? '').trim();
  final price = double.tryParse(text);
  if (price == null || price <= 0) return 'Enter a valid amount';
  if (price >= 10000000) return 'Amount is too large';
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(text)) {
    return 'Use at most 2 decimal places';
  }
  return null;
}

/// Payment labels must not hold a full card number (only e.g. "Visa ••8841").
String? validatePaymentLabel(String? v) =>
    RegExp(r'\d{7,}').hasMatch((v ?? '').replaceAll(RegExp(r'[\s-]'), ''))
        ? 'For your safety, only enter the last 4 digits'
        : null;

/// Optional link; when given it must be a web address (http/https only,
/// so links like "javascript:" can never be opened).
String? validateUrl(String? v) {
  final text = (v ?? '').trim();
  if (text.isEmpty) return null;
  final uri = Uri.tryParse(text.contains('://') ? text : 'https://$text');
  final ok = uri != null &&
      (uri.scheme == 'https' || uri.scheme == 'http') &&
      uri.host.contains('.');
  return ok ? null : 'Enter a valid web address';
}
