// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class ContractsModuleWidget extends StatefulWidget {
  final Map<String, dynamic>? profileData;
  final String apiBaseUrl;
  final VoidCallback? onProfileRefresh;

  const ContractsModuleWidget({
    super.key,
    this.profileData,
    this.apiBaseUrl = 'http://26.239.180.177:8020',
    this.onProfileRefresh,
  });

  @override
  State<ContractsModuleWidget> createState() => _ContractsModuleWidgetState();
}

class _ContractsModuleWidgetState extends State<ContractsModuleWidget> {
  // Paleta de cores oficial do Star Orphans
  static const Color _cyanColor = Color(0xFF00D2FF);
  static const Color _greenAccent = Color(0xFF00FF66);
  static const Color _amberAccent = Color(0xFFFFB800);
  static const Color _redAccent = Color(0xFFFF3333);
  static const Color _purpleAccent = Color(0xFFBD00FF);
  static const Color _panelBg = Color(0xD912161F);
  static const Color _cardBg = Color(0xFF151922);
  static const Color _cardBgSelected = Color(0xFF1C2433);

  // Modo Principal: 'CONTRATADO' ou 'CONTRATANTE'
  String _mainMode = 'CONTRATADO';

  // Sub-aba do Contratado: 'DISPONIVEIS' ou 'ATIVOS'
  String _contractorSubTab = 'DISPONIVEIS';

  // Filtros
  String _filterCareer = 'TODAS';
  String _filterType = 'TODOS';
  String _filterStation = 'TODAS';
  final TextEditingController _searchController = TextEditingController();
  bool _showFiltersBar = false;

  // Lista de estações da tabela orbit_stations (com fallback inicial)
  List<String> _stationOptions = ['TODAS'];
  List<Map<String, dynamic>> _stationList = [];

  // Estado de carregamento
  bool _isLoading = false;

  // Contrato atualmente selecionado (inicia como null para abrir SEMPRE na lista)
  Map<String, dynamic>? _selectedContract;

  // Listas de contratos
  List<Map<String, dynamic>> _availableContracts = [];
  List<Map<String, dynamic>> _activeContracts = [];
  List<Map<String, dynamic>> _myCreatedContracts = [];

  @override
  void initState() {
    super.initState();
    _fetchStations();
    _fetchContractsData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int _getPilotUid() {
    final profile = widget.profileData ?? {};
    final op = profile['operator'] ?? {};
    final dynamic rawUid =
        op['account_id'] ??
        op['operator_uid'] ??
        op['pilot_uid'] ??
        op['uid'] ??
        profile['account_id'] ??
        profile['uid'];
    if (rawUid is int) return rawUid;
    return int.tryParse(rawUid?.toString() ?? '') ?? 0;
  }

  /// Busca as estações da tabela orbit_stations no backend (exclusivamente do banco de dados)
  Future<void> _fetchStations() async {
    try {
      final res = await http
          .get(Uri.parse('${widget.apiBaseUrl}/api/stations'))
          .timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final List stations = decoded['stations'] ?? [];
        final List<String> names = ['TODAS'];
        for (var s in stations) {
          final name = s['name'] ?? s['station_name'];
          if (name != null && !names.contains(name.toString())) {
            names.add(name.toString());
          }
        }
        if (mounted) {
          setState(() {
            _stationOptions = names;
            _stationList = List<Map<String, dynamic>>.from(stations);
          });
        }
      } else {
        debugPrint(
          '[CONTRATOS] Falha ao carregar orbit_stations: status ${res.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('[CONTRATOS] Erro ao buscar orbit_stations: $e');
    }
  }

  /// Retorna o tier do jogador para uma carreira específica
  int _getPilotTierForCareer(String career) {
    final skills = (widget.profileData?['skills'] as Map?) ?? {};
    final rawVal = skills[career.toLowerCase()] ?? 0;
    final int score =
        (rawVal is num) ? rawVal.toInt() : int.tryParse(rawVal.toString()) ?? 0;

    if (score >= 80) return 5;
    if (score >= 60) return 4;
    if (score >= 40) return 3;
    if (score >= 20) return 2;
    return 1;
  }

  String _formatCredits(dynamic value) {
    if (value == null) return '0';
    final int parsed =
        (value is num) ? value.round() : int.tryParse(value.toString()) ?? 0;
    return parsed.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  Color _getCareerColor(String? career) {
    switch (career?.toLowerCase()) {
      case 'mercenary':
        return _redAccent;
      case 'extractor':
        return _amberAccent;
      case 'merchant':
        return _greenAccent;
      case 'engineer':
        return _cyanColor;
      case 'corporate':
        return _purpleAccent;
      case 'general':
      default:
        return Colors.white70;
    }
  }

  String _getCareerLabel(String? career) {
    switch (career?.toLowerCase()) {
      case 'mercenary':
        return 'MERCENÁRIO';
      case 'extractor':
        return 'EXTRATOR';
      case 'merchant':
        return 'COMERCIANTE';
      case 'engineer':
        return 'ENGENHEIRO';
      case 'corporate':
        return 'CORPORATIVO';
      case 'general':
      default:
        return 'GERAL';
    }
  }

  String _getTypeLabel(String? type) {
    switch (type?.toLowerCase()) {
      case 'bounty':
        return 'BOUNTY HUNTER';
      case 'courier':
        return 'ENTREGA (COURIER)';
      case 'mining':
        return 'MINERAÇÃO';
      case 'crafting':
        return 'FABRICAÇÃO';
      case 'corporate_emergency':
        return 'EMERGÊNCIA CORP';
      default:
        return (type ?? 'CONTRATO').toUpperCase();
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'available':
        return _cyanColor;
      case 'in_progress':
      case 'active':
        return _greenAccent;
      case 'completed':
        return _amberAccent;
      case 'failed':
      case 'cancelled':
        return _redAccent;
      default:
        return Colors.white60;
    }
  }

  String _getStatusLabel(String? status) {
    switch (status?.toLowerCase()) {
      case 'available':
        return 'DISPONÍVEL';
      case 'in_progress':
      case 'active':
        return 'EM PROGRESSO';
      case 'completed':
        return 'CONCLUÍDO';
      case 'failed':
        return 'FALHOU';
      case 'cancelled':
        return 'CANCELADO';
      default:
        return (status ?? 'DESCONHECIDO').toUpperCase();
    }
  }

  Future<void> _fetchContractsData() async {
    setState(() {
      _isLoading = true;
    });

    final pilotUid = _getPilotUid();

    try {
      final resAvailable = await http
          .get(
            Uri.parse(
              '${widget.apiBaseUrl}/api/contracts/available?pilot_uid=$pilotUid',
            ),
          )
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () => http.Response('[]', 404),
          );

      final resActive = await http
          .get(Uri.parse('${widget.apiBaseUrl}/api/contracts/active/$pilotUid'))
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () => http.Response('[]', 404),
          );

      final resCreated = await http
          .get(Uri.parse('${widget.apiBaseUrl}/api/contracts/issuer/$pilotUid'))
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () => http.Response('[]', 404),
          );

      if (resAvailable.statusCode == 200 &&
          resActive.statusCode == 200 &&
          resCreated.statusCode == 200) {
        final List avail = jsonDecode(resAvailable.body);
        final List act = jsonDecode(resActive.body);
        final List crt = jsonDecode(resCreated.body);

        setState(() {
          _availableContracts = List<Map<String, dynamic>>.from(avail);
          _activeContracts = List<Map<String, dynamic>>.from(act);
          _myCreatedContracts = List<Map<String, dynamic>>.from(crt);
          if (_selectedContract != null) {
            final dynamic selUid = _selectedContract!['contract_uid'];
            final all = [...avail, ...act, ...crt];
            final updated = all.cast<Map<String, dynamic>?>().firstWhere(
              (c) => c != null && c['contract_uid'] == selUid,
              orElse: () => null,
            );
            _selectedContract = updated != null ? Map<String, dynamic>.from(updated) : null;
          }
          _isLoading = false;
        });
      } else {
        _loadMockContracts();
      }
    } catch (_) {
      _loadMockContracts();
    }
  }

