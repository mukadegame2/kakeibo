import 'package:shared_preferences/shared_preferences.dart';

class InitialSetupService {
  static const String hasCompletedInitialSetupKey =
      'has_completed_initial_setup';

  static Future<bool> hasCompletedInitialSetup() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(hasCompletedInitialSetupKey) ?? false;
  }

  static Future<void> completeInitialSetup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(hasCompletedInitialSetupKey, true);
  }

  static Future<void> resetInitialSetup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(hasCompletedInitialSetupKey, false);
  }
}
