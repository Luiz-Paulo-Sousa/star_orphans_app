import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class InventoryModuleWidget extends StatefulWidget {
  final Map<String, dynamic>? profileData;
  final String apiBaseUrl;
  final VoidCallback? onProfileRefresh;

  const InventoryModuleWidget({
    super.key,
    this.profileData,
    this.apiBaseUrl = 'http://26.239.180.177:8020',
    this.onProfileRefresh,
  });

  @override
  State<InventoryModuleWidget> createState() => _InventoryModuleWidgetState();
}

class _InventoryModuleWidgetState extends State<InventoryModuleWidget> {
  static const Color _cyanColor = Color(0xFF00D2FF);
  static const Color _greenAccent = Color(0xFF00FF66);
  static const Color _amberAccent = Color(0xFFFFB800);
  static const Color _redAccent = Color(0xFFFF3333);
  static const Color _darkBg = Color(0xFF0A0D12);
  static const Color _panelBg = Color(0xD912161F);
  static const Color _cardBg = Color(0xFF151922);

  static const List<Map<String, dynamic>> _categories = [
    {'type': 1, 'label': 'INSUMOS', 'flex': 10},
    {'type': 2, 'label': 'ARMAS', 'flex': 8},
    {'type': 3, 'label': 'MÍSSEIS', 'flex': 10},
    {'type': 4, 'label': 'DISPOSITIVOS', 'flex': 14},
    {'type': 5, 'label': 'UTILITÁRIOS', 'flex': 13},
  ];

  bool _isLoading = true;
  bool _isTransferring = false;
  String? _errorMessage;

  String _activeTab = 'LOGÍSTICA LOCAL'; // 'LOGÍSTICA LOCAL' ou 'GESTÃO DE ATIVOS'

  // Gestão de Ativos - Estado
  bool _isLoadingAssetStations = false;
  List<Map<String, dynamic>> _assetStations = [];
  int? _selectedAssetStationId; // null = 'TODAS'
  bool _isLoadingAssets = false;
  List<Map<String, dynamic>> _assetVessels = [];
  int _selectedAssetShipIndex = 0;
  int _selectedAssetItemType = 1;
  int? _selectedAssetItemCode;
  String _selectedAssetSource = 'STATION'; // 'SHIP' ou 'STATION'
  Map<String, dynamic> _assetStationData = {
    'station_id': null,
    'station_name': 'TODAS AS ESTAÇÕES',
    'max_volume': 50000,
    'used_volume': 0,
    'available_volume': 50000,
    'items': <Map<String, dynamic>>[],
  };

  List<Map<String, dynamic>> _vessels = [];
  int _selectedShipIndex = 0;

  Map<String, dynamic> _stationData = {
    'station_id': 1,
    'station_name': 'ESTAÇÃO COMERCIAL',
    'max_volume': 50000,
    'used_volume': 0,
    'available_volume': 50000,
    'items': <Map<String, dynamic>>[],
  };

  int _selectedItemType = 1; // Começa em INSUMOS por padrão
  String _selectedSource = 'STATION'; // 'SHIP' ou 'STATION'
  int? _selectedItemCode;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _fetchInventory();
    _fetchAssetStations();
    _fetchAssetInventory();
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

