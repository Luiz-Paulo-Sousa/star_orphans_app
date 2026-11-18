import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class CorporationModuleWidget extends StatefulWidget {
  final Map<String, dynamic>? profileData;
  final String apiBaseUrl;
  final VoidCallback? onProfileRefresh;

  const CorporationModuleWidget({
    super.key,
    this.profileData,
    this.apiBaseUrl = 'http://26.239.180.177:8020',
    this.onProfileRefresh,
  });

  @override
  State<CorporationModuleWidget> createState() => _CorporationModuleWidgetState();
}

class _CorporationModuleWidgetState extends State<CorporationModuleWidget> {
  static const Color _cyanColor = Color(0xFF00D2FF);
  static const Color _greenAccent = Color(0xFF00FF66);
  static const Color _amberAccent = Color(0xFFFFB800);
  static const Color _redAccent = Color(0xFFFF3333);
  static const Color _darkBg = Color(0xFF0A0D12);
  static const Color _panelBg = Color(0xD912161F);
  static const Color _cardBg = Color(0xFF151922);

  bool _isLoading = true;
  String? _errorMessage;

  // Dados retornados da API
  bool _hasCorporation = false;
  Map<String, dynamic>? _corporationData;
  bool _hasPendingApplication = false;
  Map<String, dynamic>? _pendingApplication;

  // Alternador para testes rápidos no VS Code
  bool _simulateNoCorporation = false;

  // Navegação de telas no módulo: 'initial', 'apply', 'create'
  String _currentView = 'initial';

  // Estados do Passo 2 (Diretório e Inscrição)
  final TextEditingController _searchController = TextEditingController();
  String _searchFilter = '';
  List<Map<String, dynamic>> _activeCorporations = [];
  bool _isLoadingCorps = false;
  String? _corpsErrorMessage;
  int? _selectedCorpUid;
  bool _isSubmittingAction = false;

  @override
  void initState() {
    super.initState();
    _fetchCorporationStatus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int get _pilotUid {
    final op = widget.profileData?['operator'];
    if (op != null) {
      final uid = op['account_id'] ?? op['pilot_uid'] ?? op['id'];
      if (uid != null) return int.tryParse(uid.toString()) ?? 536870915;
    }
    return 536870915;
  }

  String _formatCredits(dynamic value) {
    if (value == null) return '0';
    final n = int.tryParse(value.toString()) ?? 0;
    return n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  String _formatDateTime(dynamic value) {
    if (value == null) return '--/--/----';
    try {
      final dt = DateTime.parse(value.toString()).toLocal();
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year.toString();
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$day/$month/$year $hour:$minute';
    } catch (_) {
      return value.toString();
    }
  }

  /// Consulta status corporativo do piloto
  Future<void> _fetchCorporationStatus({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final uri = Uri.parse('${widget.apiBaseUrl}/api/corporation/status/$_pilotUid');
      final response = await http.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['status'] == 'sucesso') {
          final data = decoded['data'] ?? {};
          setState(() {
            _hasCorporation = data['has_corporation'] == true;
            _corporationData = data['corporation'];
            _hasPendingApplication = data['has_pending_application'] == true;
            _pendingApplication = data['pending_application'];
            _isLoading = false;
          });
          return;
        }
      }
      setState(() {
        _errorMessage = 'Falha ao carregar status corporativo: ${response.statusCode}';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro de conexão com o servidor: $e';
        _isLoading = false;
      });
    }
  }