  void _loadMockContracts() {
    setState(() {
      _availableContracts = [
        {
          'contract_uid': 101,
          'issuer_type': 'corporation',
          'issuer_uid': 12,
          'issuer_name': 'Arcan Mining Corp',
          'target_career': 'extractor',
          'min_career_tier': 2,
          'contract_type': 'mining',
          'title': 'Extração de Minério Raro em Kali-3',
          'description':
              'Necessário extrair e entregar 150 unidades de Cristais de Hélio-3 na Agartha Commercial Station.',
          'origin_station_id': null,
          'destination_station_id': 1,
          'destination_station_name': 'Agartha Commercial Station',
          'target_orbit': 3,
          'reward_credits': 85000,
          'reward_reputation': 120,
          'collateral_credits': 0,
          'target_item_code': 401,
          'target_item_name': 'Cristal Hélio-3',
          'target_amount': 150,
          'duration_seconds': 7200,
          'uncancellable': 'n',
          'status': 'available',
        },
        {
          'contract_uid': 102,
          'issuer_type': 'pilot',
          'issuer_uid': 99,
          'issuer_name': 'Comandante Jax',
          'target_career': 'courier',
          'min_career_tier': 1,
          'contract_type': 'courier',
          'title': 'Carga Sensível para Estação Alpha',
          'description':
              'Transporte urgente de peças de propulsores de salto. Não sofra avarias durante o trajeto.',
          'origin_station_id': 1,
          'origin_station_name': 'Agartha Commercial Station',
          'destination_station_id': 7,
          'destination_station_name': 'Lyonesse Commercial Station',
          'target_orbit': 2,
          'reward_credits': 45000,
          'reward_reputation': 50,
          'collateral_credits': 20000,
          'target_item_code': 502,
          'target_item_name': 'Unidade de Propulsão Selada',
          'target_amount': 4,
          'duration_seconds': 3600,
          'uncancellable': 'n',
          'status': 'available',
        },
        {
          'contract_uid': 103,
          'issuer_type': 'system',
          'issuer_uid': 0,
          'issuer_name': 'Governança do Setor Kali',
          'target_career': 'mercenary',
          'min_career_tier': 3,
          'contract_type': 'bounty',
          'title': 'Neutralizar Corsário "Sombra Vermelha"',
          'description':
              'Alvo hostil avistado na órbita externa. Permite cumprimento em esquadrilha. Divisão automática de créditos.',
          'origin_station_id': null,
          'destination_station_id': null,
          'target_orbit': 5,
          'reward_credits': 180000,
          'reward_reputation': 250,
          'collateral_credits': 0,
          'target_item_code': 601,
          'target_item_name': 'Canhão de Íons Fraturados',
          'target_amount': 1,
          'duration_seconds': 10800,
          'uncancellable': 'n',
          'status': 'available',
        },
      ];

      _activeContracts = [
        {
          'acceptance_id': 1,
          'contract_uid': 201,
          'issuer_type': 'pilot',
          'issuer_uid': 55,
          'issuer_name': 'Capitão Vane',
          'target_career': 'mercenary',
          'min_career_tier': 1,
          'contract_type': 'bounty',
          'title': 'Patrulha Armada nos Anéis de Kali',
          'description':
              'Interceptar 5 drones de reconhecimento pirata interceptando sondas mineradoras.',
          'reward_credits': 60000,
          'reward_reputation': 80,
          'collateral_credits': 0,
          'target_item_code': null,
          'duration_seconds': 5400,
          'uncancellable': 'n',
          'current_progress': 3,
          'target_progress': 5,
          'accepted_at': '2026-11-14 14:00:00',
          'deadline_at': '2026-11-14 15:30:00',
          'status': 'active',
        },
      ];

      _myCreatedContracts = [
        {
          'contract_uid': 301,
          'issuer_type': 'pilot',
          'issuer_uid': _getPilotUid(),
          'issuer_name': 'Você',
          'target_career': 'extractor',
          'min_career_tier': 1,
          'contract_type': 'mining',
          'title': 'Compra de Titânio Bruto (100t)',
          'description':
              'Preciso de titânio bruto entregue na Agartha Foundry Station para reformas estruturais da corporação.',
          'origin_station_id': null,
          'destination_station_id': 2,
          'destination_station_name': 'Agartha Foundry Station',
          'target_orbit': 2,
          'reward_credits': 95000,
          'reward_reputation': 40,
          'collateral_credits': 0,
          'target_item_code': 305,
          'target_item_name': 'Minério de Titânio',
          'target_amount': 100,
          'duration_seconds': 86400,
          'uncancellable': 'n',
          'status': 'available',
        },
        {
          'contract_uid': 302,
          'issuer_type': 'pilot',
          'issuer_uid': _getPilotUid(),
          'issuer_name': 'Você',
          'target_career': 'mercenary',
          'min_career_tier': 2,
          'contract_type': 'bounty',
          'title': 'Eliminar Pirata no Ponto de Salto Delta',
          'description':
              'Contrato aceito pelo piloto "Kaelen-7". Em execução no momento.',
          'origin_station_id': null,
          'destination_station_id': null,
          'target_orbit': 4,
          'reward_credits': 120000,
          'reward_reputation': 100,
          'collateral_credits': 0,
          'duration_seconds': 14400,
          'uncancellable': 'n',
          'status': 'in_progress',
          'assigned_to': 'Kaelen-7',
        },
      ];

      // Garante que SEMPRE começa na lista de contratos
      _selectedContract = null;
      _isLoading = false;
    });
  }

