import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class MarketModuleWidget extends StatefulWidget {
  final Map<String, dynamic>? profileData;
  final String apiBaseUrl;
  final VoidCallback? onProfileRefresh;

  const MarketModuleWidget({
    super.key,
    this.profileData,
    this.apiBaseUrl = 'http://26.239.180.177:8020',
    this.onProfileRefresh,
  });

  @override
  State<MarketModuleWidget> createState() => _MarketModuleWidgetState();
}

class _MarketModuleWidgetState extends State<MarketModuleWidget> {
  static const Color _cyanColor = Color(0xFF00D2FF);
  static const Color _greenAccent = Color(0xFF00FF66);
  static const Color _amberAccent = Color(0xFFFFB800);
  static const Color _redAccent = Color(0xFFFF3333);
  static const Color _panelBg = Color(0xD912161F);
  static const Color _cardBg = Color(0xFF151922);

  bool _isLoading = true;
  bool _isProcessingAction = false;
  String? _errorMessage;

  Map<String, dynamic>? _stationContext;
  List<Map<String, dynamic>> _allListings = [];

  // Grupos principais (item_type: 6=Naves, 1..5=Itens) com larguras proporcionais (flex)
  static const List<Map<String, dynamic>> _categories = [
    {'type': 6, 'label': 'NAVES', 'flex': 8},
    {'type': 1, 'label': 'INSUMOS', 'flex': 10},
    {'type': 2, 'label': 'ARMAS', 'flex': 8},
    {'type': 3, 'label': 'MÍSSEIS', 'flex': 10},
    {'type': 4, 'label': 'DISPOSITIVOS', 'flex': 14},
    {'type': 5, 'label': 'UTILITÁRIOS', 'flex': 14},
  ];

  int _selectedItemType = 6; // Começa em NAVES por padrão
  String _selectedOwnerFilter = 'ALL'; // 'ALL', 'STATION', 'PILOTS'

  int? _selectedItemCode;
  int _selectedOwnerPilotUid = 0;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _fetchMarketCatalog();
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

