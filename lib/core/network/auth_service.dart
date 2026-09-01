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

  static String formatStatus(Object? raw) {
    final value = (raw ?? '').toString().trim().toUpperCase();
    const labels = {
      'AGUARDANDO_ACEITE': 'Aguardando aceite',
      'AGUARDANDO_EQUIPE': 'Aguardando equipe',
      'PLANEJADA': 'Planejada',
      'PLANEJAMENTO': 'Planejamento',
      'EM_ANDAMENTO': 'Em andamento',
      'EM_EXECUCAO': 'Em execução',
      'PAUSADA': 'Pausada',
      'FINALIZADA': 'Finalizada',
      'FINALIZADO': 'Finalizado',
      'CONCLUIDA': 'Concluída',
      'CONCLUIDO': 'Concluído',
      'CANCELADA': 'Cancelada',
      'CANCELADO': 'Cancelado',
    };
    if (labels.containsKey(value)) return labels[value]!;
    return value.replaceAll('_', ' ').toLowerCase().split(' ').map((word) =>
      word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}').join(' ');
  }

  static bool get isEmpreiteiro {
    final r = (_role ?? '').toUpperCase();
    return r == 'EMPREITEIRO' || r == 'ADMIN' || r == 'GESTOR';
  }

  static bool get isFuncionario {
    final r = (_role ?? '').toUpperCase();
    return r == 'FUNCIONARIO' ||
        r == 'COLABORADOR' ||
        r == 'MOBILE-FUNCIONARIO' ||
        r == 'PINTOR' ||
        r == 'ALMOXARIFE';
  }

  static bool get isCliente {
    final r = (_role ?? '').toUpperCase();
    return r == 'CLIENTE';
  }

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

  static Future<bool> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim(), 'senha': password}),
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
          'documento': cpf.replaceAll(
            RegExp(r'\D'),
            '',
          ), // Extract only numbers for validation
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

  // Fetch contractor's works from API
  static Future<List<Map<String, dynamic>>> fetchObras() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/obra/minhas-obras'),
        headers: getHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(utf8.decode(response.bodyBytes));
        return list.map((item) => Map<String, dynamic>.from(item)).toList();
      } else {
        throw Exception('Erro ao buscar obras: ${response.statusCode}');
      }
    } catch (e) {
      print('Erro ao carregar obras: $e');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchFases(int obraId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/obra/$obraId/detalhar'),
        headers: getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));

        final List<dynamic>? phases = data['fases'];
        if (phases != null && phases.isNotEmpty) {
          return phases.map((item) => Map<String, dynamic>.from(item)).toList();
        }
      }
      return [];
    } catch (e) {
      print('Erro ao carregar fases do servidor: $e');
      rethrow;
    }
  }

  static Future<bool> transitionPhaseStatus(
    int obraId,
    int faseId,
    String acao,
  ) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/fasesObra/$faseId/status'),
        headers: getHeaders(),
        body: jsonEncode({'acao': acao}),
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('Erro ao salvar transicao de status no servidor: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchObraPhotos(int obraId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/obra-fotos/obra/$obraId'),
      headers: getHeaders(),
    );
    if (response.statusCode != 200) {
      throw Exception('Não foi possível carregar as fotos da obra (${response.statusCode}).');
    }
    final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
    return data.map((item) => Map<String, dynamic>.from(item)).toList();
  }

  static Future<Map<String, dynamic>> addPhasePhoto(
    int obraId,
    int faseId,
    List<int> bytes,
    String fileName,
  ) async {
    final upload = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/storage/upload'),
    );
    upload.headers.addAll(Map<String, String>.from(getHeaders())..remove('Content-Type'));
    upload.fields['path'] = 'obras/$obraId/fases/$faseId';
    upload.files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));

    final streamed = await upload.send();
    final uploadResponse = await http.Response.fromStream(streamed);
    if (uploadResponse.statusCode != 200) {
      throw Exception('Falha ao enviar a imagem (${uploadResponse.statusCode}).');
    }
    final uploadData = jsonDecode(utf8.decode(uploadResponse.bodyBytes));
    final key = uploadData['key']?.toString();
    if (key == null || key.isEmpty) {
      throw Exception('O storage não retornou a identificação da imagem.');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/obra-fotos'),
      headers: getHeaders(),
      body: jsonEncode({
        'idObra': obraId,
        'idFase': faseId,
        'urlFoto': key,
        'descricao': 'Foto de progresso da fase $faseId',
      }),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Falha ao registrar a foto na fase (${response.statusCode}).');
    }
    return Map<String, dynamic>.from(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  static String mediaUrl(String value) {
    if (value.startsWith('http://') || value.startsWith('https://') || value.startsWith('data:')) {
      return value;
    }
    final clean = value.startsWith('/') ? value.substring(1) : value;
    return '$baseUrl/storage/local/$clean';
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

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Erro ao criar obra: $e');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchCalendarioEvents({
    int? obraId,
  }) async {
    try {
      final queryParameters =
          obraId == null ? null : <String, String>{'obraId': obraId.toString()};
      final response = await http.get(
        Uri.parse('$baseUrl/calendario').replace(
          queryParameters: queryParameters,
        ),
        headers: getHeaders(),
      );

      if (response.statusCode != 200) return [];
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((item) => Map<String, dynamic>.from(item)).toList();
    } catch (e) {
      print('Erro ao carregar eventos do calendário: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> fetchSolicitacoesMaterial({
    int? obraId,
  }) async {
    try {
      final queryParameters =
          obraId == null ? null : <String, String>{'obraId': obraId.toString()};
      final response = await http.get(
        Uri.parse('$baseUrl/solicitacoes-material').replace(
          queryParameters: queryParameters,
        ),
        headers: getHeaders(),
      );

      if (response.statusCode != 200) return [];
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((item) => Map<String, dynamic>.from(item)).toList();
    } catch (e) {
      print('Erro ao carregar solicitações de material: $e');
      return [];
    }
  }

  static Future<bool> createSolicitacaoMaterial(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/solicitacoes-material'),
        headers: {...getHeaders(), 'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Erro ao criar solicitação de material: $e');
      return false;
    }
  }

  static Future<bool> aprovarSolicitacaoMaterial(
    int id,
    String observacaoSupervisor,
  ) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/solicitacoes-material/$id/aprovar'),
        headers: {...getHeaders(), 'Content-Type': 'application/json'},
        body: jsonEncode({'observacaoSupervisor': observacaoSupervisor}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Erro ao aprovar solicitação de material: $e');
      return false;
    }
  }

  // Delete current contractor account
  static Future<bool> deleteCurrentAccount() async {
    try {
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

  // --- Tarefas / Agenda Database Integration ---

  static Future<List<Map<String, dynamic>>> fetchTarefas({int? obraId}) async {
    try {
      final uri = obraId != null
          ? Uri.parse('$baseUrl/tarefas?obraId=$obraId')
          : Uri.parse('$baseUrl/tarefas');
      final response = await http.get(uri, headers: getHeaders());
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.map((item) => Map<String, dynamic>.from(item)).toList();
      }
      return [];
    } catch (e) {
      print('Erro ao carregar tarefas do servidor: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> createTarefa(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/tarefas'),
        headers: getHeaders(),
        body: jsonEncode({
          'titulo': data['titulo'] ?? data['title'],
          'descricao': data['descricao'] ?? data['description'] ?? '',
          'dataInicio': data['dataInicio'] ?? data['startDate'],
          'dataFim': data['dataFim'] ?? data['endDate'],
          'categoria': data['categoria'] ?? data['category'] ?? 'Geral',
          'corHex': data['corHex'] ?? data['colorHex'],
          'concluida': data['concluida'] ?? data['isCompleted'] ?? false,
          'prioridade': data['prioridade'] ?? data['priority'] ?? 'Média',
          'idObra': data['idObra'] ?? data['obraId'],
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return null;
    } catch (e) {
      print('Erro ao salvar tarefa no banco de dados: $e');
      return null;
    }
  }

  static Future<bool> toggleTarefaStatus(int id) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/tarefas/$id/toggle'),
        headers: getHeaders(),
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('Erro ao alternar status da tarefa no banco: $e');
      return false;
    }
  }

  static Future<bool> deleteTarefa(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/tarefas/$id'),
        headers: getHeaders(),
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('Erro ao deletar tarefa no banco: $e');
      return false;
    }
  }
}
