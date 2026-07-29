import 'package:shared_preferences/shared_preferences.dart';

/// Tiny wrapper around SharedPreferences for the one flag SplashScreen
/// needs to decide where to route the user:
///   - isLoggedIn: true while a user session is active. Reset on logout.
///
/// Routing rule: logged in -> Home directly. Not logged in -> always show
/// How We Work (every launch, whether or not they've seen it before).
///
/// TODO: once real auth is wired up, isLoggedIn should really be derived
/// from "do we have a valid saved auth token", not a plain bool.
class AppPrefs {
  static const _kIsLoggedIn = 'is_logged_in';

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kIsLoggedIn) ?? false;
  }

  static Future<void> setLoggedIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kIsLoggedIn, value);
  }
}
