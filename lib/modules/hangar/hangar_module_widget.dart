import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class HangarModuleWidget extends StatefulWidget {
  final Map<String, dynamic>? profileData;
  final String apiBaseUrl;
  final VoidCallback? onProfileRefresh;

  const HangarModuleWidget({
    super.key,
    this.profileData,
    this.apiBaseUrl = 'http://26.239.180.177:8020',
    this.onProfileRefresh,
  });

  @override
  State<HangarModuleWidget> createState() => _HangarModuleWidgetState();
}

class _HangarModuleWidgetState extends State<HangarModuleWidget> {
  static const Color _cyanColor = Color(0xFF00D2FF);
  static const Color _greenAccent = Color(0xFF00FF66);
  static const Color _amberAccent = Color(0xFFFFB800);
  static const Color _redAccent = Color(0xFFFF3333);
  static const Color _panelBg = Color(0xD912161F);
  static const Color _cardBg = Color(0xFF151922);

  // Controle de abas para visualização Mobile
  String _activeMobileTab = 'NAVE'; // 'NAVE', 'FROTA', 'LOADOUT'

  // Nave ativa selecionada
  int _selectedShipIndex = 0;

  // Categoria de catálogo ativa no Loadout
  String _selectedLoadoutCategory = 'CANHÕES'; // 'CANHÕES', 'MÍSSEIS', 'DISPOSITIVOS', 'UTILITÁRIOS'

  // Slot selecionado no Loadout
  String _selectedSlotId = 'can:0';

  // Item selecionado no catálogo para comparação
  int _selectedCatalogItemIndex = 0;

  bool _isLoadingFleet = true;
  bool _isActivatingVessel = false;
  bool _isRepairingVessel = false;
  bool _isEquippingLoadout = false;
  String? _fleetErrorMessage;
  StateSetter? _dialogSetState;
  int? _apiPilotCredits;

  // Lista de naves carregada da API
  List<Map<String, dynamic>> _fleet = [];

  // Catálogo consolidado de itens disponíveis (Estoque + Mercado)
  Map<String, List<Map<String, dynamic>>> _catalog = {
    'CANHÕES': [],
    'MÍSSEIS': [],
    'DISPOSITIVOS': [],
    'UTILITÁRIOS': [],
  };

