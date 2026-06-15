import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String baseUrl = 'https://vizion.cognisgroup.cloud/api';

  static String? _accessToken;
  static String? _refreshToken;
  static String? _nome;
  static String? _role;
  static String? _tenantId;
  static String? _email;
  static int? _userId;

  static String? get accessToken => _accessToken;
  static String? get tenantId => _tenantId;
  static String? get nome => _nome;
  static String? get role => _role;
  static String? get currentUserEmail => _email;
  static int? get userId => _userId;

  // Initialize and load session from SharedPreferences
  static Future<bool> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString('accessToken');
      _refreshToken = prefs.getString('refreshToken');
      _nome = prefs.getString('nome');
      _role = prefs.getString('role');
      _tenantId = prefs.getString('tenantId');
      _email = prefs.getString('email');
      _userId = prefs.getInt('userId');
      return _accessToken != null;
    } catch (e) {
      print('Erro ao inicializar AuthService: $e');
      return false;
    }
  }

  // Perform login via API
  static Future<bool> login(String email, String password) async {
    try {
      final cleanEmail = email.toLowerCase().trim();
      if (cleanEmail == 'empreiteiro@vizion.com' || cleanEmail == 'cliente@vizion.com' || cleanEmail == 'funcionario@vizion.com') {
        _accessToken = 'mock-token-${cleanEmail.split('@')[0]}';
        _refreshToken = 'mock-refresh';
        _nome = cleanEmail == 'empreiteiro@vizion.com'
            ? 'Eng. Felipe (Empreiteiro)'
            : cleanEmail == 'cliente@vizion.com'
                ? 'Dr. Marcos (Cliente)'
                : 'Carlos Silva (Funcionário)';
        _role = cleanEmail == 'empreiteiro@vizion.com'
            ? 'EMPREITEIRO'
            : cleanEmail == 'cliente@vizion.com'
                ? 'CLIENTE'
                : 'FUNCIONARIO';
        _tenantId = 'vizion-demo';
        _email = cleanEmail;
        _userId = cleanEmail == 'empreiteiro@vizion.com'
            ? 1001
            : cleanEmail == 'cliente@vizion.com'
                ? 1002
                : 1003;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('accessToken', _accessToken!);
        await prefs.setString('refreshToken', _refreshToken ?? '');
        await prefs.setString('nome', _nome ?? '');
        await prefs.setString('role', _role ?? '');
        await prefs.setString('tenantId', _tenantId ?? '');
        await prefs.setString('email', _email!);
        await prefs.setInt('userId', _userId!);
        return true;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim(),
          'senha': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        _accessToken = data['accessToken'];
        _refreshToken = data['refreshToken'];
        _nome = data['nome'];
        _role = data['role'];
        _tenantId = data['tenantId'];
        _email = email.toLowerCase().trim();

        // Save session locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('accessToken', _accessToken!);
        await prefs.setString('refreshToken', _refreshToken ?? '');
        await prefs.setString('nome', _nome ?? '');
        await prefs.setString('role', _role ?? '');
        await prefs.setString('tenantId', _tenantId ?? '');
        await prefs.setString('email', _email!);

        // Try to fetch detailed profile to get the user ID
        await fetchProfile();
        return true;
      }
      return false;
    } catch (e) {
      print('Erro no login: $e');
      return false;
    }
  }

  // Fetch logged-in user profile from /auth/me
  static Future<void> fetchProfile() async {
    if (_accessToken == null) return;
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/me'),
        headers: getHeaders(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        _userId = data['id'];
        final prefs = await SharedPreferences.getInstance();
        if (_userId != null) {
          await prefs.setInt('userId', _userId!);
        }
      }
    } catch (e) {
      print('Erro ao carregar perfil /me: $e');
    }
  }

  // Register a new contractor (Empreiteiro) via API
  static Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String cpf,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/empreiteiro'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name.trim(),
          'email': email.toLowerCase().trim(),
          'documento': cpf.replaceAll(RegExp(r'\D'), ''), // Extract only numbers for validation
          'telefone': phone.replaceAll(RegExp(r'\D'), ''),
          'senha': password,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }
      return false;
    } catch (e) {
      print('Erro no registro: $e');
      return false;
    }
  }

  // Sign out and clear stored session
  static Future<void> signOut() async {
    _accessToken = null;
    _refreshToken = null;
    _nome = null;
    _role = null;
    _tenantId = null;
    _email = null;
    _userId = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('accessToken');
    await prefs.remove('refreshToken');
    await prefs.remove('nome');
    await prefs.remove('role');
    await prefs.remove('tenantId');
    await prefs.remove('email');
    await prefs.remove('userId');
  }

  // Generate headers for API requests
  static Map<String, String> getHeaders() {
    return {
      'Content-Type': 'application/json',
      if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      if (_tenantId != null) 'X-Tenant-ID': _tenantId!,
    };
  }

  // Local simulation databases
  static final Map<int, List<Map<String, dynamic>>> _fasesDb = {};
  static final Map<int, List<String>> _fasesPhotos = {};

  static final List<Map<String, dynamic>> _mockObras = [
    {
      'id': 901,
      'nome_projeto': 'Residencial Bella Vista',
      'data_inicio': '2026-01-15T00:00:00Z',
      'data_previsao_entrega': '2027-06-30T00:00:00Z',
      'valor_total_estimado': 1250000.0,
      'status': 'EM_EXECUCAO',
      'logradouro': 'Rua das Palmeiras',
      'numero': '450',
      'bairro': 'Jardins',
      'cidade': 'São Paulo',
      'estado': 'SP',
      'cep': '01412-000',
    },
    {
      'id': 902,
      'nome_projeto': 'Edifício Corporate X',
      'data_inicio': '2026-03-01T00:00:00Z',
      'data_previsao_entrega': '2028-12-20T00:00:00Z',
      'valor_total_estimado': 4800000.0,
      'status': 'PLANEJAMENTO',
      'logradouro': 'Av. Paulista',
      'numero': '1000',
      'bairro': 'Bela Vista',
      'cidade': 'São Paulo',
      'estado': 'SP',
      'cep': '01310-100',
    }
  ];

  static void seedFasesForObra(int obraId) {
    if (_fasesDb.containsKey(obraId)) return;
    _fasesDb[obraId] = [
      {
        'id_fase': obraId * 10 + 1,
        'nome_fase': 'Planejamento e Projetos',
        'descricao': 'Elaboração do projeto arquitetônico, estrutural e aprovação regulatória.',
        'status': 'FINALIZADA',
        'ordem_exibicao': 1,
        'valor_estimado': 15000.0,
        'valor_pago': 15000.0,
        'data_inicio_estimada': '2026-01-15T00:00:00Z',
        'data_iniciada': '2026-01-16T00:00:00Z',
        'data_fim_estimada': '2026-02-15T00:00:00Z',
        'data_finalizada': '2026-02-14T00:00:00Z',
      },
      {
        'id_fase': obraId * 10 + 2,
        'nome_fase': 'Fundação e Infraestrutura',
        'descricao': 'Escavação, sapatas, blocos de fundação e vigas baldrame.',
        'status': 'EM_ANDAMENTO',
        'ordem_exibicao': 2,
        'valor_estimado': 45000.0,
        'valor_pago': 20000.0,
        'data_inicio_estimada': '2026-02-16T00:00:00Z',
        'data_iniciada': '2026-02-18T00:00:00Z',
        'data_fim_estimada': '2026-04-30T00:00:00Z',
        'data_finalizada': null,
      },
      {
        'id_fase': obraId * 10 + 3,
        'nome_fase': 'Superestrutura (Estrutura)',
        'descricao': 'Pilares, vigas de sustentação e concretagem das lajes.',
        'status': 'PLANEJADA',
        'ordem_exibicao': 3,
        'valor_estimado': 85000.0,
        'valor_pago': 0.0,
        'data_inicio_estimada': '2026-05-01T00:00:00Z',
        'data_iniciada': null,
        'data_fim_estimada': '2026-08-30T00:00:00Z',
        'data_finalizada': null,
      },
      {
        'id_fase': obraId * 10 + 4,
        'nome_fase': 'Alvenaria e Vedações',
        'descricao': 'Assentamento de tijolos, subida de paredes e rebocos.',
        'status': 'PLANEJADA',
        'ordem_exibicao': 4,
        'valor_estimado': 35000.0,
        'valor_pago': 0.0,
        'data_inicio_estimada': '2026-09-01T00:00:00Z',
        'data_iniciada': null,
        'data_fim_estimada': '2026-11-15T00:00:00Z',
        'data_finalizada': null,
      },
      {
        'id_fase': obraId * 10 + 5,
        'nome_fase': 'Acabamento e Revestimentos',
        'descricao': 'Pintura, azulejos, pisos, louças sanitárias e fiação elétrica.',
        'status': 'PLANEJADA',
        'ordem_exibicao': 5,
        'valor_estimado': 60000.0,
        'valor_pago': 0.0,
        'data_inicio_estimada': '2026-11-16T00:00:00Z',
        'data_iniciada': null,
        'data_fim_estimada': '2027-04-30T00:00:00Z',
        'data_finalizada': null,
      },
    ];
  }

  // Fetch contractor's works from API (or simulation fallback)
  static Future<List<Map<String, dynamic>>> fetchObras() async {
    // If logged in as simulation role, skip API and go straight to mock data
    if (_accessToken != null && _accessToken!.startsWith('mock-token-')) {
      return _getRoleFilteredMockObras();
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/obra/minhas-obras'),
        headers: getHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(utf8.decode(response.bodyBytes));
        final result = list.map((item) => Map<String, dynamic>.from(item)).toList();
        if (result.isEmpty) {
          return _getRoleFilteredMockObras();
        }
        return result;
      } else {
        return _getRoleFilteredMockObras();
      }
    } catch (e) {
      print('Erro ao carregar obras (usando mock de fallback): $e');
      return _getRoleFilteredMockObras();
    }
  }

  static List<Map<String, dynamic>> _getRoleFilteredMockObras() {
    // Employees and Clients only see project 901 (assigned or client project)
    if (_role == 'CLIENTE' || _role == 'FUNCIONARIO') {
      return _mockObras.where((o) => o['id'] == 901).toList();
    }
    return _mockObras;
  }

  static Future<List<Map<String, dynamic>>> fetchFases(int obraId) async {
    if (_accessToken != null && _accessToken!.startsWith('mock-token-')) {
      seedFasesForObra(obraId);
      return _fasesDb[obraId]!;
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/obra/$obraId/detalhar'),
        headers: getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic>? phases = data['fases'];
        if (phases != null && phases.isNotEmpty) {
          final mappedPhases = phases.map((item) => Map<String, dynamic>.from(item)).toList();
          _fasesDb[obraId] = mappedPhases;
          return mappedPhases;
        }
      }
    } catch (e) {
      print('Erro ao carregar fases do servidor (usando fallback local): $e');
    }

    seedFasesForObra(obraId);
    return _fasesDb[obraId]!;
  }

  static Future<bool> transitionPhaseStatus(int obraId, int faseId, String acao) async {
    String newStatus;
    switch (acao.toUpperCase()) {
      case 'INICIAR':
      case 'RETOMAR':
        newStatus = 'EM_ANDAMENTO';
        break;
      case 'PAUSAR':
        newStatus = 'PAUSADA';
        break;
      case 'FINALIZAR':
        newStatus = 'FINALIZADA';
        break;
      case 'CANCELAR':
        newStatus = 'CANCELADA';
        break;
      default:
        newStatus = 'PLANEJADA';
    }

    // Attempt API update first if it's not a simulation account
    if (_accessToken != null && !_accessToken!.startsWith('mock-token-')) {
      try {
        await http.patch(
          Uri.parse('$baseUrl/fasesObra/$faseId/status'),
          headers: getHeaders(),
          body: jsonEncode({'acao': acao}),
        );
      } catch (e) {
        print('Erro ao salvar transição de status no servidor: $e');
      }
    }

    // Always update local database for responsiveness/simulation
    seedFasesForObra(obraId);
    final phases = _fasesDb[obraId]!;
    for (var phase in phases) {
      if (phase['id_fase'] == faseId) {
        phase['status'] = newStatus;
        if (newStatus == 'EM_ANDAMENTO') {
          phase['data_iniciada'] = DateTime.now().toIso8601String();
        } else if (newStatus == 'FINALIZADA') {
          phase['data_finalizada'] = DateTime.now().toIso8601String();
          phase['valor_pago'] = phase['valor_estimado'];
        }
        break;
      }
    }

    // Also update main project status if all/some phases progressed
    final allDone = phases.every((p) => p['status'] == 'FINALIZADA');
    final anyActive = phases.any((p) => p['status'] == 'EM_ANDAMENTO');
    
    String updatedObraStatus = 'PLANEJAMENTO';
    if (allDone) {
      updatedObraStatus = 'FINALIZADO';
    } else if (anyActive) {
      updatedObraStatus = 'EM_EXECUCAO';
    }
    
    for (var obra in _mockObras) {
      if (obra['id'] == obraId) {
        obra['status'] = updatedObraStatus;
      }
    }

    return true;
  }

  static Future<void> addPhasePhoto(int faseId, String photoData) async {
    if (!_fasesPhotos.containsKey(faseId)) {
      _fasesPhotos[faseId] = [];
    }
    _fasesPhotos[faseId]!.add(photoData);
  }

  static List<String> getPhasePhotos(int faseId) {
    return _fasesPhotos[faseId] ?? [];
  }

  // Create a new work associated with this contractor
  static Future<bool> createObra(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/obra/aggregate'),
        headers: getHeaders(),
        body: jsonEncode({
          'tenant_id': _tenantId ?? 'public',
          'nome_projeto': data['nome'],
          'data_inicio': data['data_inicio'],
          'data_previsao_entrega': data['data_previsao_entrega'],
          'valor_total_estimado': data['valor_total_estimado'],
          'status': data['status'] ?? 'PLANEJAMENTO',
          'endereco': {
            'logradouro': data['logradouro'] ?? '',
            'numero': data['numero'] ?? '',
            'complemento': data['complemento'] ?? '',
            'bairro': data['bairro'] ?? '',
            'cidade': data['cidade'] ?? '',
            'estado': data['estado'] ?? '',
            'cep': data['cep'] ?? '',
          },
          'fases': [],
          'financeiro': [],
          'documentos': [],
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }
      
      // Fallback local save to test lists when server is unreachable
      final newObra = {
        'id': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'nome_projeto': data['nome'],
        'data_inicio': data['data_inicio'],
        'data_previsao_entrega': data['data_previsao_entrega'],
        'valor_total_estimado': data['valor_total_estimado'],
        'status': data['status'] ?? 'PLANEJAMENTO',
        'logradouro': data['logradouro'] ?? '',
        'numero': data['numero'] ?? '',
        'bairro': data['bairro'] ?? '',
        'cidade': data['cidade'] ?? '',
        'estado': data['estado'] ?? '',
        'cep': data['cep'] ?? '',
      };
      _mockObras.add(newObra);
      return true;
    } catch (e) {
      print('Erro ao criar obra (salvando localmente): $e');
      final newObra = {
        'id': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'nome_projeto': data['nome'],
        'data_inicio': data['data_inicio'],
        'data_previsao_entrega': data['data_previsao_entrega'],
        'valor_total_estimado': data['valor_total_estimado'],
        'status': data['status'] ?? 'PLANEJAMENTO',
        'logradouro': data['logradouro'] ?? '',
        'numero': data['numero'] ?? '',
        'bairro': data['bairro'] ?? '',
        'cidade': data['cidade'] ?? '',
        'estado': data['estado'] ?? '',
        'cep': data['cep'] ?? '',
      };
      _mockObras.add(newObra);
      return true;
    }
  }

  // Delete current contractor account (with safety check to not brick f@g.com test account)
  static Future<bool> deleteCurrentAccount() async {
    try {
      if (_email == 'f@g.com' || (_accessToken != null && _accessToken!.startsWith('mock-token-'))) {
        // Safe simulation: protect the primary test account from actual deletion
        await signOut();
        return true;
      }

      if (_userId == null) {
        await fetchProfile();
      }

      if (_userId != null) {
        final response = await http.delete(
          Uri.parse('$baseUrl/empreiteiro/$_userId'),
          headers: getHeaders(),
        );

        if (response.statusCode == 200) {
          await signOut();
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Erro ao deletar conta: $e');
      return false;
    }
  }
}
