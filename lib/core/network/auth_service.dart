class AuthService {
  // Nosso banco de dados temporário agora aceita mais campos
  static final List<Map<String, String>> _registeredUsers = [];
  static String? currentUserEmail;

  // Atualizado para receber telefone e CPF
  static bool register({
    required String name, 
    required String email, 
    required String password,
    required String phone,
    required String cpf,
  }) {
    bool userExists = _registeredUsers.any((user) => user['email'] == email.toLowerCase().trim());
    
    if (userExists) {
      return false; 
    }

    _registeredUsers.add({
      'name': name,
      'email': email.toLowerCase().trim(),
      'password': password,
      'phone': phone,
      'cpf': cpf,
    });
    return true;
  }

  static bool login(String email, String password) {
    final emailClean = email.toLowerCase().trim();
    bool canLogin = _registeredUsers.any((user) => 
      user['email'] == emailClean && user['password'] == password
    );

    if (canLogin) {
      currentUserEmail = emailClean;
    }
    return canLogin;
  }

  static bool deleteCurrentAccount() {
    if (currentUserEmail == null) return false;
    _registeredUsers.removeWhere((user) => user['email'] == currentUserEmail);
    currentUserEmail = null;
    return true;
  }

  static void signOut() {
    currentUserEmail = null;
  }
}