  void _updateState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
    _dialogSetState?.call(() {});
  }

  @override
  void initState() {
    super.initState();
    _fetchFleetFromApi();
  }

  int _getPilotUid() {
    final profile = widget.profileData ?? {};
    final operatorData = profile['operator'] ?? {};
    final dynamic rawUid =
        operatorData['account_id'] ??
        operatorData['operator_uid'] ??
        operatorData['pilot_uid'] ??
        operatorData['uid'] ??
        profile['account_id'] ??
        profile['uid'];
    if (rawUid != null) {
      if (rawUid is int) return rawUid;
      return int.tryParse(rawUid.toString()) ?? 0;
    }
    return 0;
  }

  int _getPilotCredits() {
    if (_apiPilotCredits != null) return _apiPilotCredits!;
    final profile = widget.profileData ?? {};
    final dynamic rawCredits =
        profile['credits'] ??
        (profile['wallet'] is Map ? profile['wallet']['credits'] : null) ??
        (profile['operator'] is Map ? profile['operator']['credits'] : null);
    if (rawCredits != null) {
      if (rawCredits is num) return rawCredits.toInt();
      final cleaned = rawCredits.toString().replaceAll(RegExp(r'[^0-9]'), '');
      return int.tryParse(cleaned) ?? 0;
    }
    return 0;
  }

  Color _colorForIntegrity(double val, bool isSelected) {
    if (val < 70) return _amberAccent;
    if (isSelected) return _greenAccent;
    return _cyanColor;
  }

  Map<String, List<Map<String, dynamic>>> _getCurrentShipHardpoints() {
    if (_fleet.isEmpty) {
      return {
        'CANHÕES': [],
        'MÍSSEIS': [],
        'DISPOSITIVOS': [],
        'UTILITÁRIOS': [],
      };
    }
    final ship = _fleet[_selectedShipIndex.clamp(0, _fleet.length - 1)];
    final rawHp = ship['hardpoints'];
    if (rawHp is Map<String, List<Map<String, dynamic>>>) {
      return rawHp;
    }
    return {
      'CANHÕES': [],
      'MÍSSEIS': [],
      'DISPOSITIVOS': [],
      'UTILITÁRIOS': [],
    };
  }

  Future<void> _fetchFleetFromApi({bool preserveSelection = false}) async {
    final int pilotUid = _getPilotUid();
    if (pilotUid == 0) {
      _updateState(() {
        _isLoadingFleet = false;
        _fleetErrorMessage = 'ID do piloto não identificado.';
      });
      return;
    }

    final dynamic previousVesselUid =
        (preserveSelection && _fleet.isNotEmpty && _selectedShipIndex < _fleet.length)
            ? _fleet[_selectedShipIndex]['vessel_uid']
            : null;

    if (!preserveSelection) {
      _updateState(() {
        _isLoadingFleet = true;
        _fleetErrorMessage = null;
      });
    }

    try {
      final uri = Uri.parse('${widget.apiBaseUrl}/api/hangar/fleet/$pilotUid');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded['status'] == 'sucesso' && decoded['data'] != null) {
          final int? fetchedCredits =
              (decoded['data']['pilot']?['credits'] as num?)?.toInt();
          final List rawVessels = decoded['data']['vessels'] ?? [];
          final Map<String, dynamic> rawCatalog =
              (decoded['data']['catalog'] as Map<String, dynamic>?) ?? {};

          final Map<String, List<Map<String, dynamic>>> parsedCatalog = {
            'CANHÕES': [],
            'MÍSSEIS': [],
            'DISPOSITIVOS': [],
            'UTILITÁRIOS': [],
          };
          for (final catKey in parsedCatalog.keys) {
            final List rawList = (rawCatalog[catKey] as List?) ?? [];
            parsedCatalog[catKey] =
                rawList
                    .map<Map<String, dynamic>>((item) => Map<String, dynamic>.from(item as Map))
                    .toList();
          }

          final List<Map<String, dynamic>> loaded =
              rawVessels.map<Map<String, dynamic>>((v) {
                final double avgInt = (v['integrity'] as num?)?.toDouble() ?? 100.0;
                final bool isSel = v['selected'] == true;
                final int cap = (v['cargo_capacity'] as num?)?.toInt() ?? 0;
                final List rawSubs = v['subsystems'] ?? [];
                final Map<String, dynamic> rawStats =
                    (v['stats'] as Map<String, dynamic>?) ?? {};
                final Map<String, dynamic> rawHp =
                    (v['hardpoints'] as Map<String, dynamic>?) ?? {};

                final Map<String, List<Map<String, dynamic>>> parsedHp = {
                  'CANHÕES': [],
                  'MÍSSEIS': [],
                  'DISPOSITIVOS': [],
                  'UTILITÁRIOS': [],
                };
                for (final catKey in parsedHp.keys) {
                  final List rawSlots = (rawHp[catKey] as List?) ?? [];
                  parsedHp[catKey] =
                      rawSlots
                          .map<Map<String, dynamic>>((s) => Map<String, dynamic>.from(s as Map))
                          .toList();
                }

                return {
                  'id': 'v${v['vessel_uid']}',
                  'vessel_uid': v['vessel_uid'],
                  'item_code': v['item_code'],
                  'name': v['name'] ?? 'NAVE DESCONHECIDA',
                  'registry': v['registry'] ?? 'Registro #${v['vessel_uid']}',
                  'integrity': avgInt,
                  'hull_integrity': (v['hull_integrity'] as num?)?.toDouble() ?? avgInt,
                  'base_price': (v['base_price'] as num?)?.toInt() ?? 250000,
                  'damage_percent':
                      (v['damage_percent'] as num?)?.toDouble() ??
                      (100.0 - avgInt).clamp(0.0, 100.0),
                  'repair_cost': (v['repair_cost'] as num?)?.toInt() ?? 0,
                  'selected': isSel,
                  'is_at_current_station': v['is_at_current_station'] == true,
                  'status': v['status'] ?? (isSel ? 'ATIVA' : 'ATRACADA'),
                  'location_label': v['location_label'] ?? '',
                  'hold': '$cap V',
                  'hologram_url': v['hologram_url'],
                  'color': _colorForIntegrity(avgInt, isSel),
                  'subsystems':
                      rawSubs
                          .map<Map<String, dynamic>>(
                            (s) => {
                              'key': (s['key'] ?? '').toString(),
                              'name': s['name'].toString(),
                              'repair_cost': (s['repair_cost'] as num?)?.toInt() ?? 0,
                              'val': (s['val'] as num).toDouble(),
                              'status': s['status'].toString(),
                            },
                          )
                          .toList(),
                  'hardpoints': parsedHp,
                  'stats': {
                    'dps': (rawStats['dps'] as num?)?.toInt() ?? 0,
                    'energyUsed': (rawStats['energyUsed'] as num?)?.toInt() ?? 0,
                    'energyMax': (rawStats['energyMax'] as num?)?.toInt() ?? 650,
                    'mass': (rawStats['mass'] as num?)?.toDouble() ?? (cap / 50.0).clamp(5.0, 500.0),
                  },
                };
              }).toList();

          if (mounted) {
            _updateState(() {
              if (fetchedCredits != null) {
                _apiPilotCredits = fetchedCredits;
              }
              _fleet = loaded;
              _catalog = parsedCatalog;
              _isLoadingFleet = false;
              if (preserveSelection && previousVesselUid != null) {
                final int prevIdx = _fleet.indexWhere(
                  (s) => s['vessel_uid'] == previousVesselUid,
                );
                if (prevIdx >= 0) {
                  _selectedShipIndex = prevIdx;
                }
              } else {
                final int activeIdx = _fleet.indexWhere((s) => s['selected'] == true);
                if (activeIdx >= 0) {
                  _selectedShipIndex = activeIdx;
                } else {
                  final int stationIdx = _fleet.indexWhere(
                    (s) => s['is_at_current_station'] == true,
                  );
                  _selectedShipIndex = stationIdx >= 0 ? stationIdx : 0;
                }
              }
              final catItems = _catalog[_selectedLoadoutCategory] ?? [];
              if (_selectedCatalogItemIndex >= catItems.length) {
                _selectedCatalogItemIndex = 0;
              }
            });
          }
          return;
        }
      }
      if (mounted) {
        _updateState(() {
          _isLoadingFleet = false;
          _fleetErrorMessage = 'Erro ao carregar frota (${response.statusCode}).';
        });
      }
    } catch (e) {
      if (mounted) {
        _updateState(() {
          _isLoadingFleet = false;
          _fleetErrorMessage = 'Falha de conexão com o servidor do Hangar.';
        });
      }
    }
  }

  Future<void> _activateVessel(Map<String, dynamic> ship) async {
    if (_isActivatingVessel) return;
    final bool isAtStation = ship['is_at_current_station'] == true;
    if (!isAtStation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: _amberAccent,
          content: Text(
            'ESTA NAVE ESTÁ EM OUTRA ESTAÇÃO! Viaje até lá para ativá-la.',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
        ),
      );
      return;
    }

    final int pilotUid = _getPilotUid();
    final dynamic vesselUid = ship['vessel_uid'];
    if (pilotUid == 0 || vesselUid == null) return;

    _updateState(() {
      _isActivatingVessel = true;
    });

    try {
      final uri = Uri.parse('${widget.apiBaseUrl}/api/hangar/select-vessel');
      final response = await http.put(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'pilot_uid': pilotUid,
          'vessel_uid': vesselUid,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        await _fetchFleetFromApi(preserveSelection: true);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _greenAccent,
            content: Text(
              'NAVE ${ship['name']} ATIVADA COM SUCESSO!',
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        );
      } else {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _redAccent,
            content: Text(decoded['mensagem'] ?? 'Falha ao ativar nave.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _redAccent,
          content: Text('Erro ao ativar nave: $e'),
        ),
      );
    } finally {
      if (mounted) {
        _updateState(() {
          _isActivatingVessel = false;
        });
      }
    }
  }

  int _resolveTargetDbSlotForCategory(String category) {
    final hp = _getCurrentShipHardpoints();
    final slots = hp[category] ?? [];
    if (slots.isEmpty) {
      if (category == 'MÍSSEIS') return 100;
      if (category == 'DISPOSITIVOS') return 200;
      if (category == 'UTILITÁRIOS') return 300;
      return 0;
    }
    // Se o slot atualmente selecionado pertence a esta categoria, usa ele!
    final selectedInCat = slots.where((s) => s['id'] == _selectedSlotId).toList();
    if (selectedInCat.isNotEmpty) {
      return (selectedInCat.first['db_slot'] as num?)?.toInt() ?? 0;
    }
    // Caso contrário, prioriza o primeiro slot livre da categoria, ou o primeiro slot da categoria
    final freeSlot = slots.where((s) => s['free'] == true).toList();
    if (freeSlot.isNotEmpty) {
      _selectedSlotId = freeSlot.first['id'].toString();
      return (freeSlot.first['db_slot'] as num?)?.toInt() ?? 0;
    }
    _selectedSlotId = slots.first['id'].toString();
    return (slots.first['db_slot'] as num?)?.toInt() ?? 0;
  }

  Future<void> _equipCatalogItem(Map<String, dynamic> item) async {
    if (_isEquippingLoadout || _fleet.isEmpty) return;
    final currentShip = _fleet[_selectedShipIndex];
    if (currentShip['is_at_current_station'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: _amberAccent,
          content: Text(
            'Apenas naves atracadas na estação atual podem ter seu Loadout modificado.',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
        ),
      );
      return;
    }

    final int pilotUid = _getPilotUid();
    final dynamic vesselUid = currentShip['vessel_uid'];
    final int targetDbSlot = _resolveTargetDbSlotForCategory(_selectedLoadoutCategory);
    final bool inStock = item['inStock'] == true;

    _updateState(() {
      _isEquippingLoadout = true;
    });

    try {
      final uri = Uri.parse('${widget.apiBaseUrl}/api/hangar/equip-slot');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'pilot_uid': pilotUid,
          'vessel_uid': vesselUid,
          'db_slot': targetDbSlot,
          'item_code': item['item_code'],
          'buy_if_missing': !inStock,
        }),
      );

      if (!mounted) return;
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 && decoded['status'] == 'sucesso') {
        widget.onProfileRefresh?.call();
        await _fetchFleetFromApi(preserveSelection: true);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _greenAccent,
            content: Text(
              decoded['mensagem'] ?? 'Item equipado com sucesso!',
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _redAccent,
            content: Text(decoded['mensagem'] ?? 'Falha ao equipar item.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _redAccent,
          content: Text('Erro de conexão ao equipar item: $e'),
        ),
      );
    } finally {
      if (mounted) {
        _updateState(() {
          _isEquippingLoadout = false;
        });
      }
    }
  }

  Future<void> _unequipHardpointSlot(Map<String, dynamic> slot) async {
    if (_isEquippingLoadout || _fleet.isEmpty) return;
    final currentShip = _fleet[_selectedShipIndex];
    if (currentShip['is_at_current_station'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: _amberAccent,
          content: Text(
            'Apenas naves atracadas na estação atual podem ter seu Loadout modificado.',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
        ),
      );
      return;
    }

    final int pilotUid = _getPilotUid();
    final dynamic vesselUid = currentShip['vessel_uid'];
    final int dbSlot = (slot['db_slot'] as num?)?.toInt() ?? 0;

    _updateState(() {
      _isEquippingLoadout = true;
    });

    try {
      final uri = Uri.parse('${widget.apiBaseUrl}/api/hangar/unequip-slot');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'pilot_uid': pilotUid,
          'vessel_uid': vesselUid,
          'db_slot': dbSlot,
        }),
      );

      if (!mounted) return;
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 && decoded['status'] == 'sucesso') {
        await _fetchFleetFromApi(preserveSelection: true);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _cyanColor,
            content: Text(
              decoded['mensagem'] ?? 'Item removido para o depósito!',
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _redAccent,
            content: Text(decoded['mensagem'] ?? 'Falha ao desequipar slot.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _redAccent,
          content: Text('Erro de conexão ao desequipar slot: $e'),
        ),
      );
    } finally {
      if (mounted) {
        _updateState(() {
          _isEquippingLoadout = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingFleet) {
      return Container(
        color: const Color(0xFF0A0D12),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  color: _cyanColor,
                  strokeWidth: 2.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'SINCRONIZANDO HANGAR...',
                style: GoogleFonts.shareTechMono(
                  color: _cyanColor,
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_fleet.isEmpty) {
      return Container(
        color: const Color(0xFF0A0D12),
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _panelBg,
              border: Border.all(color: _cyanColor.withValues(alpha: 0.6)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.rocket_launch_outlined, color: _cyanColor, size: 32),
                const SizedBox(height: 10),
                Text(
                  _fleetErrorMessage ?? 'NENHUMA NAVE REGISTRADA PARA ESTE OPERADOR.',
                  style: GoogleFonts.shareTechMono(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _fetchFleetFromApi,
                  icon: const Icon(Icons.refresh, color: Colors.black, size: 15),
                  label: Text(
                    'TENTAR NOVAMENTE',
                    style: GoogleFonts.shareTechMono(
                      color: Colors.black,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(backgroundColor: _cyanColor),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= 950;
        return Container(
          color: const Color(0xFF0A0D12),
          padding: const EdgeInsets.all(12.0),
          child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
        );
      },
    );
  }

  // =========================================================================
  // 1. LAYOUT DESKTOP (Panorâmico em 3 Colunas)
  // =========================================================================
  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Coluna Esquerda: Frota
        SizedBox(
          width: 330,
          child: _buildFleetPanel(),
        ),
        const SizedBox(width: 12),

        // Centro: Holograma da Nave e Status Ativo
        Expanded(
          child: _buildCenterHologramPanel(isDesktop: true),
        ),
        const SizedBox(width: 12),

        // Coluna Direita: Subsistemas & Diagnóstico
        SizedBox(
          width: 360,
          child: _buildSubsystemsPanel(isDesktop: true),
        ),
      ],
    );
  }

  // =========================================================================
  // 2. LAYOUT MOBILE (Organizado em Sub-abas)
  // =========================================================================
  Widget _buildMobileLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Seletor de Sub-Abas no topo
        Row(
          children: [
            Expanded(child: _buildMobileSubTab('NAVE', Icons.rocket_launch)),
            const SizedBox(width: 4),
            Expanded(child: _buildMobileSubTab('FROTA', Icons.format_list_bulleted)),
            const SizedBox(width: 4),
            Expanded(child: _buildMobileSubTab('LOADOUT', Icons.build_circle)),
          ],
        ),
        const SizedBox(height: 10),

        // Conteúdo da Aba Ativa
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _buildMobileTabContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileSubTab(String label, IconData icon) {
    final bool isSelected = _activeMobileTab == label;
    return InkWell(
      onTap: () {
        setState(() {
          _activeMobileTab = label;
        });
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _cyanColor.withValues(alpha: 0.15) : _panelBg,
          border: Border.all(
            color: isSelected ? _greenAccent : _cyanColor.withValues(alpha: 0.4),
            width: isSelected ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? _greenAccent : Colors.white70,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.shareTechMono(
                color: isSelected ? _greenAccent : Colors.white,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileTabContent() {
    switch (_activeMobileTab) {
      case 'FROTA':
        return _buildFleetPanel();
      case 'LOADOUT':
        return _buildLoadoutFullView(isDesktop: false);
      case 'NAVE':
      default:
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildShipCarouselSelector(),
              const SizedBox(height: 10),
              Container(
                height: 260,
                decoration: BoxDecoration(
                  color: _panelBg,
                  border: Border.all(color: _cyanColor.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: _buildHologramViewport(),
              ),
              const SizedBox(height: 10),
              _buildSubsystemsPanel(isDesktop: false),
            ],
          ),
        );
    }
  }

  // =========================================================================
  // PAINEL: FROTA (Seleção de Naves)
  // =========================================================================
  Widget _buildFleetPanel() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _panelBg,
        border: Border.all(color: _cyanColor.withValues(alpha: 0.5), width: 1.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'FROTA',
                style: GoogleFonts.shareTechMono(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${_fleet.length} NAVES',
                style: GoogleFonts.shareTechMono(
                  color: _cyanColor,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'SELEÇÃO DA NAVE ATIVA',
            style: GoogleFonts.shareTechMono(
              color: Colors.white38,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 10),

          // Carrossel compacto no topo
          _buildShipCarouselSelector(),
          const SizedBox(height: 12),

          // Lista de naves da frota
          Expanded(
            child: ListView.separated(
              itemCount: _fleet.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final ship = _fleet[index];
                final bool isSelected = _selectedShipIndex == index;
                final bool isActive = ship['selected'] == true;
                final bool isAtStation = ship['is_at_current_station'] == true;
                final Color shipColor = ship['color'] as Color;
                final double integrity = (ship['integrity'] as num).toDouble();
                final String locationStr = (ship['location_label'] ?? '').toString();

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedShipIndex = index;
                    });
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected ? _cardBg : Colors.transparent,
                      border: Border.all(
                        color: isSelected ? _cyanColor : Colors.white12,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: _cyanColor.withValues(alpha: 0.15),
                                blurRadius: 8,
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
                              isAtStation ? Icons.rocket_launch : Icons.lock_outline,
                              size: 14,
                              color: isAtStation ? shipColor : _amberAccent,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ship['name'],
                                    style: GoogleFonts.shareTechMono(
                                      color: isSelected ? Colors.white : Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (locationStr.isNotEmpty)
                                    Text(
                                      locationStr,
                                      style: GoogleFonts.shareTechMono(
                                        color: isAtStation ? Colors.white54 : _amberAccent,
                                        fontSize: 9,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            if (!isActive && isAtStation)
                              Padding(
                                padding: const EdgeInsets.only(right: 6.0),
                                child: InkWell(
                                  onTap: () => _activateVessel(ship),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: _cyanColor.withValues(alpha: 0.2),
                                      border: Border.all(color: _cyanColor, width: 0.9),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                    child: Text(
                                      'ATIVAR',
                                      style: GoogleFonts.shareTechMono(
                                        color: _cyanColor,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? _greenAccent.withValues(alpha: 0.15)
                                    : (isAtStation ? Colors.white10 : _amberAccent.withValues(alpha: 0.15)),
                                border: Border.all(
                                  color: isActive
                                      ? _greenAccent
                                      : (isAtStation ? Colors.white24 : _amberAccent),
                                  width: 0.8,
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: Text(
                                ship['status'],
                                style: GoogleFonts.shareTechMono(
                                  color: isActive
                                      ? _greenAccent
                                      : (isAtStation ? Colors.white54 : _amberAccent),
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: (integrity / 100).clamp(0.0, 1.0),
                                  minHeight: 4,
                                  backgroundColor: Colors.white10,
                                  valueColor: AlwaysStoppedAnimation<Color>(shipColor),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${integrity.toStringAsFixed(1)}%',
                              style: GoogleFonts.shareTechMono(
                                color: shipColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
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

  // =========================================================================
  // CARROSSEL DE SELEÇÃO RÁPIDA DE NAVE (Filtra naves na mesma estação)
  // =========================================================================
  void _cycleStationShip(int delta) {
    final List<int> stationIndices = [];
    for (int i = 0; i < _fleet.length; i++) {
      if (_fleet[i]['is_at_current_station'] == true) {
        stationIndices.add(i);
      }
    }
    if (stationIndices.isEmpty) {
      setState(() {
        _selectedShipIndex =
            (_selectedShipIndex + delta + _fleet.length) % _fleet.length;
      });
      return;
    }
    final int currentPos = stationIndices.indexOf(_selectedShipIndex);
    final int nextPos =
        currentPos >= 0
            ? (currentPos + delta + stationIndices.length) % stationIndices.length
            : 0;
    setState(() {
      _selectedShipIndex = stationIndices[nextPos];
    });
  }

  Widget _buildShipCarouselSelector() {
    final currentShip = _fleet[_selectedShipIndex];
    final bool isActive = currentShip['selected'] == true;
    final bool isAtStation = currentShip['is_at_current_station'] == true;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: _cardBg,
        border: Border.all(color: Colors.white24, width: 0.8),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_left, color: _cyanColor),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => _cycleStationShip(-1),
          ),
          Expanded(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        currentShip['name'],
                        style: GoogleFonts.shareTechMono(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: _greenAccent.withValues(alpha: 0.18),
                          border: Border.all(color: _greenAccent, width: 0.8),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(
                          'ATIVA',
                          style: GoogleFonts.shareTechMono(
                            color: _greenAccent,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else if (isAtStation)
                      InkWell(
                        onTap: _isActivatingVessel ? null : () => _activateVessel(currentShip),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: _cyanColor.withValues(alpha: 0.2),
                            border: Border.all(color: _cyanColor, width: 0.8),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Text(
                            _isActivatingVessel ? '...' : 'ATIVAR NAVE',
                            style: GoogleFonts.shareTechMono(
                              color: _cyanColor,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: _amberAccent.withValues(alpha: 0.18),
                          border: Border.all(color: _amberAccent, width: 0.8),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(
                          'OUTRA ESTAÇÃO',
                          style: GoogleFonts.shareTechMono(
                            color: _amberAccent,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  currentShip['registry'],
                  style: GoogleFonts.shareTechMono(
                    color: Colors.white54,
                    fontSize: 9,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_right, color: _cyanColor),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => _cycleStationShip(1),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // CENTRO: HOLOGRAMA DA NAVE COM SVG CUSTOM PAINTER
  // =========================================================================
  Widget _buildCenterHologramPanel({required bool isDesktop}) {
    final currentShip = _fleet[_selectedShipIndex];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _panelBg,
        border: Border.all(color: _cyanColor.withValues(alpha: 0.5), width: 1.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          // Tag Superior de Status da Nave Ativa
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _cardBg,
              border: Border.all(color: _cyanColor, width: 1.0),
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: _cyanColor.withValues(alpha: 0.2),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  currentShip['name'],
                  style: GoogleFonts.shareTechMono(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: _greenAccent.withValues(alpha: 0.2),
                    border: Border.all(color: _greenAccent, width: 0.8),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    currentShip['status'],
                    style: GoogleFonts.shareTechMono(
                      color: _greenAccent,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'INT: ${currentShip['integrity']}%',
                  style: GoogleFonts.shareTechMono(
                    color: _cyanColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Área do Holograma Vetorial
          Expanded(
            child: _buildHologramViewport(),
          ),

          // Botão Rápido para Configurar Loadout no Desktop
          if (isDesktop) ...[
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () {
                _showLoadoutDialog();
              },
              icon: const Icon(Icons.build_circle, color: Colors.black, size: 16),
              label: Text(
                'ABRIR LOADOUT COMPLETO',
                style: GoogleFonts.shareTechMono(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _cyanColor,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHologramViewport() {
    final currentShip = _fleet[_selectedShipIndex];
    final String? rawHoloUrl = currentShip['hologram_url']?.toString();
    final String fullHoloUrl =
        (rawHoloUrl != null && rawHoloUrl.isNotEmpty)
            ? (rawHoloUrl.startsWith('http')
                ? rawHoloUrl
                : '${widget.apiBaseUrl}$rawHoloUrl')
            : '';

    return Center(
      child: Container(
        margin: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              _cyanColor.withValues(alpha: 0.10),
              Colors.transparent,
            ],
            radius: 0.85,
          ),
        ),
        child:
            fullHoloUrl.isNotEmpty
                ? Image.network(
                  fullHoloUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: _cyanColor,
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) {
                    return AspectRatio(
                      aspectRatio: 600 / 260,
                      child: CustomPaint(
                        painter: _ShipHologramPainter(),
                      ),
                    );
                  },
                )
                : AspectRatio(
                  aspectRatio: 600 / 260,
                  child: CustomPaint(
                    painter: _ShipHologramPainter(),
                  ),
                ),
      ),
    );
  }

  // =========================================================================
  // PAINEL: SUBSISTEMAS E DIAGNÓSTICO
  // =========================================================================
  Widget _buildSubsystemsPanel({required bool isDesktop}) {
    final currentShip = _fleet[_selectedShipIndex];
    final List subsystems = currentShip['subsystems'] as List;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _panelBg,
        border: Border.all(color: _cyanColor.withValues(alpha: 0.5), width: 1.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SUBSISTEMAS',
                style: GoogleFonts.shareTechMono(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _cyanColor.withValues(alpha: 0.15),
                  border: Border.all(color: _cyanColor, width: 0.8),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  '${currentShip['integrity']}% MÉDIA',
                  style: GoogleFonts.shareTechMono(
                    color: _cyanColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'DIAGNÓSTICO EM TEMPO REAL',
            style: GoogleFonts.shareTechMono(
              color: Colors.white38,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 14),

          // Lista de Subsistemas
          ...subsystems.map((sub) {
            final String name = sub['name'];
            final double val = (sub['val'] as num).toDouble();
            Color barColor = _cyanColor;
            if (val > 100) {
              barColor = _greenAccent;
            } else if (val < 80) {
              barColor = _amberAccent;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.shareTechMono(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        '${val.toStringAsFixed(1)}%',
                        style: GoogleFonts.shareTechMono(
                          color: barColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: (val / 100).clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation<Color>(barColor),
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 6),
          // Legenda do diagnóstico
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildLegendItem('■ >100% SOBRECARGA', _greenAccent),
              _buildLegendItem('■ NOMINAL', _cyanColor),
              _buildLegendItem('■ <80% ATENÇÃO', _amberAccent),
            ],
          ),

          const SizedBox(height: 16),
          _buildRepairSection(currentShip),
          const SizedBox(height: 10),
          // Botão principal de ação
          ElevatedButton(
            onPressed: () {
              if (isDesktop) {
                _showLoadoutDialog();
              } else {
                setState(() {
                  _activeMobileTab = 'LOADOUT';
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _cyanColor,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            child: Text(
              'CONFIGURAR LOADOUT',
              style: GoogleFonts.shareTechMono(
                color: Colors.black,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
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

  Widget _buildRepairSection(Map<String, dynamic> ship) {
    final bool isAtStation = ship['is_at_current_station'] == true;
    final int basePrice = (ship['base_price'] as num?)?.toInt() ?? 250000;
    final double damagePercent = (ship['damage_percent'] as num?)?.toDouble() ?? 0.0;
    final int repairCost = (ship['repair_cost'] as num?)?.toInt() ?? 0;
    final int pilotCredits = _getPilotCredits();
    final bool needsRepair = damagePercent > 0.0 && repairCost > 0;
    final bool canAffordTotal = pilotCredits >= repairCost;
    final bool insufficientFunds = isAtStation && needsRepair && !canAffordTotal;
    final bool canRepair =
        isAtStation && needsRepair && canAffordTotal && !_isRepairingVessel;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _cardBg,
        border: Border.all(
          color: needsRepair
              ? _amberAccent.withValues(alpha: 0.65)
              : _greenAccent.withValues(alpha: 0.45),
          width: 1.0,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'VALOR BASE: ${_formatCredits(basePrice)} CR',
                style: GoogleFonts.shareTechMono(
                  color: Colors.white54,
                  fontSize: 10,
                ),
              ),
              Text(
                needsRepair
                    ? 'AVARIA: ${damagePercent.toStringAsFixed(1)}%'
                    : '100% OPERACIONAL',
                style: GoogleFonts.shareTechMono(
                  color: needsRepair ? _amberAccent : _greenAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: canRepair ? () => _showRepairDialog(ship) : null,
            icon: Icon(
              needsRepair ? Icons.build_rounded : Icons.verified_outlined,
              color: canRepair ? Colors.black : Colors.white38,
              size: 15,
            ),
            label: (_isRepairingVessel || !isAtStation || !needsRepair)
                ? Text(
                    _isRepairingVessel
                        ? 'REPARANDO SUBSISTEMAS...'
                        : (!isAtStation
                            ? 'REPARO INDISPONÍVEL (OUTRA ESTAÇÃO)'
                            : 'SUBSISTEMAS 100% REPARADOS'),
                    style: GoogleFonts.shareTechMono(
                      color: canRepair ? Colors.black : Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  )
                : RichText(
                    text: TextSpan(
                      style: GoogleFonts.shareTechMono(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                      children: [
                        TextSpan(
                          text: 'REPARAR SUBSISTEMAS ',
                          style: TextStyle(
                            color: canRepair ? Colors.black : Colors.white38,
                          ),
                        ),
                        TextSpan(
                          text: '(${_formatCredits(repairCost)} CR)',
                          style: TextStyle(
                            color: canRepair ? Colors.black : _redAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _greenAccent,
              disabledBackgroundColor:
                  insufficientFunds ? Colors.white12 : Colors.white10,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: insufficientFunds
                    ? BorderSide(
                        color: _redAccent.withValues(alpha: 0.45),
                        width: 1.0,
                      )
                    : BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showRepairDialog(Map<String, dynamic> ship) async {
    final int basePrice = (ship['base_price'] as num?)?.toInt() ?? 250000;
    final double damagePercent = (ship['damage_percent'] as num?)?.toDouble() ?? 0.0;
    final int repairCost = (ship['repair_cost'] as num?)?.toInt() ?? 0;
    final List subsystems = ship['subsystems'] as List? ?? [];

    final String? actionKey = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF10151E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: const BorderSide(color: _cyanColor, width: 1.5),
          ),
          title: Row(
            children: [
              const Icon(Icons.build_circle_outlined, color: _greenAccent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'OFICINA DE REPAROS DA ESTAÇÃO',
                  style: GoogleFonts.shareTechMono(
                    color: _greenAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 390,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'NAVE: ${ship['name']} (${ship['registry']})',
                  style: GoogleFonts.shareTechMono(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _cardBg,
                    border: Border.all(color: Colors.white12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'VALOR BASE DA NAVE NOVA:',
                            style: GoogleFonts.shareTechMono(color: Colors.white70, fontSize: 10),
                          ),
                          Text(
                            '${_formatCredits(basePrice)} CR',
                            style: GoogleFonts.shareTechMono(color: _cyanColor, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'AVARIA ACUMULADA:',
                            style: GoogleFonts.shareTechMono(color: Colors.white70, fontSize: 10),
                          ),
                          Text(
                            '${damagePercent.toStringAsFixed(1)}%',
                            style: GoogleFonts.shareTechMono(color: _amberAccent, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white12, height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'CUSTO TOTAL DE REPARO:',
                            style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${_formatCredits(repairCost)} CR',
                            style: GoogleFonts.shareTechMono(color: _greenAccent, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'DETALHAMENTO POR SUBSISTEMA:',
                  style: GoogleFonts.shareTechMono(color: Colors.white54, fontSize: 10),
                ),
                const SizedBox(height: 6),
                ...subsystems.map((sub) {
                  final String key = (sub['key'] ?? '').toString();
                  final String name = (sub['name'] ?? '').toString();
                  final double val = (sub['val'] as num?)?.toDouble() ?? 100.0;
                  final int subCost = (sub['repair_cost'] as num?)?.toInt() ?? 0;
                  final bool damaged = val < 100.0 && subCost > 0;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '$name (${val.toStringAsFixed(0)}%)',
                            style: GoogleFonts.shareTechMono(
                              color: damaged ? Colors.white : Colors.white54,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        if (damaged && key.isNotEmpty)
                          InkWell(
                            onTap: () => Navigator.of(ctx).pop(key),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: _cyanColor.withValues(alpha: 0.15),
                                border: Border.all(color: _cyanColor, width: 0.8),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                'REPARAR (${_formatCredits(subCost)} CR)',
                                style: GoogleFonts.shareTechMono(
                                  color: _cyanColor,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          )
                        else
                          Text(
                            '100% OK',
                            style: GoogleFonts.shareTechMono(
                              color: _greenAccent,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: Text(
                'CANCELAR',
                style: GoogleFonts.shareTechMono(color: Colors.white54, fontSize: 11),
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: _greenAccent),
              onPressed: () => Navigator.of(ctx).pop('ALL'),
              icon: const Icon(Icons.build_rounded, color: Colors.black, size: 14),
              label: Text(
                'REPARAR TUDO (${_formatCredits(repairCost)} CR)',
                style: GoogleFonts.shareTechMono(
                  color: Colors.black,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (actionKey == null) return;
    await _repairVessel(ship, subsystemKey: actionKey == 'ALL' ? null : actionKey);
  }

  Future<void> _repairVessel(Map<String, dynamic> ship, {String? subsystemKey}) async {
    if (_isRepairingVessel) return;
    final int pilotUid = _getPilotUid();
    final dynamic vesselUid = ship['vessel_uid'];
    if (pilotUid == 0 || vesselUid == null) return;

    setState(() {
      _isRepairingVessel = true;
    });

    try {
      final uri = Uri.parse('${widget.apiBaseUrl}/api/hangar/repair-vessel');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'pilot_uid': pilotUid,
          'vessel_uid': vesselUid,
          if (subsystemKey != null) 'subsystem_key': subsystemKey,
        }),
      );

      if (!mounted) return;
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 && decoded['status'] == 'sucesso') {
        widget.onProfileRefresh?.call();
        await _fetchFleetFromApi();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _greenAccent,
            content: Text(
              decoded['mensagem'] ?? 'Subsistemas reparados com sucesso!',
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _redAccent,
            content: Text(decoded['mensagem'] ?? 'Falha ao reparar subsistemas.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _redAccent,
          content: Text('Erro de conexão ao reparar nave: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRepairingVessel = false;
        });
      }
    }
  }

  Widget _buildLegendItem(String text, Color color) {
    return Text(
      text,
      style: GoogleFonts.shareTechMono(
        color: color,
        fontSize: 9,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  // =========================================================================
  // VIEW: LOADOUT (Hardpoints + Catálogo + Comparador)
  // =========================================================================
  String _buildCatalogItemSpecSummary(String category, Map<String, dynamic> item) {
    final int dps = (item['dps'] as num?)?.toInt() ?? 0;
    final int energy = (item['energy'] as num?)?.toInt() ?? 0;
    final int range = (item['range'] as num?)?.toInt() ?? 0;
    final String targetMod = (item['target_module'] ?? '-').toString();
    final String effectVal = (item['effect_value'] ?? '-').toString();
    final String usageType = (item['usage_type'] ?? '-').toString();
    final String cooldown = (item['cooldown'] ?? '-').toString();

    if (category == 'DISPOSITIVOS') {
      return '$targetMod ($effectVal) · $energy MW';
    }
    if (category == 'UTILITÁRIOS') {
      return '$usageType · $effectVal · Recarga $cooldown · $energy MW';
    }
    return 'DPS $dps · $energy MW · $range m';
  }

  Widget _buildLoadoutFullView({required bool isDesktop}) {
    final currentShip = _fleet[_selectedShipIndex];
    final stats = currentShip['stats'] as Map<String, dynamic>;
    final hardpointsMap = _getCurrentShipHardpoints();
    final int pilotCredits = _getPilotCredits();

    Widget hardpointsSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'HARDPOINTS',
              style: GoogleFonts.shareTechMono(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              currentShip['name'],
              style: GoogleFonts.shareTechMono(
                color: _cyanColor,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        ...hardpointsMap.entries.map((entry) {
          final catName = entry.key;
          final slots = entry.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$catName (${slots.where((s) => s['free'] != true).length}/${slots.length})',
                style: GoogleFonts.shareTechMono(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              if (slots.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'Nenhum slot disponível nesta nave',
                    style: GoogleFonts.shareTechMono(color: Colors.white24, fontSize: 9),
                  ),
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: slots.map((slot) {
                    final bool isFree = slot['free'] == true;
                    final bool isSelected = _selectedSlotId == slot['id'];

                    return InkWell(
                      onTap: () {
                        _updateState(() {
                          _selectedSlotId = slot['id'].toString();
                          if (_selectedLoadoutCategory != catName) {
                            _selectedLoadoutCategory = catName;
                            _selectedCatalogItemIndex = 0;
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _cyanColor.withValues(alpha: 0.2)
                              : (isFree ? Colors.transparent : _cardBg),
                          border: Border.all(
                            color: isSelected
                                ? _cyanColor
                                : (isFree ? Colors.white24 : Colors.white38),
                            width: isSelected ? 1.5 : 0.8,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isFree ? Icons.add : Icons.check_circle_outline,
                              size: 11,
                              color: isFree
                                  ? (isSelected ? _cyanColor : Colors.white38)
                                  : _cyanColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              slot['name'].toString(),
                              style: GoogleFonts.shareTechMono(
                                color: isFree
                                    ? (isSelected ? _cyanColor : Colors.white38)
                                    : Colors.white,
                                fontSize: 10,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            if (slot['qty'] != null) ...[
                              const SizedBox(width: 4),
                              Text(
                                'x${slot['qty']}',
                                style: GoogleFonts.shareTechMono(
                                  color: _amberAccent,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                            if (!isFree) ...[
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: _isEquippingLoadout
                                    ? null
                                    : () => _unequipHardpointSlot(slot),
                                child: Padding(
                                  padding: const EdgeInsets.all(2.0),
                                  child: Icon(
                                    Icons.close,
                                    size: 12,
                                    color: _redAccent.withValues(alpha: 0.85),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 10),
            ],
          );
        }),

        // Resumo de Especificações
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _cardBg,
            border: Border.all(color: Colors.white12),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatCol('DPS ESTIMADO', '${stats['dps']}', _redAccent),
              _buildStatCol(
                'ENERGIA',
                '${stats['energyUsed']} / ${stats['energyMax']} MW',
                (stats['energyUsed'] as num) > (stats['energyMax'] as num)
                    ? _redAccent
                    : _cyanColor,
              ),
              _buildStatCol('CARGA/MASSA', '${stats['mass']} T', Colors.white),
            ],
          ),
        ),
      ],
    );

    final List<Map<String, dynamic>> currentCatItems =
        _catalog[_selectedLoadoutCategory] ?? [];

    Widget catalogSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CATÁLOGO DE ITENS',
          style: GoogleFonts.shareTechMono(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        // Abas de categorias do catálogo
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['CANHÕES', 'MÍSSEIS', 'DISPOSITIVOS', 'UTILITÁRIOS'].map((cat) {
              final isCatSelected = _selectedLoadoutCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 6.0),
                child: InkWell(
                  onTap: () {
                    _updateState(() {
                      _selectedLoadoutCategory = cat;
                      _selectedCatalogItemIndex = 0;
                      final catSlots = hardpointsMap[cat] ?? [];
                      if (catSlots.isNotEmpty &&
                          !catSlots.any((s) => s['id'] == _selectedSlotId)) {
                        _selectedSlotId = catSlots.first['id'].toString();
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isCatSelected ? _cyanColor : Colors.transparent,
                      border: Border.all(color: _cyanColor, width: 1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      cat,
                      style: GoogleFonts.shareTechMono(
                        color: isCatSelected ? Colors.black : _cyanColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),

        if (currentCatItems.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _cardBg,
              border: Border.all(color: Colors.white12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text(
                'Nenhum item desta categoria disponível no estoque ou no mercado da estação.',
                style: GoogleFonts.shareTechMono(color: Colors.white54, fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          // Lista de Itens do catálogo
          ...currentCatItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final bool isSel = _selectedCatalogItemIndex == index;
            final bool inStock = item['inStock'] == true;
            final int stockCount = (item['stock'] as num?)?.toInt() ?? 0;
            final int marketStock = (item['market_stock'] as num?)?.toInt() ?? 0;
            final int buyPrice = (item['buy_price'] as num?)?.toInt() ?? 0;
            final bool canAfford = pilotCredits >= buyPrice;

            String availabilityLabel;
            if (inStock && marketStock > 0) {
              availabilityLabel =
                  '$stockCount no estoque · $marketStock no mercado (${_formatCredits(buyPrice)} CR)';
            } else if (inStock) {
              availabilityLabel = '$stockCount no estoque';
            } else {
              availabilityLabel =
                  '$marketStock no mercado · ${_formatCredits(buyPrice)} CR';
            }

            return InkWell(
              onTap: () {
                _updateState(() {
                  _selectedCatalogItemIndex = index;
                });
              },
              borderRadius: BorderRadius.circular(4),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSel ? _cyanColor.withValues(alpha: 0.12) : _cardBg,
                  border: Border.all(
                    color: isSel ? _cyanColor : Colors.white12,
                    width: isSel ? 1.5 : 0.8,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['name'].toString(),
                            style: GoogleFonts.shareTechMono(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _buildCatalogItemSpecSummary(_selectedLoadoutCategory, item),
                            style: GoogleFonts.shareTechMono(
                              color: Colors.white54,
                              fontSize: 9,
                            ),
                          ),
                          Text(
                            availabilityLabel,
                            style: GoogleFonts.shareTechMono(
                              color: inStock
                                  ? _greenAccent
                                  : (canAfford ? _amberAccent : _redAccent),
                              fontSize: 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isEquippingLoadout || (!inStock && !canAfford)
                          ? null
                          : () {
                              _updateState(() {
                                _selectedCatalogItemIndex = index;
                              });
                              _equipCatalogItem(item);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: inStock
                            ? _cyanColor
                            : (canAfford ? _amberAccent : const Color(0xFF1E2430)),
                        disabledBackgroundColor: const Color(0xFF1E2430),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(2),
                          side: (!inStock && !canAfford)
                              ? BorderSide(color: _redAccent.withValues(alpha: 0.5), width: 0.8)
                              : BorderSide.none,
                        ),
                      ),
                      child: Text(
                        inStock
                            ? 'EQUIPAR'
                            : 'COMPRAR (${_formatCredits(buyPrice)} CR)',
                        style: GoogleFonts.shareTechMono(
                          color: (!inStock && !canAfford) ? _redAccent : Colors.black,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

        const SizedBox(height: 10),
        // Caixa de Comparação
        _buildComparisonBox(),
      ],
    );

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: SingleChildScrollView(child: catalogSection)),
          const SizedBox(width: 14),
          Expanded(child: SingleChildScrollView(child: hardpointsSection)),
        ],
      );
    } else {
      return SingleChildScrollView(
        child: Column(
          children: [
            hardpointsSection,
            const SizedBox(height: 14),
            catalogSection,
          ],
        ),
      );
    }
  }

  Widget _buildStatCol(String title, String val, Color valColor) {
    return Column(
      children: [
        Text(
          title,
          style: GoogleFonts.shareTechMono(
            color: Colors.white38,
            fontSize: 8,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          val,
          style: GoogleFonts.shareTechMono(
            color: valColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Map<String, dynamic>? _getSelectedHardpointSlotData() {
    final hp = _getCurrentShipHardpoints();
    // Procura primeiro pelo _selectedSlotId em todas as categorias
    for (final entry in hp.entries) {
      for (final slot in entry.value) {
        if (slot['id'] == _selectedSlotId) {
          return slot;
        }
      }
    }
    // Se não achar, pega o primeiro slot da categoria atual
    final catSlots = hp[_selectedLoadoutCategory] ?? [];
    if (catSlots.isNotEmpty) {
      return catSlots.first;
    }
    return null;
  }

  Widget _buildCompareMetricText(
    String label,
    int candidateVal,
    int currentVal,
    String unit, {
    bool lowerIsBetter = false,
  }) {
    String arrow = '';
    Color color = Colors.white70;
    if (candidateVal > currentVal) {
      arrow = ' ▲';
      color = lowerIsBetter ? _redAccent : _greenAccent;
    } else if (candidateVal < currentVal) {
      arrow = ' ▼';
      color = lowerIsBetter ? _greenAccent : _amberAccent;
    }
    final String unitSuffix = unit.isNotEmpty ? ' $unit' : '';
    return Text(
      '$label: $candidateVal$unitSuffix$arrow',
      style: GoogleFonts.shareTechMono(
        color: color,
        fontSize: 9,
        fontWeight: arrow.isNotEmpty ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildComparisonBox() {
    final catItems = _catalog[_selectedLoadoutCategory] ?? [];
    final selectedItem =
        catItems.isNotEmpty && _selectedCatalogItemIndex < catItems.length
            ? catItems[_selectedCatalogItemIndex]
            : null;

    if (selectedItem == null) return const SizedBox.shrink();

    final currentSlot = _getSelectedHardpointSlotData();
    final bool isSlotFree = currentSlot == null || currentSlot['free'] == true;
    final String slotIdLabel =
        currentSlot != null ? currentSlot['id'].toString().toUpperCase() : 'SLOT';
    final String currentName =
        isSlotFree ? '+ SLOT LIVRE' : (currentSlot['name'] ?? 'Vazio').toString();

    final int curDps = isSlotFree ? 0 : ((currentSlot['dps'] as num?)?.toInt() ?? 0);
    final int curEnergy = isSlotFree ? 0 : ((currentSlot['energy'] as num?)?.toInt() ?? 0);
    final int curRange = isSlotFree ? 0 : ((currentSlot['range'] as num?)?.toInt() ?? 0);
    final String curTarget =
        isSlotFree ? '-' : (currentSlot['target_module'] ?? '-').toString();
    final String curEffect =
        isSlotFree ? '-' : (currentSlot['effect_value'] ?? '-').toString();
    final String curUsage =
        isSlotFree ? '-' : (currentSlot['usage_type'] ?? '-').toString();
    final String curCooldown =
        isSlotFree ? '-' : (currentSlot['cooldown'] ?? '-').toString();

    final int selDps = (selectedItem['dps'] as num?)?.toInt() ?? 0;
    final int selEnergy = (selectedItem['energy'] as num?)?.toInt() ?? 0;
    final int selRange = (selectedItem['range'] as num?)?.toInt() ?? 0;
    final String selTarget = (selectedItem['target_module'] ?? '-').toString();
    final String selEffect = (selectedItem['effect_value'] ?? '-').toString();
    final String selUsage = (selectedItem['usage_type'] ?? '-').toString();
    final String selCooldown = (selectedItem['cooldown'] ?? '-').toString();
    final bool selInStock = selectedItem['inStock'] == true;

    List<Widget> leftSpecs;
    List<Widget> rightSpecs;

    if (_selectedLoadoutCategory == 'DISPOSITIVOS') {
      leftSpecs = [
        Text('Módulo: $curTarget', style: GoogleFonts.shareTechMono(color: Colors.white70, fontSize: 9)),
        Text('Efeito: $curEffect', style: GoogleFonts.shareTechMono(color: Colors.white70, fontSize: 9)),
        Text('Energia: $curEnergy MW', style: GoogleFonts.shareTechMono(color: Colors.white70, fontSize: 9)),
      ];
      rightSpecs = [
        Text('Módulo: $selTarget', style: GoogleFonts.shareTechMono(color: Colors.white70, fontSize: 9)),
        Text('Efeito: $selEffect', style: GoogleFonts.shareTechMono(color: _greenAccent, fontSize: 9, fontWeight: FontWeight.bold)),
        _buildCompareMetricText('Energia', selEnergy, curEnergy, 'MW', lowerIsBetter: true),
      ];
    } else if (_selectedLoadoutCategory == 'UTILITÁRIOS') {
      leftSpecs = [
        Text('Uso: $curUsage', style: GoogleFonts.shareTechMono(color: Colors.white70, fontSize: 9)),
        Text('Efeito: $curEffect', style: GoogleFonts.shareTechMono(color: Colors.white70, fontSize: 9)),
        Text('Recarga: $curCooldown', style: GoogleFonts.shareTechMono(color: Colors.white70, fontSize: 9)),
        Text('Energia: $curEnergy MW', style: GoogleFonts.shareTechMono(color: Colors.white70, fontSize: 9)),
      ];
      rightSpecs = [
        Text('Uso: $selUsage', style: GoogleFonts.shareTechMono(color: Colors.white70, fontSize: 9)),
        Text('Efeito: $selEffect', style: GoogleFonts.shareTechMono(color: _greenAccent, fontSize: 9, fontWeight: FontWeight.bold)),
        Text('Recarga: $selCooldown', style: GoogleFonts.shareTechMono(color: _cyanColor, fontSize: 9)),
        _buildCompareMetricText('Energia', selEnergy, curEnergy, 'MW', lowerIsBetter: true),
      ];
    } else {
      leftSpecs = [
        Text('DPS: $curDps', style: GoogleFonts.shareTechMono(color: Colors.white70, fontSize: 9)),
        Text('Energia: $curEnergy MW', style: GoogleFonts.shareTechMono(color: Colors.white70, fontSize: 9)),
        Text('Alcance: $curRange m', style: GoogleFonts.shareTechMono(color: Colors.white70, fontSize: 9)),
      ];
      rightSpecs = [
        _buildCompareMetricText('DPS', selDps, curDps, ''),
        _buildCompareMetricText('Energia', selEnergy, curEnergy, 'MW', lowerIsBetter: true),
        _buildCompareMetricText('Alcance', selRange, curRange, 'm'),
      ];
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _cardBg,
        border: Border.all(color: _cyanColor.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '// COMPARAÇÃO DE ITENS',
            style: GoogleFonts.shareTechMono(
              color: _cyanColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ATUAL ($slotIdLabel)',
                      style: GoogleFonts.shareTechMono(color: Colors.white38, fontSize: 8),
                    ),
                    Text(
                      currentName,
                      style: GoogleFonts.shareTechMono(
                        color: isSlotFree ? Colors.white38 : Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    ...leftSpecs,
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  'VS',
                  style: GoogleFonts.shareTechMono(
                    color: _amberAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      selInStock ? 'SELECIONADO (ESTOQUE)' : 'SELECIONADO (MERCADO)',
                      style: GoogleFonts.shareTechMono(
                        color: selInStock ? _cyanColor : _amberAccent,
                        fontSize: 8,
                      ),
                    ),
                    Text(
                      selectedItem['name'].toString(),
                      style: GoogleFonts.shareTechMono(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    ...rightSpecs,
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showLoadoutDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            _dialogSetState = setDialogState;
            return Dialog(
              backgroundColor: const Color(0xFF0A0D12),
              insetPadding: const EdgeInsets.all(20),
              child: Container(
                width: 900,
                height: 620,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: _cyanColor, width: 1.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'CONFIGURAÇÃO DE LOADOUT',
                          style: GoogleFonts.shareTechMono(
                            color: _cyanColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () {
                            _dialogSetState = null;
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white24),
                    Expanded(child: _buildLoadoutFullView(isDesktop: true)),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      _dialogSetState = null;
    });
  }
}

// ===========================================================================
// PINTOR VETORIAL DO HOLOGRAMA DA NAVE (CustomPainter com geometria exata)
// ===========================================================================
class _ShipHologramPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double scaleX = size.width / 600.0;
    final double scaleY = size.height / 260.0;

    Offset pt(double x, double y) => Offset(x * scaleX, y * scaleY);

    // 1. Corpo principal com gradiente espacial escuro
    final Path hullPath = Path();
    hullPath.moveTo(pt(300, 30).dx, pt(300, 30).dy);
    hullPath.lineTo(pt(360, 120).dx, pt(360, 120).dy);
    hullPath.lineTo(pt(560, 170).dx, pt(560, 170).dy);
    hullPath.lineTo(pt(380, 185).dx, pt(380, 185).dy);
    hullPath.lineTo(pt(330, 230).dx, pt(330, 230).dy);
    hullPath.lineTo(pt(270, 230).dx, pt(270, 230).dy);
    hullPath.lineTo(pt(220, 185).dx, pt(220, 185).dy);
    hullPath.lineTo(pt(40, 170).dx, pt(40, 170).dy);
    hullPath.lineTo(pt(240, 120).dx, pt(240, 120).dy);
    hullPath.close();

    final Paint fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Color(0xFF0A1830),
          Color(0xFF1D3A5C),
          Color(0xFF0A1830),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    canvas.drawPath(hullPath, fillPaint);

    // 2. Traço exterior neon ciano com efeito glow
    final Paint glowPaint = Paint()
      ..color = const Color(0xFF00F0FF).withValues(alpha: 0.8)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4);
    canvas.drawPath(hullPath, glowPaint);

    final Paint strokePaint = Paint()
      ..color = const Color(0xFF00F0FF)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(hullPath, strokePaint);

    // 3. Linhas estruturais internas (wireframe)
    final Paint innerLinePaint = Paint()
      ..color = const Color(0xFF00F0FF).withValues(alpha: 0.35)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Linha de centro longitudinal
    canvas.drawLine(pt(300, 30), pt(300, 230), innerLinePaint);
    // Nervuras das asas
    canvas.drawLine(pt(240, 120), pt(360, 120), innerLinePaint);
    canvas.drawLine(pt(220, 185), pt(380, 185), innerLinePaint);

    // 4. Cockpit / Domo Central
    final Paint cockpitPaint = Paint()
      ..color = const Color(0xFF00F0FF).withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pt(300, 105), 10 * scaleX, cockpitPaint);

    // 5. Motores / Propulsores traseiros brilhantes
    final Paint thrusterPaint = Paint()
      ..color = const Color(0xFF00F0FF)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 6);

    canvas.drawOval(
      Rect.fromCenter(center: pt(275, 236), width: 20 * scaleX, height: 10 * scaleY),
      thrusterPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: pt(325, 236), width: 20 * scaleX, height: 10 * scaleY),
      thrusterPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
