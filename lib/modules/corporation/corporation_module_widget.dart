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
  num _pilotCredits = 0;

  // Alternador para testes rápidos no VS Code
  bool _simulateNoCorporation = false;

  // Navegação de telas no módulo (Freelancer): 'initial', 'apply', 'create'
  String _currentView = 'initial';

  // Sub-abas de Gestão Corporativa: 'admitted' (Controle dos Admitidos), 'items' (Itens), 'finance' (Financeiro)
  String _currentAffiliatedTab = 'admitted';

  // Estados de Gerenciamento de Membros (Controle dos Membros)
  List<Map<String, dynamic>> _corpMembers = [];
  bool _isLoadingMembers = false;
  String? _membersErrorMessage;
  String _memberRoleFilter = 'all'; // 'all', 'leader', 'officer', 'member'
  String _memberTeamFilter = 'all'; // 'all', 'none', ou team_uid

  // Estados de Gerenciamento de Equipes (corporation_teams)
  List<Map<String, dynamic>> _corpTeams = [];
  bool _isLoadingTeams = false;
  String? _teamsErrorMessage;

  // Sub-aba ITENS (Movimentação e Gestão de Itens da Corporação)
  // Grupos principais (item_type: 6=Naves, 1..5=Itens) com larguras proporcionais (flex) como no Mercado
  static const List<Map<String, dynamic>> _itemCategories = [
    {'type': 6, 'label': 'NAVES', 'flex': 8},
    {'type': 1, 'label': 'INSUMOS', 'flex': 10},
    {'type': 2, 'label': 'ARMAS', 'flex': 8},
    {'type': 3, 'label': 'MÍSSEIS', 'flex': 10},
    {'type': 4, 'label': 'DISPOSITIVOS', 'flex': 14},
    {'type': 5, 'label': 'UTILITÁRIOS', 'flex': 14},
  ];
  int _selectedItemCategory = 6;

  List<Map<String, dynamic>> _corpCargoItems = [];
  bool _isLoadingCorpCargo = false;
  int _corpMaxVolume = 100000;
  int _corpUsedVolume = 0;

  List<Map<String, dynamic>> _memberCargoItems = [];
  bool _isLoadingMemberCargo = false;
  int _memberMaxVolume = 50000;
  int _memberUsedVolume = 0;
  int? _selectedMemberPilotUid;
  Map<String, dynamic>? _selectedMemberData;

  String? _selectedTransferSource; // 'CORP' ou 'MEMBER'
  int? _selectedTransferItemCode;
  int _transferQuantity = 1;
  bool _isTransferringItem = false;

  // Estados do Passo 2 (Diretório e Inscrição)
  final TextEditingController _searchController = TextEditingController();
  String _searchFilter = '';
  List<Map<String, dynamic>> _activeCorporations = [];
  bool _isLoadingCorps = false;
  String? _corpsErrorMessage;
  int? _selectedCorpUid;
  bool _isSubmittingAction = false;

  // Estados do Passo 4 (Criação de Corporação)
  final TextEditingController _corpNameController = TextEditingController();
  final TextEditingController _stationSearchController = TextEditingController();
  String _stationSearchFilter = '';
  List<Map<String, dynamic>> _availableStations = [];
  bool _isLoadingStations = false;
  String? _stationsErrorMessage;
  int? _selectedStationId;

  @override
  void initState() {
    super.initState();
    final op = widget.profileData?['operator'];
    _pilotCredits = (op?['credits'] ?? widget.profileData?['wallet']?['credits'] ?? 0) as num;
    _fetchCorporationStatus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _corpNameController.dispose();
    _stationSearchController.dispose();
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

  int? get _corpUid {
    final corp = _corporationData;
    if (corp != null && corp['corporation_uid'] != null) {
      return int.tryParse(corp['corporation_uid'].toString());
    }
    return null;
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
            if (data['pilot_credits'] != null) {
              _pilotCredits = (data['pilot_credits'] as num);
            }
            _isLoading = false;
          });

          if (data['has_corporation'] == true && data['corporation'] != null) {
            _fetchCorporationTeams(silent: true);
            _fetchCorporationMembers(silent: true);
            if (_currentAffiliatedTab == 'items') {
              _fetchCorpCargo(silent: true);
              _fetchMemberCargo(_selectedMemberPilotUid ?? _pilotUid, silent: true);
            }
          }
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

  /// Busca as equipes da corporação (tabela corporation_teams)
  Future<void> _fetchCorporationTeams({bool silent = false}) async {
    final corpId = _corpUid;
    if (corpId == null) return;

    if (!silent) {
      setState(() {
        _isLoadingTeams = true;
        _teamsErrorMessage = null;
      });
    }

    try {
      final uri = Uri.parse('${widget.apiBaseUrl}/api/corporation/$corpId/teams');
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final decoded = json.decode(res.body);
        if (decoded['status'] == 'sucesso') {
          if (mounted) {
            setState(() {
              _corpTeams = List<Map<String, dynamic>>.from(decoded['data'] ?? []);
              _isLoadingTeams = false;
            });
          }
          return;
        }
      }
      if (mounted) {
        setState(() {
          _teamsErrorMessage = 'Falha ao obter equipes.';
          _isLoadingTeams = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _teamsErrorMessage = 'Erro ao carregar equipes: $e';
          _isLoadingTeams = false;
        });
      }
    }
  }

  /// Busca a lista de admitidos na corporação (corporation_members)
  Future<void> _fetchCorporationMembers({bool silent = false}) async {
    final corpId = _corpUid;
    if (corpId == null) return;

    if (!silent) {
      setState(() {
        _isLoadingMembers = true;
        _membersErrorMessage = null;
      });
    }

    try {
      final uri = Uri.parse('${widget.apiBaseUrl}/api/corporation/$corpId/members');
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final decoded = json.decode(res.body);
        if (decoded['status'] == 'sucesso') {
          if (mounted) {
            setState(() {
              _corpMembers = List<Map<String, dynamic>>.from(decoded['data'] ?? []);
              _isLoadingMembers = false;
            });
          }
          return;
        }
      }
      if (mounted) {
        setState(() {
          _membersErrorMessage = 'Falha ao obter membros admitidos.';
          _isLoadingMembers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _membersErrorMessage = 'Erro ao carregar membros: $e';
          _isLoadingMembers = false;
        });
      }
    }
  }

  /// Atualiza o cargo de um admitido
  Future<void> _updateMemberRole(dynamic pilotUid, String newRole) async {
    if (!_isLeaderOrOfficer) return;
    final corpId = _corpUid;
    if (corpId == null) return;

    try {
      final uri = Uri.parse('${widget.apiBaseUrl}/api/corporation/$corpId/members/$pilotUid');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'role': newRole}),
      ).timeout(const Duration(seconds: 8));

      final decoded = json.decode(res.body);
      if (res.statusCode == 200 && decoded['status'] == 'sucesso') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: _panelBg,
              content: Text('Cargo atualizado com sucesso!', style: GoogleFonts.shareTechMono(color: _cyanColor)),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        await _fetchCorporationMembers(silent: true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF421515),
              content: Text(decoded['mensagem'] ?? 'Falha ao atualizar cargo.', style: GoogleFonts.shareTechMono(color: Colors.white)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF421515),
            content: Text('Erro: $e', style: GoogleFonts.shareTechMono(color: Colors.white)),
          ),
        );
      }
    }
  }

  /// Atualiza a equipe de um admitido
  Future<void> _updateMemberTeam(dynamic pilotUid, int? newTeamUid) async {
    if (!_isLeaderOrOfficer) return;
    final corpId = _corpUid;
    if (corpId == null) return;

    try {
      final uri = Uri.parse('${widget.apiBaseUrl}/api/corporation/$corpId/members/$pilotUid');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'team_uid': newTeamUid}),
      ).timeout(const Duration(seconds: 8));

      final decoded = json.decode(res.body);
      if (res.statusCode == 200 && decoded['status'] == 'sucesso') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: _panelBg,
              content: Text('Equipe atualizada com sucesso!', style: GoogleFonts.shareTechMono(color: _greenAccent)),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        await _fetchCorporationMembers(silent: true);
        await _fetchCorporationTeams(silent: true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF421515),
              content: Text(decoded['mensagem'] ?? 'Falha ao atualizar equipe.', style: GoogleFonts.shareTechMono(color: Colors.white)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF421515),
            content: Text('Erro: $e', style: GoogleFonts.shareTechMono(color: Colors.white)),
          ),
        );
      }
    }
  }

  /// Exclui/desliga um admitido da corporação
  Future<void> _confirmRemoveMember(Map<String, dynamic> member) async {
    if (!_isLeaderOrOfficer) return;
    final pilotName = member['pilot_name'] ?? 'Piloto';
    final pilotUid = member['pilot_uid'];
    final corpId = _corpUid;
    if (corpId == null || pilotUid == null) return;

    final confirm = await showDialog<bool>(
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
              'DESLIGAR MEMBRO',
              style: GoogleFonts.shareTechMono(color: _redAccent, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ],
        ),
        content: Text(
          'Deseja realmente desligar o piloto "$pilotName" da corporação?\n\nEle perderá todos os acessos e voltará ao status de Freelancer Independente.',
          style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('CANCELAR', style: GoogleFonts.shareTechMono(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: _redAccent),
            child: Text('DESLIGAR', style: GoogleFonts.shareTechMono(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final uri = Uri.parse('${widget.apiBaseUrl}/api/corporation/$corpId/members/$pilotUid');
      final res = await http.delete(uri).timeout(const Duration(seconds: 8));
      final decoded = json.decode(res.body);

      if (res.statusCode == 200 && decoded['status'] == 'sucesso') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: _panelBg,
              content: Text('Piloto $pilotName foi desligado da corporação.', style: GoogleFonts.shareTechMono(color: _greenAccent)),
            ),
          );
        }
        await _fetchCorporationMembers(silent: true);
        await _fetchCorporationTeams(silent: true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF421515),
              content: Text(decoded['mensagem'] ?? 'Falha ao desligar piloto.', style: GoogleFonts.shareTechMono(color: Colors.white)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF421515),
            content: Text('Erro ao conectar: $e', style: GoogleFonts.shareTechMono(color: Colors.white)),
          ),
        );
      }
    }
  }

  /// Abre o modal para gerenciar a tabela corporation_teams
  Future<void> _showTeamsManagementDialog() async {
    if (!_isLeaderOrOfficer) return;
    final corpId = _corpUid;
    if (corpId == null) return;

    final newTeamController = TextEditingController();
    bool isSubmittingTeam = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: _cardBg,
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: _cyanColor, width: 1.2),
              borderRadius: BorderRadius.circular(8),
            ),
            title: Row(
              children: [
                const Icon(Icons.groups_outlined, color: _cyanColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'GERENCIAR EQUIPES',
                    style: GoogleFonts.shareTechMono(
                      color: _cyanColor,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                  onPressed: () => Navigator.of(ctx).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Cadastre ou remova equipes/divisões para os membros da sua corporação.',
                    style: GoogleFonts.shareTechMono(color: Colors.white60, fontSize: 11),
                  ),
                  const SizedBox(height: 14),

                  // Campo para cadastrar nova equipe
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: newTeamController,
                          style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 12),
                          decoration: InputDecoration(
                            hintText: 'Nome da nova equipe (ex: Mineração)',
                            hintStyle: GoogleFonts.shareTechMono(color: Colors.white24, fontSize: 12),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            fillColor: _darkBg,
                            filled: true,
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Colors.white12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: _greenAccent),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: isSubmittingTeam
                            ? null
                            : () async {
                                final desc = newTeamController.text.trim();
                                if (desc.isEmpty) return;
                                setDialogState(() => isSubmittingTeam = true);

                                try {
                                  final uri = Uri.parse('${widget.apiBaseUrl}/api/corporation/$corpId/teams');
                                  final res = await http.post(
                                    uri,
                                    headers: {'Content-Type': 'application/json'},
                                    body: json.encode({'description': desc}),
                                  ).timeout(const Duration(seconds: 8));

                                  final decoded = json.decode(res.body);
                                  if (res.statusCode == 200 && decoded['status'] == 'sucesso') {
                                    newTeamController.clear();
                                    await _fetchCorporationTeams(silent: true);
                                    setDialogState(() => isSubmittingTeam = false);
                                    setState(() {});
                                  } else {
                                    setDialogState(() => isSubmittingTeam = false);
                                  }
                                } catch (_) {
                                  setDialogState(() => isSubmittingTeam = false);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _greenAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                        child: isSubmittingTeam
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              )
                            : Text(
                                'CRIAR',
                                style: GoogleFonts.shareTechMono(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 10),

                  Text(
                    'EQUIPES CADASTRADAS (${_corpTeams.length}):',
                    style: GoogleFonts.shareTechMono(color: _cyanColor, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: _isLoadingTeams
                        ? const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: _cyanColor)))
                        : _teamsErrorMessage != null
                            ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(_teamsErrorMessage!, style: GoogleFonts.shareTechMono(color: _redAccent, fontSize: 11))))
                            : _corpTeams.isEmpty
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Text(
                                        'Nenhuma equipe criada ainda.',
                                        style: GoogleFonts.shareTechMono(color: Colors.white30, fontSize: 12),
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                            shrinkWrap: true,
                            itemCount: _corpTeams.length,
                            itemBuilder: (context, i) {
                              final t = _corpTeams[i];
                              final teamUid = t['team_uid'];
                              final count = t['members_count'] ?? 0;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _darkBg,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.shield_outlined, color: _greenAccent, size: 14),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        t['description'] ?? '',
                                        style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white10,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: Text(
                                        '$count ${count == 1 ? "membro" : "membros"}',
                                        style: GoogleFonts.shareTechMono(color: Colors.white54, fontSize: 10),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: _redAccent, size: 16),
                                      tooltip: 'Excluir equipe',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () async {
                                        final bool? delConfirm = await showDialog<bool>(
                                          context: ctx,
                                          builder: (dCtx) => AlertDialog(
                                            backgroundColor: _cardBg,
                                            shape: RoundedRectangleBorder(
                                              side: const BorderSide(color: _redAccent),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            title: Text('EXCLUIR EQUIPE', style: GoogleFonts.shareTechMono(color: _redAccent, fontSize: 14, fontWeight: FontWeight.bold)),
                                            content: Text(
                                              'Deseja excluir a equipe "${t['description']}"? Os membros alocados nela ficarão "Sem Equipe".',
                                              style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 12),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.of(dCtx).pop(false),
                                                child: Text('CANCELAR', style: GoogleFonts.shareTechMono(color: Colors.white54)),
                                              ),
                                              ElevatedButton(
                                                onPressed: () => Navigator.of(dCtx).pop(true),
                                                style: ElevatedButton.styleFrom(backgroundColor: _redAccent),
                                                child: Text('EXCLUIR', style: GoogleFonts.shareTechMono(color: Colors.white, fontWeight: FontWeight.bold)),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (delConfirm == true) {
                                          try {
                                            final uri = Uri.parse('${widget.apiBaseUrl}/api/corporation/$corpId/teams/$teamUid');
                                            await http.delete(uri).timeout(const Duration(seconds: 8));
                                            await _fetchCorporationTeams(silent: true);
                                            await _fetchCorporationMembers(silent: true);
                                            setDialogState(() {});
                                            setState(() {});
                                          } catch (_) {}
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('CONCLUÍDO', style: GoogleFonts.shareTechMono(color: _cyanColor, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );

    newTeamController.dispose();
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

  /// Consulta a lista de estações disponíveis para fundar corporação (Passo 4)
  Future<void> _fetchAvailableStations() async {
    setState(() {
      _isLoadingStations = true;
      _stationsErrorMessage = null;
    });

    try {
      final uri = Uri.parse('${widget.apiBaseUrl}/api/corporation/stations');
      final response = await http.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['status'] == 'sucesso') {
          final list = List<Map<String, dynamic>>.from(decoded['data'] ?? []);
          setState(() {
            _availableStations = list;
            _isLoadingStations = false;
          });
          return;
        }
      }
      setState(() {
        _stationsErrorMessage = 'Falha ao carregar lista de estações disponíveis.';
        _isLoadingStations = false;
      });
    } catch (e) {
      setState(() {
        _stationsErrorMessage = 'Erro ao conectar ao servidor: $e';
        _isLoadingStations = false;
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
              'Uma mensagem de e-mail direta será transmitida aos canais do comandante fundador. Você deverá aguardar a análise.',
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

  /// Confirma e cria a própria corporação (Passo 4)
  Future<void> _submitCreateCorporation() async {
    final corpName = _corpNameController.text.trim();
    if (corpName.length < 3 || _selectedStationId == null || _isSubmittingAction) return;

    if (_pilotCredits < 1000000) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF421515),
          content: Text(
            'Créditos insuficientes! Você possui ${_formatCredits(_pilotCredits)} CR, mas a fundação exige 1.000.000 CR.',
            style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 12),
          ),
        ),
      );
      return;
    }

    final selectedStation = _availableStations.firstWhere(
      (s) => s['station_id'] == _selectedStationId,
      orElse: () => {},
    );
    final stationName = selectedStation['station_name'] ?? 'Estação Selecionada';
    final orbitName = selectedStation['orbit_name'] ?? 'Setor';

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: _greenAccent, width: 1.5),
          borderRadius: BorderRadius.circular(6),
        ),
        title: Row(
          children: [
            const Icon(Icons.rocket_launch_outlined, color: _greenAccent, size: 20),
            const SizedBox(width: 8),
            Text(
              'CONFIRMAR FUNDAÇÃO CORPORATIVA',
              style: GoogleFonts.shareTechMono(
                color: _greenAccent,
                fontWeight: FontWeight.bold,
                fontSize: 14,
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
              'Deseja oficializar a fundação da corporação "${corpName.toUpperCase()}"?',
              style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _panelBg,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDialogRow('NOME OFICIAL:', corpName.toUpperCase()),
                  const SizedBox(height: 6),
                  _buildDialogRow('ESTAÇÃO BASE:', stationName),
                  const SizedBox(height: 6),
                  _buildDialogRow('ÓRBITA:', orbitName),
                  const SizedBox(height: 6),
                  _buildDialogRow('TAXA DE ABERTURA:', '1.000.000 CR'),
                  const SizedBox(height: 6),
                  _buildDialogRow('DESTINO DA TAXA:', 'Carteira da Estação Base'),
                  const SizedBox(height: 6),
                  _buildDialogRow('SEU SALDO ATUAL:', '${_formatCredits(_pilotCredits)} CR'),
                  const SizedBox(height: 6),
                  _buildDialogRow(
                    'SALDO APÓS DÉBITO:',
                    '${_formatCredits(_pilotCredits - 1000000)} CR',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'O valor será debitado imediatamente e uma transação financeira oficial será registrada. Você assumirá a patente de Comandante Líder.',
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
              backgroundColor: _greenAccent.withOpacity(0.2),
              foregroundColor: _greenAccent,
              side: const BorderSide(color: _greenAccent),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'PAGAR 1.000.000 CR & FUNDAR',
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
      final uri = Uri.parse('${widget.apiBaseUrl}/api/corporation/create');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'pilot_uid': _pilotUid,
          'name': corpName,
          'station_uid': _selectedStationId,
        }),
      ).timeout(const Duration(seconds: 12));

      final decoded = json.decode(response.body);

      if (response.statusCode == 201 && decoded['status'] == 'sucesso') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF0D3B2E),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: _greenAccent),
                borderRadius: BorderRadius.circular(4),
              ),
              content: Row(
                children: [
                  const Icon(Icons.verified, color: _greenAccent, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      decoded['mensagem'] ?? 'Corporação fundada com sucesso!',
                      style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Notifica o app para atualizar os créditos e dados no cabeçalho
        widget.onProfileRefresh?.call();

        // Atualiza status local do módulo (agora has_corporation = true)
        setState(() {
          _currentView = 'initial';
          _corpNameController.clear();
          _selectedStationId = null;
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
                decoded['mensagem'] ?? 'Falha ao criar corporação.',
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
      child: effectiveHasCorp
          ? _buildAffiliatedView()
          : _buildFreelancerView(),
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

    // PASSO 4: Tela de Criação de Corporação
    if (_currentView == 'create') {
      return _buildCreateView();
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
              // Badge de status e botão de atualização
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
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
                  IconButton(
                    icon: const Icon(Icons.refresh, color: _cyanColor, size: 18),
                    tooltip: 'Atualizar Dados',
                    onPressed: () => _fetchCorporationStatus(),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
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
                    _corpNameController.clear();
                    _stationSearchController.clear();
                    _stationSearchFilter = '';
                    _selectedStationId = null;
                  });
                  _fetchAvailableStations();
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
              // Badge de status pendente e botão de atualização
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
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
                  IconButton(
                    icon: const Icon(Icons.refresh, color: _cyanColor, size: 18),
                    tooltip: 'Atualizar Dados',
                    onPressed: () => _fetchCorporationStatus(),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
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

  /// PASSO 4: Tela de Criação da Própria Corporação
  Widget _buildCreateView() {
    final filteredStations = _availableStations.where((s) {
      final name = (s['station_name'] ?? '').toString().toLowerCase();
      final orbit = (s['orbit_name'] ?? '').toString().toLowerCase();
      final term = _stationSearchFilter.toLowerCase().trim();
      return name.contains(term) || orbit.contains(term);
    }).toList();

    final bool hasEnoughCredits = _pilotCredits >= 1000000;
    final bool isNameValid = _corpNameController.text.trim().length >= 3;
    final bool canSubmit = isNameValid && _selectedStationId != null && hasEnoughCredits && !_isSubmittingAction;

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
                border: const Border(bottom: BorderSide(color: Colors.white12)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: _greenAccent, size: 20),
                    tooltip: 'Voltar',
                    onPressed: () {
                      setState(() {
                        _currentView = 'initial';
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CRIAR UMA CORPORAÇÃO ESTELAR',
                          style: GoogleFonts.shareTechMono(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                        Text(
                          'Defina o nome oficial, escolha a estação base e transfira a taxa de abertura',
                          style: GoogleFonts.shareTechMono(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Conteúdo rolável de criação
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Card 1: Resumo Financeiro da Fundação
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _panelBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: hasEnoughCredits ? _greenAccent.withOpacity(0.4) : _redAccent.withOpacity(0.5),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                hasEnoughCredits ? Icons.account_balance_wallet_outlined : Icons.money_off_outlined,
                                color: hasEnoughCredits ? _greenAccent : _redAccent,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'TAXA DE FUNDAÇÃO & CARTEIRA',
                                style: GoogleFonts.shareTechMono(
                                  color: hasEnoughCredits ? _greenAccent : _redAccent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: hasEnoughCredits
                                      ? _greenAccent.withOpacity(0.15)
                                      : _redAccent.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: hasEnoughCredits
                                        ? _greenAccent.withOpacity(0.6)
                                        : _redAccent.withOpacity(0.6),
                                  ),
                                ),
                                child: Text(
                                  hasEnoughCredits ? '✓ SALDO SUFICIENTE' : '✗ SALDO INSUFICIENTE',
                                  style: GoogleFonts.shareTechMono(
                                    color: hasEnoughCredits ? _greenAccent : _redAccent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(color: Colors.white12, height: 20),
                          _buildInfoRow('CUSTO DE ABERTURA:', '1.000.000 CR'),
                          const SizedBox(height: 6),
                          _buildInfoRow('SEU SALDO ATUAL:', '${_formatCredits(_pilotCredits)} CR'),
                          const SizedBox(height: 6),
                          _buildInfoRow(
                            'DESTINO DA TAXA:',
                            _selectedStationId != null ? 'Carteira da Estação Base' : 'Estação a definir',
                          ),
                          if (!hasEnoughCredits) ...[
                            const SizedBox(height: 10),
                            Text(
                              'Você precisa de pelo menos 1.000.000 CR para fundar uma corporação. Complete contratos ou venda itens para acumular os créditos.',
                              style: GoogleFonts.shareTechMono(color: _redAccent, fontSize: 11),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Card 2: Nome da Corporação
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _panelBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.badge_outlined, color: _cyanColor, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                '1. NOME DA CORPORAÇÃO (3 A 30 CARACTERES)',
                                style: GoogleFonts.shareTechMono(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _corpNameController,
                            maxLength: 30,
                            onChanged: (val) {
                              setState(() {});
                            },
                            style: GoogleFonts.shareTechMono(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: _cardBg,
                              hintText: 'Ex: Weyland-Yutani, Atlas Corp, Orion Syndicate...',
                              hintStyle: GoogleFonts.shareTechMono(color: Colors.white38, fontSize: 13),
                              prefixIcon: const Icon(Icons.business_outlined, color: _cyanColor, size: 20),
                              counterStyle: GoogleFonts.shareTechMono(color: Colors.white38, fontSize: 11),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: isNameValid ? _cyanColor.withOpacity(0.5) : Colors.white24,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: const BorderSide(color: _cyanColor, width: 1.5),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Card 3: Seleção da Estação Base
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _panelBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.hub_outlined, color: _cyanColor, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '2. ESCOLHA A ESTAÇÃO BASE PRINCIPAL',
                                  style: GoogleFonts.shareTechMono(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ),
                              if (_selectedStationId != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _greenAccent.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: _greenAccent.withOpacity(0.5)),
                                  ),
                                  child: Text(
                                    'SELECIONADA',
                                    style: GoogleFonts.shareTechMono(
                                      color: _greenAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'A estação base será a sede oficial de operações da sua corporação. A taxa de 1.000.000 CR será depositada na carteira desta estação.',
                            style: GoogleFonts.shareTechMono(color: Colors.white54, fontSize: 11, height: 1.3),
                          ),
                          const SizedBox(height: 12),

                          // Campo de busca da estação
                          TextField(
                            controller: _stationSearchController,
                            onChanged: (val) {
                              setState(() {
                                _stationSearchFilter = val;
                              });
                            },
                            style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 12),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: _cardBg,
                              hintText: 'Filtrar estação pelo nome ou órbita...',
                              hintStyle: GoogleFonts.shareTechMono(color: Colors.white38, fontSize: 12),
                              prefixIcon: const Icon(Icons.search, color: _cyanColor, size: 18),
                              suffixIcon: _stationSearchFilter.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, color: Colors.white54, size: 16),
                                      onPressed: () {
                                        setState(() {
                                          _stationSearchController.clear();
                                          _stationSearchFilter = '';
                                        });
                                      },
                                    )
                                  : null,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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

                          const SizedBox(height: 12),

                          // Lista rolável de estações
                          _isLoadingStations
                              ? const Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Center(
                                    child: CircularProgressIndicator(color: _cyanColor),
                                  ),
                                )
                              : _stationsErrorMessage != null
                                  ? Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        children: [
                                          Text(
                                            _stationsErrorMessage!,
                                            style: GoogleFonts.shareTechMono(color: _redAccent, fontSize: 12),
                                          ),
                                          const SizedBox(height: 8),
                                          ElevatedButton(
                                            onPressed: _fetchAvailableStations,
                                            style: ElevatedButton.styleFrom(backgroundColor: _cyanColor),
                                            child: Text('TENTAR NOVAMENTE', style: GoogleFonts.shareTechMono()),
                                          ),
                                        ],
                                      ),
                                    )
                                  : filteredStations.isEmpty
                                      ? Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Center(
                                            child: Text(
                                              'Nenhuma estação encontrada.',
                                              style: GoogleFonts.shareTechMono(color: Colors.white38, fontSize: 12),
                                            ),
                                          ),
                                        )
                                      : Container(
                                          constraints: const BoxConstraints(maxHeight: 220),
                                          decoration: BoxDecoration(
                                            color: _cardBg,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: Colors.white12),
                                          ),
                                          child: ListView.separated(
                                            shrinkWrap: true,
                                            padding: const EdgeInsets.all(8),
                                            itemCount: filteredStations.length,
                                            separatorBuilder: (ctx, i) => const Divider(color: Colors.white10, height: 1),
                                            itemBuilder: (ctx, index) {
                                              final st = filteredStations[index];
                                              final int stId = st['station_id'];
                                              final bool isSelected = _selectedStationId == stId;

                                              return InkWell(
                                                onTap: () {
                                                  setState(() {
                                                    _selectedStationId = stId;
                                                  });
                                                },
                                                borderRadius: BorderRadius.circular(4),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                  decoration: BoxDecoration(
                                                    color: isSelected ? _greenAccent.withOpacity(0.12) : Colors.transparent,
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: isSelected ? Border.all(color: _greenAccent) : null,
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                                        color: isSelected ? _greenAccent : Colors.white38,
                                                        size: 18,
                                                      ),
                                                      const SizedBox(width: 10),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text(
                                                              st['station_name'] ?? 'Estação',
                                                              style: GoogleFonts.shareTechMono(
                                                                color: isSelected ? _greenAccent : Colors.white,
                                                                fontSize: 13,
                                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                              ),
                                                            ),
                                                            Text(
                                                              'ÓRBITA: ${st['orbit_name'] ?? 'Desconhecida'}',
                                                              style: GoogleFonts.shareTechMono(
                                                                color: Colors.white54,
                                                                fontSize: 10,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      Text(
                                                        '#$stId',
                                                        style: GoogleFonts.shareTechMono(color: Colors.white30, fontSize: 11),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Barra inferior com botões de ação
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _panelBg,
                border: Border(top: BorderSide(color: _greenAccent.withOpacity(0.3))),
              ),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _currentView = 'initial';
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
                      onPressed: canSubmit ? _submitCreateCorporation : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _greenAccent.withOpacity(0.2),
                        foregroundColor: _greenAccent,
                        side: BorderSide(
                          color: canSubmit ? _greenAccent : Colors.white12,
                          width: 1.2,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      icon: _isSubmittingAction
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: _greenAccent),
                            )
                          : const Icon(Icons.add_business_outlined, size: 18),
                      label: Text(
                        !hasEnoughCredits
                            ? 'SALDO INSUFICIENTE (1.000.000 CR)'
                            : !isNameValid
                                ? 'INFORME O NOME DA CORP'
                                : _selectedStationId == null
                                    ? 'SELECIONE A ESTAÇÃO BASE'
                                    : 'FUNDAR CORPORAÇÃO (1.000.000 CR)',
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

  /// Verifica se o jogador logado possui privilégios de gestão (Líder ou Oficial)
  bool get _isLeaderOrOfficer {
    final corp = _corporationData ?? {};
    final myMemberInfo = _corpMembers.firstWhere(
      (m) => m['pilot_uid'] == _pilotUid,
      orElse: () => {},
    );
    final String myRole = (myMemberInfo['role'] ?? corp['role'] ?? 'member').toString().toLowerCase();
    return myRole == 'leader' ||
        myRole == 'officer' ||
        corp['is_leader'] == true ||
        myMemberInfo['is_founder'] == true ||
        myMemberInfo['is_founder'] == 1 ||
        myMemberInfo['is_founder'] == '1';
  }

  /// Visão caso o jogador já pertença a uma corporação
  Widget _buildAffiliatedView() {
    final corp = _corporationData ?? {};
    final String corpName = corp['name'] ?? 'CORPORAÇÃO';
    final String role = (corp['role'] ?? 'Membro').toString().toUpperCase();
    final bool isLeaderOrOfficer = _isLeaderOrOfficer;
    final String stationName = corp['station_name'] ?? 'Não Definida';
    final String founderName = corp['founder_name'] ?? 'Desconhecido';
    final num corpCredits = num.tryParse(corp['credits']?.toString() ?? corp['corporation_credits']?.toString() ?? '0') ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Box com informações da Corporação
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                        const Icon(Icons.shield_outlined, color: _cyanColor, size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                corpName.toUpperCase(),
                                style: GoogleFonts.shareTechMono(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              Text(
                                'SUA CORPORAÇÃO ATIVA',
                                style: GoogleFonts.shareTechMono(
                                  color: _greenAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.refresh, color: _cyanColor, size: 18),
                              tooltip: 'Atualizar Dados',
                              onPressed: () {
                                _fetchCorporationStatus();
                                _fetchCorporationTeams();
                                _fetchCorporationMembers();
                                if (_currentAffiliatedTab == 'items') {
                                  _fetchCorpCargo();
                                  _fetchMemberCargo(_selectedMemberPilotUid ?? _pilotUid);
                                }
                              },
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _cyanColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: _cyanColor.withOpacity(0.5)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.military_tech_outlined, color: _cyanColor, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    role,
                                    style: GoogleFonts.shareTechMono(
                                      color: _cyanColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Abas internas: MEMBROS | ITENS | FINANCEIRO logo abaixo do nome da corporação
                    _buildAffiliatedTabs(),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Conteúdo Dinâmico da Aba Selecionada
              if (_currentAffiliatedTab == 'admitted') ...[
                // Box separado para informações de operação e gestão da corporação
                _buildCorporationInfoBox(
                  stationName: stationName,
                  founderName: founderName,
                  corpCredits: corpCredits,
                  isLeaderOrOfficer: isLeaderOrOfficer,
                ),
                const SizedBox(height: 10),
                _buildAdmittedManagementView(),
              ] else if (_currentAffiliatedTab == 'items') ...[
                _buildItemsManagementView(),
              ] else if (_currentAffiliatedTab == 'finance') ...[
                _buildPlaceholderTab(
                  'PARTE FINANCEIRA',
                  'Módulo de tesouraria, fluxo de caixa, transferências e histórico financeiro em desenvolvimento.',
                  Icons.account_balance_wallet_outlined,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Box separado com informações operacionais da Corporação (Estação Base, Líder, Status, Saldo, Equipes)
  Widget _buildCorporationInfoBox({
    required String stationName,
    required String founderName,
    required num corpCredits,
    required bool isLeaderOrOfficer,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _panelBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('ESTAÇÃO BASE:', stationName),
          const SizedBox(height: 4),
          // Linha com Líder Fundador e Status juntos, sem espaçamento interno entre label e valor
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'LÍDER FUNDADOR: ',
                    style: GoogleFonts.shareTechMono(color: Colors.white54, fontSize: 11),
                  ),
                  Text(
                    founderName,
                    style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'STATUS: ',
                    style: GoogleFonts.shareTechMono(color: Colors.white54, fontSize: 11),
                  ),
                  Text(
                    'EM OPERAÇÃO ATIVA',
                    style: GoogleFonts.shareTechMono(color: _cyanColor, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          if (isLeaderOrOfficer) ...[
            const SizedBox(height: 4),
            _buildInfoRow(
              'SALDO DE CRÉDITOS:',
              '${_formatCredits(corpCredits)} CR',
              valueColor: _greenAccent,
            ),
          ],
          const SizedBox(height: 6),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 6),
          // Linha com Total de Membros no lado esquerdo e Botão Gerenciar Equipes no lado direito
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.people_alt_outlined, color: _cyanColor, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'TOTAL DE MEMBROS: ',
                    style: GoogleFonts.shareTechMono(color: Colors.white54, fontSize: 11),
                  ),
                  Text(
                    '${_corpMembers.length}',
                    style: GoogleFonts.shareTechMono(
                      color: _cyanColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: isLeaderOrOfficer ? _showTeamsManagementDialog : null,
                icon: Icon(
                  Icons.groups_outlined,
                  size: 14,
                  color: isLeaderOrOfficer ? _cyanColor : Colors.white24,
                ),
                label: Text(
                  'GERENCIAR EQUIPES',
                  style: GoogleFonts.shareTechMono(
                    color: isLeaderOrOfficer ? _cyanColor : Colors.white24,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: isLeaderOrOfficer ? _cyanColor.withOpacity(0.5) : Colors.white10,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  backgroundColor: isLeaderOrOfficer ? _cyanColor.withOpacity(0.06) : Colors.transparent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Barra de 3 Abas de Gestão Corporativa
  Widget _buildAffiliatedTabs() {
    return Row(
      children: [
        Expanded(
          child: _buildTabButton(
            title: 'MEMBROS',
            icon: Icons.badge_outlined,
            isSelected: _currentAffiliatedTab == 'admitted',
            onTap: () => setState(() => _currentAffiliatedTab = 'admitted'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildTabButton(
            title: 'ITENS',
            icon: Icons.inventory_2_outlined,
            isSelected: _currentAffiliatedTab == 'items',
            onTap: _onItemsTabSelected,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildTabButton(
            title: 'FINANCEIRO',
            icon: Icons.account_balance_wallet_outlined,
            isSelected: _currentAffiliatedTab == 'finance',
            onTap: () => setState(() => _currentAffiliatedTab = 'finance'),
          ),
        ),
      ],
    );
  }

  Widget _buildTabButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _cyanColor.withOpacity(0.18) : _darkBg,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? _cyanColor : Colors.white12,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: isSelected ? _cyanColor : Colors.white54),
            const SizedBox(width: 6),
            Text(
              title,
              style: GoogleFonts.shareTechMono(
                color: isSelected ? _cyanColor : Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// PARTE 1: Controle dos Admitidos
  Widget _buildAdmittedManagementView() {
    if (_isLoadingMembers) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: _cyanColor),
              const SizedBox(height: 12),
              Text(
                'CARREGANDO MEMBROS ADMITIDOS...',
                style: GoogleFonts.shareTechMono(color: _cyanColor, fontSize: 12, letterSpacing: 1.1),
              ),
            ],
          ),
        ),
      );
    }

    if (_membersErrorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _panelBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _redAccent.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: _redAccent, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _membersErrorMessage!,
                style: GoogleFonts.shareTechMono(color: Colors.white70, fontSize: 12),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: _cyanColor, size: 18),
              onPressed: () => _fetchCorporationMembers(),
            ),
          ],
        ),
      );
    }

    final filteredMembers = _corpMembers.where((m) {
      if (_memberRoleFilter != 'all') {
        final role = (m['role']?.toString() ?? 'member').toLowerCase();
        if (role != _memberRoleFilter) return false;
      }
      if (_memberTeamFilter != 'all') {
        if (_memberTeamFilter == 'none') {
          if (m['team_uid'] != null) return false;
        } else {
          if (m['team_uid']?.toString() != _memberTeamFilter) return false;
        }
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Linha com 2 Filtros (Cargo e Equipe) no lugar do antigo label, mais botão de refresh
        Row(
          children: [
            // Filtro por Cargo
            Expanded(
              child: Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: _panelBg,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _memberRoleFilter != 'all' ? _cyanColor : Colors.white12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _memberRoleFilter,
                    isDense: true,
                    isExpanded: true,
                    dropdownColor: _cardBg,
                    icon: const Icon(Icons.arrow_drop_down, color: _cyanColor, size: 18),
                    style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 11),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('Cargo: Todos')),
                      DropdownMenuItem(value: 'leader', child: Text('Líder', style: TextStyle(color: _amberAccent))),
                      DropdownMenuItem(value: 'officer', child: Text('Oficial', style: TextStyle(color: _cyanColor))),
                      DropdownMenuItem(value: 'member', child: Text('Membro', style: TextStyle(color: Colors.white70))),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _memberRoleFilter = val);
                      }
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Filtro por Equipe
            Expanded(
              child: Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: _panelBg,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _memberTeamFilter != 'all' ? _greenAccent : Colors.white12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: (_memberTeamFilter == 'all' || _memberTeamFilter == 'none' || _corpTeams.any((t) => t['team_uid'].toString() == _memberTeamFilter))
                        ? _memberTeamFilter
                        : 'all',
                    isDense: true,
                    isExpanded: true,
                    dropdownColor: _cardBg,
                    icon: const Icon(Icons.arrow_drop_down, color: _greenAccent, size: 18),
                    style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 11),
                    items: [
                      const DropdownMenuItem(value: 'all', child: Text('Equipe: Todas')),
                      const DropdownMenuItem(value: 'none', child: Text('Sem Equipe', style: TextStyle(color: Colors.white38))),
                      ..._corpTeams.map((t) {
                        final tUid = t['team_uid'].toString();
                        final desc = t['description']?.toString() ?? 'Equipe';
                        return DropdownMenuItem(
                          value: tUid,
                          child: Text(
                            desc,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: _greenAccent),
                          ),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _memberTeamFilter = val);
                      }
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),

            // Botão de Refresh da lista
            IconButton(
              icon: const Icon(Icons.refresh, color: _cyanColor, size: 18),
              tooltip: 'Atualizar Lista',
              onPressed: () {
                _fetchCorporationMembers();
                _fetchCorporationTeams();
              },
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (_corpMembers.isEmpty)
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: _panelBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white12),
            ),
            child: Center(
              child: Text(
                'Nenhum membro na corporação até o momento.',
                style: GoogleFonts.shareTechMono(color: Colors.white38, fontSize: 12),
              ),
            ),
          )
        else if (filteredMembers.isEmpty)
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: _panelBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white12),
            ),
            child: Center(
              child: Text(
                'Nenhum membro encontrado com os filtros selecionados.',
                style: GoogleFonts.shareTechMono(color: Colors.white38, fontSize: 12),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: _panelBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white12),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (int i = 0; i < filteredMembers.length; i++) ...[
                  if (i > 0) const Divider(color: Colors.white10, height: 1),
                  _buildMemberCard(filteredMembers[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }

  /// Linha compacta (Single-Line) de cada membro admitido dentro do box unificado
  Widget _buildMemberCard(Map<String, dynamic> member) {
    final pilotName = member['pilot_name']?.toString() ?? 'Piloto';
    final pilotUid = member['pilot_uid'];
    final isFounder = member['is_founder'] == true || member['is_founder'] == 1 || member['is_founder'] == '1';
    final isMe = pilotUid == _pilotUid;
    final roleStr = (member['role']?.toString() ?? 'member').toLowerCase();

    String roleLabel;
    Color roleColor;
    switch (roleStr) {
      case 'leader':
        roleLabel = 'Líder';
        roleColor = _amberAccent;
        break;
      case 'officer':
        roleLabel = 'Oficial';
        roleColor = _cyanColor;
        break;
      case 'member':
      default:
        roleLabel = 'Membro';
        roleColor = Colors.white70;
        break;
    }

    // Busca o nome da equipe associada
    String teamName = member['team_name']?.toString() ?? 'Sem Equipe';
    if (member['team_uid'] != null) {
      final teamMatch = _corpTeams.firstWhere(
        (t) => t['team_uid'] == member['team_uid'] || t['team_uid'].toString() == member['team_uid'].toString(),
        orElse: () => {},
      );
      if (teamMatch.isNotEmpty && teamMatch['description'] != null) {
        teamName = teamMatch['description'];
      }
    }
    final bool hasTeam = teamName != 'Sem Equipe' && teamName.isNotEmpty;

    return Material(
      color: isMe ? _cyanColor.withOpacity(0.05) : Colors.transparent,
      child: InkWell(
        onTap: _isLeaderOrOfficer ? () => _showMemberDetailsDialog(member) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            children: [
              // Ícone indicativo
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isFounder ? _amberAccent.withOpacity(0.15) : _cyanColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isFounder ? _amberAccent.withOpacity(0.5) : _cyanColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Icon(
                  isFounder ? Icons.military_tech_outlined : Icons.person_outline,
                  color: isFounder ? _amberAccent : _cyanColor,
                  size: 14,
                ),
              ),
              const SizedBox(width: 8),

              // Nome do Piloto + Badge VOCÊ
              Expanded(
                flex: 5,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        pilotName.toUpperCase(),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: GoogleFonts.shareTechMono(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: _greenAccent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: _greenAccent.withOpacity(0.5)),
                        ),
                        child: Text(
                          'VOCÊ',
                          style: GoogleFonts.shareTechMono(
                            color: _greenAccent,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),

              // Cargo
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: roleColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: roleColor.withOpacity(0.4)),
                ),
                child: Text(
                  roleLabel,
                  style: GoogleFonts.shareTechMono(
                    color: roleColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Equipe (se não couber na tela, omite o resto com reticências)
              Expanded(
                flex: 4,
                child: Text(
                  teamName,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  textAlign: TextAlign.end,
                  style: GoogleFonts.shareTechMono(
                    color: hasTeam ? _greenAccent : Colors.white38,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Ícone Lápis para abrir Detalhes (desativado para membros comuns)
              IconButton(
                icon: Icon(
                  Icons.edit_outlined,
                  color: _isLeaderOrOfficer ? _cyanColor : Colors.white24,
                  size: 16,
                ),
                tooltip: _isLeaderOrOfficer ? 'Gerenciar Piloto' : 'Apenas Líder e Oficiais',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: _isLeaderOrOfficer ? () => _showMemberDetailsDialog(member) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Diálogo de Detalhes e Gestão do Membro
  Future<void> _showMemberDetailsDialog(Map<String, dynamic> member) async {
    if (!_isLeaderOrOfficer) return;
    final pilotUid = member['pilot_uid'];
    if (pilotUid == null) return;

    final pilotName = member['pilot_name']?.toString() ?? 'Piloto';
    final isFounder = member['is_founder'] == true || member['is_founder'] == 1 || member['is_founder'] == '1';
    final isMe = pilotUid == _pilotUid;
    final joinedAt = _formatDateTime(member['joined_at']);

    String selectedRole = (member['role']?.toString() ?? 'member').toLowerCase();
    if (!['leader', 'officer', 'member'].contains(selectedRole)) selectedRole = 'member';
    int? selectedTeamUid = member['team_uid'] != null ? int.tryParse(member['team_uid'].toString()) : null;

    bool isUpdatingRole = false;
    bool isUpdatingTeam = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isTeamValid = selectedTeamUid == null || _corpTeams.any((t) => int.tryParse(t['team_uid'].toString()) == selectedTeamUid);
          final effectiveTeamUid = isTeamValid ? selectedTeamUid : null;

          return AlertDialog(
            backgroundColor: _cardBg,
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: _cyanColor, width: 1.2),
              borderRadius: BorderRadius.circular(8),
            ),
            titlePadding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            title: Row(
              children: [
                const Icon(Icons.manage_accounts_outlined, color: _cyanColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'DETALHES DO MEMBRO',
                    style: GoogleFonts.shareTechMono(
                      color: _cyanColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                  onPressed: () => Navigator.of(ctx).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Box com info de cabeçalho do piloto
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _panelBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isFounder ? _amberAccent.withOpacity(0.15) : _cyanColor.withOpacity(0.12),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isFounder ? _amberAccent.withOpacity(0.5) : _cyanColor.withOpacity(0.3),
                                ),
                              ),
                              child: Icon(
                                isFounder ? Icons.military_tech_outlined : Icons.person_outline,
                                color: isFounder ? _amberAccent : _cyanColor,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    pilotName.toUpperCase(),
                                    style: GoogleFonts.shareTechMono(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                  if (isFounder)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _amberAccent.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(3),
                                        border: Border.all(color: _amberAccent.withOpacity(0.6)),
                                      ),
                                      child: Text(
                                        'FUNDADOR',
                                        style: GoogleFonts.shareTechMono(color: _amberAccent, fontSize: 9, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  if (isMe)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _greenAccent.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(3),
                                        border: Border.all(color: _greenAccent.withOpacity(0.6)),
                                      ),
                                      child: Text(
                                        'VOCÊ',
                                        style: GoogleFonts.shareTechMono(color: _greenAccent, fontSize: 9, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.access_time, size: 12, color: Colors.white38),
                            const SizedBox(width: 6),
                            Text(
                              'DATA DE ADMISSÃO: $joinedAt',
                              style: GoogleFonts.shareTechMono(color: Colors.white54, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Atribuir Cargo
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'CARGO NA CORPORAÇÃO:',
                        style: GoogleFonts.shareTechMono(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      if (isUpdatingRole)
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2, color: _cyanColor),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: _panelBg,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: _cyanColor.withOpacity(0.4)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedRole,
                        isDense: true,
                        isExpanded: true,
                        dropdownColor: _cardBg,
                        icon: const Icon(Icons.arrow_drop_down, color: _cyanColor),
                        style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 12),
                        items: const [
                          DropdownMenuItem(
                            value: 'leader',
                            child: Text('Líder', style: TextStyle(color: _amberAccent, fontWeight: FontWeight.bold)),
                          ),
                          DropdownMenuItem(
                            value: 'officer',
                            child: Text('Oficial', style: TextStyle(color: _cyanColor, fontWeight: FontWeight.bold)),
                          ),
                          DropdownMenuItem(
                            value: 'member',
                            child: Text('Membro', style: TextStyle(color: Colors.white70)),
                          ),
                        ],
                        onChanged: isFounder || isUpdatingRole
                            ? null
                            : (newRole) async {
                                if (newRole != null && newRole != selectedRole) {
                                  setDialogState(() {
                                    selectedRole = newRole;
                                    isUpdatingRole = true;
                                  });
                                  member['role'] = newRole;
                                  await _updateMemberRole(pilotUid, newRole);
                                  setDialogState(() {
                                    isUpdatingRole = false;
                                  });
                                  setState(() {});
                                }
                              },
                      ),
                    ),
                  ),
                  if (isFounder) ...[
                    const SizedBox(height: 4),
                    Text(
                      '* O comandante fundador detém a liderança permanente.',
                      style: GoogleFonts.shareTechMono(color: _amberAccent.withOpacity(0.8), fontSize: 10),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Atribuir Equipe
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'EQUIPE / DIVISÃO:',
                        style: GoogleFonts.shareTechMono(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      if (isUpdatingTeam)
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2, color: _greenAccent),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: _panelBg,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: _greenAccent.withOpacity(0.4)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        value: effectiveTeamUid,
                        isDense: true,
                        isExpanded: true,
                        dropdownColor: _cardBg,
                        icon: const Icon(Icons.arrow_drop_down, color: _greenAccent),
                        style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 12),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Sem Equipe', style: TextStyle(color: Colors.white38)),
                          ),
                          ..._corpTeams.map((t) {
                            final tUid = int.tryParse(t['team_uid'].toString());
                            final desc = t['description']?.toString() ?? 'Equipe';
                            return DropdownMenuItem<int?>(
                              value: tUid,
                              child: Text(desc, style: const TextStyle(color: _greenAccent)),
                            );
                          }).toList(),
                        ],
                        onChanged: isUpdatingTeam
                            ? null
                            : (newTeamUid) async {
                                if (newTeamUid != effectiveTeamUid) {
                                  setDialogState(() {
                                    selectedTeamUid = newTeamUid;
                                    isUpdatingTeam = true;
                                  });
                                  member['team_uid'] = newTeamUid;
                                  await _updateMemberTeam(pilotUid, newTeamUid);
                                  setDialogState(() {
                                    isUpdatingTeam = false;
                                  });
                                  setState(() {});
                                }
                              },
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 12),

                  // Botão de Desligar Membro (apenas se não for fundador)
                  if (!isFounder)
                    OutlinedButton.icon(
                      onPressed: () async {
                        final nav = Navigator.of(ctx);
                        await _confirmRemoveMember(member);
                        nav.pop();
                      },
                      icon: const Icon(Icons.person_remove_outlined, color: _redAccent, size: 16),
                      label: Text(
                        'DESLIGAR MEMBRO DA CORPORAÇÃO',
                        style: GoogleFonts.shareTechMono(color: _redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _redAccent.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        backgroundColor: _redAccent.withOpacity(0.06),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('CONCLUÍDO', style: GoogleFonts.shareTechMono(color: _cyanColor, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Placeholder para abas de Itens e Financeiro
  Widget _buildPlaceholderTab(String title, String description, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      decoration: BoxDecoration(
        color: _panelBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _cyanColor.withOpacity(0.4), size: 36),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.shareTechMono(
                color: _cyanColor,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                description,
                textAlign: TextAlign.center,
                style: GoogleFonts.shareTechMono(color: Colors.white54, fontSize: 11, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.shareTechMono(color: Colors.white54, fontSize: 11),
        ),
        Text(
          value,
          style: GoogleFonts.shareTechMono(
            color: valueColor ?? Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // MÓDULO DE MOVIMENTAÇÃO DE ITENS DA CORPORAÇÃO (SUB-ABA ITENS)
  // ===========================================================================

  void _onItemsTabSelected() {
    setState(() {
      _currentAffiliatedTab = 'items';
      if (_selectedMemberPilotUid == null) {
        _selectedMemberPilotUid = _pilotUid;
        final myMember = _corpMembers.firstWhere(
          (m) => m['pilot_uid']?.toString() == _pilotUid.toString(),
          orElse: () => _corpMembers.isNotEmpty ? _corpMembers.first : <String, dynamic>{},
        );
        _selectedMemberData = myMember.isNotEmpty ? myMember : null;
      }
    });
    _fetchCorpCargo();
    _fetchMemberCargo(_selectedMemberPilotUid ?? _pilotUid);
  }

  Future<void> _fetchCorpCargo({bool silent = false}) async {
    final corpId = _corpUid;
    if (corpId == null) return;
    if (!silent) setState(() => _isLoadingCorpCargo = true);

    try {
      final uri = Uri.parse('${widget.apiBaseUrl}/api/corporation/$corpId/items');
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final decoded = json.decode(res.body);
        if (decoded['status'] == 'sucesso') {
          final data = decoded['data'] ?? {};
          setState(() {
            _corpCargoItems = List<Map<String, dynamic>>.from(data['items'] ?? []);
            _corpMaxVolume = (data['max_volume'] as num?)?.toInt() ?? 100000;
            _corpUsedVolume = (data['used_volume'] as num?)?.toInt() ?? 0;
            _isLoadingCorpCargo = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('Erro ao buscar itens da corporação: $e');
    }
    if (mounted) setState(() => _isLoadingCorpCargo = false);
  }

  Future<void> _fetchMemberCargo(int pilotUid, {bool silent = false}) async {
    final corpId = _corpUid;
    if (corpId == null) return;
    if (!silent) setState(() => _isLoadingMemberCargo = true);

    try {
      final uri = Uri.parse('${widget.apiBaseUrl}/api/corporation/$corpId/member-hangar/$pilotUid');
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final decoded = json.decode(res.body);
        if (decoded['status'] == 'sucesso') {
          final data = decoded['data'] ?? {};
          setState(() {
            _memberCargoItems = List<Map<String, dynamic>>.from(data['items'] ?? []);
            _memberMaxVolume = (data['max_volume'] as num?)?.toInt() ?? 50000;
            _memberUsedVolume = (data['used_volume'] as num?)?.toInt() ?? 0;
            _isLoadingMemberCargo = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('Erro ao buscar itens do membro: $e');
    }
    if (mounted) setState(() => _isLoadingMemberCargo = false);
  }

  Map<String, dynamic>? _getSelectedTransferItem() {
    if (_selectedTransferItemCode == null || _selectedTransferSource == null) return null;
    final list = _selectedTransferSource == 'CORP' ? _corpCargoItems : _memberCargoItems;
    try {
      return list.firstWhere(
        (it) => (it['item_code'] as num).toInt() == _selectedTransferItemCode,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _handleTransferItem(String direction) async {
    final corpId = _corpUid;
    if (corpId == null || _isTransferringItem) return;
    final item = _getSelectedTransferItem();
    if (item == null) return;

    final targetPilotUid = _selectedMemberPilotUid ?? _pilotUid;
    final itemCode = (item['item_code'] as num).toInt();
    final quantity = _transferQuantity;

    setState(() => _isTransferringItem = true);

    try {
      final uri = Uri.parse('${widget.apiBaseUrl}/api/corporation/$corpId/transfer-item');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'pilot_uid': targetPilotUid,
          'item_code': itemCode,
          'quantity': quantity,
          'direction': direction,
          'operator_pilot_uid': _pilotUid,
        }),
      ).timeout(const Duration(seconds: 8));

      final decoded = json.decode(res.body);
      if (!mounted) return;
      if (res.statusCode == 200 && decoded['status'] == 'sucesso') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              decoded['mensagem'] ?? 'Transferência realizada com sucesso!',
              style: GoogleFonts.shareTechMono(color: Colors.white),
            ),
            backgroundColor: const Color(0xFF00382B),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {
          _selectedTransferItemCode = null;
          _selectedTransferSource = null;
          _transferQuantity = 1;
        });
        await _fetchCorpCargo(silent: true);
        await _fetchMemberCargo(targetPilotUid, silent: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              decoded['mensagem'] ?? 'Falha ao transferir item.',
              style: GoogleFonts.shareTechMono(color: Colors.white),
            ),
            backgroundColor: _redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erro de conexão com o servidor: $e',
            style: GoogleFonts.shareTechMono(color: Colors.white),
          ),
          backgroundColor: _redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isTransferringItem = false);
    }
  }

  Widget _buildItemsManagementView() {
    final selectedItem = _getSelectedTransferItem();
    final int maxItemAmount = selectedItem != null
        ? ((selectedItem['amount'] as num?)?.toInt() ?? 0)
        : 0;

    final bool isMemberItemSelected = selectedItem != null && _selectedTransferSource == 'MEMBER';
    final bool isCorpItemSelected = selectedItem != null && _selectedTransferSource == 'CORP';

    final bool canMoveToCorp = !_isTransferringItem &&
        isMemberItemSelected &&
        _transferQuantity > 0 &&
        _transferQuantity <= maxItemAmount;

    final bool canMoveToMember = !_isTransferringItem &&
        isCorpItemSelected &&
        _transferQuantity > 0 &&
        _transferQuantity <= maxItemAmount;

    final memberName = _selectedMemberData?['pilot_name'] ??
        _corpMembers.firstWhere(
          (m) => m['pilot_uid']?.toString() == _selectedMemberPilotUid?.toString(),
          orElse: () => {'pilot_name': 'VOCÊ'},
        )['pilot_name'] ?? 'PILOTO';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Barra de Categorias de Itens (INSUMOS, ARMAS, MÍSSEIS, DISPOSITIVOS, UTILITÁRIOS)
        _buildItemCategoriesBar(),
        const SizedBox(height: 8),

        // 2. Box Superior: Área de Carga da Corporação
        _buildCargoBox(
          title: 'ÁREA DE CARGA DA CORPORAÇÃO',
          subtitle: 'LIVRE: ${_formatCredits(_corpMaxVolume - _corpUsedVolume)} m³ / MÁX: ${_formatCredits(_corpMaxVolume)} m³',
          items: _corpCargoItems.where((it) => (it['item_type'] as num?)?.toInt() == _selectedItemCategory).toList(),
          sourceKey: 'CORP',
          isLoading: _isLoadingCorpCargo,
          accentColor: _cyanColor,
          emptyMessage: 'Nenhum item deste grupo na área de carga da corporação.',
        ),
        const SizedBox(height: 8),

        // 3. Barra Central: [PARA A CORPORAÇÃO] [- QTD +] [PARA O MEMBRO] [HISTÓRICO]
        _buildItemTransferControlBar(
          canMoveToCorp: canMoveToCorp,
          canMoveToMember: canMoveToMember,
          maxItemAmount: maxItemAmount,
        ),
        const SizedBox(height: 8),

        // 4. Box Inferior: Área de Carga do Membro
        _buildCargoBox(
          title: 'ÁREA DE CARGA DE:',
          memberName: memberName,
          isMemberBox: true,
          subtitle: 'OCUPADO: ${_formatCredits(_memberUsedVolume)} / ${_formatCredits(_memberMaxVolume)} m³ (LIVRE: ${_formatCredits(_memberMaxVolume - _memberUsedVolume)} m³)',
          items: _memberCargoItems.where((it) => (it['item_type'] as num?)?.toInt() == _selectedItemCategory).toList(),
          sourceKey: 'MEMBER',
          isLoading: _isLoadingMemberCargo,
          accentColor: _amberAccent,
          emptyMessage: 'Nenhum item deste grupo na área de carga selecionada.',
        ),
      ],
    );
  }

  Widget _buildItemCategoriesBar() {
    return Row(
      children: _itemCategories.map((cat) {
        final int type = cat['type'] as int;
        final String label = cat['label'] as String;
        final int flexWeight = (cat['flex'] as int?) ?? 10;
        final bool isSelected = _selectedItemCategory == type;

        return Expanded(
          flex: flexWeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedItemCategory = type;
                  _selectedTransferItemCode = null;
                  _selectedTransferSource = null;
                  _transferQuantity = 1;
                });
              },
              borderRadius: BorderRadius.circular(4),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                decoration: BoxDecoration(
                  color: isSelected ? _greenAccent : _panelBg,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isSelected ? _greenAccent : _cyanColor,
                    width: isSelected ? 1.8 : 1.0,
                  ),
                ),
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: GoogleFonts.shareTechMono(
                      color: isSelected ? Colors.black : Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCargoBox({
    required String title,
    String? memberName,
    bool isMemberBox = false,
    required String subtitle,
    required List<Map<String, dynamic>> items,
    required String sourceKey,
    required bool isLoading,
    required Color accentColor,
    required String emptyMessage,
  }) {
    return Container(
      height: 155,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _panelBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _cyanColor.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (!isMemberBox) ...[
                Text(
                  title,
                  style: GoogleFonts.shareTechMono(
                    color: _greenAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ] else ...[
                Text(
                  title,
                  style: GoogleFonts.shareTechMono(
                    color: _cyanColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 6),
                if (_isLeaderOrOfficer) ...[
                  InkWell(
                    onTap: _showMemberSelectorDialog,
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _cyanColor.withOpacity(0.12),
                        border: Border.all(color: _cyanColor, width: 1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            memberName?.toUpperCase() ?? 'MEMBRO',
                            style: GoogleFonts.shareTechMono(
                              color: _cyanColor,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_drop_down, color: _cyanColor, size: 14),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      border: Border.all(color: Colors.white24, width: 1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      memberName?.toUpperCase() ?? 'VOCÊ',
                      style: GoogleFonts.shareTechMono(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
              const Spacer(),
              Text(
                subtitle,
                style: GoogleFonts.shareTechMono(
                  color: Colors.white60,
                  fontSize: 9.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 6),

          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: _cyanColor, strokeWidth: 2))
                : items.isEmpty
                    ? Center(
                        child: Text(
                          emptyMessage,
                          style: GoogleFonts.shareTechMono(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 82,
                          mainAxisExtent: 90,
                          crossAxisSpacing: 6,
                          mainAxisSpacing: 6,
                        ),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final int itemCode = (item['item_code'] as num).toInt();
                          final bool isSelected = _selectedTransferSource == sourceKey &&
                              _selectedTransferItemCode == itemCode;
                          final int amount = (item['amount'] as num?)?.toInt() ?? 0;
                          final int itemType = (item['item_type'] as num?)?.toInt() ?? 1;

                          return InkWell(
                            onTap: () {
                              setState(() {
                                _selectedTransferSource = sourceKey;
                                _selectedTransferItemCode = itemCode;
                                _transferQuantity = 1;
                              });
                            },
                            borderRadius: BorderRadius.circular(4),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: isSelected ? accentColor.withOpacity(0.18) : _cardBg,
                                border: Border.all(
                                  color: isSelected ? accentColor : Colors.white24,
                                  width: isSelected ? 1.6 : 0.8,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: Stack(
                                      children: [
                                        Positioned.fill(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF0B0E14),
                                              borderRadius: BorderRadius.circular(2),
                                            ),
                                            clipBehavior: Clip.antiAlias,
                                            child: _buildItemImage(
                                              item['image_url'] as String?,
                                              itemType,
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          right: 2,
                                          bottom: 2,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(0.85),
                                              border: Border.all(color: accentColor, width: 0.7),
                                              borderRadius: BorderRadius.circular(2),
                                            ),
                                            child: Text(
                                              'QTD: $amount',
                                              style: GoogleFonts.shareTechMono(
                                                color: accentColor,
                                                fontSize: 7.5,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 2),

                                  Text(
                                    (item['name'] ?? '').toString().toUpperCase(),
                                    style: GoogleFonts.shareTechMono(
                                      color: isSelected ? accentColor : Colors.white,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemTransferControlBar({
    required bool canMoveToCorp,
    required bool canMoveToMember,
    required int maxItemAmount,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: _panelBg,
        border: Border.all(color: _cyanColor.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 28,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _greenAccent,
                  disabledBackgroundColor: Colors.white12,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                onPressed: canMoveToCorp ? () => _handleTransferItem('TO_CORPORATION') : null,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.arrow_upward_rounded,
                        color: canMoveToCorp ? Colors.black : Colors.white24,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'PARA A CORPORAÇÃO',
                        style: GoogleFonts.shareTechMono(
                          color: canMoveToCorp ? Colors.black : Colors.white24,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 6),

          Container(
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF0D121B),
              border: Border.all(color: _cyanColor.withOpacity(0.6)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: _selectedTransferItemCode != null && _transferQuantity > 1
                      ? () => setState(() => _transferQuantity--)
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Icon(
                      Icons.remove,
                      color: _selectedTransferItemCode != null && _transferQuantity > 1
                          ? _cyanColor
                          : Colors.white24,
                      size: 14,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'QTD: $_transferQuantity',
                    style: GoogleFonts.shareTechMono(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                InkWell(
                  onTap: _selectedTransferItemCode != null && _transferQuantity < maxItemAmount
                      ? () => setState(() => _transferQuantity++)
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Icon(
                      Icons.add,
                      color: _selectedTransferItemCode != null && _transferQuantity < maxItemAmount
                          ? _cyanColor
                          : Colors.white24,
                      size: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 6),

          Expanded(
            child: SizedBox(
              height: 28,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _cyanColor,
                  disabledBackgroundColor: Colors.white12,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                onPressed: canMoveToMember ? () => _handleTransferItem('TO_MEMBER') : null,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.arrow_downward_rounded,
                        color: canMoveToMember ? Colors.black : Colors.white24,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'PARA O MEMBRO',
                        style: GoogleFonts.shareTechMono(
                          color: canMoveToMember ? Colors.black : Colors.white24,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 6),

          SizedBox(
            height: 28,
            width: 32,
            child: IconButton(
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF0D121B),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                  side: BorderSide(color: _cyanColor.withOpacity(0.6)),
                ),
              ),
              icon: const Icon(Icons.receipt_long, color: _cyanColor, size: 15),
              tooltip: 'Histórico de Movimentações',
              onPressed: _showItemTransactionsDialog,
            ),
          ),
        ],
      ),
    );
  }

  void _showMemberSelectorDialog() {
    String search = '';
    String selectedRole = 'all';
    String selectedTeam = 'all';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = _corpMembers.where((m) {
              final name = (m['pilot_name'] ?? '').toString().toLowerCase();
              final role = (m['role'] ?? 'member').toString().toLowerCase();
              final teamUid = m['team_uid']?.toString() ?? 'none';

              if (search.isNotEmpty && !name.contains(search.toLowerCase())) {
                return false;
              }
              if (selectedRole != 'all' && role != selectedRole) {
                return false;
              }
              if (selectedTeam != 'all') {
                if (selectedTeam == 'none' && teamUid != 'none') return false;
                if (selectedTeam != 'none' && teamUid != selectedTeam) return false;
              }
              return true;
            }).toList();

            return Dialog(
              backgroundColor: const Color(0xFF0B0E14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: _cyanColor, width: 1.5),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480, maxHeight: 520),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.person_search, color: _cyanColor, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'SELECIONAR CARGA DE MEMBRO',
                                style: GoogleFonts.shareTechMono(
                                  color: _cyanColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                            onPressed: () => Navigator.of(ctx).pop(),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      TextField(
                        style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Filtrar por nome do piloto...',
                          hintStyle: GoogleFonts.shareTechMono(color: Colors.white38, fontSize: 11),
                          prefixIcon: const Icon(Icons.search, color: _cyanColor, size: 16),
                          filled: true,
                          fillColor: const Color(0xFF151922),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: const BorderSide(color: Colors.white24),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: const BorderSide(color: _cyanColor),
                          ),
                        ),
                        onChanged: (val) {
                          setModalState(() => search = val);
                        },
                      ),
                      const SizedBox(height: 8),

                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedRole,
                              dropdownColor: const Color(0xFF151922),
                              isDense: true,
                              style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 11),
                              decoration: InputDecoration(
                                labelText: 'Cargo',
                                labelStyle: GoogleFonts.shareTechMono(color: _cyanColor, fontSize: 10),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                filled: true,
                                fillColor: const Color(0xFF151922),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'all', child: Text('Todos os Cargos')),
                                DropdownMenuItem(value: 'leader', child: Text('Líder')),
                                DropdownMenuItem(value: 'officer', child: Text('Oficial')),
                                DropdownMenuItem(value: 'member', child: Text('Membro')),
                              ],
                              onChanged: (val) {
                                if (val != null) setModalState(() => selectedRole = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedTeam,
                              dropdownColor: const Color(0xFF151922),
                              isDense: true,
                              style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 11),
                              decoration: InputDecoration(
                                labelText: 'Equipe',
                                labelStyle: GoogleFonts.shareTechMono(color: _cyanColor, fontSize: 10),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                filled: true,
                                fillColor: const Color(0xFF151922),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                              ),
                              items: [
                                const DropdownMenuItem(value: 'all', child: Text('Todas as Equipes')),
                                const DropdownMenuItem(value: 'none', child: Text('Sem Equipe')),
                                ..._corpTeams.map((t) => DropdownMenuItem(
                                  value: t['team_uid'].toString(),
                                  child: Text(t['description'] ?? 'Equipe #${t['team_uid']}'),
                                )),
                              ],
                              onChanged: (val) {
                                if (val != null) setModalState(() => selectedTeam = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Divider(color: Colors.white12, height: 1),
                      const SizedBox(height: 6),

                      Expanded(
                        child: filtered.isEmpty
                            ? Center(
                                child: Text(
                                  'Nenhum membro encontrado com os filtros aplicados.',
                                  style: GoogleFonts.shareTechMono(color: Colors.white38, fontSize: 11),
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 6),
                                itemBuilder: (context, idx) {
                                  final m = filtered[idx];
                                  final pUid = (m['pilot_uid'] as num).toInt();
                                  final isCurrent = _selectedMemberPilotUid == pUid;
                                  final role = (m['role'] ?? 'member').toString();
                                  final roleLabel = role == 'leader' ? 'Líder' : (role == 'officer' ? 'Oficial' : 'Membro');
                                  final teamName = m['team_name'] ?? 'Sem Equipe';

                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isCurrent ? _cyanColor.withOpacity(0.12) : const Color(0xFF12161F),
                                      border: Border.all(
                                        color: isCurrent ? _cyanColor : Colors.white12,
                                        width: isCurrent ? 1.4 : 0.8,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          role == 'leader' ? Icons.military_tech : (role == 'officer' ? Icons.security : Icons.person_outline),
                                          color: role == 'leader' ? _amberAccent : (role == 'officer' ? _cyanColor : Colors.white70),
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                (m['pilot_name'] ?? 'Piloto').toString().toUpperCase(),
                                                style: GoogleFonts.shareTechMono(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                '$roleLabel • $teamName',
                                                style: GoogleFonts.shareTechMono(
                                                  color: Colors.white54,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: isCurrent ? _greenAccent : _cyanColor,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            visualDensity: VisualDensity.compact,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                          ),
                                          onPressed: () {
                                            Navigator.of(ctx).pop();
                                            setState(() {
                                              _selectedMemberPilotUid = pUid;
                                              _selectedMemberData = m;
                                              _selectedTransferItemCode = null;
                                              _selectedTransferSource = null;
                                              _transferQuantity = 1;
                                            });
                                            _fetchMemberCargo(pUid);
                                          },
                                          child: Text(
                                            isCurrent ? 'SELECIONADO' : 'SELECIONAR',
                                            style: GoogleFonts.shareTechMono(
                                              color: Colors.black,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showItemTransactionsDialog() {
    final corpId = _corpUid;
    if (corpId == null) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return FutureBuilder<http.Response>(
          future: http.get(
            Uri.parse('${widget.apiBaseUrl}/api/corporation/$corpId/item-transactions?caller_pilot_uid=$_pilotUid'),
          ).timeout(const Duration(seconds: 8)),
          builder: (context, snapshot) {
            List<Map<String, dynamic>> transactions = [];
            bool loading = snapshot.connectionState == ConnectionState.waiting;
            String? error;

            if (snapshot.hasError) {
              error = 'Erro ao carregar histórico: ${snapshot.error}';
            } else if (snapshot.hasData) {
              final res = snapshot.data!;
              if (res.statusCode == 200) {
                final decoded = json.decode(res.body);
                if (decoded['status'] == 'sucesso') {
                  transactions = List<Map<String, dynamic>>.from(decoded['data'] ?? []);
                } else {
                  error = decoded['mensagem'] ?? 'Falha ao buscar movimentações.';
                }
              } else {
                error = 'Erro no servidor: ${res.statusCode}';
              }
            }

            return Dialog(
              backgroundColor: const Color(0xFF0B0E14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: _cyanColor, width: 1.5),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520, maxHeight: 540),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.receipt_long, color: _cyanColor, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'HISTÓRICO DE MOVIMENTAÇÃO',
                                style: GoogleFonts.shareTechMono(
                                  color: _cyanColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                            onPressed: () => Navigator.of(ctx).pop(),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isLeaderOrOfficer
                            ? 'Registro de todas as doações e retiradas de itens da corporação.'
                            : 'Registro das movimentações de itens associadas a você.',
                        style: GoogleFonts.shareTechMono(color: Colors.white54, fontSize: 10),
                      ),
                      const SizedBox(height: 10),
                      const Divider(color: Colors.white12, height: 1),
                      const SizedBox(height: 8),

                      Expanded(
                        child: loading
                            ? const Center(child: CircularProgressIndicator(color: _cyanColor, strokeWidth: 2))
                            : error != null
                                ? Center(
                                    child: Text(
                                      error,
                                      style: GoogleFonts.shareTechMono(color: _redAccent, fontSize: 11),
                                      textAlign: TextAlign.center,
                                    ),
                                  )
                                : transactions.isEmpty
                                    ? Center(
                                        child: Text(
                                          'Nenhuma movimentação de itens registrada até o momento.',
                                          style: GoogleFonts.shareTechMono(color: Colors.white38, fontSize: 11),
                                          textAlign: TextAlign.center,
                                        ),
                                      )
                                    : ListView.separated(
                                        itemCount: transactions.length,
                                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                                        itemBuilder: (context, idx) {
                                          final t = transactions[idx];
                                          final bool isToCorp = t['direction'] == 'TO_CORPORATION';
                                          final String itemName = t['item_name'] ?? 'Item';
                                          final int qty = (t['quantity'] as num?)?.toInt() ?? 1;
                                          final String pilotName = t['pilot_name'] ?? 'Piloto';
                                          final String operatorName = t['operator_name'] ?? 'Operador';
                                          final String dateStr = _formatDateTime(t['created_at']);
                                          final Color badgeColor = isToCorp ? _greenAccent : _cyanColor;

                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF12161F),
                                              border: Border.all(color: Colors.white12),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(5),
                                                  decoration: BoxDecoration(
                                                    color: badgeColor.withOpacity(0.12),
                                                    border: Border.all(color: badgeColor, width: 0.8),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Icon(
                                                    isToCorp ? Icons.arrow_upward : Icons.arrow_downward,
                                                    color: badgeColor,
                                                    size: 16,
                                                  ),
                                                ),
                                                const SizedBox(width: 10),

                                                Container(
                                                  width: 34,
                                                  height: 34,
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF0B0E14),
                                                    borderRadius: BorderRadius.circular(3),
                                                    border: Border.all(color: Colors.white12),
                                                  ),
                                                  clipBehavior: Clip.antiAlias,
                                                  child: _buildItemImage(
                                                    t['image_url'] as String?,
                                                    (t['item_type'] as num?)?.toInt() ?? 1,
                                                  ),
                                                ),
                                                const SizedBox(width: 10),

                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Text(
                                                            itemName.toUpperCase(),
                                                            style: GoogleFonts.shareTechMono(
                                                              color: Colors.white,
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                          const SizedBox(width: 6),
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                            decoration: BoxDecoration(
                                                              color: badgeColor.withOpacity(0.15),
                                                              borderRadius: BorderRadius.circular(2),
                                                            ),
                                                            child: Text(
                                                              'QTD: $qty',
                                                              style: GoogleFonts.shareTechMono(
                                                                color: badgeColor,
                                                                fontSize: 9,
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        isToCorp ? 'Doador: $pilotName' : 'Destinatário: $pilotName',
                                                        style: GoogleFonts.shareTechMono(color: Colors.white70, fontSize: 10),
                                                      ),
                                                      if (operatorName != pilotName) ...[
                                                        Text(
                                                          'Por: $operatorName',
                                                          style: GoogleFonts.shareTechMono(color: Colors.white38, fontSize: 9),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),

                                                Text(
                                                  dateStr,
                                                  style: GoogleFonts.shareTechMono(color: Colors.white38, fontSize: 9.5),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildItemImage(String? rawUrl, int itemType) {
    if (rawUrl != null && rawUrl.trim().isNotEmpty) {
      String cleanUrl = rawUrl.trim();
      if (cleanUrl.toLowerCase().endsWith('.svg')) {
        cleanUrl = cleanUrl.replaceAll(RegExp(r'\.svg$', caseSensitive: false), '.png');
      }
      final String fullUrl = cleanUrl.startsWith('http')
          ? cleanUrl
          : '${widget.apiBaseUrl}${cleanUrl.startsWith('/') ? '' : '/'}$cleanUrl';
      return Image.network(
        fullUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildItemFallbackIcon(itemType),
      );
    }
    return _buildItemFallbackIcon(itemType);
  }

  Widget _buildItemFallbackIcon(int itemType) {
    IconData iconData = Icons.category_outlined;
    switch (itemType) {
      case 1: iconData = Icons.hexagon_outlined; break;
      case 2: iconData = Icons.gps_fixed; break;
      case 3: iconData = Icons.rocket_launch_outlined; break;
      case 4: iconData = Icons.memory; break;
      case 5: iconData = Icons.handyman_outlined; break;
      case 6: iconData = Icons.flight; break;
    }
    return Center(child: Icon(iconData, color: Colors.white30, size: 18));
  }
}
