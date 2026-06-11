class AuthService {
  // Nosso banco de dados temporário agora aceita mais campos, incluindo 'role'
  static final List<Map<String, String>> _registeredUsers = [
    {
      'name': 'Carlos Cliente',
      'email': 'cliente@vizion.com',
      'password': '123456',
      'phone': '11999999999',
      'cpf': '11111111111',
      'role': 'Cliente',
    },
    {
      'name': 'Marcos Empreiteiro',
      'email': 'empreiteiro@vizion.com',
      'password': '123456',
      'phone': '11888888888',
      'cpf': '22222222222',
      'role': 'Empreiteiro',
    },
    {
      'name': 'Fabio Funcionário',
      'email': 'funcionario@vizion.com',
      'password': '123456',
      'phone': '11777777777',
      'cpf': '33333333333',
      'role': 'Funcionário',
    },
  ];
  static String? currentUserEmail;

  // Atualizado para receber telefone, CPF e perfil (role)
  static bool register({
    required String name, 
    required String email, 
    required String password,
    required String phone,
    required String cpf,
    required String role,
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
      'role': role,
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

  static Map<String, String>? getUserInfo(String email) {
    final emailClean = email.toLowerCase().trim();
    try {
      return _registeredUsers.firstWhere((user) => user['email'] == emailClean);
    } catch (_) {
      return null;
    }
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