  String _formatCredits(dynamic value) {
    if (value == null) return '0';
    final int parsed =
        (value is num) ? value.round() : int.tryParse(value.toString()) ?? 0;
    return parsed.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  Future<void> _fetchMarketCatalog({bool silent = false}) async {
    final int pilotUid = _getPilotUid();
    if (pilotUid == 0) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'ID do operador não identificado.';
      });
      return;
    }

    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final uri = Uri.parse('${widget.apiBaseUrl}/api/market/catalog/$pilotUid');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded['status'] == 'sucesso' && decoded['data'] != null) {
          final ctx = Map<String, dynamic>.from(decoded['data']['context'] ?? {});
          final rawItems = List<dynamic>.from(decoded['data']['items'] ?? []);
          final loaded = rawItems
              .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
              .toList();

          if (mounted) {
            setState(() {
              _stationContext = ctx;
              _allListings = loaded;
              _isLoading = false;
              _ensureValidSelection();
            });
          }
          return;
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Falha ao carregar catálogo do Mercado (${response.statusCode}).';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erro de conexão com o Mercado: $e';
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredListings {
    return _allListings.where((item) {
      final int iType = (item['item_type'] as num?)?.toInt() ?? 0;
      if (iType != _selectedItemType) return false;

      final int ownerUid = (item['owner_pilot_uid'] as num?)?.toInt() ?? 0;
      if (_selectedOwnerFilter == 'STATION' && ownerUid != 0) return false;
      if (_selectedOwnerFilter == 'PILOTS' && ownerUid == 0) return false;
      return true;
    }).toList();
  }

  void _ensureValidSelection() {
    final filtered = _filteredListings;
    if (filtered.isEmpty) {
      _selectedItemCode = null;
      _selectedOwnerPilotUid = 0;
      return;
    }
    final exists = filtered.any(
      (e) =>
          e['item_code'] == _selectedItemCode &&
          (e['owner_pilot_uid'] ?? 0) == _selectedOwnerPilotUid,
    );
    if (!exists) {
      _selectedItemCode = filtered.first['item_code'] as int;
      _selectedOwnerPilotUid = (filtered.first['owner_pilot_uid'] as num?)?.toInt() ?? 0;
      _quantity = 1;
    }
  }

  Map<String, dynamic>? get _selectedItem {
    final filtered = _filteredListings;
    if (filtered.isEmpty) return null;
    for (final item in filtered) {
      if (item['item_code'] == _selectedItemCode &&
          (item['owner_pilot_uid'] ?? 0) == _selectedOwnerPilotUid) {
        return item;
      }
    }
    return filtered.first;
  }

  Future<void> _handleBuy() async {
    final item = _selectedItem;
    if (item == null || _isProcessingAction) return;

    final int pilotUid = _getPilotUid();
    final int itemCode = item['item_code'] as int;
    final int ownerUid = (item['owner_pilot_uid'] as num?)?.toInt() ?? 0;
    final int stock = (item['station_stock'] as num?)?.toInt() ?? 0;

    if (stock < _quantity) {
      _showFeedback('Estoque insuficiente no mercado para esta quantidade!', isError: true);
      return;
    }

    setState(() => _isProcessingAction = true);
    try {
      final response = await http.post(
        Uri.parse('${widget.apiBaseUrl}/api/market/buy'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'pilot_uid': pilotUid,
          'item_code': itemCode,
          'owner_pilot_uid': ownerUid,
          'quantity': _quantity,
        }),
      );

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200 && decoded['status'] == 'sucesso') {
        _showFeedback(decoded['mensagem'] ?? 'Compra realizada com sucesso!');
        widget.onProfileRefresh?.call();
        await _fetchMarketCatalog(silent: true);
      } else {
        _showFeedback(decoded['mensagem'] ?? 'Falha ao realizar compra.', isError: true);
      }
    } catch (e) {
      _showFeedback('Erro ao comunicar com o servidor: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isProcessingAction = false);
      }
    }
  }

  Future<void> _handleSellToStation() async {
    final item = _selectedItem;
    if (item == null || _isProcessingAction) return;

    final int pilotUid = _getPilotUid();
    final int itemCode = item['item_code'] as int;
    final int playerStock = (item['player_stock'] as num?)?.toInt() ?? 0;

    if (playerStock < _quantity) {
      _showFeedback(
        'Você não possui $_quantity un. deste item no depósito desta estação (Disponível: $playerStock).',
        isError: true,
      );
      return;
    }

    setState(() => _isProcessingAction = true);
    try {
      final response = await http.post(
        Uri.parse('${widget.apiBaseUrl}/api/market/sell'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'pilot_uid': pilotUid,
          'item_code': itemCode,
          'quantity': _quantity,
        }),
      );

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200 && decoded['status'] == 'sucesso') {
        _showFeedback(decoded['mensagem'] ?? 'Venda concluída com sucesso!');
        widget.onProfileRefresh?.call();
        await _fetchMarketCatalog(silent: true);
      } else {
        _showFeedback(decoded['mensagem'] ?? 'Falha ao realizar venda.', isError: true);
      }
    } catch (e) {
      _showFeedback('Erro ao comunicar com o servidor: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isProcessingAction = false);
      }
    }
  }

  Future<void> _showCreatePlayerAdDialog() async {
    final item = _selectedItem;
    if (item == null) return;

    final int playerStock = (item['player_stock'] as num?)?.toInt() ?? 0;
    if (playerStock <= 0) {
      _showFeedback(
        'Você precisa ter este item no seu depósito da estação para anunciá-lo.',
        isError: true,
      );
      return;
    }

    final TextEditingController priceCtrl = TextEditingController(
      text: (item['buy_price'] ?? 1000).toString(),
    );
    final TextEditingController qtyCtrl = TextEditingController(
      text: _quantity.clamp(1, playerStock).toString(),
    );

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF10151E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: const BorderSide(color: _cyanColor, width: 1.5),
          ),
          title: Text(
            'ANUNCIAR PARA PILOTOS NA ESTAÇÃO',
            style: GoogleFonts.shareTechMono(
              color: _greenAccent,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ITEM: ${item['name']} (No seu depósito: $playerStock un.)',
                style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 11),
              ),
              const SizedBox(height: 6),
              Text(
                'O item ficará disponível para compra direta por qualquer piloto atracado nesta mesma estação.',
                style: GoogleFonts.shareTechMono(color: Colors.white70, fontSize: 10),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'QUANTIDADE A ANUNCIAR (MÁX: $playerStock)',
                  labelStyle: GoogleFonts.shareTechMono(color: _cyanColor, fontSize: 10),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: _greenAccent),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'PREÇO UNITÁRIO DE VENDA (CR)',
                  labelStyle: GoogleFonts.shareTechMono(color: _cyanColor, fontSize: 10),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: _greenAccent),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'CANCELAR',
                style: GoogleFonts.shareTechMono(color: Colors.white54, fontSize: 11),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _greenAccent),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                'PUBLICAR ANÚNCIO',
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

    if (confirmed != true) return;

    final int adQty = (int.tryParse(qtyCtrl.text.trim()) ?? 1).clamp(1, playerStock);
    final int adPrice = int.tryParse(priceCtrl.text.trim()) ?? 0;
    if (adPrice <= 0) {
      _showFeedback('Informe um preço válido maior que zero.', isError: true);
      return;
    }

    setState(() => _isProcessingAction = true);
    try {
      final response = await http.post(
        Uri.parse('${widget.apiBaseUrl}/api/market/create-listing'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'pilot_uid': _getPilotUid(),
          'item_code': item['item_code'],
          'quantity': adQty,
          'unit_price': adPrice,
        }),
      );
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200 && decoded['status'] == 'sucesso') {
        _showFeedback(decoded['mensagem'] ?? 'Anúncio publicado!');
        await _fetchMarketCatalog(silent: true);
      } else {
        _showFeedback(decoded['mensagem'] ?? 'Erro ao criar anúncio.', isError: true);
      }
    } catch (e) {
      _showFeedback('Erro ao publicar anúncio: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  Future<void> _handleCancelOwnListing() async {
    final item = _selectedItem;
    if (item == null || _isProcessingAction) return;

    setState(() => _isProcessingAction = true);
    try {
      final response = await http.post(
        Uri.parse('${widget.apiBaseUrl}/api/market/cancel-listing'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'pilot_uid': _getPilotUid(),
          'item_code': item['item_code'],
        }),
      );
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200 && decoded['status'] == 'sucesso') {
        _showFeedback(decoded['mensagem'] ?? 'Anúncio removido!');
        await _fetchMarketCatalog(silent: true);
      } else {
        _showFeedback(decoded['mensagem'] ?? 'Erro ao encerrar anúncio.', isError: true);
      }
    } catch (e) {
      _showFeedback('Erro: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  void _showFeedback(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? _redAccent : const Color(0xFF005B7F),
        duration: const Duration(seconds: 3),
        content: Text(
          message.toUpperCase(),
          style: GoogleFonts.shareTechMono(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  String _valOrBlank(dynamic val, {String suffix = ''}) {
    if (val == null) return '';
    final str = val.toString().trim();
    if (str.isEmpty) return '';
    return '$str$suffix';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: const Color(0xFF0A0D12),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(color: _cyanColor, strokeWidth: 2.5),
              ),
              const SizedBox(height: 12),
              Text(
                'CARREGANDO MERCADO DA ESTAÇÃO...',
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

    if (_errorMessage != null) {
      return Container(
        color: const Color(0xFF0A0D12),
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _panelBg,
              border: Border.all(color: _redAccent),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: _redAccent, size: 32),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: _cyanColor),
                  onPressed: _fetchMarketCatalog,
                  icon: const Icon(Icons.refresh, color: Colors.black, size: 16),
                  label: Text(
                    'TENTAR NOVAMENTE',
                    style: GoogleFonts.shareTechMono(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
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
          color: const Color(0xFF0A0D12),
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. JANELA DE PROPRIEDADES DO ITEM SELECIONADO (IMAGEM 128x128 + ATRIBUTOS)
              _buildPropertiesWindow(isWide: isWide),
              const SizedBox(height: 8),

              // 2. BOTÕES DOS GRUPOS + FILTRO DE PROPRIETÁRIO (ESTAÇÃO / PILOTOS)
              _buildGroupButtonsBar(isWide: isWide),
              const SizedBox(height: 8),

              // 3. GRADE DE ITENS DO GRUPO SELECIONADO (COM IMAGENS 128x128 E BORDA VERDE NO SELECIONADO)
              Expanded(
                child: _buildItemsGrid(isWide: isWide),
              ),
              const SizedBox(height: 8),

              // 4. BARRA INFERIOR DE AÇÃO: COMPRAR E VENDER (-20% DESÁGIO) + ANUNCIAR
              _buildBottomActionBar(isWide: isWide),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPropertiesWindow({required bool isWide}) {
    final item = _selectedItem;
    if (item == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _panelBg,
          border: Border.all(color: _cyanColor.withValues(alpha: 0.6)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'NENHUM ITEM DISPONÍVEL NESTE FILTRO/GRUPO.',
          style: GoogleFonts.shareTechMono(color: Colors.white70, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      );
    }

    final specs = Map<String, dynamic>.from(item['specs'] ?? {});
    final bool isPilotAd = (item['owner_pilot_uid'] ?? 0) != 0;
    final String ownerName = (item['owner_name'] ?? 'ESTAÇÃO COMERCIAL').toString().toUpperCase();
    final int plStock = (item['player_stock'] as num?)?.toInt() ?? 0;
    final bool canAnnounce = !_isProcessingAction && plStock > 0 && _quantity <= plStock;

    final List<Map<String, String>> propertyCells = [
      {
        'label': 'ESTOQUE OFERTA',
        'value': '${item['station_stock'] ?? 0} un.',
        'highlight': 'cyan',
      },
      {
        'label': 'NO SEU DEPÓSITO',
        'value': '${item['player_stock'] ?? 0} un.',
        'highlight': 'green',
      },
      {
        'label': 'PREÇO VENDA',
        'value': '${_formatCredits(item['buy_price'])} CR',
        'highlight': 'cyan',
      },
      {
        'label': 'PREÇO RECOMPRA',
        'value': '${_formatCredits(item['sell_price'])} CR',
        'highlight': 'amber',
      },
      {
        'label': 'VOLUME / PILHA',
        'value': '${item['volume'] ?? 1} m³ / máx ${item['stack'] ?? 1}',
      },
      {
        'label': 'DANO / SEG (DPS)',
        'value': _valOrBlank(specs['dps']),
      },
      {
        'label': 'CONSUMO (MW)',
        'value': _valOrBlank(specs['energy_mw'], suffix: ' MW'),
      },
      {
        'label': 'ALCANCE',
        'value': _valOrBlank(specs['fire_range'], suffix: ' m'),
      },
      {
        'label': 'TAXA DE DISPARO',
        'value': _valOrBlank(specs['fire_rate'], suffix: ' /s'),
      },
      {
        'label': 'DISPARO AUTOMÁTICO',
        'value': _valOrBlank(specs['auto_fire']),
      },
      {
        'label': 'MÓDULO AFETADO',
        'value': _valOrBlank(specs['target_module']),
      },
      {
        'label': 'EFEITO / BÔNUS',
        'value': _valOrBlank(specs['effect_label']),
      },
      {
        'label': 'TIPO DE USO',
        'value': _valOrBlank(specs['usage_type']),
      },
      {
        'label': 'TEMPO DE RECARGA',
        'value': _valOrBlank(specs['cooldown_seconds'], suffix: ' s'),
      },
    ];

    final double imgSize = isWide ? 128.0 : 106.0;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _panelBg,
        border: Border.all(color: _cyanColor, width: 1.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Coluna Esquerda: Moldura 128x128 + Badge + Seletor de Quantidade + Botão Anunciar
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: imgSize,
                height: imgSize,
                decoration: BoxDecoration(
                  color: const Color(0xFF0B0E14),
                  border: Border.all(color: _greenAccent, width: 2.0),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: _greenAccent.withValues(alpha: 0.2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: _buildItemImage(item['image_url']?.toString(), item['item_type'] as int? ?? 1),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: imgSize,
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                decoration: BoxDecoration(
                  color: isPilotAd
                      ? _amberAccent.withValues(alpha: 0.18)
                      : _cyanColor.withValues(alpha: 0.15),
                  border: Border.all(
                    color: isPilotAd ? _amberAccent : _cyanColor,
                    width: 0.8,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  isPilotAd ? 'ANÚNCIO PILOTO' : 'ESTAÇÃO OFICIAL',
                  style: GoogleFonts.shareTechMono(
                    color: isPilotAd ? _amberAccent : _cyanColor,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 6),

              // Seletor de Quantidade (- / QTD / +) abaixo da imagem
              Container(
                width: imgSize,
                height: 30,
                decoration: BoxDecoration(
                  color: _cardBg,
                  border: Border.all(color: _cyanColor.withValues(alpha: 0.65)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: _quantity > 1
                          ? () => setState(() => _quantity--)
                          : null,
                      child: SizedBox(
                        width: 26,
                        height: 30,
                        child: Icon(
                          Icons.remove,
                          color: _quantity > 1 ? _cyanColor : Colors.white24,
                          size: 14,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'QTD: $_quantity',
                        style: GoogleFonts.shareTechMono(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _quantity++),
                      child: const SizedBox(
                        width: 26,
                        height: 30,
                        child: Icon(
                          Icons.add,
                          color: _cyanColor,
                          size: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // Botão ANUNCIAR abaixo do seletor de quantidade (esmaecido quando sem estoque ou QTD > estoque)
              SizedBox(
                width: imgSize,
                height: 30,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _amberAccent,
                    disabledBackgroundColor: Colors.white12,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  onPressed: canAnnounce ? _showCreatePlayerAdDialog : null,
                  icon: Icon(
                    Icons.campaign_outlined,
                    color: canAnnounce ? Colors.black : Colors.white38,
                    size: 14,
                  ),
                  label: Text(
                    'ANUNCIAR',
                    style: GoogleFonts.shareTechMono(
                      color: canAnnounce ? Colors.black : Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // Painel de Descrição e Grade Unificada de Propriedades
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Linha 1: Nome + Código + Proprietário
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      (item['name'] ?? 'ITEM').toString().toUpperCase(),
                      style: GoogleFonts.shareTechMono(
                        color: _greenAccent,
                        fontSize: isWide ? 15 : 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        'CÓD: ${item['item_code_formatted']} · ${(item['group_name'] ?? '').toString().toUpperCase()}',
                        style: GoogleFonts.shareTechMono(
                          color: Colors.white70,
                          fontSize: 9,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: isPilotAd
                            ? _amberAccent.withValues(alpha: 0.15)
                            : _cyanColor.withValues(alpha: 0.12),
                        border: Border.all(
                          color: isPilotAd ? _amberAccent : _cyanColor.withValues(alpha: 0.6),
                          width: 0.8,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        'PROPRIETÁRIO: $ownerName',
                        style: GoogleFonts.shareTechMono(
                          color: isPilotAd ? _amberAccent : _cyanColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Descrição do item
                Text(
                  item['description']?.toString() ?? '',
                  style: GoogleFonts.shareTechMono(
                    color: Colors.white70,
                    fontSize: 10,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // Grade de todas as propriedades (deixando em branco as que não se aplicam ao grupo)
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  children: propertyCells.map((cell) {
                    final String val = cell['value'] ?? '';
                    final bool isEmpty = val.isEmpty;
                    final String? hl = cell['highlight'];
                    Color valColor = Colors.white;
                    if (hl == 'green') valColor = _greenAccent;
                    if (hl == 'cyan') valColor = _cyanColor;
                    if (hl == 'amber') valColor = _amberAccent;

                    return Container(
                      width: isWide ? 132 : 104,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: isEmpty
                            ? const Color(0xFF0D1118).withValues(alpha: 0.5)
                            : _cardBg,
                        border: Border.all(
                          color: isEmpty
                              ? Colors.white12
                              : _cyanColor.withValues(alpha: 0.35),
                          width: 0.8,
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cell['label'] ?? '',
                            style: GoogleFonts.shareTechMono(
                              color: isEmpty ? Colors.white24 : Colors.white54,
                              fontSize: 8,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 1),
                          Text(
                            val, // Fica em branco quando não se aplica ao grupo
                            style: GoogleFonts.shareTechMono(
                              color: valColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupButtonsBar({required bool isWide}) {
    final int playerAdsCount =
        _allListings.where((e) => (e['owner_pilot_uid'] ?? 0) != 0).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Linha dos botões dos Grupos de Item (Verde para o grupo selecionado)
        Row(
          children: _categories.map((cat) {
            final int typeCode = cat['type'] as int;
            final String label = cat['label'] as String;
            final int flexWeight = (cat['flex'] as int?) ?? 10;
            final bool isSelected = _selectedItemType == typeCode;

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
                    padding: EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: isWide ? 4 : 2,
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
                        label,
                        style: GoogleFonts.shareTechMono(
                          color: isSelected ? Colors.black : Colors.white,
                          fontSize: isWide ? 11 : 9,
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
        ),
        const SizedBox(height: 5),

        // Sub-barra: Filtro de Proprietário (Todos / Estação / Anúncios de Pilotos na mesma Estação)
        Row(
          children: [
            _buildOwnerFilterChip('TODOS OS ITENS', 'ALL'),
            const SizedBox(width: 6),
            _buildOwnerFilterChip('OFERTAS DA ESTAÇÃO', 'STATION'),
            const SizedBox(width: 6),
            _buildOwnerFilterChip('ANÚNCIOS DE PILOTOS ($playerAdsCount)', 'PILOTS'),
            const Spacer(),
            if (_stationContext != null && isWide)
              Text(
                'ESTAÇÃO ATUAL: ${_stationContext!['location_label'] ?? ''}',
                style: GoogleFonts.shareTechMono(
                  color: _cyanColor,
                  fontSize: 10,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildOwnerFilterChip(String label, String value) {
    final bool isSelected = _selectedOwnerFilter == value;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedOwnerFilter = value;
          _ensureValidSelection();
        });
      },
      borderRadius: BorderRadius.circular(3),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? _cyanColor.withValues(alpha: 0.22)
              : const Color(0xFF0E131B),
          border: Border.all(
            color: isSelected ? _greenAccent : Colors.white24,
            width: isSelected ? 1.4 : 0.8,
          ),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          label,
          style: GoogleFonts.shareTechMono(
            color: isSelected ? _greenAccent : Colors.white70,
            fontSize: 9,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildItemsGrid({required bool isWide}) {
    final items = _filteredListings;

    if (items.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: _panelBg,
          border: Border.all(color: _cyanColor.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Text(
            _selectedOwnerFilter == 'PILOTS'
                ? 'NENHUM ANÚNCIO DE PILOTO NESTE GRUPO NA ESTAÇÃO ATUAL.'
                : 'NENHUM ITEM ENCONTRADO NESTE GRUPO.',
            style: GoogleFonts.shareTechMono(color: Colors.white54, fontSize: 11),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _panelBg,
        border: Border.all(color: _cyanColor.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: isWide ? 160 : 135,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.76,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final int iCode = item['item_code'] as int;
          final int ownerUid = (item['owner_pilot_uid'] as num?)?.toInt() ?? 0;
          final bool isSelected =
              iCode == _selectedItemCode && ownerUid == _selectedOwnerPilotUid;
          final bool isPilotAd = ownerUid > 0;
          final int stStock = (item['station_stock'] as num?)?.toInt() ?? 0;
          final int plStock = (item['player_stock'] as num?)?.toInt() ?? 0;

          return InkWell(
            onTap: () {
              setState(() {
                _selectedItemCode = iCode;
                _selectedOwnerPilotUid = ownerUid;
                _quantity = 1;
              });
            },
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isSelected
                    ? _greenAccent.withValues(alpha: 0.12)
                    : _cardBg,
                border: Border.all(
                  color: isSelected
                      ? _greenAccent
                      : (isPilotAd ? _amberAccent.withValues(alpha: 0.7) : Colors.white24),
                  width: isSelected ? 2.2 : 1.0,
                ),
                borderRadius: BorderRadius.circular(4),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: _greenAccent.withValues(alpha: 0.25),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Imagem 128x128 com badge de estoque
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF0A0D12),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: _buildItemImage(
                              item['image_url']?.toString(),
                              item['item_type'] as int? ?? 1,
                            ),
                          ),
                        ),
                        if (isPilotAd)
                          Positioned(
                            top: 3,
                            left: 3,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                border: Border.all(color: _amberAccent, width: 0.8),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: Text(
                                item['owner_name']?.toString().toUpperCase() ?? 'PILOTO',
                                style: GoogleFonts.shareTechMono(
                                  color: _amberAccent,
                                  fontSize: 7,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        if (plStock > 0)
                          Positioned(
                            bottom: 3,
                            right: 3,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                border: Border.all(color: _greenAccent, width: 0.8),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: Text(
                                'DEP: $plStock',
                                style: GoogleFonts.shareTechMono(
                                  color: _greenAccent,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),

                  // Nome do item
                  Text(
                    (item['name'] ?? '').toString().toUpperCase(),
                    style: GoogleFonts.shareTechMono(
                      color: isSelected ? _greenAccent : Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),

                  // Preço e Estoque na Estação
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          '${_formatCredits(item['buy_price'])} CR',
                          style: GoogleFonts.shareTechMono(
                            color: _cyanColor,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        'EST:$stStock',
                        style: GoogleFonts.shareTechMono(
                          color: stStock > 0 ? Colors.white70 : _redAccent,
                          fontSize: 8,
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
    );
  }

  Widget _buildBottomActionBar({required bool isWide}) {
    final item = _selectedItem;
    final int buyUnitPrice = (item?['buy_price'] as num?)?.toInt() ?? 0;
    final int sellUnitPrice = (item?['sell_price'] as num?)?.toInt() ?? 0;
    final int totalBuy = buyUnitPrice * _quantity;
    final int totalSell = sellUnitPrice * _quantity;
    final bool isOwnAd = item?['is_own_listing'] == true;
    final int plStock = (item?['player_stock'] as num?)?.toInt() ?? 0;
    final int stStock = (item?['station_stock'] as num?)?.toInt() ?? 0;
    final int pilotCredits = (_stationContext?['credits'] as num?)?.toInt() ?? 0;

    final bool hasEnoughCredits = pilotCredits >= totalBuy;
    final bool hasStationStock = stStock > 0 && stStock >= _quantity;
    final bool canBuy = item != null &&
        !_isProcessingAction &&
        (isOwnAd || (hasStationStock && hasEnoughCredits));
    final bool canSell = item != null &&
        !_isProcessingAction &&
        plStock > 0 &&
        plStock >= _quantity;

    final Color buyLabelColor = canBuy ? Colors.black : Colors.white38;
    // Se não tiver créditos suficientes, destaca o Valor Total da compra em vermelho vivo
    final Color buyTotalValueColor = !hasEnoughCredits
        ? _redAccent
        : (canBuy ? Colors.black : Colors.white38);

    final Color sellTextColor = canSell ? Colors.black : Colors.white38;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _panelBg,
        border: Border.all(color: _cyanColor, width: 1.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          // Botão COMPRAR (50% da barra inferior)
          Expanded(
            child: SizedBox(
              height: isWide ? 42 : 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isOwnAd ? _amberAccent : _greenAccent,
                  disabledBackgroundColor: Colors.white12,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                    side: (!hasEnoughCredits && !isOwnAd)
                        ? BorderSide(color: _redAccent.withValues(alpha: 0.7), width: 1.0)
                        : BorderSide.none,
                  ),
                ),
                onPressed: canBuy
                    ? (isOwnAd ? _handleCancelOwnListing : _handleBuy)
                    : null,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: isOwnAd
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.undo, color: buyLabelColor, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'RECOLHER MEU ANÚNCIO',
                              style: GoogleFonts.shareTechMono(
                                color: buyLabelColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        )
                      : (isWide
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.shopping_cart_checkout,
                                  color: buyLabelColor,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                RichText(
                                  text: TextSpan(
                                    style: GoogleFonts.shareTechMono(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: 'COMPRAR ',
                                        style: TextStyle(color: buyLabelColor),
                                      ),
                                      TextSpan(
                                        text: '(${_formatCredits(totalBuy)} CR)',
                                        style: TextStyle(color: buyTotalValueColor),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.shopping_cart_checkout,
                                      color: buyLabelColor,
                                      size: 13,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'COMPRAR',
                                      style: GoogleFonts.shareTechMono(
                                        color: buyLabelColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${_formatCredits(totalBuy)} CR',
                                  style: GoogleFonts.shareTechMono(
                                    color: buyTotalValueColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            )),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Botão VENDER (50% da barra inferior)
          Expanded(
            child: SizedBox(
              height: isWide ? 42 : 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _cyanColor,
                  disabledBackgroundColor: Colors.white12,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                onPressed: canSell ? _handleSellToStation : null,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: isWide
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.sell_outlined, color: sellTextColor, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'VENDER (+${_formatCredits(totalSell)} CR)',
                              style: GoogleFonts.shareTechMono(
                                color: sellTextColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.sell_outlined, color: sellTextColor, size: 13),
                                const SizedBox(width: 4),
                                Text(
                                  'VENDER',
                                  style: GoogleFonts.shareTechMono(
                                    color: sellTextColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '+${_formatCredits(totalSell)} CR',
                              style: GoogleFonts.shareTechMono(
                                color: sellTextColor,
                                fontSize: 11,
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
      final String fullUrl = rawUrl.startsWith('http')
          ? rawUrl
          : '${widget.apiBaseUrl}${rawUrl.startsWith('/') ? '' : '/'}$rawUrl';
      final Widget img = Image.network(
        fullUrl,
        fit: itemType == 6 ? BoxFit.contain : BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildFallbackIcon(itemType),
      );
      if (itemType == 6) {
        return Padding(
          padding: const EdgeInsets.all(6.0),
          child: img,
        );
      }
      return img;
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
      case 6:
        iconData = Icons.rocket_launch_outlined;
        break;
    }
    return Center(
      child: Icon(iconData, color: _cyanColor.withValues(alpha: 0.5), size: 36),
    );
  }
}
