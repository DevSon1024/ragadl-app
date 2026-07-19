import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TermsAcceptanceNotifier extends AsyncNotifier<bool> {
  static const String _key = 'has_accepted_terms';

  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  Future<void> acceptTerms() async {
    state = const AsyncValue.loading();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, true);
      state = const AsyncValue.data(true);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final termsAcceptanceProvider = AsyncNotifierProvider<TermsAcceptanceNotifier, bool>(
  TermsAcceptanceNotifier.new,
);