  String _formatNumber(dynamic value) {
    if (value == null) return '0';
    final int parsed =
        (value is num) ? value.round() : int.tryParse(value.toString()) ?? 0;
    return parsed.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  Future<void> _fetchInventory({bool preserveSelection = false}) async {
    final int pilotUid = _getPilotUid();
    if (pilotUid == 0) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'ID do operador não identificado.';
      });
      return;
    }

    final dynamic prevVesselUid =
        (preserveSelection &&
                _vessels.isNotEmpty &&
                _selectedShipIndex < _vessels.length)
            ? _vessels[_selectedShipIndex]['vessel_uid']
            : null;

    if (!preserveSelection) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final uri = Uri.parse(
        '${widget.apiBaseUrl}/api/hangar/inventory/$pilotUid',
      );
      final response = await http.get(uri);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded['status'] == 'sucesso' && decoded['data'] != null) {
          final rawStation =
              (decoded['data']['station'] as Map<String, dynamic>?) ?? {};
          final List rawStationItems = (rawStation['items'] as List?) ?? [];
          final List rawVessels = (decoded['data']['vessels'] as List?) ?? [];

          final parsedStationItems =
              rawStationItems
                  .map<Map<String, dynamic>>(
                    (e) => Map<String, dynamic>.from(e as Map),
                  )
                  .toList();

          final parsedVessels =
              rawVessels.map<Map<String, dynamic>>((v) {
                final map = Map<String, dynamic>.from(v as Map);
                final List rawCargo = (map['cargo_items'] as List?) ?? [];
                map['cargo_items'] =
                    rawCargo
                        .map<Map<String, dynamic>>(
                          (c) => Map<String, dynamic>.from(c as Map),
                        )
                        .toList();
                return map;
              }).toList();

          setState(() {
            _stationData = {
              'station_id': rawStation['station_id'] ?? 1,
              'station_name':
                  (rawStation['station_name'] ?? 'ESTAÇÃO COMERCIAL').toString(),
              'max_volume': (rawStation['max_volume'] as num?)?.toInt() ?? 50000,
              'used_volume': (rawStation['used_volume'] as num?)?.toInt() ?? 0,
              'available_volume':
                  (rawStation['available_volume'] as num?)?.toInt() ?? 50000,
              'items': parsedStationItems,
            };
            _vessels = parsedVessels;
            _isLoading = false;

            if (_vessels.isNotEmpty) {
              if (preserveSelection && prevVesselUid != null) {
                final idx = _vessels.indexWhere(
                  (v) => v['vessel_uid'] == prevVesselUid,
                );
                _selectedShipIndex = idx >= 0 ? idx : 0;
              } else {
                final activeIdx = _vessels.indexWhere(
                  (v) => v['selected'] == true,
                );
                _selectedShipIndex = activeIdx >= 0 ? activeIdx : 0;
              }
            } else {
              _selectedShipIndex = 0;
            }

            _ensureValidSelection();
          });
          return;
        }
      }

      setState(() {
        _isLoading = false;
        _errorMessage =
            'Falha ao carregar estoque (${response.statusCode}).';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erro de conexão com o servidor: $e';
      });
    }
  }

  Future<void> _fetchAssetStations() async {
    final int pilotUid = _getPilotUid();
    if (pilotUid == 0) return;

    setState(() {
      _isLoadingAssetStations = true;
    });

    try {
      final uri = Uri.parse(
        '${widget.apiBaseUrl}/api/hangar/asset-stations/$pilotUid',
      );
      final response = await http.get(uri);
      if (!mounted) return;
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded['status'] == 'sucesso' && decoded['data'] is List) {
          setState(() {
            _assetStations =
                (decoded['data'] as List)
                    .map<Map<String, dynamic>>(
                      (e) => Map<String, dynamic>.from(e as Map),
                    )
                    .toList();
            _isLoadingAssetStations = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('Erro ao buscar estações com ativos: $e');
    }

    if (mounted) {
      setState(() {
        _isLoadingAssetStations = false;
      });
    }
  }

  Future<void> _fetchAssetInventory({bool preserveSelection = false}) async {
    final int pilotUid = _getPilotUid();
    if (pilotUid == 0) return;

    final dynamic prevVesselUid =
        (preserveSelection &&
                _assetVessels.isNotEmpty &&
                _selectedAssetShipIndex < _assetVessels.length)
            ? _assetVessels[_selectedAssetShipIndex]['vessel_uid']
            : null;

    if (!preserveSelection || _assetVessels.isEmpty) {
      setState(() {
        _isLoadingAssets = true;
      });
    }

    try {
      final String stationParam =
          _selectedAssetStationId != null
              ? 'station_id=$_selectedAssetStationId'
              : 'station_id=all';
      final uri = Uri.parse(
        '${widget.apiBaseUrl}/api/hangar/inventory/$pilotUid?$stationParam',
      );
      final response = await http.get(uri);
      if (!mounted) return;

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded['status'] == 'sucesso' && decoded['data'] != null) {
          final rawStation =
              (decoded['data']['station'] as Map<String, dynamic>?) ?? {};
          final List rawStationItems = (rawStation['items'] as List?) ?? [];
          final List rawVessels = (decoded['data']['vessels'] as List?) ?? [];

          final parsedStationItems =
              rawStationItems
                  .map<Map<String, dynamic>>(
                    (e) => Map<String, dynamic>.from(e as Map),
                  )
                  .toList();

          final parsedVessels =
              rawVessels.map<Map<String, dynamic>>((v) {
                final map = Map<String, dynamic>.from(v as Map);
                final List rawCargo = (map['cargo_items'] as List?) ?? [];
                map['cargo_items'] =
                    rawCargo
                        .map<Map<String, dynamic>>(
                          (c) => Map<String, dynamic>.from(c as Map),
                        )
                        .toList();
                return map;
              }).toList();

          setState(() {
            _assetStationData = {
              'station_id': rawStation['station_id'],
              'station_name':
                  (rawStation['station_name'] ?? 'ESTAÇÃO').toString(),
              'max_volume':
                  (rawStation['max_volume'] as num?)?.toInt() ?? 50000,
              'used_volume':
                  (rawStation['used_volume'] as num?)?.toInt() ?? 0,
              'available_volume':
                  (rawStation['available_volume'] as num?)?.toInt() ?? 50000,
              'items': parsedStationItems,
            };
            _assetVessels = parsedVessels;
            if (preserveSelection && prevVesselUid != null) {
              final idx = _assetVessels.indexWhere(
                (v) => v['vessel_uid'] == prevVesselUid,
              );
              _selectedAssetShipIndex = idx >= 0 ? idx : 0;
            } else {
              _selectedAssetShipIndex = 0;
            }
            _selectedAssetItemCode = null;
            _isLoadingAssets = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('Erro ao carregar inventário de ativos: $e');
    }

    if (mounted) {
      setState(() {
        _isLoadingAssets = false;
      });
    }
  }

  List<Map<String, dynamic>> _getAssetShipItemsForType(int itemType) {
    if (_assetVessels.isEmpty ||
        _selectedAssetShipIndex >= _assetVessels.length) {
      return [];
    }
    final ship = _assetVessels[_selectedAssetShipIndex];
    final List<Map<String, dynamic>> items =
        (ship['cargo_items'] as List<Map<String, dynamic>>?) ?? [];
    return items
        .where((i) => (i['item_type'] as num?)?.toInt() == itemType)
        .toList();
  }

  List<Map<String, dynamic>> _getAssetStationItemsForType(int itemType) {
    final List<Map<String, dynamic>> items =
        (_assetStationData['items'] as List<Map<String, dynamic>>?) ?? [];
    return items
        .where((i) => (i['item_type'] as num?)?.toInt() == itemType)
        .toList();
  }

  void _cycleAssetShip(int delta) {
    if (_assetVessels.length <= 1) return;
    setState(() {
      _selectedAssetShipIndex =
          (_selectedAssetShipIndex + delta + _assetVessels.length) %
          _assetVessels.length;
      _selectedAssetItemCode = null;
    });
  }

  List<Map<String, dynamic>> _getShipItemsForType(int itemType) {
    if (_vessels.isEmpty) return [];
    final ship = _vessels[_selectedShipIndex.clamp(0, _vessels.length - 1)];
    final List<Map<String, dynamic>> items =
        (ship['cargo_items'] as List<Map<String, dynamic>>?) ?? [];
    return items
        .where((i) => (i['item_type'] as num?)?.toInt() == itemType)
        .toList();
  }

  List<Map<String, dynamic>> _getStationItemsForType(int itemType) {
    final List<Map<String, dynamic>> items =
        (_stationData['items'] as List<Map<String, dynamic>>?) ?? [];
    return items
        .where((i) => (i['item_type'] as num?)?.toInt() == itemType)
        .toList();
  }

  void _ensureValidSelection() {
    final shipItems = _getShipItemsForType(_selectedItemType);
    final stationItems = _getStationItemsForType(_selectedItemType);

    if (_selectedSource == 'SHIP') {
      final found = shipItems.where((i) => i['item_code'] == _selectedItemCode);
      if (found.isNotEmpty) {
        final int maxAmt = (found.first['amount'] as num?)?.toInt() ?? 1;
        if (_quantity > maxAmt) _quantity = maxAmt.clamp(1, 999999);
        return;
      }
      if (shipItems.isNotEmpty) {
        _selectedItemCode = (shipItems.first['item_code'] as num).toInt();
        _quantity = 1;
        return;
      }
      if (stationItems.isNotEmpty) {
        _selectedSource = 'STATION';
        _selectedItemCode = (stationItems.first['item_code'] as num).toInt();
        _quantity = 1;
        return;
      }
    } else {
      final found = stationItems.where(
        (i) => i['item_code'] == _selectedItemCode,
      );
      if (found.isNotEmpty) {
        final int maxAmt = (found.first['amount'] as num?)?.toInt() ?? 1;
        if (_quantity > maxAmt) _quantity = maxAmt.clamp(1, 999999);
        return;
      }
      if (stationItems.isNotEmpty) {
        _selectedItemCode = (stationItems.first['item_code'] as num).toInt();
        _quantity = 1;
        return;
      }
      if (shipItems.isNotEmpty) {
        _selectedSource = 'SHIP';
        _selectedItemCode = (shipItems.first['item_code'] as num).toInt();
        _quantity = 1;
        return;
      }
    }

    _selectedItemCode = null;
    _quantity = 1;
  }

  Map<String, dynamic>? _getSelectedItem() {
    if (_selectedItemCode == null) return null;
    final list =
        _selectedSource == 'SHIP'
            ? _getShipItemsForType(_selectedItemType)
            : _getStationItemsForType(_selectedItemType);
    for (final item in list) {
      if (item['item_code'] == _selectedItemCode) return item;
    }
    return null;
  }

  void _cycleShip(int delta) {
    if (_vessels.isEmpty) return;
    setState(() {
      _selectedShipIndex =
          (_selectedShipIndex + delta + _vessels.length) % _vessels.length;
      _ensureValidSelection();
    });
  }

  Future<void> _handleTransfer(String direction) async {
    if (_isTransferring || _vessels.isEmpty) return;
    final selectedItem = _getSelectedItem();
    if (selectedItem == null) return;

    final int pilotUid = _getPilotUid();
    final ship = _vessels[_selectedShipIndex];
    final dynamic vesselUid = ship['vessel_uid'];
    final int itemCode = (selectedItem['item_code'] as num).toInt();

    setState(() {
      _isTransferring = true;
    });

    try {
      final uri = Uri.parse('${widget.apiBaseUrl}/api/hangar/transfer-cargo');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'pilot_uid': pilotUid,
          'vessel_uid': vesselUid,
          'item_code': itemCode,
          'quantity': _quantity,
          'direction': direction,
        }),
      );

      if (!mounted) return;
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 && decoded['status'] == 'sucesso') {
        await _fetchInventory(preserveSelection: true);
        _fetchAssetInventory(preserveSelection: true);
        _fetchAssetStations();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor:
                direction == 'TO_SHIP' ? _greenAccent : _cyanColor,
            content: Text(
              decoded['mensagem'] ?? 'Transferência concluída!',
              style: GoogleFonts.shareTechMono(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _redAccent,
            content: Text(
              decoded['mensagem'] ?? 'Falha ao transferir item.',
              style: GoogleFonts.shareTechMono(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _redAccent,
          content: Text('Erro de conexão: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isTransferring = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: _darkBg,
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
                'SINCRONIZANDO ESTOQUE E CARGA...',
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

    if (_errorMessage != null || _vessels.isEmpty) {
      return Container(
        color: _darkBg,
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
                const Icon(
                  Icons.inventory_2_outlined,
                  color: _cyanColor,
                  size: 32,
                ),
                const SizedBox(height: 10),
                Text(
                  _errorMessage ??
                      'NENHUMA NAVE ATRACADA NESTA ESTAÇÃO PARA GERENCIAR CARGA.',
                  style: GoogleFonts.shareTechMono(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => _fetchInventory(),
                  icon: const Icon(
                    Icons.refresh,
                    color: Colors.black,
                    size: 15,
                  ),
                  label: Text(
                    'ATUALIZAR',
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
        final bool isWide = constraints.maxWidth >= 700;
        return Container(
          color: _darkBg,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 0. Abas Superiores: LOGÍSTICA LOCAL vs GESTÃO DE ATIVOS
              _buildTopTabBar(isWide: isWide),
              const SizedBox(height: 6),

              if (_activeTab == 'LOGÍSTICA LOCAL') ...[
                // 1. Seletor de Nave na Estação (com holograma 38x38 e volumes de carga)
                _buildShipSelectorHeader(isWide: isWide),
                const SizedBox(height: 6),

                // 2. Botões de Grupos de Itens (mesmo padrão do Mercado)
                _buildGroupButtonsBar(isWide: isWide),
                const SizedBox(height: 6),

                // 3. Mostruário Superior: Área de Carga da Nave
                Expanded(
                  child: _buildShowcasePanel(
                    title:
                        'ÁREA DE CARGA DA NAVE (${_vessels[_selectedShipIndex]['name']})',
                    subtitle:
                        'LIVRE: ${_formatNumber(_vessels[_selectedShipIndex]['available_cargo_volume'])} m³ / MÁX: ${_formatNumber(_vessels[_selectedShipIndex]['max_cargo_volume'])} m³',
                    items: _getShipItemsForType(_selectedItemType),
                    sourceKey: 'SHIP',
                    accentColor: _greenAccent,
                    emptyMessage:
                        'Nenhum item deste grupo na área de carga desta nave.',
                  ),
                ),
                const SizedBox(height: 6),

                // 4. Barra Central: [PARA A NAVE]  [- QTD +]  [PARA A ESTAÇÃO]
                _buildTransferControlBar(isWide: isWide),
                const SizedBox(height: 6),

                // 5. Mostruário Inferior: Depósito da Estação
                Expanded(
                  child: _buildShowcasePanel(
                    title:
                        'DEPÓSITO DA ESTAÇÃO (${_stationData['station_name']})',
                    subtitle:
                        'OCUPADO: ${_formatNumber(_stationData['used_volume'])} / ${_formatNumber(_stationData['max_volume'])} m³ (LIVRE: ${_formatNumber(_stationData['available_volume'])} m³)',
                    items: _getStationItemsForType(_selectedItemType),
                    sourceKey: 'STATION',
                    accentColor: _cyanColor,
                    emptyMessage:
                        'Nenhum item deste grupo no seu depósito desta estação.',
                  ),
                ),
              ] else ...[
                // GESTÃO DE ATIVOS (Visão Global)
                Expanded(
                  child: _buildAssetManagementTab(isWide: isWide),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ===========================================================================
  // 0. ABAS SUPERIORES (LOGÍSTICA LOCAL VS GESTÃO DE ATIVOS)
  // ===========================================================================
  Widget _buildTopTabBar({required bool isWide}) {
    return Row(
      children: [
        Expanded(
          child: _buildTopTabButton(
            label: 'LOGÍSTICA LOCAL',
            icon: Icons.swap_horiz_rounded,
            isSelected: _activeTab == 'LOGÍSTICA LOCAL',
            onTap: () {
              setState(() => _activeTab = 'LOGÍSTICA LOCAL');
              _fetchInventory(preserveSelection: true);
            },
            isWide: isWide,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _buildTopTabButton(
            label: 'GESTÃO DE ATIVOS',
            icon: Icons.travel_explore_rounded,
            isSelected: _activeTab == 'GESTÃO DE ATIVOS',
            onTap: () {
              setState(() => _activeTab = 'GESTÃO DE ATIVOS');
              _fetchAssetStations();
              _fetchAssetInventory(preserveSelection: true);
            },
            isWide: isWide,
          ),
        ),
      ],
    );
  }

  Widget _buildTopTabButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isWide,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
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
              size: 14,
              color: isSelected ? _greenAccent : Colors.white70,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.shareTechMono(
                color: isSelected ? _greenAccent : Colors.white,
                fontSize: isWide ? 11 : 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetManagementTab({required bool isWide}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _panelBg,
        border: Border.all(
          color: _cyanColor.withValues(alpha: 0.55),
          width: 1.2,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Barra de Filtro de Estação (Top Filter)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1117),
              border: Border.all(
                color: _cyanColor.withValues(alpha: 0.6),
                width: 1.0,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.filter_alt_outlined,
                  color: _cyanColor,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  'ESTAÇÃO:',
                  style: GoogleFonts.shareTechMono(
                    color: _cyanColor,
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 29,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: _cardBg,
                      border: Border.all(
                        color:
                            _selectedAssetStationId != null
                                ? _greenAccent
                                : _cyanColor.withValues(alpha: 0.7),
                        width: 1.0,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        value: _selectedAssetStationId,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF10141D),
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: _cyanColor,
                          size: 20,
                        ),
                        style: GoogleFonts.shareTechMono(
                          color:
                              _selectedAssetStationId != null
                                  ? _greenAccent
                                  : Colors.white,
                          fontSize: isWide ? 11.5 : 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                        items: [
                          DropdownMenuItem<int?>(
                            value: null,
                            child: Text(
                              'TODAS (${_assetStations.length})',
                              style: GoogleFonts.shareTechMono(
                                color:
                                    _selectedAssetStationId == null
                                        ? _greenAccent
                                        : Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          ..._assetStations.map((st) {
                            final int id = (st['id'] as num).toInt();
                            final String name = st['name'].toString();
                            return DropdownMenuItem<int?>(
                              value: id,
                              child: Text(
                                name,
                                style: GoogleFonts.shareTechMono(
                                  color:
                                      _selectedAssetStationId == id
                                          ? _greenAccent
                                          : Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedAssetStationId = val;
                          });
                          _fetchAssetInventory();
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon:
                      (_isLoadingAssetStations || _isLoadingAssets)
                          ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _cyanColor,
                            ),
                          )
                          : const Icon(
                            Icons.refresh,
                            color: _cyanColor,
                            size: 18,
                          ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  tooltip: 'Recarregar estações com ativos',
                  onPressed:
                      (_isLoadingAssetStations || _isLoadingAssets)
                          ? null
                          : () {
                            _fetchAssetStations();
                            _fetchAssetInventory();
                          },
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // 2. Seletor de Naves em Ativos + Grupos de Itens + Área de Carga da Nave + Depósito da Estação
          if (_isLoadingAssets)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(color: _cyanColor),
              ),
            )
          else if (_assetVessels.isEmpty &&
              (_assetStationData['items'] as List).isEmpty)
            Expanded(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1117),
                    border: Border.all(
                      color: _cyanColor.withValues(alpha: 0.3),
                      width: 1.0,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.inventory_2_outlined,
                        color: _cyanColor,
                        size: 38,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'NENHUM ATIVO ENCONTRADO NESTA LOCALIZAÇÃO.',
                        style: GoogleFonts.shareTechMono(
                          color: _cyanColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Não há naves nem itens no depósito para o filtro selecionado.',
                        style: GoogleFonts.shareTechMono(
                          color: Colors.white54,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else ...[
            _buildAssetShipSelectorHeader(isWide: isWide),
            const SizedBox(height: 6),
            _buildAssetGroupButtonsBar(isWide: isWide),
            const SizedBox(height: 6),
            // Mostruário Superior: Área de Carga da Nave
            Expanded(
              child: _buildAssetShowcasePanel(
                title:
                    _assetVessels.isNotEmpty
                        ? 'ÁREA DE CARGA DA NAVE (${_assetVessels[_selectedAssetShipIndex]['name']})'
                        : 'ÁREA DE CARGA DA NAVE',
                subtitle:
                    _assetVessels.isNotEmpty
                        ? 'LIVRE: ${_formatNumber(_assetVessels[_selectedAssetShipIndex]['available_cargo_volume'])} m³ / MÁX: ${_formatNumber(_assetVessels[_selectedAssetShipIndex]['max_cargo_volume'])} m³'
                        : 'SEM NAVE',
                items: _getAssetShipItemsForType(_selectedAssetItemType),
                sourceKey: 'SHIP',
                accentColor: _greenAccent,
                emptyMessage:
                    _assetVessels.isNotEmpty
                        ? 'Nenhum item deste grupo na área de carga desta nave.'
                        : 'Nenhuma nave atracada nesta localização.',
              ),
            ),
            const SizedBox(height: 6),
            // Mostruário Inferior: Depósito da Estação
            Expanded(
              child: _buildAssetShowcasePanel(
                title:
                    _selectedAssetStationId == null
                        ? 'DEPÓSITO (TODAS AS ESTAÇÕES)'
                        : 'DEPÓSITO DA ESTAÇÃO (${_assetStationData['station_name']})',
                subtitle:
                    _selectedAssetStationId == null
                        ? 'TOTAL OCUPADO: ${_formatNumber(_assetStationData['used_volume'])} m³'
                        : 'OCUPADO: ${_formatNumber(_assetStationData['used_volume'])} / ${_formatNumber(_assetStationData['max_volume'])} m³ (LIVRE: ${_formatNumber(_assetStationData['available_volume'])} m³)',
                items: _getAssetStationItemsForType(_selectedAssetItemType),
                sourceKey: 'STATION',
                accentColor: _cyanColor,
                emptyMessage:
                    _selectedAssetStationId == null
                        ? 'Nenhum item deste grupo nos depósitos das estações.'
                        : 'Nenhum item deste grupo no seu depósito desta estação.',
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // 1b. GESTÃO DE ATIVOS - SELETOR DE NAVE COM HOLOGRAMA E VOLUME
  // ===========================================================================
  Widget _buildAssetShipSelectorHeader({required bool isWide}) {
    if (_assetVessels.isEmpty ||
        _selectedAssetShipIndex >= _assetVessels.length) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _panelBg,
          border: Border.all(
            color: _cyanColor.withValues(alpha: 0.4),
            width: 1.0,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            const Icon(Icons.rocket_outlined, color: _cyanColor, size: 18),
            const SizedBox(width: 8),
            Text(
              'NENHUMA NAVE ATRACADA NESTA LOCALIZAÇÃO.',
              style: GoogleFonts.shareTechMono(
                color: Colors.white70,
                fontSize: isWide ? 11 : 10,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      );
    }
    final ship = _assetVessels[_selectedAssetShipIndex];
    final bool isActive = ship['selected'] == true;
    final int maxVol = (ship['max_cargo_volume'] as num?)?.toInt() ?? 1;
    final int usedVol = (ship['used_cargo_volume'] as num?)?.toInt() ?? 0;
    final int availVol = (ship['available_cargo_volume'] as num?)?.toInt() ?? 0;
    final double ratio = (usedVol / (maxVol > 0 ? maxVol : 1)).clamp(0.0, 1.0);
    final String? holoUrl = ship['hologram_url'] as String?;
    final String fullHoloUrl =
        (holoUrl != null && holoUrl.isNotEmpty)
            ? (holoUrl.startsWith('http')
                ? holoUrl
                : '${widget.apiBaseUrl}${holoUrl.startsWith('/') ? '' : '/'}$holoUrl')
            : '';

    final Color barColor =
        ratio > 0.9 ? _redAccent : (ratio > 0.7 ? _amberAccent : _greenAccent);

    final String shipStationName = (ship['station_name'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: _panelBg,
        border: Border.all(color: _cyanColor.withValues(alpha: 0.6), width: 1.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_left, color: _cyanColor, size: 22),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed:
                _assetVessels.length > 1 ? () => _cycleAssetShip(-1) : null,
          ),
          const SizedBox(width: 4),

          // Miniatura do Holograma da Nave (38x38)
          Container(
            width: 38,
            height: 38,
            padding: const EdgeInsets.all(3),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFF0B0F16),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isActive ? _greenAccent : _cyanColor,
                width: 1.0,
              ),
            ),
            child:
                fullHoloUrl.isNotEmpty
                    ? Image.network(
                      fullHoloUrl,
                      fit: BoxFit.contain,
                      errorBuilder:
                          (_, __, ___) => const Icon(
                            Icons.rocket_launch,
                            color: _cyanColor,
                            size: 20,
                          ),
                    )
                    : const Icon(
                      Icons.rocket_launch,
                      color: _cyanColor,
                      size: 20,
                    ),
          ),
          const SizedBox(width: 10),

          // Nome da Nave + Status + Estação (se filtro for TODAS) + Métricas
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      ship['name'].toString(),
                      style: GoogleFonts.shareTechMono(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isActive
                                ? _greenAccent.withValues(alpha: 0.18)
                                : _cyanColor.withValues(alpha: 0.15),
                        border: Border.all(
                          color: isActive ? _greenAccent : _cyanColor,
                          width: 0.8,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        isActive ? 'ATIVA' : 'ATRACADA',
                        style: GoogleFonts.shareTechMono(
                          color: isActive ? _greenAccent : _cyanColor,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (_selectedAssetStationId == null &&
                        shipStationName.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '• $shipStationName',
                          style: GoogleFonts.shareTechMono(
                            color: _cyanColor.withValues(alpha: 0.8),
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      'MÁX: ${_formatNumber(maxVol)} m³  |  DISPONÍVEL: ${_formatNumber(availVol)} m³',
                      style: GoogleFonts.shareTechMono(
                        color: availVol > 0 ? _cyanColor : _redAccent,
                        fontSize: isWide ? 11 : 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 5,
                          backgroundColor: Colors.white12,
                          valueColor: AlwaysStoppedAnimation<Color>(barColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'OCUPADO: ${_formatNumber(usedVol)} m³ (${(ratio * 100).toStringAsFixed(0)}%)',
                      style: GoogleFonts.shareTechMono(
                        color: Colors.white70,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.arrow_right, color: _cyanColor, size: 22),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed:
                _assetVessels.length > 1 ? () => _cycleAssetShip(1) : null,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2b. GESTÃO DE ATIVOS - BARRA DE BOTÕES DE GRUPOS DE ITENS
  // ===========================================================================
  Widget _buildAssetGroupButtonsBar({required bool isWide}) {
    return Row(
      children:
          _categories.map((cat) {
            final int typeCode = cat['type'] as int;
            final String label = cat['label'] as String;
            final int flexWeight = (cat['flex'] as int?) ?? 10;
            final bool isSelected = _selectedAssetItemType == typeCode;

            final int shipCount = _getAssetShipItemsForType(typeCode).length;

            return Expanded(
              flex: flexWeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedAssetItemType = typeCode;
                      _selectedAssetItemCode = null;
                    });
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 7,
                      horizontal: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? _greenAccent : _panelBg,
                      border: Border.all(
                        color: isSelected ? _greenAccent : _cyanColor,
                        width: isSelected ? 1.8 : 1.0,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        shipCount > 0 ? '$label ($shipCount)' : label,
                        style: GoogleFonts.shareTechMono(
                          color: isSelected ? Colors.black : Colors.white,
                          fontSize: isWide ? 11 : 9.5,
                          fontWeight: FontWeight.bold,
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

  // ===========================================================================
  // 3b & 5b. GESTÃO DE ATIVOS - MOSTRUÁRIO DE ITENS (CARGA DA NAVE / DEPÓSITO)
  // ===========================================================================
  Widget _buildAssetShowcasePanel({
    required String title,
    required String subtitle,
    required List<Map<String, dynamic>> items,
    required String sourceKey,
    required Color accentColor,
    required String emptyMessage,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _panelBg,
        border: Border.all(
          color: accentColor.withValues(alpha: 0.55),
          width: 1.2,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: GoogleFonts.shareTechMono(
                    color: accentColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                subtitle,
                style: GoogleFonts.shareTechMono(
                  color: Colors.white70,
                  fontSize: 9.5,
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 10),
          Expanded(
            child:
                items.isEmpty
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
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 116,
                            mainAxisExtent: 124,
                            crossAxisSpacing: 6,
                            mainAxisSpacing: 6,
                          ),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final int itemCode =
                            (item['item_code'] as num).toInt();
                        final bool isSelected =
                            _selectedAssetSource == sourceKey &&
                            _selectedAssetItemCode == itemCode;
                        final int amount =
                            (item['amount'] as num?)?.toInt() ?? 0;
                        final int unitVol =
                            (item['unit_volume'] as num?)?.toInt() ?? 1;
                        final int totalVol =
                            (item['total_volume'] as num?)?.toInt() ??
                            (amount * unitVol);
                        final int itemType =
                            (item['item_type'] as num?)?.toInt() ?? 1;

                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedAssetSource = sourceKey;
                              _selectedAssetItemCode = itemCode;
                            });
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color:
                                  isSelected
                                      ? accentColor.withValues(alpha: 0.14)
                                      : _cardBg,
                              border: Border.all(
                                color:
                                    isSelected ? accentColor : Colors.white24,
                                width: isSelected ? 1.8 : 1.0,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Imagem do Item + Badge de Quantidade
                                Expanded(
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0B0E14),
                                            borderRadius: BorderRadius.circular(
                                              3,
                                            ),
                                          ),
                                          clipBehavior: Clip.antiAlias,
                                          child: _buildItemImage(
                                            item['image_url'] as String?,
                                            itemType,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        right: 3,
                                        bottom: 3,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 1.5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(
                                              alpha: 0.85,
                                            ),
                                            border: Border.all(
                                              color: accentColor,
                                              width: 0.8,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              3,
                                            ),
                                          ),
                                          child: Text(
                                            'QTD: $amount',
                                            style: GoogleFonts.shareTechMono(
                                              color: accentColor,
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 3),

                                // Nome do Item
                                Text(
                                  (item['name'] ?? '').toString().toUpperCase(),
                                  style: GoogleFonts.shareTechMono(
                                    color:
                                        isSelected
                                            ? accentColor
                                            : Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 1.5),

                                // Volume unitário e Volume total ocupado pelo lote
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Un: ${unitVol}m³',
                                      style: GoogleFonts.shareTechMono(
                                        color: Colors.white54,
                                        fontSize: 8,
                                      ),
                                    ),
                                    Text(
                                      'Tot: ${totalVol}m³',
                                      style: GoogleFonts.shareTechMono(
                                        color: _cyanColor,
                                        fontSize: 8,
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

  // ===========================================================================
  // 1. SELETOR DE NAVE COM HOLOGRAMA 38x38 E VOLUME DE CARGA (30% DO VOLUME)
  // ===========================================================================
  Widget _buildShipSelectorHeader({required bool isWide}) {
    final ship = _vessels[_selectedShipIndex];
    final bool isActive = ship['selected'] == true;
    final int maxVol = (ship['max_cargo_volume'] as num?)?.toInt() ?? 1;
    final int usedVol = (ship['used_cargo_volume'] as num?)?.toInt() ?? 0;
    final int availVol = (ship['available_cargo_volume'] as num?)?.toInt() ?? 0;
    final double ratio = (usedVol / (maxVol > 0 ? maxVol : 1)).clamp(0.0, 1.0);
    final String? holoUrl = ship['hologram_url'] as String?;
    final String fullHoloUrl =
        (holoUrl != null && holoUrl.isNotEmpty)
            ? (holoUrl.startsWith('http')
                ? holoUrl
                : '${widget.apiBaseUrl}${holoUrl.startsWith('/') ? '' : '/'}$holoUrl')
            : '';

    final Color barColor =
        ratio > 0.9 ? _redAccent : (ratio > 0.7 ? _amberAccent : _greenAccent);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: _panelBg,
        border: Border.all(color: _cyanColor.withValues(alpha: 0.6), width: 1.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_left, color: _cyanColor, size: 22),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: _vessels.length > 1 ? () => _cycleShip(-1) : null,
          ),
          const SizedBox(width: 4),

          // Miniatura do Holograma da Nave (38x38 - exato mesmo tamanho do avatar do operador no topo!)
          Container(
            width: 38,
            height: 38,
            padding: const EdgeInsets.all(3),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFF0B0F16),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isActive ? _greenAccent : _cyanColor,
                width: 1.0,
              ),
            ),
            child:
                fullHoloUrl.isNotEmpty
                    ? Image.network(
                      fullHoloUrl,
                      fit: BoxFit.contain,
                      errorBuilder:
                          (_, __, ___) => const Icon(
                            Icons.rocket_launch,
                            color: _cyanColor,
                            size: 20,
                          ),
                    )
                    : const Icon(
                      Icons.rocket_launch,
                      color: _cyanColor,
                      size: 20,
                    ),
          ),
          const SizedBox(width: 10),

          // Nome da Nave + Status + Barra e Métricas de Volume de Carga
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      ship['name'].toString(),
                      style: GoogleFonts.shareTechMono(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isActive
                                ? _greenAccent.withValues(alpha: 0.18)
                                : _cyanColor.withValues(alpha: 0.15),
                        border: Border.all(
                          color: isActive ? _greenAccent : _cyanColor,
                          width: 0.8,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        isActive ? 'ATIVA' : 'ATRACADA',
                        style: GoogleFonts.shareTechMono(
                          color: isActive ? _greenAccent : _cyanColor,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'MÁX: ${_formatNumber(maxVol)} m³  |  DISPONÍVEL: ${_formatNumber(availVol)} m³',
                      style: GoogleFonts.shareTechMono(
                        color: availVol > 0 ? _cyanColor : _redAccent,
                        fontSize: isWide ? 11 : 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 5,
                          backgroundColor: Colors.white12,
                          valueColor: AlwaysStoppedAnimation<Color>(barColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'OCUPADO: ${_formatNumber(usedVol)} m³ (${(ratio * 100).toStringAsFixed(0)}%)',
                      style: GoogleFonts.shareTechMono(
                        color: Colors.white70,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.arrow_right, color: _cyanColor, size: 22),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: _vessels.length > 1 ? () => _cycleShip(1) : null,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. BARRA DE BOTÕES DE GRUPOS DE ITENS
  // ===========================================================================
  Widget _buildGroupButtonsBar({required bool isWide}) {
    return Row(
      children:
          _categories.map((cat) {
            final int typeCode = cat['type'] as int;
            final String label = cat['label'] as String;
            final int flexWeight = (cat['flex'] as int?) ?? 10;
            final bool isSelected = _selectedItemType == typeCode;

            final int shipCount = _getShipItemsForType(typeCode).length;

            return Expanded(
              flex: flexWeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedItemType = typeCode;
                      _ensureValidSelection();
                    });
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 7,
                      horizontal: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? _greenAccent : _panelBg,
                      border: Border.all(
                        color: isSelected ? _greenAccent : _cyanColor,
                        width: isSelected ? 1.8 : 1.0,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        shipCount > 0 ? '$label ($shipCount)' : label,
                        style: GoogleFonts.shareTechMono(
                          color: isSelected ? Colors.black : Colors.white,
                          fontSize: isWide ? 11 : 9.5,
                          fontWeight: FontWeight.bold,
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

  // ===========================================================================
  // 3 & 5. MOSTRUÁRIO DE ITENS (CARGA DA NAVE / DEPÓSITO DA ESTAÇÃO)
  // ===========================================================================
  Widget _buildShowcasePanel({
    required String title,
    required String subtitle,
    required List<Map<String, dynamic>> items,
    required String sourceKey,
    required Color accentColor,
    required String emptyMessage,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _panelBg,
        border: Border.all(
          color: accentColor.withValues(alpha: 0.55),
          width: 1.2,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: GoogleFonts.shareTechMono(
                    color: accentColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                subtitle,
                style: GoogleFonts.shareTechMono(
                  color: Colors.white70,
                  fontSize: 9.5,
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 10),
          Expanded(
            child:
                items.isEmpty
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
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 116,
                            mainAxisExtent: 124,
                            crossAxisSpacing: 6,
                            mainAxisSpacing: 6,
                          ),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final int itemCode =
                            (item['item_code'] as num).toInt();
                        final bool isSelected =
                            _selectedSource == sourceKey &&
                            _selectedItemCode == itemCode;
                        final int amount =
                            (item['amount'] as num?)?.toInt() ?? 0;
                        final int unitVol =
                            (item['unit_volume'] as num?)?.toInt() ?? 1;
                        final int totalVol =
                            (item['total_volume'] as num?)?.toInt() ??
                            (amount * unitVol);
                        final int itemType =
                            (item['item_type'] as num?)?.toInt() ?? 1;

                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedSource = sourceKey;
                              _selectedItemCode = itemCode;
                              _quantity = 1;
                            });
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color:
                                  isSelected
                                      ? accentColor.withValues(alpha: 0.14)
                                      : _cardBg,
                              border: Border.all(
                                color:
                                    isSelected ? accentColor : Colors.white24,
                                width: isSelected ? 1.8 : 1.0,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Imagem do Item + Badge de Quantidade
                                Expanded(
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0B0E14),
                                            borderRadius: BorderRadius.circular(
                                              3,
                                            ),
                                          ),
                                          clipBehavior: Clip.antiAlias,
                                          child: _buildItemImage(
                                            item['image_url'] as String?,
                                            itemType,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        right: 3,
                                        bottom: 3,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 1.5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(
                                              alpha: 0.85,
                                            ),
                                            border: Border.all(
                                              color: accentColor,
                                              width: 0.8,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              3,
                                            ),
                                          ),
                                          child: Text(
                                            'QTD: $amount',
                                            style: GoogleFonts.shareTechMono(
                                              color: accentColor,
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 3),

                                // Nome do Item
                                Text(
                                  (item['name'] ?? '').toString().toUpperCase(),
                                  style: GoogleFonts.shareTechMono(
                                    color:
                                        isSelected
                                            ? accentColor
                                            : Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 1.5),

                                // Volume unitário e Volume total ocupado pelo lote
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Un: ${unitVol}m³',
                                      style: GoogleFonts.shareTechMono(
                                        color: Colors.white54,
                                        fontSize: 8,
                                      ),
                                    ),
                                    Text(
                                      'Tot: ${totalVol}m³',
                                      style: GoogleFonts.shareTechMono(
                                        color: _cyanColor,
                                        fontSize: 8,
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

  // ===========================================================================
  // 4. BARRA CENTRAL DE TRANSFERÊNCIA ([PARA A NAVE] [- QTD +] [PARA A ESTAÇÃO])
  // ===========================================================================
  Widget _buildTransferControlBar({required bool isWide}) {
    final selectedItem = _getSelectedItem();
    final ship = _vessels[_selectedShipIndex];

    final int maxItemAmount =
        selectedItem != null
            ? ((selectedItem['amount'] as num?)?.toInt() ?? 0)
            : 0;
    final int unitVolume =
        selectedItem != null
            ? ((selectedItem['unit_volume'] as num?)?.toInt() ?? 1)
            : 0;
    final int selectedTotalVolume = _quantity * unitVolume;

    final int shipAvailVolume =
        (ship['available_cargo_volume'] as num?)?.toInt() ?? 0;
    final int stationAvailVolume =
        (_stationData['available_volume'] as num?)?.toInt() ?? 50000;

    final bool isStationItemSelected =
        selectedItem != null && _selectedSource == 'STATION';
    final bool isShipItemSelected =
        selectedItem != null && _selectedSource == 'SHIP';

    // Verifica se o volume selecionado ultrapassa o volume disponível na área de carga da nave
    final bool exceedsShipVolume =
        isStationItemSelected && selectedTotalVolume > shipAvailVolume;
    final bool exceedsStationVolume =
        isShipItemSelected && selectedTotalVolume > stationAvailVolume;

    final bool canMoveToShip =
        !_isTransferring &&
        isStationItemSelected &&
        _quantity > 0 &&
        _quantity <= maxItemAmount &&
        !exceedsShipVolume;

    final bool canMoveToStation =
        !_isTransferring &&
        isShipItemSelected &&
        _quantity > 0 &&
        _quantity <= maxItemAmount &&
        !exceedsStationVolume;

    final Color qtyTextColor =
        (exceedsShipVolume || exceedsStationVolume) ? _redAccent : Colors.white;

    final Color toShipTextColor =
        canMoveToShip
            ? Colors.black
            : (exceedsShipVolume ? _redAccent : Colors.white24);
    final Color toStationTextColor =
        canMoveToStation
            ? Colors.black
            : (exceedsStationVolume ? _redAccent : Colors.white24);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: _panelBg,
        border: Border.all(color: _cyanColor.withValues(alpha: 0.6), width: 1.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          // Botão Esquerdo: PARA A NAVE (Seta para cima)
          Expanded(
            child: SizedBox(
              height: isWide ? 28 : 30,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _greenAccent,
                  disabledBackgroundColor: Colors.white12,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 0,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                    side:
                        exceedsShipVolume
                            ? BorderSide(
                              color: _redAccent.withValues(alpha: 0.6),
                              width: 1.0,
                            )
                            : BorderSide.none,
                  ),
                ),
                onPressed:
                    canMoveToShip ? () => _handleTransfer('TO_SHIP') : null,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.arrow_upward_rounded,
                        color: toShipTextColor,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        exceedsShipVolume ? 'SEM ESPAÇO' : 'PARA A NAVE',
                        style: GoogleFonts.shareTechMono(
                          color: toShipTextColor,
                          fontSize: isWide ? 11 : 10,
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

          // Seletor Central de Quantidade (- QTD +)
          Container(
            height: isWide ? 28 : 30,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: _cardBg,
              border: Border.all(
                color:
                    (exceedsShipVolume || exceedsStationVolume)
                        ? _redAccent
                        : _cyanColor.withValues(alpha: 0.6),
                width:
                    (exceedsShipVolume || exceedsStationVolume) ? 1.5 : 1.0,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap:
                      selectedItem != null && _quantity > 1
                          ? () => setState(() => _quantity--)
                          : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: Icon(
                      Icons.remove,
                      color:
                          selectedItem != null && _quantity > 1
                              ? _cyanColor
                              : Colors.white24,
                      size: 14,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    'QTD: $_quantity',
                    style: GoogleFonts.shareTechMono(
                      color: qtyTextColor,
                      fontSize: isWide ? 11 : 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                InkWell(
                  onTap:
                      selectedItem != null && _quantity < maxItemAmount
                          ? () => setState(() => _quantity++)
                          : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: Icon(
                      Icons.add,
                      color:
                          selectedItem != null && _quantity < maxItemAmount
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

          // Botão Direito: PARA A ESTAÇÃO (Seta para baixo)
          Expanded(
            child: SizedBox(
              height: isWide ? 28 : 30,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _cyanColor,
                  disabledBackgroundColor: Colors.white12,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 0,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                    side:
                        exceedsStationVolume
                            ? BorderSide(
                              color: _redAccent.withValues(alpha: 0.6),
                              width: 1.0,
                            )
                            : BorderSide.none,
                  ),
                ),
                onPressed:
                    canMoveToStation
                        ? () => _handleTransfer('TO_STATION')
                        : null,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.arrow_downward_rounded,
                        color: toStationTextColor,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        exceedsStationVolume ? 'SEM ESPAÇO' : 'PARA A ESTAÇÃO',
                        style: GoogleFonts.shareTechMono(
                          color: toStationTextColor,
                          fontSize: isWide ? 11 : 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemImage(String? rawUrl, int itemType) {
    if (rawUrl != null && rawUrl.trim().isNotEmpty) {
      final String fullUrl =
          rawUrl.startsWith('http')
              ? rawUrl
              : '${widget.apiBaseUrl}${rawUrl.startsWith('/') ? '' : '/'}$rawUrl';
      return Image.network(
        fullUrl,
        fit: BoxFit.cover,
        errorBuilder:
            (context, error, stackTrace) => _buildFallbackIcon(itemType),
      );
    }
    return _buildFallbackIcon(itemType);
  }

  Widget _buildFallbackIcon(int itemType) {
    IconData iconData = Icons.category_outlined;
    switch (itemType) {
      case 1:
        iconData = Icons.hexagon_outlined;
        break;
      case 2:
        iconData = Icons.gps_fixed;
        break;
      case 3:
        iconData = Icons.rocket_outlined;
        break;
      case 4:
        iconData = Icons.memory_outlined;
        break;
      case 5:
        iconData = Icons.bolt_outlined;
        break;
    }
    return Center(
      child: Icon(iconData, color: _cyanColor.withValues(alpha: 0.5), size: 26),
    );
  }
}