  // Filtragem local dos contratos
  List<Map<String, dynamic>> _getFilteredContracts(
    List<Map<String, dynamic>> list,
  ) {
    return list.where((contract) {
      if (_filterCareer != 'TODAS') {
        if (contract['target_career']?.toString().toLowerCase() !=
            _filterCareer.toLowerCase()) {
          return false;
        }
      }
      if (_filterType != 'TODOS') {
        if (contract['contract_type']?.toString().toLowerCase() !=
            _filterType.toLowerCase()) {
          return false;
        }
      }
      if (_filterStation != 'TODAS') {
        final stFilter = _filterStation.toLowerCase();
        final orig =
            (contract['origin_station_name'] ?? '').toString().toLowerCase();
        final dest =
            (contract['destination_station_name'] ?? '')
                .toString()
                .toLowerCase();
        if (!orig.contains(stFilter) && !dest.contains(stFilter)) {
          return false;
        }
      }
      final search = _searchController.text.trim().toLowerCase();
      if (search.isNotEmpty) {
        final title = (contract['title'] ?? '').toString().toLowerCase();
        final desc = (contract['description'] ?? '').toString().toLowerCase();
        final orig =
            (contract['origin_station_name'] ?? '').toString().toLowerCase();
        final dest =
            (contract['destination_station_name'] ?? '')
                .toString()
                .toLowerCase();
        final issuer = (contract['issuer_name'] ?? '').toString().toLowerCase();
        final item =
            (contract['target_item_name'] ?? '').toString().toLowerCase();
        if (!title.contains(search) &&
            !desc.contains(search) &&
            !orig.contains(search) &&
            !dest.contains(search) &&
            !issuer.contains(search) &&
            !item.contains(search)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  void _onAcceptContract(Map<String, dynamic> contract) {
    final pilotTier = _getPilotTierForCareer(
      contract['target_career'] ?? 'general',
    );
    final minTier = contract['min_career_tier'] ?? 1;

    if (pilotTier < minTier) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _redAccent,
          content: Text(
            'Requisito insuficiente! Seu nível em ${_getCareerLabel(contract['target_career'])} é Tier $pilotTier, mas o contrato exige Tier $minTier.',
            style: GoogleFonts.shareTechMono(color: Colors.white),
          ),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: _cardBg,
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: _cyanColor, width: 1.5),
              borderRadius: BorderRadius.circular(4),
            ),
            title: Text(
              'CONFIRMAR ACEITE DE CONTRATO',
              style: GoogleFonts.shareTechMono(
                color: _cyanColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            content: Text(
              'Deseja aceitar a missão "${contract['title']}"?\n\n'
              'Recompensa: ${_formatCredits(contract['reward_credits'])} CR\n'
              'Caução: ${_formatCredits(contract['collateral_credits'])} CR',
              style: GoogleFonts.shareTechMono(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'CANCELAR',
                  style: GoogleFonts.shareTechMono(color: Colors.white54),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _greenAccent),
                onPressed: () {
                  Navigator.pop(ctx);
                  _executeAcceptContract(contract);
                },
                child: Text(
                  'ACEITAR MISSÃO',
                  style: GoogleFonts.shareTechMono(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _executeAcceptContract(Map<String, dynamic> contract) async {
    final int pilotUid = _getPilotUid();
    try {
      final res = await http.post(
        Uri.parse('${widget.apiBaseUrl}/api/contracts/${contract['contract_uid']}/accept'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'pilot_uid': pilotUid}),
      );
      final decoded = jsonDecode(res.body);
      if (res.statusCode == 200 && decoded['status'] == 'sucesso') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _greenAccent,
            content: Text(
              decoded['mensagem'] ?? 'Contrato aceito com sucesso! Verifique em "Meus Contratos Ativos".',
              style: GoogleFonts.shareTechMono(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
        widget.onProfileRefresh?.call();
        await _fetchContractsData();
        setState(() {
          _contractorSubTab = 'ATIVOS';
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _redAccent,
            content: Text(
              decoded['mensagem'] ?? 'Erro ao aceitar contrato',
              style: GoogleFonts.shareTechMono(color: Colors.white),
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _redAccent,
          content: Text('Falha de conexão: $e', style: GoogleFonts.shareTechMono(color: Colors.white)),
        ),
      );
    }
  }

  void _onAbandonContract(Map<String, dynamic> contract) {
    if (contract['uncancellable'] == 'y') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _redAccent,
          content: Text(
            'Este contrato está marcado como NÃO CANCELÁVEL!',
            style: GoogleFonts.shareTechMono(color: Colors.white),
          ),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: _cardBg,
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: _redAccent, width: 1.5),
              borderRadius: BorderRadius.circular(4),
            ),
            title: Text(
              'ABANDONAR MISSÃO',
              style: GoogleFonts.shareTechMono(
                color: _redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            content: Text(
              'Tem certeza que deseja abandonar a missão "${contract['title']}"?\n\n'
              'Atenção: Quaisquer cauções depositadas serão perdidas.',
              style: GoogleFonts.shareTechMono(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'VOLTAR',
                  style: GoogleFonts.shareTechMono(color: Colors.white54),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _redAccent),
                onPressed: () {
                  Navigator.pop(ctx);
                  _executeAbandonContract(contract);
                },
                child: Text(
                  'CONFIRMAR ABANDONO',
                  style: GoogleFonts.shareTechMono(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _executeAbandonContract(Map<String, dynamic> contract) async {
    final int pilotUid = _getPilotUid();
    try {
      final res = await http.post(
        Uri.parse('${widget.apiBaseUrl}/api/contracts/${contract['contract_uid']}/abandon'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'pilot_uid': pilotUid}),
      );
      final decoded = jsonDecode(res.body);
      if (res.statusCode == 200 && decoded['status'] == 'sucesso') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _redAccent,
            content: Text(
              decoded['mensagem'] ?? 'Missão abandonada.',
              style: GoogleFonts.shareTechMono(color: Colors.white),
            ),
          ),
        );
        widget.onProfileRefresh?.call();
        await _fetchContractsData();
        setState(() {
          _selectedContract = null;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _redAccent,
            content: Text(
              decoded['mensagem'] ?? 'Erro ao abandonar contrato',
              style: GoogleFonts.shareTechMono(color: Colors.white),
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _redAccent,
          content: Text('Falha de conexão: $e', style: GoogleFonts.shareTechMono(color: Colors.white)),
        ),
      );
    }
  }

  Future<void> _onDeliverContract(Map<String, dynamic> contract) async {
    final int pilotUid = _getPilotUid();
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: _greenAccent, width: 1.5),
          borderRadius: BorderRadius.circular(4),
        ),
        title: Text(
          'ENTREGAR / CONCLUIR MISSÃO',
          style: GoogleFonts.shareTechMono(
            color: _greenAccent,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        content: Text(
          'Deseja entregar e concluir a missão "${contract['title']}"?\n\n'
          'Recompensa a receber: ${_formatCredits(contract['reward_credits'])} CR'
          '${(contract['collateral_credits'] ?? 0) > 0 ? '\nDevolução da caução: ${_formatCredits(contract['collateral_credits'])} CR' : ''}\n'
          'Reputação ganha: +${contract['reward_reputation'] ?? 0} REP',
          style: GoogleFonts.shareTechMono(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('CANCELAR', style: GoogleFonts.shareTechMono(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _greenAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'CONFIRMAR ENTREGA',
              style: GoogleFonts.shareTechMono(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await http.post(
        Uri.parse('${widget.apiBaseUrl}/api/contracts/${contract['contract_uid']}/deliver'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'pilot_uid': pilotUid}),
      );
      final decoded = jsonDecode(res.body);
      if (res.statusCode == 200 && decoded['status'] == 'sucesso') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _greenAccent,
            content: Text(
              decoded['mensagem'] ?? 'Missão concluída com sucesso! Recompensa creditada na sua carteira.',
              style: GoogleFonts.shareTechMono(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        );
        widget.onProfileRefresh?.call();
        await _fetchContractsData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _redAccent,
            content: Text(
              decoded['mensagem'] ?? 'Erro ao entregar contrato',
              style: GoogleFonts.shareTechMono(color: Colors.white),
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _redAccent,
          content: Text('Falha de conexão: $e', style: GoogleFonts.shareTechMono(color: Colors.white)),
        ),
      );
    }
  }

  Future<void> _onCancelContract(Map<String, dynamic> contract) async {
    final int pilotUid = _getPilotUid();
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: _redAccent, width: 1.5),
          borderRadius: BorderRadius.circular(4),
        ),
        title: Text(
          'CANCELAR CONTRATO',
          style: GoogleFonts.shareTechMono(
            color: _redAccent,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        content: Text(
          'Deseja cancelar o contrato "${contract['title']}"?\n\n'
          'A recompensa de ${_formatCredits(contract['reward_credits'])} CR será estornada para sua carteira.',
          style: GoogleFonts.shareTechMono(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('VOLTAR', style: GoogleFonts.shareTechMono(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'CONFIRMAR CANCELAMENTO',
              style: GoogleFonts.shareTechMono(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await http.post(
        Uri.parse('${widget.apiBaseUrl}/api/contracts/${contract['contract_uid']}/cancel'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'issuer_uid': pilotUid}),
      );
      final decoded = jsonDecode(res.body);
      if (res.statusCode == 200 && decoded['status'] == 'sucesso') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _greenAccent,
            content: Text(
              decoded['mensagem'] ?? 'Contrato cancelado e créditos estornados!',
              style: GoogleFonts.shareTechMono(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        );
        widget.onProfileRefresh?.call();
        await _fetchContractsData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _redAccent,
            content: Text(
              decoded['mensagem'] ?? 'Erro ao cancelar contrato',
              style: GoogleFonts.shareTechMono(color: Colors.white),
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _redAccent,
          content: Text('Falha de conexão: $e', style: GoogleFonts.shareTechMono(color: Colors.white)),
        ),
      );
    }
  }

  Future<void> _onReactivateContract(Map<String, dynamic> contract) async {
    final int pilotUid = _getPilotUid();
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: _greenAccent, width: 1.5),
          borderRadius: BorderRadius.circular(4),
        ),
        title: Text(
          'REATIVAR CONTRATO',
          style: GoogleFonts.shareTechMono(
            color: _greenAccent,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        content: Text(
          'Deseja reativar a missão "${contract['title']}"?\n\n'
          'Será debitada a recompensa de ${_formatCredits(contract['reward_credits'])} CR da sua carteira e o contrato voltará a ficar disponível para outros pilotos.',
          style: GoogleFonts.shareTechMono(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('CANCELAR', style: GoogleFonts.shareTechMono(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _greenAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'REATIVAR MISSÃO',
              style: GoogleFonts.shareTechMono(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await http.post(
        Uri.parse('${widget.apiBaseUrl}/api/contracts/${contract['contract_uid']}/reactivate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'issuer_uid': pilotUid}),
      );
      final decoded = jsonDecode(res.body);
      if (res.statusCode == 200 && decoded['status'] == 'sucesso') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _greenAccent,
            content: Text(
              decoded['mensagem'] ?? 'Contrato reativado com sucesso!',
              style: GoogleFonts.shareTechMono(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        );
        widget.onProfileRefresh?.call();
        await _fetchContractsData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _redAccent,
            content: Text(
              decoded['mensagem'] ?? 'Erro ao reativar contrato',
              style: GoogleFonts.shareTechMono(color: Colors.white),
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _redAccent,
          content: Text('Falha de conexão: $e', style: GoogleFonts.shareTechMono(color: Colors.white)),
        ),
      );
    }
  }

  void _showContractFormModal({
    Map<String, dynamic>? contractToEdit,
    Map<String, dynamic>? contractToClone,
  }) {
    final bool isEditing = contractToEdit != null;
    final bool isCloning = contractToClone != null;
    final Map<String, dynamic>? baseContract = contractToEdit ?? contractToClone;

    final TextEditingController titleCtrl = TextEditingController(
      text: isCloning
          ? '${baseContract?['title'] ?? ''} (Clone)'
          : (baseContract?['title'] ?? ''),
    );
    final TextEditingController descCtrl = TextEditingController(
      text: baseContract?['description'] ?? '',
    );
    final TextEditingController rewardCtrl = TextEditingController(
      text: (baseContract?['reward_credits'] ?? 25000).toString(),
    );
    final TextEditingController repCtrl = TextEditingController(
      text: (baseContract?['reward_reputation'] ?? 10).toString(),
    );
    final TextEditingController collatCtrl = TextEditingController(
      text: (baseContract?['collateral_credits'] ?? 0).toString(),
    );

    String selectedCareer = baseContract?['target_career'] ?? 'general';
    int selectedTier = (baseContract?['min_career_tier'] ?? 0) as int;
    String selectedType = baseContract?['contract_type'] ?? 'bounty';
    int selectedDuration = (baseContract?['duration_seconds'] ?? 86400) as int;
    int? selectedOriginStationId = baseContract?['origin_station_id'];
    int? selectedDestStationId = baseContract?['destination_station_id'];
    bool isUncancellable = (baseContract?['uncancellable'] == 'y');
    bool isSubmitting = false;

    final List<Map<String, String>> careerOptions = [
      {'val': 'general', 'label': 'GERAL'},
      {'val': 'mercenary', 'label': 'MERCENÁRIO'},
      {'val': 'extractor', 'label': 'EXTRATOR'},
      {'val': 'merchant', 'label': 'COMERCIANTE'},
      {'val': 'engineer', 'label': 'ENGENHEIRO'},
      {'val': 'corporate', 'label': 'CORPORATIVO'},
    ];

    final List<Map<String, String>> typeOptions = [
      {'val': 'bounty', 'label': 'BOUNTY HUNTER'},
      {'val': 'courier', 'label': 'ENTREGA (COURIER)'},
      {'val': 'mining', 'label': 'MINERAÇÃO'},
      {'val': 'crafting', 'label': 'FABRICAÇÃO'},
      {'val': 'corporate_emergency', 'label': 'EMERGÊNCIA CORP'},
    ];

    final List<Map<String, dynamic>> durationOptions = [
      {'val': 3600, 'label': '1 HORA'},
      {'val': 7200, 'label': '2 HORAS'},
      {'val': 14400, 'label': '4 HORAS'},
      {'val': 28800, 'label': '8 HORAS'},
      {'val': 86400, 'label': '24 HORAS'},
      {'val': 172800, 'label': '48 HORAS'},
      {'val': 259200, 'label': '72 HORAS'},
    ];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            String dialogTitle = 'CRIAR NOVO CONTRATO';
            IconData titleIcon = Icons.post_add;
            Color themeColor = _cyanColor;

            if (isEditing) {
              dialogTitle = 'EDITAR CONTRATO #${contractToEdit['contract_uid']}';
              titleIcon = Icons.edit_note;
              themeColor = _cyanColor;
            } else if (isCloning) {
              dialogTitle = 'CLONAR CONTRATO #${contractToClone['contract_uid']}';
              titleIcon = Icons.copy;
              themeColor = _amberAccent;
            }

            return Dialog(
              backgroundColor: _cardBg,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              shape: RoundedRectangleBorder(
                side: BorderSide(color: themeColor.withValues(alpha: 0.8), width: 1.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 620, maxHeight: 780),
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(titleIcon, color: themeColor, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              dialogTitle,
                              style: GoogleFonts.shareTechMono(
                                color: themeColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                          onPressed: () => Navigator.of(ctx).pop(),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white12, height: 16),

                    // Scrollable content
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Título
                            _buildFormFieldLabel('TÍTULO DO CONTRATO / MISSÃO *'),
                            TextField(
                              controller: titleCtrl,
                              maxLength: 60,
                              style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 13),
                              decoration: _buildInputDecoration('Ex: Escoltar Carga de Urânio em Kali-4'),
                            ),
                            const SizedBox(height: 8),

                            // Descrição
                            _buildFormFieldLabel('DESCRIÇÃO DOS OBJETIVOS *'),
                            TextField(
                              controller: descCtrl,
                              maxLength: 255,
                              maxLines: 3,
                              style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 12),
                              decoration: _buildInputDecoration('Detalhes, condições e instruções para o contratado...'),
                            ),
                            const SizedBox(height: 12),

                            // Carreira e Tier
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildFormFieldLabel('CARREIRA ALVO'),
                                      DropdownButtonFormField<String>(
                                        value: selectedCareer,
                                        dropdownColor: const Color(0xFF151922),
                                        isDense: true,
                                        style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 12),
                                        decoration: _buildInputDecoration(null),
                                        items: careerOptions
                                            .map((c) => DropdownMenuItem(
                                                  value: c['val'],
                                                  child: Text(c['label']!),
                                                ))
                                            .toList(),
                                        onChanged: (val) {
                                          if (val != null) setDialogState(() => selectedCareer = val);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildFormFieldLabel('TIER MÍNIMO'),
                                      DropdownButtonFormField<int>(
                                        value: selectedTier,
                                        dropdownColor: const Color(0xFF151922),
                                        isDense: true,
                                        style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 12),
                                        decoration: _buildInputDecoration(null),
                                        items: [0, 1, 2, 3, 4, 5]
                                            .map((t) => DropdownMenuItem(
                                                  value: t,
                                                  child: Text('TIER $t'),
                                                ))
                                            .toList(),
                                        onChanged: (val) {
                                          if (val != null) setDialogState(() => selectedTier = val);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Tipo e Duração
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildFormFieldLabel('TIPO DE CONTRATO'),
                                      DropdownButtonFormField<String>(
                                        value: selectedType,
                                        dropdownColor: const Color(0xFF151922),
                                        isDense: true,
                                        style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 12),
                                        decoration: _buildInputDecoration(null),
                                        items: typeOptions
                                            .map((t) => DropdownMenuItem(
                                                  value: t['val'],
                                                  child: Text(t['label']!),
                                                ))
                                            .toList(),
                                        onChanged: (val) {
                                          if (val != null) setDialogState(() => selectedType = val);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildFormFieldLabel('DURAÇÃO LIMITE'),
                                      DropdownButtonFormField<int>(
                                        value: selectedDuration,
                                        dropdownColor: const Color(0xFF151922),
                                        isDense: true,
                                        style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 12),
                                        decoration: _buildInputDecoration(null),
                                        items: durationOptions
                                            .map((d) => DropdownMenuItem(
                                                  value: d['val'] as int,
                                                  child: Text(d['label'] as String),
                                                ))
                                            .toList(),
                                        onChanged: (val) {
                                          if (val != null) setDialogState(() => selectedDuration = val);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Estação Origem e Destino
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildFormFieldLabel('ESTAÇÃO ORIGEM'),
                                      DropdownButtonFormField<int?>(
                                        value: selectedOriginStationId,
                                        dropdownColor: const Color(0xFF151922),
                                        isDense: true,
                                        style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 11),
                                        decoration: _buildInputDecoration(null),
                                        items: [
                                          const DropdownMenuItem<int?>(
                                            value: null,
                                            child: Text('QUALQUER / ESPAÇO'),
                                          ),
                                          ..._stationList.map((s) {
                                            final int id = (s['id'] ?? s['station_id'] ?? 0) as int;
                                            final String name = (s['name'] ?? s['station_name'] ?? 'Estação $id').toString();
                                            return DropdownMenuItem<int?>(
                                              value: id,
                                              child: Text(name, overflow: TextOverflow.ellipsis),
                                            );
                                          }),
                                        ],
                                        onChanged: (val) => setDialogState(() => selectedOriginStationId = val),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildFormFieldLabel('ESTAÇÃO DESTINO'),
                                      DropdownButtonFormField<int?>(
                                        value: selectedDestStationId,
                                        dropdownColor: const Color(0xFF151922),
                                        isDense: true,
                                        style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 11),
                                        decoration: _buildInputDecoration(null),
                                        items: [
                                          const DropdownMenuItem<int?>(
                                            value: null,
                                            child: Text('QUALQUER / ESPAÇO'),
                                          ),
                                          ..._stationList.map((s) {
                                            final int id = (s['id'] ?? s['station_id'] ?? 0) as int;
                                            final String name = (s['name'] ?? s['station_name'] ?? 'Estação $id').toString();
                                            return DropdownMenuItem<int?>(
                                              value: id,
                                              child: Text(name, overflow: TextOverflow.ellipsis),
                                            );
                                          }),
                                        ],
                                        onChanged: (val) => setDialogState(() => selectedDestStationId = val),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Recompensas e Caução
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildFormFieldLabel('RECOMPENSA (CR) *'),
                                      TextField(
                                        controller: rewardCtrl,
                                        keyboardType: TextInputType.number,
                                        style: GoogleFonts.shareTechMono(
                                          color: _greenAccent,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        decoration: _buildInputDecoration('Valor a pagar'),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildFormFieldLabel('REPUTAÇÃO (+REP)'),
                                      TextField(
                                        controller: repCtrl,
                                        keyboardType: TextInputType.number,
                                        style: GoogleFonts.shareTechMono(color: _amberAccent, fontSize: 13),
                                        decoration: _buildInputDecoration('Reputação'),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildFormFieldLabel('CAUÇÃO (CR)'),
                                      TextField(
                                        controller: collatCtrl,
                                        keyboardType: TextInputType.number,
                                        style: GoogleFonts.shareTechMono(color: Colors.white70, fontSize: 13),
                                        decoration: _buildInputDecoration('Depósito exigido'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Opção Não Cancelável
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              activeColor: _redAccent,
                              title: Text(
                                'CONTRATO NÃO CANCELÁVEL (SEM DESISTÊNCIA)',
                                style: GoogleFonts.shareTechMono(color: Colors.white70, fontSize: 11),
                              ),
                              value: isUncancellable,
                              onChanged: (val) => setDialogState(() => isUncancellable = val ?? false),
                            ),

                            // Nota de custódia
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black38,
                                border: Border.all(color: Colors.white12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.info_outline, color: _cyanColor, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      isEditing
                                          ? 'Ao atualizar, a diferença de recompensa será automaticamente ajustada em sua carteira.'
                                          : 'A recompensa será retida da sua carteira na publicação e repassada ao piloto que cumprir o contrato.',
                                      style: GoogleFonts.shareTechMono(color: Colors.white54, fontSize: 10),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(color: Colors.white12, height: 16),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
                          child: Text('CANCELAR', style: GoogleFonts.shareTechMono(color: Colors.white54)),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: themeColor,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  final String title = titleCtrl.text.trim();
                                  final String desc = descCtrl.text.trim();
                                  if (title.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: _redAccent,
                                        content: Text(
                                          'Informe o título da missão!',
                                          style: GoogleFonts.shareTechMono(color: Colors.white),
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  final num reward = num.tryParse(rewardCtrl.text.trim()) ?? 0;
                                  final num rep = num.tryParse(repCtrl.text.trim()) ?? 0;
                                  final num collat = num.tryParse(collatCtrl.text.trim()) ?? 0;
                                  final int pilotUid = _getPilotUid();

                                  setDialogState(() => isSubmitting = true);

                                  try {
                                    final Map<String, dynamic> bodyData = {
                                      'issuer_type': 'pilot',
                                      'issuer_uid': pilotUid,
                                      'title': title,
                                      'description': desc,
                                      'target_career': selectedCareer,
                                      'min_career_tier': selectedTier,
                                      'contract_type': selectedType,
                                      'origin_station_id': selectedOriginStationId,
                                      'destination_station_id': selectedDestStationId,
                                      'reward_credits': reward,
                                      'reward_reputation': rep,
                                      'collateral_credits': collat,
                                      'duration_seconds': selectedDuration,
                                      'uncancellable': isUncancellable ? 'y' : 'n',
                                    };

                                    http.Response res;
                                    if (isEditing) {
                                      res = await http.put(
                                        Uri.parse('${widget.apiBaseUrl}/api/contracts/${contractToEdit['contract_uid']}'),
                                        headers: {'Content-Type': 'application/json'},
                                        body: jsonEncode(bodyData),
                                      );
                                    } else {
                                      res = await http.post(
                                        Uri.parse('${widget.apiBaseUrl}/api/contracts/create'),
                                        headers: {'Content-Type': 'application/json'},
                                        body: jsonEncode(bodyData),
                                      );
                                    }

                                    final decoded = jsonDecode(res.body);
                                    if (res.statusCode >= 200 && res.statusCode < 300 && decoded['status'] == 'sucesso') {
                                      Navigator.of(ctx).pop();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          backgroundColor: _greenAccent,
                                          content: Text(
                                            decoded['mensagem'] ??
                                                (isEditing
                                                    ? 'Contrato atualizado com sucesso!'
                                                    : 'Contrato publicado no quadro de missões!'),
                                            style: GoogleFonts.shareTechMono(
                                              color: Colors.black,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      );
                                      widget.onProfileRefresh?.call();
                                      await _fetchContractsData();
                                    } else {
                                      setDialogState(() => isSubmitting = false);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          backgroundColor: _redAccent,
                                          content: Text(
                                            decoded['mensagem'] ?? 'Erro ao salvar contrato',
                                            style: GoogleFonts.shareTechMono(color: Colors.white),
                                          ),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    setDialogState(() => isSubmitting = false);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: _redAccent,
                                        content: Text('Erro de conexão: $e', style: GoogleFonts.shareTechMono(color: Colors.white)),
                                      ),
                                    );
                                  }
                                },
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                )
                              : Text(
                                  isEditing
                                      ? 'SALVAR ALTERAÇÕES'
                                      : (isCloning ? 'PUBLICAR CLONE' : 'PUBLICAR CONTRATO'),
                                  style: GoogleFonts.shareTechMono(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFormFieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: GoogleFonts.shareTechMono(
          color: _cyanColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String? hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.shareTechMono(color: Colors.white24, fontSize: 11),
      filled: true,
      fillColor: const Color(0xFF151922),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: _cyanColor),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A0D12),
      child: Column(
        children: [
          _buildTopModeHeader(),
          if (_mainMode == 'CONTRATADO') _buildContractorSubTabs(),
          if (_showFiltersBar) _buildFiltersBar(),
          Expanded(
            child:
                _isLoading
                    ? const Center(
                      child: CircularProgressIndicator(color: _cyanColor),
                    )
                    : _buildMainBody(),
          ),
        ],
      ),
    );
  }

  /// 1- Botões no alto da interface: "Contratante" e "Contratado" (Totalmente responsivo sem overflow)
  Widget _buildTopModeHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 600;
        final bool isVeryCompact = constraints.maxWidth < 420;

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 8 : 16,
            vertical: 8,
          ),
          decoration: const BoxDecoration(
            color: _panelBg,
            border: Border(
              bottom: BorderSide(color: Color(0x3300D2FF), width: 1.2),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildModeButton(
                  label: 'CONTRATADO',
                  subLabel: isCompact ? null : 'ACEITAR E CUMPRIR MISSÕES',
                  icon: Icons.shield_outlined,
                  isSelected: _mainMode == 'CONTRATADO',
                  isCompact: isCompact,
                  onTap: () {
                    setState(() {
                      _mainMode = 'CONTRATADO';
                      _selectedContract = null; // Abre na lista!
                    });
                  },
                ),
              ),
              SizedBox(width: isCompact ? 6 : 12),
              Expanded(
                child: _buildModeButton(
                  label: 'CONTRATANTE',
                  subLabel: isCompact ? null : 'CRIAR E GERENCIAR CONTRATOS',
                  icon: Icons.assignment_ind_outlined,
                  isSelected: _mainMode == 'CONTRATANTE',
                  isCompact: isCompact,
                  onTap: () {
                    setState(() {
                      _mainMode = 'CONTRATANTE';
                      _selectedContract = null; // Abre na lista!
                    });
                  },
                ),
              ),
              SizedBox(width: isCompact ? 6 : 12),
              // Botão para alternar barra de filtros
              InkWell(
                onTap: () => setState(() => _showFiltersBar = !_showFiltersBar),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isVeryCompact ? 8 : 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color:
                        _showFiltersBar
                            ? _cyanColor.withValues(alpha: 0.2)
                            : _cardBg,
                    border: Border.all(
                      color: _showFiltersBar ? _cyanColor : Colors.white24,
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.filter_list,
                        size: 16,
                        color: _showFiltersBar ? _cyanColor : Colors.white70,
                      ),
                      if (!isVeryCompact) ...[
                        const SizedBox(width: 4),
                        Text(
                          'FILTROS',
                          style: GoogleFonts.shareTechMono(
                            color:
                                _showFiltersBar ? _cyanColor : Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModeButton({
    required String label,
    String? subLabel,
    required IconData icon,
    required bool isSelected,
    required bool isCompact,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(
          vertical: 8,
          horizontal: isCompact ? 6 : 10,
        ),
        decoration: BoxDecoration(
          color: isSelected ? _cyanColor.withValues(alpha: 0.15) : _cardBg,
          border: Border.all(
            color: isSelected ? _cyanColor : Colors.white24,
            width: isSelected ? 1.8 : 1.0,
          ),
          borderRadius: BorderRadius.circular(4),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: _cyanColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                  : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? _cyanColor : Colors.white54,
              size: isCompact ? 18 : 20,
            ),
            SizedBox(width: isCompact ? 6 : 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.shareTechMono(
                      color: isSelected ? _cyanColor : Colors.white70,
                      fontSize: isCompact ? 12 : 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  if (subLabel != null)
                    Text(
                      subLabel,
                      style: GoogleFonts.shareTechMono(
                        color: isSelected ? _greenAccent : Colors.white38,
                        fontSize: 8.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Sub-abas da Área do Contratado: Disponíveis vs Ativos
  Widget _buildContractorSubTabs() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: const Color(0xFF0F131A),
      child: Row(
        children: [
          _buildSubTabItem(
            title: 'CONTRATOS DISPONÍVEIS',
            count: _availableContracts.length,
            isSelected: _contractorSubTab == 'DISPONIVEIS',
            onTap: () {
              setState(() {
                _contractorSubTab = 'DISPONIVEIS';
                _selectedContract = null; // Abre na lista!
              });
            },
          ),
          const SizedBox(width: 12),
          _buildSubTabItem(
            title: 'MEUS CONTRATOS ATIVOS',
            count: _activeContracts.length,
            isSelected: _contractorSubTab == 'ATIVOS',
            onTap: () {
              setState(() {
                _contractorSubTab = 'ATIVOS';
                _selectedContract = null; // Abre na lista!
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSubTabItem({
    required String title,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? _panelBg : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: isSelected ? _greenAccent : Colors.transparent,
              width: 2.0,
            ),
          ),
        ),
        child: Row(
          children: [
            Text(
              title,
              style: GoogleFonts.shareTechMono(
                color: isSelected ? _greenAccent : Colors.white60,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? _greenAccent.withValues(alpha: 0.2)
                        : Colors.white10,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.shareTechMono(
                  color: isSelected ? _greenAccent : Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Barra de Filtros Responsiva (Carreira, Tipo, Estação orbit_stations e Busca)
  Widget _buildFiltersBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 650;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFF131822),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  // Filtro por Carreira
                  Text(
                    'CARREIRA:',
                    style: GoogleFonts.shareTechMono(
                      color: Colors.white54,
                      fontSize: 10.5,
                    ),
                  ),
                  const SizedBox(width: 4),
                  DropdownButton<String>(
                    value: _filterCareer,
                    dropdownColor: _cardBg,
                    isDense: true,
                    style: GoogleFonts.shareTechMono(
                      color: _cyanColor,
                      fontSize: 11,
                    ),
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'TODAS', child: Text('TODAS')),
                      DropdownMenuItem(
                        value: 'mercenary',
                        child: Text('MERCENÁRIO'),
                      ),
                      DropdownMenuItem(
                        value: 'extractor',
                        child: Text('EXTRATOR'),
                      ),
                      DropdownMenuItem(
                        value: 'merchant',
                        child: Text('COMERCIANTE'),
                      ),
                      DropdownMenuItem(
                        value: 'engineer',
                        child: Text('ENGENHEIRO'),
                      ),
                      DropdownMenuItem(
                        value: 'corporate',
                        child: Text('CORPORATIVO'),
                      ),
                      DropdownMenuItem(value: 'general', child: Text('GERAL')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _filterCareer = val);
                    },
                  ),
                  const SizedBox(width: 12),
                  // Filtro por Tipo de Contrato
                  Text(
                    'TIPO:',
                    style: GoogleFonts.shareTechMono(
                      color: Colors.white54,
                      fontSize: 10.5,
                    ),
                  ),
                  const SizedBox(width: 4),
                  DropdownButton<String>(
                    value: _filterType,
                    dropdownColor: _cardBg,
                    isDense: true,
                    style: GoogleFonts.shareTechMono(
                      color: _cyanColor,
                      fontSize: 11,
                    ),
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'TODOS', child: Text('TODOS')),
                      DropdownMenuItem(value: 'bounty', child: Text('BOUNTY')),
                      DropdownMenuItem(
                        value: 'courier',
                        child: Text('COURIER'),
                      ),
                      DropdownMenuItem(value: 'mining', child: Text('MINING')),
                      DropdownMenuItem(
                        value: 'crafting',
                        child: Text('CRAFTING'),
                      ),
                      DropdownMenuItem(
                        value: 'corporate_emergency',
                        child: Text('EMERGÊNCIA'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _filterType = val);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  // Filtro por Estação (orbit_stations)
                  Text(
                    'ESTAÇÃO:',
                    style: GoogleFonts.shareTechMono(
                      color: Colors.white54,
                      fontSize: 10.5,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    flex: isCompact ? 5 : 4,
                    child: DropdownButton<String>(
                      value:
                          _stationOptions.contains(_filterStation)
                              ? _filterStation
                              : 'TODAS',
                      dropdownColor: _cardBg,
                      isDense: true,
                      isExpanded: true,
                      style: GoogleFonts.shareTechMono(
                        color: _cyanColor,
                        fontSize: 11,
                      ),
                      underline: const SizedBox(),
                      items:
                          _stationOptions.map((st) {
                            return DropdownMenuItem<String>(
                              value: st,
                              child: Text(st, overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _filterStation = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Campo de Busca
                  Expanded(
                    flex: isCompact ? 5 : 5,
                    child: SizedBox(
                      height: 30,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        style: GoogleFonts.shareTechMono(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Buscar...',
                          hintStyle: GoogleFonts.shareTechMono(
                            color: Colors.white30,
                            fontSize: 10.5,
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            size: 14,
                            color: _cyanColor,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 0,
                          ),
                          filled: true,
                          fillColor: _cardBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: const BorderSide(color: Colors.white24),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Corpo Principal com Split-View (Lista de Cards à Esquerda e Detalhes à Direita)
  Widget _buildMainBody() {
    List<Map<String, dynamic>> targetList = [];
    if (_mainMode == 'CONTRATADO') {
      targetList =
          _contractorSubTab == 'DISPONIVEIS'
              ? _availableContracts
              : _activeContracts;
    } else {
      targetList = _myCreatedContracts;
    }

    final filteredList = _getFilteredContracts(targetList);

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isLargeScreen = constraints.maxWidth >= 780;

        if (isLargeScreen) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Coluna da Esquerda: Lista de Contratos (400px)
              SizedBox(
                width: 400,
                child: _buildContractsListPanel(filteredList),
              ),
              // Divisor Vertical
              Container(width: 1, color: _cyanColor.withValues(alpha: 0.2)),
              // Coluna da Direita: Painel de Detalhes
              Expanded(child: _buildContractDetailPanel()),
            ],
          );
        } else {
          // Visualização Mobile/Compacta: abre SEMPRE na lista se _selectedContract == null
          if (_selectedContract == null) {
            return _buildContractsListPanel(filteredList);
          } else {
            return _buildContractDetailPanel(
              onBackToList: () {
                setState(() => _selectedContract = null);
              },
            );
          }
        }
      },
    );
  }

  /// Painel da Lista de Contratos
  Widget _buildContractsListPanel(List<Map<String, dynamic>> list) {
    return Container(
      color: const Color(0xFF0C0F16),
      child: Column(
        children: [
          // Topo da lista do Contratante com botão "+ CRIAR NOVO CONTRATO"
          if (_mainMode == 'CONTRATANTE')
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white12)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _cyanColor.withValues(alpha: 0.2),
                        side: const BorderSide(color: _cyanColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: () => _showContractFormModal(),
                      icon: const Icon(Icons.add, color: _cyanColor, size: 16),
                      label: Text(
                        'CRIAR NOVO CONTRATO',
                        style: GoogleFonts.shareTechMono(
                          color: _cyanColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child:
                list.isEmpty
                    ? Center(
                      child: Text(
                        'Nenhum contrato encontrado.',
                        style: GoogleFonts.shareTechMono(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final contract = list[index];
                        final isSelected =
                            _selectedContract?['contract_uid'] ==
                            contract['contract_uid'];
                        return _buildContractCard(contract, isSelected);
                      },
                    ),
          ),
        ],
      ),
    );
  }

  /// Card de Contrato individual
  Widget _buildContractCard(Map<String, dynamic> contract, bool isSelected) {
    final careerColor = _getCareerColor(contract['target_career']);
    final bool isActiveMode =
        _mainMode == 'CONTRATADO' && _contractorSubTab == 'ATIVOS';

    return InkWell(
      onTap: () {
        setState(() {
          _selectedContract = contract;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? _cardBgSelected : _cardBg,
          border: Border.all(
            color: isSelected ? _cyanColor : Colors.white12,
            width: isSelected ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(4),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: _cyanColor.withValues(alpha: 0.15),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ]
                  : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Linha superior: Tag da Carreira + Recompensa
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: careerColor.withValues(alpha: 0.2),
                    border: Border.all(color: careerColor, width: 0.8),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    _getCareerLabel(contract['target_career']),
                    style: GoogleFonts.shareTechMono(
                      color: careerColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${_formatCredits(contract['reward_credits'])} CR',
                  style: GoogleFonts.shareTechMono(
                    color: _amberAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Título do Contrato
            Text(
              contract['title'] ?? 'Sem Título',
              style: GoogleFonts.shareTechMono(
                color: isSelected ? _cyanColor : Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            // Requisito ou Rota
            if (contract['contract_type'] == 'courier') ...[
              Text(
                'Rota: ${contract['origin_station_name'] ?? 'Origem'} ➔ ${contract['destination_station_name'] ?? 'Destino'}',
                style: GoogleFonts.shareTechMono(
                  color: Colors.white54,
                  fontSize: 10,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ] else ...[
              Text(
                'Tipo: ${_getTypeLabel(contract['contract_type'])} · Exige Tier ${contract['min_career_tier'] ?? 1}',
                style: GoogleFonts.shareTechMono(
                  color: Colors.white54,
                  fontSize: 10,
                ),
              ),
            ],
            // Barra de Progresso se for Ativo
            if (isActiveMode) ...[
              const SizedBox(height: 8),
              _buildProgressBar(
                current: contract['current_progress'] ?? 0,
                target: contract['target_progress'] ?? 1,
              ),
            ],
            // Badge de Status para Contratante
            if (_mainMode == 'CONTRATANTE') ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(
                      contract['status'],
                    ).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(
                      color: _getStatusColor(contract['status']),
                      width: 0.6,
                    ),
                  ),
                  child: Text(
                    _getStatusLabel(contract['status']),
                    style: GoogleFonts.shareTechMono(
                      color: _getStatusColor(contract['status']),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar({required int current, required int target}) {
    final double pct = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Progresso: $current / $target',
              style: GoogleFonts.shareTechMono(
                color: Colors.white70,
                fontSize: 10,
              ),
            ),
            Text(
              '${(pct * 100).toInt()}%',
              style: GoogleFonts.shareTechMono(
                color: _greenAccent,
                fontSize: 10,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: Colors.white12,
            valueColor: const AlwaysStoppedAnimation<Color>(_greenAccent),
            minHeight: 4,
          ),
        ),
      ],
    );
  }

  /// Painel de Detalhes Completo com SingleChildScrollView (Sem bottom overflow)
  Widget _buildContractDetailPanel({VoidCallback? onBackToList}) {
    final contract = _selectedContract;
    if (contract == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.assignment_outlined,
                color: Colors.white24,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                'Selecione um contrato na lista para ver os detalhes operacionais.',
                style: GoogleFonts.shareTechMono(
                  color: Colors.white38,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final careerColor = _getCareerColor(contract['target_career']);
    final bool isBounty = contract['contract_type'] == 'bounty';
    final bool isCourier = contract['contract_type'] == 'courier';
    final bool isActive =
        _mainMode == 'CONTRATADO' && _contractorSubTab == 'ATIVOS';

    return Container(
      color: _panelBg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Botão voltar em visualização Mobile
            if (onBackToList != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: onBackToList,
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _cyanColor.withValues(alpha: 0.1),
                      border: Border.all(color: _cyanColor, width: 0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.arrow_back,
                          color: _cyanColor,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'VOLTAR PARA A LISTA',
                          style: GoogleFonts.shareTechMono(
                            color: _cyanColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            // Linha de Cabeçalho: Tipo + Carreira + Órbita
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: careerColor.withValues(alpha: 0.2),
                    border: Border.all(color: careerColor),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    _getCareerLabel(contract['target_career']),
                    style: GoogleFonts.shareTechMono(
                      color: careerColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    _getTypeLabel(contract['contract_type']),
                    style: GoogleFonts.shareTechMono(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ),
                const Spacer(),
                if (contract['target_orbit'] != null)
                  Text(
                    'ÓRBITA ${contract['target_orbit']}',
                    style: GoogleFonts.shareTechMono(
                      color: _cyanColor,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Título Principal
            Text(
              contract['title'] ?? '',
              style: GoogleFonts.shareTechMono(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            // Emissor
            Text(
              'EMITIDO POR: ${(contract['issuer_name'] ?? contract['issuer_type'] ?? 'DESCONHECIDO').toString().toUpperCase()}',
              style: GoogleFonts.shareTechMono(
                color: Colors.white38,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 14),
            // Descrição
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _cardBg,
                border: Border.all(color: Colors.white10),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                contract['description'] ?? 'Sem descrição detalhada.',
                style: GoogleFonts.shareTechMono(
                  color: Colors.white70,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Regra Especial de Bounty Hunter
            if (isBounty)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _redAccent.withValues(alpha: 0.1),
                  border: Border.all(color: _redAccent.withValues(alpha: 0.5)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.group_outlined,
                      color: _redAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'MISSÃO DE ESQUADRILHA: Pode ser cumprida em grupo. Créditos são divididos igualmente; itens vão para o líder da esquadrilha.',
                        style: GoogleFonts.shareTechMono(
                          color: _redAccent,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // Seção de Especificações / Rota
            _buildInfoRow(
              'EXIGÊNCIA DE CARREIRA',
              '${_getCareerLabel(contract['target_career'])} (Tier mínimo ${contract['min_career_tier'] ?? 1})',
            ),
            if (isCourier) ...[
              _buildInfoRow(
                'ESTAÇÃO DE ORIGEM',
                contract['origin_station_name'] ?? 'Não informada',
              ),
              _buildInfoRow(
                'ESTAÇÃO DE DESTINO',
                contract['destination_station_name'] ?? 'Não informada',
              ),
              _buildInfoRow(
                'CAUÇÃO EXIGIDA',
                '${_formatCredits(contract['collateral_credits'])} CR',
              ),
            ],
            if (contract['target_item_name'] != null)
              _buildInfoRow(
                'ITEM ALVO',
                '${contract['target_amount'] ?? 1}x ${contract['target_item_name']}',
              ),
            if (contract['duration_seconds'] != null)
              _buildInfoRow(
                'DURAÇÃO MÁXIMA',
                '${(contract['duration_seconds'] / 3600).toStringAsFixed(1)} HORAS',
              ),
            const SizedBox(height: 14),
            // Bloco de Recompensas
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _cardBg,
                border: Border.all(color: _amberAccent.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        'RECOMPENSA EM CRÉDITOS',
                        style: GoogleFonts.shareTechMono(
                          color: Colors.white54,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatCredits(contract['reward_credits'])} CR',
                        style: GoogleFonts.shareTechMono(
                          color: _amberAccent,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(width: 1, height: 30, color: Colors.white12),
                  Column(
                    children: [
                      Text(
                        'REPUTAÇÃO',
                        style: GoogleFonts.shareTechMono(
                          color: Colors.white54,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '+${contract['reward_reputation'] ?? 0}',
                        style: GoogleFonts.shareTechMono(
                          color: _greenAccent,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            // Ações do Contratado ou Contratante
            _buildBottomActionButtons(contract, isActive),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.shareTechMono(
              color: Colors.white38,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.shareTechMono(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionButtons(
    Map<String, dynamic> contract,
    bool isActive,
  ) {
    if (_mainMode == 'CONTRATADO') {
      if (isActive) {
        // Botões para Contrato Ativo: ENTREGAR e ABANDONAR
        return Row(
          children: [
            Expanded(
              flex: 3,
              child: SizedBox(
                height: 42,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _greenAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  onPressed: () => _onDeliverContract(contract),
                  icon: const Icon(
                    Icons.check_circle_outline,
                    color: Colors.black,
                    size: 18,
                  ),
                  label: Text(
                    'ENTREGAR CONTRATO',
                    style: GoogleFonts.shareTechMono(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 42,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _redAccent, width: 1.2),
                    backgroundColor: _redAccent.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  onPressed: () => _onAbandonContract(contract),
                  icon: const Icon(
                    Icons.cancel_outlined,
                    color: _redAccent,
                    size: 16,
                  ),
                  label: Text(
                    'ABANDONAR',
                    style: GoogleFonts.shareTechMono(
                      color: _redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      } else {
        // Botão para Aceitar Contrato
        return SizedBox(
          width: double.infinity,
          height: 42,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _greenAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            onPressed: () => _onAcceptContract(contract),
            icon: const Icon(
              Icons.check_circle_outline,
              color: Colors.black,
              size: 18,
            ),
            label: Text(
              'ACEITAR ESTE CONTRATO',
              style: GoogleFonts.shareTechMono(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        );
      }
    } else {
      // Ações do Contratante para contratos criados
      final String status = (contract['status'] ?? 'available').toString().toLowerCase();
      final bool isAvailable = status == 'available';

      if (isAvailable) {
        return Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 40,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _cyanColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  onPressed: () => _showContractFormModal(contractToEdit: contract),
                  icon: const Icon(Icons.edit_note, color: _cyanColor, size: 16),
                  label: Text(
                    'EDITAR',
                    style: GoogleFonts.shareTechMono(
                      color: _cyanColor,
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 40,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _amberAccent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  onPressed: () => _showContractFormModal(contractToClone: contract),
                  icon: const Icon(Icons.copy, color: _amberAccent, size: 16),
                  label: Text(
                    'CLONAR',
                    style: GoogleFonts.shareTechMono(
                      color: _amberAccent,
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 40,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _redAccent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  onPressed: () => _onCancelContract(contract),
                  icon: const Icon(Icons.cancel_outlined, color: _redAccent, size: 16),
                  label: Text(
                    'CANCELAR',
                    style: GoogleFonts.shareTechMono(
                      color: _redAccent,
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      } else {
        return Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 40,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _greenAccent),
                    backgroundColor: _greenAccent.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  onPressed: () => _onReactivateContract(contract),
                  icon: const Icon(Icons.refresh, color: _greenAccent, size: 16),
                  label: Text(
                    'REATIVAR CONTRATO',
                    style: GoogleFonts.shareTechMono(
                      color: _greenAccent,
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 40,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _amberAccent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  onPressed: () => _showContractFormModal(contractToClone: contract),
                  icon: const Icon(Icons.copy, color: _amberAccent, size: 16),
                  label: Text(
                    'CLONAR',
                    style: GoogleFonts.shareTechMono(
                      color: _amberAccent,
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      }
    }
  }
}
