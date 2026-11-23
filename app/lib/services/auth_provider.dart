import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'api.dart';

class AuthProvider extends ChangeNotifier {
  UserProfile? user;
  bool ready = false;

  bool get loggedIn => user != null;

  /// Called once at startup: restore the saved session if the token is still valid.
  Future<void> boot() async {
    await Api.I.init();
    if (Api.I.token != null) {
      try {
        user = await Api.I.me();
      } catch (_) {
        // Backend offline or token expired: show login screen.
        user = null;
      }
    }
    ready = true;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    user = await Api.I.login(email, password);
    notifyListeners();
  }

  Future<void> register(String name, String email, String password) async {
    user = await Api.I.register(name, email, password);
    notifyListeners();
  }

  Future<void> loginGoogle(String name, String email, {String? avatarUrl}) async {
    user = await Api.I.loginGoogle(name, email, avatarUrl: avatarUrl);
    notifyListeners();
  }

  Future<void> resetPassword(String email, String newPassword) async {
    await Api.I.resetPassword(email, newPassword);
  }

  Future<void> updateProfile({
    String? name,
    String? email,
    String? currentPassword,
    String? newPassword,
  }) async {
    user = await Api.I.updateProfile(
      name: name,
      email: email,
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
    notifyListeners();
  }

  Future<void> updatePrefs({String? lang, String? level}) async {
    user = await Api.I.updateProfile(preferredLang: lang, readingLevel: level);
    notifyListeners();
  }

  Future<void> logout() async {
    await Api.I.setToken(null);
    user = null;
    notifyListeners();
  }
}