  /// Consulta a lista de corporações ativas para o Passo 2
  Future<void> _fetchActiveCorporations() async {
    setState(() {
      _isLoadingCorps = true;
      _corpsErrorMessage = null;
    });

    try {
      final uri = Uri.parse('${widget.apiBaseUrl}/api/corporation/list');
      final response = await http.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['status'] == 'sucesso') {
          final list = List<Map<String, dynamic>>.from(decoded['data'] ?? []);
          setState(() {
            _activeCorporations = list;
            _isLoadingCorps = false;
          });
          return;
        }
      }
      setState(() {
        _corpsErrorMessage = 'Falha ao obter diretório de corporações.';
        _isLoadingCorps = false;
      });
    } catch (e) {
      setState(() {
        _corpsErrorMessage = 'Erro ao conectar ao servidor: $e';
        _isLoadingCorps = false;
      });
    }
  }

  /// Confirma e envia solicitação de ingresso (Passo 2)
  Future<void> _submitApplication() async {
    if (_selectedCorpUid == null || _isSubmittingAction) return;

    final selectedCorp = _activeCorporations.firstWhere(
      (c) => c['corporation_uid'] == _selectedCorpUid,
      orElse: () => {},
    );
    if (selectedCorp.isEmpty) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: _cyanColor, width: 1.5),
          borderRadius: BorderRadius.circular(6),
        ),
        title: Row(
          children: [
            const Icon(Icons.send_rounded, color: _cyanColor, size: 20),
            const SizedBox(width: 8),
            Text(
              'CONFIRMAR SOLICITAÇÃO',
              style: GoogleFonts.shareTechMono(
                color: _cyanColor,
                fontWeight: FontWeight.bold,
                fontSize: 15,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Deseja enviar uma solicitação oficial de ingresso para a corporação "${selectedCorp['name']}"?',
              style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _panelBg,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDialogRow('LÍDER FUNDADOR:', selectedCorp['founder_name'] ?? 'Desconhecido'),
                  const SizedBox(height: 4),
                  _buildDialogRow(
                    'TAXA DE ADMISSÃO:',
                    (selectedCorp['admission_fee'] ?? 0) > 0
                        ? '${_formatCredits(selectedCorp['admission_fee'])} CR'
                        : 'ISENTA',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Uma notificação direta será transmitida ao comandante fundador. Você deverá aguardar a análise.',
              style: GoogleFonts.shareTechMono(color: Colors.white60, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('CANCELAR', style: GoogleFonts.shareTechMono(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _cyanColor.withOpacity(0.2),
              foregroundColor: _cyanColor,
              side: const BorderSide(color: _cyanColor),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'ENVIAR SOLICITAÇÃO',
              style: GoogleFonts.shareTechMono(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isSubmittingAction = true;
    });

    try {
      final uri = Uri.parse('${widget.apiBaseUrl}/api/corporation/apply');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'pilot_uid': _pilotUid,
          'corporation_uid': _selectedCorpUid,
        }),
      ).timeout(const Duration(seconds: 10));

      final decoded = json.decode(response.body);

      if (response.statusCode == 200 && decoded['status'] == 'sucesso') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF0D3B2E),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: _greenAccent),
                borderRadius: BorderRadius.circular(4),
              ),
              content: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: _greenAccent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      decoded['mensagem'] ?? 'Solicitação enviada com sucesso! Aguarde a aprovação.',
                      style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Atualiza status corporativo (que agora terá has_pending_application = true)
        setState(() {
          _currentView = 'initial';
          _selectedCorpUid = null;
        });
        await _fetchCorporationStatus(silent: true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF421515),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: _redAccent),
                borderRadius: BorderRadius.circular(4),
              ),
              content: Text(
                decoded['mensagem'] ?? 'Falha ao enviar solicitação.',
                style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 12),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF421515),
            content: Text(
              'Erro ao conectar: $e',
              style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingAction = false;
        });
      }
    }
  }

  /// Confirma e cancela solicitação de ingresso pendente (Passo 3)
  Future<void> _confirmCancelApplication() async {
    if (_isSubmittingAction) return;

    final corpName = _pendingApplication?['corporation_name'] ?? 'Corporação';

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: _redAccent, width: 1.5),
          borderRadius: BorderRadius.circular(6),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: _redAccent, size: 20),
            const SizedBox(width: 8),
            Text(
              'CANCELAR SOLICITAÇÃO',
              style: GoogleFonts.shareTechMono(
                color: _redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 15,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Deseja realmente cancelar sua solicitação de admissão na corporação "$corpName"?',
              style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            Text(
              'Uma notificação oficial de cancelamento será transmitida ao comandante fundador.',
              style: GoogleFonts.shareTechMono(color: Colors.white60, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('MANTER PEDIDO', style: GoogleFonts.shareTechMono(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _redAccent.withOpacity(0.2),
              foregroundColor: _redAccent,
              side: const BorderSide(color: _redAccent),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'CANCELAR SOLICITAÇÃO',
              style: GoogleFonts.shareTechMono(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isSubmittingAction = true;
    });

    try {
      final uri = Uri.parse('${widget.apiBaseUrl}/api/corporation/cancel-application');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'pilot_uid': _pilotUid}),
      ).timeout(const Duration(seconds: 10));

      final decoded = json.decode(response.body);

      if (response.statusCode == 200 && decoded['status'] == 'sucesso') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF0D3B2E),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: _greenAccent),
                borderRadius: BorderRadius.circular(4),
              ),
              content: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: _greenAccent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      decoded['mensagem'] ?? 'Solicitação cancelada com sucesso.',
                      style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Atualiza status corporativo (que agora terá has_pending_application = false)
        await _fetchCorporationStatus(silent: true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF421515),
              content: Text(
                decoded['mensagem'] ?? 'Falha ao cancelar solicitação.',
                style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 12),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF421515),
            content: Text(
              'Erro ao conectar: $e',
              style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingAction = false;
        });
      }
    }
  }

  Widget _buildDialogRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.shareTechMono(color: Colors.white54, fontSize: 11)),
        Text(value, style: GoogleFonts.shareTechMono(color: _cyanColor, fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: _cyanColor),
            const SizedBox(height: 16),
            Text(
              'CONSULTANDO REGISTROS CORPORATIVOS...',
              style: GoogleFonts.shareTechMono(color: _cyanColor, fontSize: 13, letterSpacing: 1.2),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _panelBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _redAccent.withOpacity(0.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: _redAccent, size: 40),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.shareTechMono(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _fetchCorporationStatus(),
                icon: const Icon(Icons.refresh, size: 16),
                label: Text('TENTAR NOVAMENTE', style: GoogleFonts.shareTechMono()),
                style: ElevatedButton.styleFrom(backgroundColor: _redAccent.withOpacity(0.8)),
              ),
            ],
          ),
        ),
      );
    }

    // Se o jogador estiver simulando sem corporação ou realmente não tiver
    final bool effectiveHasCorp = _hasCorporation && !_simulateNoCorporation;

    return Container(
      color: _darkBg,
      child: Column(
        children: [
          _buildHeaderBar(effectiveHasCorp),
          Expanded(
            child: effectiveHasCorp
                ? _buildAffiliatedView()
                : _buildFreelancerView(),
          ),
        ],
      ),
    );
  }

  /// Barra superior do módulo
  Widget _buildHeaderBar(bool effectiveHasCorp) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _panelBg,
        border: Border(bottom: BorderSide(color: _cyanColor.withOpacity(0.3), width: 1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.corporate_fare_outlined, color: _cyanColor, size: 20),
          const SizedBox(width: 10),
          Text(
            'MÓDULO DE CORPORAÇÃO',
            style: GoogleFonts.shareTechMono(
              color: _cyanColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const Spacer(),

          // Botão de simulação para testes rápidos no VS Code
          if (_hasCorporation)
            InkWell(
              onTap: () {
                setState(() {
                  _simulateNoCorporation = !_simulateNoCorporation;
                  _currentView = 'initial';
                });
              },
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _simulateNoCorporation
                      ? _amberAccent.withOpacity(0.2)
                      : Colors.transparent,
                  border: Border.all(
                    color: _simulateNoCorporation ? _amberAccent : Colors.white24,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _simulateNoCorporation ? Icons.check_box : Icons.check_box_outline_blank,
                      color: _simulateNoCorporation ? _amberAccent : Colors.white54,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'TESTE SEM CORP',
                      style: GoogleFonts.shareTechMono(
                        color: _simulateNoCorporation ? _amberAccent : Colors.white54,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(width: 8),

          IconButton(
            icon: const Icon(Icons.refresh, color: _cyanColor, size: 18),
            tooltip: 'Atualizar',
            onPressed: () => _fetchCorporationStatus(),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  /// Visão do jogador Freelancer (SEM corporação)
  Widget _buildFreelancerView() {
    // PASSO 3: Se possui solicitação pendente e não está simulando o contrário
    if (_hasPendingApplication && _pendingApplication != null && !_simulateNoCorporation) {
      return _buildPendingApplicationView();
    }

    // PASSO 2: Tela de Inscrição em Corporação (Diretório aberto com filtro)
    if (_currentView == 'apply') {
      return _buildApplyView();
    }

    // PASSO 4: Criação de Corporação (Em breve)
    if (_currentView == 'create') {
      return _buildPlaceholderSubView(
        'CRIAR UMA CORPORAÇÃO',
        'Etapa 4 em desenvolvimento: aqui será selecionada a estação base com validação da taxa de abertura de 1.000.000 CR.',
        Icons.add_business_outlined,
      );
    }

    // PASSO 1: Menu inicial de Freelancer
    return _buildFreelancerInitialView();
  }

  /// PASSO 1: Menu de Opções do Freelancer
  Widget _buildFreelancerInitialView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Badge de status
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _amberAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: _amberAccent.withOpacity(0.6)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_outline, color: _amberAccent, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'STATUS: FREELANCER INDEPENDENTE',
                        style: GoogleFonts.shareTechMono(
                          color: _amberAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Card principal com mensagem informativa básica
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: _panelBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _cyanColor.withOpacity(0.4), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: _cyanColor.withOpacity(0.08),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _cyanColor.withOpacity(0.1),
                        border: Border.all(color: _cyanColor.withOpacity(0.6), width: 1.5),
                      ),
                      child: const Icon(
                        Icons.corporate_fare_rounded,
                        color: _cyanColor,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'NENHUMA AFILIAÇÃO CORPORATIVA',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.shareTechMono(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Você atualmente opera de forma autônoma na galáxia e não pertence a nenhuma corporação estelar registrada.\n\n'
                      'Fazer parte de uma corporação permite acesso a operações estratégicas conjuntas, frotas combinadas, benefícios econômicos e bases estelares dedicadas.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.shareTechMono(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Opção 1: Criar Corporação
              _buildActionCard(
                title: 'CRIAR UMA CORPORAÇÃO',
                badgeText: 'TAXA: 1.000.000 CR',
                badgeColor: _greenAccent,
                description:
                    'Funde sua própria corporação estelar, defina o nome oficial, estabeleça uma estação base no setor e recrute pilotos para sua tripulação.',
                icon: Icons.add_business_outlined,
                accentColor: _greenAccent,
                buttonLabel: 'INICIAR FUNDAÇÃO',
                onTap: () {
                  setState(() {
                    _currentView = 'create';
                  });
                },
              ),

              const SizedBox(height: 16),

              // Opção 2: Inscrever-se numa Corporação
              _buildActionCard(
                title: 'INSCREVER-SE NUMA CORPORAÇÃO',
                badgeText: 'DIRETÓRIO ABERTO',
                badgeColor: _cyanColor,
                description:
                    'Consulte a lista de corporações ativas na galáxia, pesquise por nome, confira as taxas de admissão e envie uma solicitação de ingresso diretamente ao fundador.',
                icon: Icons.group_add_outlined,
                accentColor: _cyanColor,
                buttonLabel: 'CONSULTAR DIRETÓRIO',
                onTap: () {
                  setState(() {
                    _currentView = 'apply';
                    _selectedCorpUid = null;
                    _searchFilter = '';
                    _searchController.clear();
                  });
                  _fetchActiveCorporations();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// PASSO 2: Tela do Diretório de Corporações Ativas com Filtro e Confirmação
  Widget _buildApplyView() {
    // Filtragem em tempo real por nome ou parte do nome
    final filteredCorps = _activeCorporations.where((c) {
      final name = (c['name'] ?? '').toString().toLowerCase();
      return name.contains(_searchFilter.toLowerCase().trim());
    }).toList();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Column(
          children: [
            // Barra superior de navegação da sub-tela
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _panelBg,
                border: Border(bottom: BorderSide(color: Colors.white12)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: _cyanColor, size: 20),
                    tooltip: 'Voltar',
                    onPressed: () {
                      setState(() {
                        _currentView = 'initial';
                        _selectedCorpUid = null;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'INSCREVER-SE NUMA CORPORAÇÃO',
                          style: GoogleFonts.shareTechMono(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                        Text(
                          'Selecione uma corporação ativa para enviar sua solicitação ao fundador',
                          style: GoogleFonts.shareTechMono(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Campo de busca / filtro por nome
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: _darkBg,
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() {
                    _searchFilter = val;
                  });
                },
                style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: _cardBg,
                  hintText: 'Buscar corporação pelo nome ou termo...',
                  hintStyle: GoogleFonts.shareTechMono(color: Colors.white38, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: _cyanColor, size: 20),
                  suffixIcon: _searchFilter.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchFilter = '';
                            });
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: _cyanColor.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: _cyanColor, width: 1.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),

            // Lista de corporações ativas
            Expanded(
              child: _isLoadingCorps
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: _cyanColor),
                          const SizedBox(height: 12),
                          Text(
                            'CARREGANDO DIRETÓRIO DE CORPORAÇÕES...',
                            style: GoogleFonts.shareTechMono(color: _cyanColor, fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  : _corpsErrorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _corpsErrorMessage!,
                                style: GoogleFonts.shareTechMono(color: _redAccent, fontSize: 13),
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton(
                                onPressed: _fetchActiveCorporations,
                                style: ElevatedButton.styleFrom(backgroundColor: _cyanColor),
                                child: Text('TENTAR NOVAMENTE', style: GoogleFonts.shareTechMono()),
                              ),
                            ],
                          ),
                        )
                      : filteredCorps.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.search_off_rounded, color: Colors.white38, size: 40),
                                  const SizedBox(height: 10),
                                  Text(
                                    _searchFilter.isEmpty
                                        ? 'NENHUMA CORPORAÇÃO ATIVA ENCONTRADA'
                                        : 'NENHUMA CORPORAÇÃO ENCONTRADA COM "$_searchFilter"',
                                    style: GoogleFonts.shareTechMono(color: Colors.white54, fontSize: 13),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: filteredCorps.length,
                              itemBuilder: (context, index) {
                                final corp = filteredCorps[index];
                                final int corpUid = corp['corporation_uid'];
                                final bool isSelected = _selectedCorpUid == corpUid;
                                final num fee = corp['admission_fee'] ?? 0;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _selectedCorpUid = corpUid;
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: isSelected ? _panelBg : _cardBg,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isSelected ? _cyanColor : Colors.white12,
                                          width: isSelected ? 1.5 : 1,
                                        ),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: _cyanColor.withOpacity(0.18),
                                                  blurRadius: 10,
                                                  spreadRadius: 1,
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                isSelected
                                                    ? Icons.radio_button_checked
                                                    : Icons.radio_button_off,
                                                color: isSelected ? _cyanColor : Colors.white38,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  (corp['name'] ?? 'CORPORAÇÃO').toString().toUpperCase(),
                                                  style: GoogleFonts.shareTechMono(
                                                    color: isSelected ? _cyanColor : Colors.white,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 1.1,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: fee > 0
                                                      ? _amberAccent.withOpacity(0.15)
                                                      : _greenAccent.withOpacity(0.15),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(
                                                    color: fee > 0
                                                        ? _amberAccent.withOpacity(0.6)
                                                        : _greenAccent.withOpacity(0.6),
                                                  ),
                                                ),
                                                child: Text(
                                                  fee > 0 ? 'TAXA: ${_formatCredits(fee)} CR' : 'TAXA: ISENTA',
                                                  style: GoogleFonts.shareTechMono(
                                                    color: fee > 0 ? _amberAccent : _greenAccent,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Wrap(
                                            spacing: 16,
                                            runSpacing: 6,
                                            children: [
                                              _buildMetaPill(
                                                Icons.person_pin_outlined,
                                                'LÍDER:',
                                                corp['founder_name'] ?? 'Comandante',
                                              ),
                                              _buildMetaPill(
                                                Icons.hub_outlined,
                                                'ESTAÇÃO BASE:',
                                                corp['station_name'] ?? 'Não Definida',
                                              ),
                                              _buildMetaPill(
                                                Icons.people_outline,
                                                'MEMBROS:',
                                                '${corp['members_count'] ?? 0}',
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
            ),

            // Barra inferior com botões de ação
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _panelBg,
                border: Border(top: BorderSide(color: _cyanColor.withOpacity(0.3))),
              ),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _currentView = 'initial';
                        _selectedCorpUid = null;
                      });
                    },
                    icon: const Icon(Icons.arrow_back, size: 16, color: Colors.white70),
                    label: Text(
                      'VOLTAR',
                      style: GoogleFonts.shareTechMono(color: Colors.white70, fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: (_selectedCorpUid != null && !_isSubmittingAction)
                          ? _submitApplication
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _cyanColor.withOpacity(0.2),
                        foregroundColor: _cyanColor,
                        side: BorderSide(
                          color: _selectedCorpUid != null ? _cyanColor : Colors.white12,
                          width: 1.2,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      icon: _isSubmittingAction
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: _cyanColor),
                            )
                          : const Icon(Icons.send_rounded, size: 16),
                      label: Text(
                        _selectedCorpUid == null
                            ? 'SELECIONE UMA CORPORAÇÃO'
                            : 'CONFIRMAR INSCRIÇÃO',
                        style: GoogleFonts.shareTechMono(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// PASSO 3: Tela exibida quando o jogador possui uma solicitação pendente de aprovação
  Widget _buildPendingApplicationView() {
    final pending = _pendingApplication ?? {};
    final String corpName = pending['corporation_name'] ?? 'Corporação';
    final String founderName = pending['founder_name'] ?? 'Fundador';
    final num fee = pending['admission_fee'] ?? 0;
    final String formattedDate = _formatDateTime(pending['date_time']);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Badge de status pendente
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _amberAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: _amberAccent.withOpacity(0.7)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.hourglass_top_rounded, color: _amberAccent, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'STATUS: SOLICITAÇÃO PENDENTE DE APROVAÇÃO',
                        style: GoogleFonts.shareTechMono(
                          color: _amberAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Card principal com detalhes da solicitação
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: _panelBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _amberAccent.withOpacity(0.5), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: _amberAccent.withOpacity(0.08),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _amberAccent.withOpacity(0.12),
                        border: Border.all(color: _amberAccent.withOpacity(0.6), width: 1.5),
                      ),
                      child: const Icon(
                        Icons.hourglass_empty_rounded,
                        color: _amberAccent,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      corpName.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.shareTechMono(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'SOLICITAÇÃO DE ADMISSÃO EM PROCESSAMENTO',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.shareTechMono(
                        color: _amberAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const Divider(color: Colors.white24, height: 26),

                    // Linhas de detalhe
                    _buildInfoRow('DESTINO DA SOLICITAÇÃO:', corpName),
                    const SizedBox(height: 8),
                    _buildInfoRow('LÍDER DESTINATÁRIO:', founderName),
                    const SizedBox(height: 8),
                    _buildInfoRow('DATA / HORA DA TRANSMISSÃO:', formattedDate),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      'TAXA DE ADMISSÃO:',
                      fee > 0 ? '${_formatCredits(fee)} CR' : 'ISENTA',
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow('ESTADO ATUAL:', 'AGUARDANDO APROVAÇÃO DO FUNDADOR'),

                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _cardBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline, color: _cyanColor, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Sua solicitação de ingresso foi transmitida ao comandante fundador. '
                              'Enquanto seu pedido estiver pendente, você não pode criar uma nova corporação '
                              'nem se inscrever em outra organização.\n\n'
                              'Caso deseje escolher outra corporação, cancele esta solicitação abaixo.',
                              style: GoogleFonts.shareTechMono(
                                color: Colors.white70,
                                fontSize: 11,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Botão para Cancelar a Solicitação
              ElevatedButton.icon(
                onPressed: _isSubmittingAction ? null : _confirmCancelApplication,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _redAccent.withOpacity(0.18),
                  foregroundColor: _redAccent,
                  side: const BorderSide(color: _redAccent, width: 1.2),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                icon: _isSubmittingAction
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: _redAccent),
                      )
                    : const Icon(Icons.cancel_outlined, size: 18),
                label: Text(
                  'CANCELAR SOLICITAÇÃO DE INGRESSO',
                  style: GoogleFonts.shareTechMono(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Botão secundário para verificar novamente
              TextButton.icon(
                onPressed: () => _fetchCorporationStatus(),
                icon: const Icon(Icons.refresh, size: 16, color: _cyanColor),
                label: Text(
                  'VERIFICAR STATUS NOVAMENTE',
                  style: GoogleFonts.shareTechMono(color: _cyanColor, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaPill(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white54),
        const SizedBox(width: 4),
        Text(
          '$label ',
          style: GoogleFonts.shareTechMono(color: Colors.white54, fontSize: 11),
        ),
        Text(
          value,
          style: GoogleFonts.shareTechMono(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// Card de ação reutilizável (usado no Passo 1)
  Widget _buildActionCard({
    required String title,
    required String badgeText,
    required Color badgeColor,
    required String description,
    required IconData icon,
    required Color accentColor,
    required String buttonLabel,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accentColor.withOpacity(0.4), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: accentColor.withOpacity(0.4)),
                ),
                child: Icon(icon, color: accentColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.shareTechMono(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: badgeColor.withOpacity(0.5)),
                ),
                child: Text(
                  badgeText,
                  style: GoogleFonts.shareTechMono(
                    color: badgeColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: GoogleFonts.shareTechMono(
              color: Colors.white70,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor.withOpacity(0.2),
              foregroundColor: accentColor,
              side: BorderSide(color: accentColor, width: 1.2),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16),
                const SizedBox(width: 8),
                Text(
                  buttonLabel,
                  style: GoogleFonts.shareTechMono(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Visão temporária para telas filhas (preparação para passo 4)
  Widget _buildPlaceholderSubView(String title, String subtitle, IconData icon) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 520),
        decoration: BoxDecoration(
          color: _panelBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _cyanColor.withOpacity(0.4)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _cyanColor, size: 48),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.shareTechMono(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.shareTechMono(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _currentView = 'initial';
                });
              },
              icon: const Icon(Icons.arrow_back, size: 16, color: _cyanColor),
              label: Text(
                'VOLTAR AO MENU DE OPÇÕES',
                style: GoogleFonts.shareTechMono(color: _cyanColor, fontSize: 12),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _cyanColor),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Visão caso o jogador já pertença a uma corporação
  Widget _buildAffiliatedView() {
    final corp = _corporationData ?? {};
    final String corpName = corp['name'] ?? 'CORPORAÇÃO';
    final String role = (corp['role'] ?? 'Membro').toString().toUpperCase();
    final String stationName = corp['station_name'] ?? 'Não Definida';
    final String founderName = corp['founder_name'] ?? 'Desconhecido';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _panelBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _cyanColor.withOpacity(0.5)),
                  boxShadow: [
                    BoxShadow(color: _cyanColor.withOpacity(0.08), blurRadius: 12),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.shield_outlined, color: _cyanColor, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                corpName.toUpperCase(),
                                style: GoogleFonts.shareTechMono(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.3,
                                ),
                              ),
                              Text(
                                'SUA CORPORAÇÃO ATIVA',
                                style: GoogleFonts.shareTechMono(
                                  color: _greenAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _cyanColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: _cyanColor.withOpacity(0.5)),
                          ),
                          child: Text(
                            role,
                            style: GoogleFonts.shareTechMono(
                              color: _cyanColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white24, height: 26),
                    _buildInfoRow('ESTAÇÃO BASE:', stationName),
                    const SizedBox(height: 8),
                    _buildInfoRow('LÍDER FUNDADOR:', founderName),
                    const SizedBox(height: 8),
                    _buildInfoRow('STATUS:', 'EM OPERAÇÃO ATIVA'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.shareTechMono(color: Colors.white54, fontSize: 12),
        ),
        Text(
          value,
          style: GoogleFonts.shareTechMono(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
