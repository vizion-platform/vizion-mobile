import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../log.dart';
import 'api_client.dart';
import 'token_store.dart';

enum RenovacaoSessao { renovada, rejeitada, indisponivel }

class AuthService {
  static const String baseUrl = 'https://vizion.cognisgroup.cloud/api';

  static String? _accessToken;
  static String? _refreshToken;
  static String? _nome;
  static String? _role;
  static String? _tenantId;
  static String? _email;
  static int? _userId;
  static bool _trocaSenhaObrigatoria = false;

  /// Chamado quando a sessão não pode mais ser renovada (o app volta ao login).
  static Future<void> Function()? onSessionExpired;

  /// Chamado quando o servidor exige a troca da senha temporária.
  static void Function()? onPasswordChangeRequired;

  static Future<RenovacaoSessao>? _renovacaoEmAndamento;

  static String? get accessToken => _accessToken;
  static String? get tenantId => _tenantId;
  static String? get nome => _nome;
  static String? get role => _role;
  static String? get currentUserEmail => _email;
  static int? get userId => _userId;
  static bool get mustChangePassword => _trocaSenhaObrigatoria;

  static bool get isEmpreiteiro {
    final r = (_role ?? '').toUpperCase();
    return r == 'EMPREITEIRO' || r == 'ADMIN' || r == 'GESTOR';
  }

  static bool get isFuncionario {
    final r = (_role ?? '').toUpperCase();
    return r == 'FUNCIONARIO' || r == 'COLABORADOR' || r == 'MOBILE-FUNCIONARIO';
  }

  static bool get isCliente {
    final r = (_role ?? '').toUpperCase();
    return r == 'CLIENTE';
  }

  /// Apenas para testes de widget: define o papel em memória, sem token e sem persistir nada.
  @visibleForTesting
  static void definirPapelParaTeste(String role, String nome, String email) {
    _role = role;
    _nome = nome;
    _email = email;
  }

