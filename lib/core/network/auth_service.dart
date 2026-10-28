import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show ValueNotifier, visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../log.dart';
import 'api_client.dart';
import 'token_store.dart';

enum RenovacaoSessao { renovada, rejeitada, indisponivel }

/// O que uma fase pode fazer agora, segundo a API (fluxo único das fases).
class FaseFluxo {
  final List<String> acoesPermitidas;
  final String? motivoBloqueio;

  const FaseFluxo({this.acoesPermitidas = const [], this.motivoBloqueio});

  bool permite(String acao) => acoesPermitidas.contains(acao);
}

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

  /// Chave da foto de perfil no storage (null = sem foto). Notifica as telas quando muda.
  static final ValueNotifier<String?> avatarKey = ValueNotifier<String?>(null);

  static String? get avatarUrl {
    final key = avatarKey.value;
    return (key == null || key.isEmpty) ? null : mediaUrl(key);
  }

  static Future<void> _definirAvatar(String? key) async {
    avatarKey.value = (key == null || key.isEmpty) ? null : key;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (avatarKey.value == null) {
        await prefs.remove('avatarKey');
      } else {
        await prefs.setString('avatarKey', avatarKey.value!);
      }
    } catch (_) {}
  }

  static String? get accessToken => _accessToken;
  static String? get tenantId => _tenantId;
  static String? get nome => _nome;
  static String? get role => _role;
  static String? get currentUserEmail => _email;
  static int? get userId => _userId;
  static bool get mustChangePassword => _trocaSenhaObrigatoria;

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
      avatarKey.value = prefs.getString('avatarKey');
      _trocaSenhaObrigatoria = prefs.getBool('trocaSenhaObrigatoria') ?? false;
      return _accessToken != null;
    } catch (e) {
      logDebug('Erro ao inicializar AuthService: $e');
      return false;
    }
  }

  // login
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
        await _definirAvatar(data['avatarKey']?.toString());
      }
    } catch (e) {
      logDebug('Erro ao carregar perfil /me: $e');
    }
  }

  static Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String cpf,
  }) async {
    try {
      // chama a api para registrar um novo empreiteiro
      final response = await http.post(
        Uri.parse('$baseUrl/empreiteiro'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name.trim(),
          'email': email.toLowerCase().trim(),
          'documento': cpf.replaceAll(
            RegExp(r'\D'),
            '',
          ),
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

  static const Set<String> _preferenciasDoAparelho = {
    'vizion_theme',
    'vizion_font_scale',
    'vizion_bold_text',
    'vizion_reduce_motion',
    'vizion_last_email',
  };

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
    // Preferências do aparelho (tema, acessibilidade e último e-mail) continuam: quem aumentou a letra
    // não pode perder a escolha ao sair.
    for (final chave in prefs.getKeys().where((k) => k.startsWith('vizion_') && !_preferenciasDoAparelho.contains(k)).toList()) {
      await prefs.remove(chave);
    }
    await prefs.remove('nome');
    await prefs.remove('role');
    await prefs.remove('tenantId');
    await prefs.remove('email');
    await prefs.remove('userId');
    await prefs.remove('avatarKey');
    avatarKey.value = null;
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

  static Map<String, String> getHeaders() {
    return {
      'Content-Type': 'application/json',
      if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
    };
  }

  // Gerencia as obras e fases e puxa do banco
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
    return (await transitionPhase(faseId, acao)).ok;
  }

  /// Executa uma ação do fluxo das fases (INICIAR, PAUSAR, RETOMAR, FINALIZAR). Quando o servidor recusa
  /// (ex.: a fase anterior ainda não foi finalizada), devolve o motivo para mostrar ao usuário.
  static Future<({bool ok, String? mensagem})> transitionPhase(int faseId, String acao) async {
    try {
      final response = await ApiClient.patch(
        Uri.parse('$baseUrl/fasesObra/$faseId/status'),
        headers: getHeaders(),
        body: jsonEncode({'acao': acao}),
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        return (ok: true, mensagem: null);
      }
      String? motivo;
      try {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        if (body is Map && body['message'] is String) motivo = body['message'] as String;
      } catch (_) {}
      if (response.statusCode == 403) {
        motivo ??= 'Seu perfil não pode alterar esta fase.';
      }
      return (ok: false, mensagem: motivo);
    } catch (e) {
      logDebug('Erro ao salvar transicao de status no servidor: $e');
      return (ok: false, mensagem: null);
    }
  }

  /// Fluxo único das fases, definido pela API: o que cada fase pode fazer agora e, quando travada, o porquê.
  /// Mobile, desktop e web desenham os botões a partir desta resposta.
  static Future<Map<int, FaseFluxo>> fetchPhaseFlow(int obraId) async {
    final response = await ApiClient.get(
      Uri.parse('$baseUrl/fasesObra/obra/$obraId/fluxo'),
      headers: getHeaders(),
    );
    if (response.statusCode != 200) {
      throw Exception('Não foi possível carregar o fluxo das fases (${response.statusCode}).');
    }
    final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
    final fluxo = <int, FaseFluxo>{};
    for (final item in data) {
      final map = Map<String, dynamic>.from(item as Map);
      final id = map['id_fase'];
      if (id is! num) continue;
      fluxo[id.toInt()] = FaseFluxo(
        acoesPermitidas: List<String>.from(map['acoes_permitidas'] ?? const []),
        motivoBloqueio: map['motivo_bloqueio']?.toString(),
      );
    }
    return fluxo;
  }

  /// Envia a foto de perfil e atualiza o avatar em todas as telas.
  static Future<String> uploadAvatar(List<int> bytes, String fileName) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/auth/avatar'));
    request.headers.addAll(Map<String, String>.from(getHeaders())..remove('Content-Type'));
    request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 200) {
      String? motivo;
      try {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        if (body is Map && body['message'] is String) motivo = body['message'] as String;
      } catch (_) {}
      throw Exception(motivo ?? 'Não foi possível enviar a foto (${response.statusCode}).');
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    final key = data['avatarKey']?.toString();
    await _definirAvatar(key);
    return key ?? '';
  }

  // envio de fotos e progresso
  static Future<List<Map<String, dynamic>>> fetchObraPhotos(int obraId) async {
    final response = await ApiClient.get(
      Uri.parse('$baseUrl/obra-fotos/obra/$obraId'),
      headers: getHeaders(),
    );
    if (response.statusCode != 200) {
      throw Exception('Não foi possível carregar as fotos da obra (${response.statusCode}).');
    }
    final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
    return data.map((item) => Map<String, dynamic>.from(item)).toList();
  }

  /// Envia a foto ao storage e a registra na fase. Lança exceção se qualquer etapa falhar.
  /// O upload multipart usa http direto (ApiClient não suporta multipart), então não renova token em 401.
  static Future<Map<String, dynamic>> addPhasePhoto(
    int obraId,
    int faseId,
    List<int> bytes,
    String fileName, {
    String? descricao,
  }) async {
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
    final response = await ApiClient.post(
      Uri.parse('$baseUrl/obra-fotos'),
      headers: getHeaders(),
      body: jsonEncode({
        'idObra': obraId,
        'idFase': faseId,
        'urlFoto': key,
        // Observação do andamento digitada junto com a foto (o campo da tela limita a 500 caracteres).
        'descricao': (descricao == null || descricao.isEmpty)
            ? 'Foto de progresso da fase $faseId'
            : descricao,
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

  // calendario e solicitacoes de material
  static Future<List<Map<String, dynamic>>> fetchCalendarioEvents({
    int? obraId,
  }) async {
    try {
      // Chama a API para buscar os eventos do calendário
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
      // Chama a API para buscar as solicitações de material
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
      // Chama a API para criar a solicitação de material
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
      // Chama a API para aprovar a solicitação de material
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
