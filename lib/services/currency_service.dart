import 'dart:convert';
import 'package:http/http.dart' as http;

class CurrencyService {
  static const String _baseUrl = 'https://open.er-api.com/v6/latest/IDR';
  static Map<String, double>? _ratesCache;
  static DateTime? _lastFetch;

  static Future<double> convert(double amountInIdr, String targetCurrency) async {
    if (targetCurrency == 'IDR') return amountInIdr;

    // Cache valid for 1 hour
    if (_ratesCache == null || _lastFetch == null || DateTime.now().difference(_lastFetch!).inHours > 1) {
      try {
        final response = await http.get(Uri.parse(_baseUrl));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['rates'] != null) {
            _ratesCache = Map<String, double>.from(data['rates'].map((key, value) => MapEntry(key, value.toDouble())));
            _lastFetch = DateTime.now();
          }
        }
      } catch (e) {
        // Fallback to static approximate rates if network fails
        _ratesCache = {
          'USD': 0.000063,
          'EUR': 0.000058,
          'SGD': 0.000085,
          'JPY': 0.0095,
        };
      }
    }

    final rate = _ratesCache?[targetCurrency] ?? 1.0; // fallback to 1.0
    return amountInIdr * rate;
  }
}
