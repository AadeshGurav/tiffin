/// UPI payment URI (PRD §6.3). The bill itself is drawn by the UI
/// (`BillView`) so it is in the reader's language.
///
/// The UPI QR is deliberately NOT on the bill — it's shown at the moment of
/// payment and is worth nothing afterwards. The bill is the record.
class BillingService {
  BillingService();

  /// Standard `upi://pay` URI (no gateway). Null when no UPI ID is configured
  /// — cash-only setups.
  String? upiPaymentUri({
    required double amount,
    required String note,
    required String upiId,
    required String upiPayeeName,
  }) {
    if (upiId.isEmpty) return null;
    final params = {
      'pa': upiId,
      'pn': upiPayeeName,
      'am': amount.toStringAsFixed(2),
      'cu': 'INR',
      'tn': note,
    };
    final query = params.entries
        .map((e) =>
            '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return 'upi://pay?$query';
  }
}