  // Initialize and load session from SharedPreferences
  static Future<bool> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await TokenStore.migrateFromPrefs(prefs);
      _accessToken = await TokenStore.readAccess();
      _refreshToken = await TokenStore.readRefresh();
      _nome = prefs.getString('nome');
      _role = prefs.getString('role');
      _tenantId = prefs.getString('tenantId');
      _email = prefs.getString('email');
      _userId = prefs.getInt('userId');
      _trocaSenhaObrigatoria = prefs.getBool('trocaSenhaObrigatoria') ?? false;
      return _accessToken != null;
    } catch (e) {
      logDebug('Erro ao inicializar AuthService: $e');
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
        _trocaSenhaObrigatoria = data['trocaSenhaObrigatoria'] == true;

        // Save session locally
        final prefs = await SharedPreferences.getInstance();
        await TokenStore.save(access: _accessToken, refresh: _refreshToken);
        await prefs.setString('nome', _nome ?? '');
        await prefs.setString('role', _role ?? '');
        await prefs.setString('tenantId', _tenantId ?? '');
        await prefs.setString('email', _email!);
        await prefs.setBool('trocaSenhaObrigatoria', _trocaSenhaObrigatoria);

        // Try to fetch detailed profile to get the user ID
        await fetchProfile();
        return true;
      }
      return false;
    } catch (e) {
      logDebug('Erro no login: $e');
      return false;
    }
  }

  // Fetch logged-in user profile from /auth/me
  static Future<void> fetchProfile() async {
    if (_accessToken == null) return;
    try {
      final response = await ApiClient.get(
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
      logDebug('Erro ao carregar perfil /me: $e');
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
      logDebug('Erro no registro: $e');
      return false;
    }
  }

  // Sign out and clear stored session
  static Future<void> signOut() async {
    // Revoga o refresh token no servidor; sem rede a saída local continua valendo.
    if (_accessToken != null) {
      try {
        await http
            .post(Uri.parse('$baseUrl/auth/logout'), headers: getHeaders())
            .timeout(const Duration(seconds: 5));
      } catch (_) {}
    }
    await _limparSessaoLocal();
  }

  static Future<void> _limparSessaoLocal() async {
    _trocaSenhaObrigatoria = false;
    _accessToken = null;
    _refreshToken = null;
    _nome = null;
    _role = null;
    _tenantId = null;
    _email = null;
    _userId = null;

    await TokenStore.clear();
    final prefs = await SharedPreferences.getInstance();
    // Remove também os caches de ponto/agenda (chaves vizion_*) para não vazar dados a outro usuário no aparelho.
    for (final chave in prefs.getKeys().where((k) => k.startsWith('vizion_')).toList()) {
      await prefs.remove(chave);
    }
    await prefs.remove('nome');
    await prefs.remove('role');
    await prefs.remove('tenantId');
    await prefs.remove('email');
    await prefs.remove('userId');
    await prefs.remove('trocaSenhaObrigatoria');
  }

  /// Renova o access token com o refresh token (uso único; o servidor devolve um novo par).
  /// Chamadas simultâneas compartilham a mesma renovação.
  static Future<RenovacaoSessao> renovarSessao() {
    return _renovacaoEmAndamento ??= _renovar().whenComplete(() {
      _renovacaoEmAndamento = null;
    });
  }

  static Future<RenovacaoSessao> _renovar() async {
    final refresh = _refreshToken;
    if (refresh == null || refresh.isEmpty) return RenovacaoSessao.rejeitada;
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': refresh}),
          )
          .timeout(ApiClient.timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        _accessToken = data['accessToken'];
        _refreshToken = data['refreshToken'];
        await TokenStore.save(access: _accessToken, refresh: _refreshToken);
        return RenovacaoSessao.renovada;
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        return RenovacaoSessao.rejeitada;
      }
      return RenovacaoSessao.indisponivel;
    } catch (_) {
      return RenovacaoSessao.indisponivel;
    }
  }

  static Future<void> encerrarSessaoExpirada() async {
    await _limparSessaoLocal();
    await onSessionExpired?.call();
  }

  static void sinalizarTrocaDeSenhaObrigatoria() {
    if (_trocaSenhaObrigatoria) return;
    _trocaSenhaObrigatoria = true;
    onPasswordChangeRequired?.call();
  }

  /// Troca a senha (inclusive a temporária). Devolve null em sucesso ou a mensagem de erro.
  static Future<String?> trocarSenha(String senhaAtual, String novaSenha) async {
    try {
      final response = await ApiClient.post(
        Uri.parse('$baseUrl/auth/trocar-senha'),
        headers: getHeaders(),
        body: jsonEncode({'senhaAtual': senhaAtual, 'novaSenha': novaSenha}),
      );
      if (response.statusCode == 204 || response.statusCode == 200) {
        _trocaSenhaObrigatoria = false;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('trocaSenhaObrigatoria', false);
        // O servidor revoga os refresh tokens ao trocar a senha; o access token atual segue válido.
        _refreshToken = null;
        await TokenStore.clear();
        await TokenStore.save(access: _accessToken);
        return null;
      }
      try {
        final corpo = jsonDecode(utf8.decode(response.bodyBytes));
        if (corpo is Map && corpo['message'] is String) return corpo['message'];
      } catch (_) {}
      return 'Não foi possível alterar a senha.';
    } catch (_) {
      return 'Sem conexão com o servidor. Tente novamente.';
    }
  }

  // Generate headers for API requests
  static Map<String, String> getHeaders() {
    return {
      'Content-Type': 'application/json',
      if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
    };
  }

  // Local databases
  static final Map<int, List<String>> _fasesPhotos = {};

  // Fetch contractor's works from API
  static Future<List<Map<String, dynamic>>> fetchObras() async {
    try {
      final response = await ApiClient.get(
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
      logDebug('Erro ao carregar obras: $e');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchFases(int obraId) async {
    try {
      final response = await ApiClient.get(
        Uri.parse('$baseUrl/obra/$obraId/detalhar'),
        headers: getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));

        // Sync uploaded photo documents from server to mobile phase gallery
        final List<dynamic>? docs = data['documentos'];
        if (docs != null) {
          for (var doc in docs) {
            if (doc['tipo_documento'] == 'ARQUIVO') {
              final String name = doc['nome_arquivo'] ?? '';
              final String desc = doc['descricao_arquivo'] ?? '';
              final String url = doc['url_arquivo'] ?? '';
              if (url.isNotEmpty) {
                int? parsedFaseId;
                final nameMatch = RegExp(r'fase_(\d+)').firstMatch(name);
                if (nameMatch != null) {
                  parsedFaseId = int.tryParse(nameMatch.group(1)!);
                } else {
                  final descMatch = RegExp(r'fase\s+(\d+)').firstMatch(desc);
                  if (descMatch != null) {
                    parsedFaseId = int.tryParse(descMatch.group(1)!);
                  }
                }

                if (parsedFaseId != null) {
                  if (!_fasesPhotos.containsKey(parsedFaseId)) {
                    _fasesPhotos[parsedFaseId] = [];
                  }
                  if (!_fasesPhotos[parsedFaseId]!.contains(url)) {
                    _fasesPhotos[parsedFaseId]!.add(url);
                  }
                }
              }
            }
          }
        }

        final List<dynamic>? phases = data['fases'];
        if (phases != null && phases.isNotEmpty) {
          return phases.map((item) => Map<String, dynamic>.from(item)).toList();
        }
      }
      return [];
    } catch (e) {
      logDebug('Erro ao carregar fases do servidor: $e');
      rethrow;
    }
  }

  static Future<bool> transitionPhaseStatus(
    int obraId,
    int faseId,
    String acao,
  ) async {
    try {
      final response = await ApiClient.patch(
        Uri.parse('$baseUrl/fasesObra/$faseId/status'),
        headers: getHeaders(),
        body: jsonEncode({'acao': acao}),
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      logDebug('Erro ao salvar transicao de status no servidor: $e');
      return false;
    }
  }

  /// Envia a foto ao servidor. Só entra na galeria local se o servidor aceitar.
  static Future<bool> addPhasePhoto(
    int obraId,
    int faseId,
    String photoData,
  ) async {
    try {
      final response = await ApiClient.post(
        Uri.parse('$baseUrl/obra-fotos'),
        headers: getHeaders(),
        body: jsonEncode({
          'idObra': obraId,
          'idFase': faseId,
          'urlFoto': photoData,
          'descricao': 'Foto de progresso da fase $faseId',
        }),
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        logDebug('Erro do servidor ao salvar foto: ${response.statusCode}');
        return false;
      }
      _fasesPhotos.putIfAbsent(faseId, () => []).add(photoData);
      return true;
    } catch (e) {
      logDebug('Erro de conexao ao salvar foto no servidor: ${e.runtimeType}');
      return false;
    }
  }

  static List<String> getPhasePhotos(int faseId) {
    return _fasesPhotos[faseId] ?? [];
  }

  // Create a new work associated with this contractor
  static Future<bool> createObra(Map<String, dynamic> data) async {
    try {
      final response = await ApiClient.post(
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
      logDebug('Erro ao criar obra: $e');
      rethrow;
    }
  }

  // Delete current contractor account
  static Future<bool> deleteCurrentAccount() async {
    try {
      if (_userId == null) {
        await fetchProfile();
      }

      if (_userId != null) {
        final response = await ApiClient.delete(
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
      logDebug('Erro ao deletar conta: $e');
      return false;
    }
  }

  // --- Tarefas / Agenda Database Integration ---

  static Future<List<Map<String, dynamic>>> fetchTarefas({int? obraId}) async {
    try {
      final uri = obraId != null
          ? Uri.parse('$baseUrl/tarefas?obraId=$obraId')
          : Uri.parse('$baseUrl/tarefas');
      final response = await ApiClient.get(uri, headers: getHeaders());
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.map((item) => Map<String, dynamic>.from(item)).toList();
      }
      return [];
    } catch (e) {
      logDebug('Erro ao carregar tarefas do servidor: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> createTarefa(Map<String, dynamic> data) async {
    try {
      final response = await ApiClient.post(
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
      logDebug('Erro ao salvar tarefa no banco de dados: $e');
      return null;
    }
  }

  static Future<bool> toggleTarefaStatus(int id) async {
    try {
      final response = await ApiClient.patch(
        Uri.parse('$baseUrl/tarefas/$id/toggle'),
        headers: getHeaders(),
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      logDebug('Erro ao alternar status da tarefa no banco: $e');
      return false;
    }
  }

  static Future<bool> deleteTarefa(int id) async {
    try {
      final response = await ApiClient.delete(
        Uri.parse('$baseUrl/tarefas/$id'),
        headers: getHeaders(),
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      logDebug('Erro ao deletar tarefa no banco: $e');
      return false;
    }
  }
}
