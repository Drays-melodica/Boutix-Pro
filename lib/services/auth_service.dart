import '../database/database_helper.dart';
import '../models/app_user.dart';
import 'password_hasher.dart';
import 'permissions.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final _db = DatabaseHelper.instance;
  AppUser? _currentUser;

  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;

  Future<List<String>> getActiveUsernames() async {
    final users = await _db.getActiveUsers();
    return users.map((u) => u.username).toList();
  }

  Future<AppUser> login(String username, String password) async {
    final user = await _db.getUserByUsername(username.trim());
    if (user == null || !user.active) {
      throw Exception('Identifiant ou mot de passe incorrect.');
    }
    if (!PasswordHasher.verify(password, user.passwordHash, user.passwordSalt)) {
      throw Exception('Identifiant ou mot de passe incorrect.');
    }
    _currentUser = user;
    SessionContext.currentUser = user;
    return user;
  }

  void logout() {
    _currentUser = null;
    SessionContext.currentUser = null;
  }
}
