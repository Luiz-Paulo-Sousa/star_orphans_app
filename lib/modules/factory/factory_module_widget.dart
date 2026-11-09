import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class FactoryModuleWidget extends StatefulWidget {
  final Map<String, dynamic>? profileData;
  final String apiBaseUrl;
  final VoidCallback? onProfileRefresh;

  const FactoryModuleWidget({
    super.key,
    this.profileData,
    this.apiBaseUrl = 'http://26.239.180.177:8020',
    this.onProfileRefresh,
  });

  @override
  State<FactoryModuleWidget> createState() => _FactoryModuleWidgetState();
}

class _FactoryModuleWidgetState extends State<FactoryModuleWidget> {
  static const Color _cyanColor = Color(0xFF00D2FF);
  static const Color _greenAccent = Color(0xFF00FF66);
  static const Color _amberAccent = Color(0xFFFFB800);
  static const Color _redAccent = Color(0xFFFF3333);
  static const Color _darkBg = Color(0xFF0A0D12);
  static const Color _panelBg = Color(0xD912161F);
  static const Color _cardBg = Color(0xFF151922);

  // Categorias idênticas à interface do Mercado com larguras flex
  static const List<Map<String, dynamic>> _categories = [
    {'type': 6, 'label': 'NAVES', 'flex': 8},
    {'type': 1, 'label': 'INSUMOS', 'flex': 10},
    {'type': 2, 'label': 'ARMAS', 'flex': 8},
    {'type': 3, 'label': 'MÍSSEIS', 'flex': 10},
    {'type': 4, 'label': 'DISPOSITIVOS', 'flex': 14},
    {'type': 5, 'label': 'UTILITÁRIOS', 'flex': 14},
  ];

  int _selectedSubTab = 0; // 0 = PROJETOS, 1 = FILA DE PRODUÇÃO
  int _selectedItemType = 1; // Categoria padrão (Insumos/Matéria-prima)
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  Map<String, dynamic>? _stationInfo;
  List<Map<String, dynamic>> _recipes = [];
  List<Map<String, dynamic>> _queue = [];

  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _loadFactoryData();
    // Atualização a cada 1s para o timer regressivo da fila
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _queue.isNotEmpty) {
        setState(() {
          for (var item in _queue) {
            int sec = (item['remaining_seconds'] as int? ?? 0);
            if (sec > 0) {
              item['remaining_seconds'] = sec - 1;
            }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  int _getPilotUid() {
    final profile = widget.profileData ?? {};
    final op = profile['operator'] ?? {};
    final dynamic raw =
        op['account_id'] ??
        op['operator_uid'] ??
        op['pilot_uid'] ??
        op['uid'] ??
        profile['account_id'] ??
        profile['uid'];
    if (raw != null) {
      if (raw is int) return raw;
      return int.tryParse(raw.toString()) ?? 0;
    }
    return 0;
  }

  Future<void> _loadFactoryData() async {
    final pilotUid = _getPilotUid();
    if (pilotUid == 0) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final infoRes = await http.get(Uri.parse('${widget.apiBaseUrl}/api/factory/info/$pilotUid'));
      final recipesRes = await http.get(Uri.parse('${widget.apiBaseUrl}/api/factory/recipes/$pilotUid'));
      final queueRes = await http.get(Uri.parse('${widget.apiBaseUrl}/api/factory/queue/$pilotUid'));

      if (infoRes.statusCode == 200 && recipesRes.statusCode == 200 && queueRes.statusCode == 200) {
        final infoData = jsonDecode(infoRes.body);
        final recipesData = jsonDecode(recipesRes.body);
        final queueData = jsonDecode(queueRes.body);

        final loadedRecipes = List<Map<String, dynamic>>.from(recipesData['recipes'] ?? []);
        final stationType = infoData?['pilot']?['station_type']?.toString().toLowerCase() ?? 'fabrica';

        setState(() {
          _stationInfo = infoData;
          _recipes = loadedRecipes;
          _queue = List<Map<String, dynamic>>.from(queueData['queue'] ?? []);
          _isLoading = false;

          // Se for fundição, seleciona automaticamente INSUMOS; se fábrica, se não tiver itens da categoria atual, busca a primeira com itens
          if (stationType == 'fundicao') {
            _selectedItemType = 1;
          } else {
            final hasCurrent = loadedRecipes.any((r) => r['item_type'] == _selectedItemType);
            if (!hasCurrent && loadedRecipes.isNotEmpty) {
              _selectedItemType = loadedRecipes.first['item_type'] ?? 1;
            }
          }
        });
      } else {
        setState(() {
          _errorMessage = 'Falha ao sincronizar dados da fábrica com o servidor.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Erro de conexão com o servidor: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _startCrafting(int itemCode, int amount) async {
    final pilotUid = _getPilotUid();
    if (pilotUid == 0 || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final res = await http.post(
        Uri.parse('${widget.apiBaseUrl}/api/factory/start'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'pilot_uid': pilotUid,
          'item_code': itemCode,
          'amount': amount,
        }),
      );

      final data = jsonDecode(res.body);

      if (res.statusCode == 201 || res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF152A1E),
            content: Text(
              'PRODUÇÃO INICIADA COM SUCESSO!',
              style: GoogleFonts.shareTechMono(color: _greenAccent, fontWeight: FontWeight.bold),
            ),
          ),
        );
        widget.onProfileRefresh?.call();
        await _loadFactoryData();
        setState(() => _selectedSubTab = 1);
      } else {
        _showErrorDialog(data['mensagem'] ?? 'Erro ao iniciar fabricação.');
      }
    } catch (e) {
      _showErrorDialog('Erro de rede: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _cancelCrafting(int queueUid) async {
    final pilotUid = _getPilotUid();
    if (pilotUid == 0 || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final res = await http.post(
        Uri.parse('${widget.apiBaseUrl}/api/factory/cancel'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'pilot_uid': pilotUid,
          'queue_uid': queueUid,
        }),
      );

      final data = jsonDecode(res.body);

      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _panelBg,
            content: Text(
              'ORDEM DE PRODUÇÃO CANCELADA.',
              style: GoogleFonts.shareTechMono(color: _amberAccent),
            ),
          ),
        );
        await _loadFactoryData();
      } else {
        _showErrorDialog(data['mensagem'] ?? 'Erro ao cancelar ordem.');
      }
    } catch (e) {
      _showErrorDialog('Erro de conexão: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showErrorDialog(String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panelBg,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: _redAccent, width: 1.5),
          borderRadius: BorderRadius.circular(4),
        ),
        title: Text(
          '// AVISO DO SISTEMA',
          style: GoogleFonts.shareTechMono(color: _redAccent, fontWeight: FontWeight.bold, fontSize: 13),
        ),
        content: Text(
          msg,
          style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('ENTENDIDO', style: GoogleFonts.shareTechMono(color: _cyanColor)),
          ),
        ],
      ),
    );
  }

  String _formatSeconds(int seconds) {
    if (seconds <= 0) return '00:00:00';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _cyanColor),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, color: _redAccent, size: 40),
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: _loadFactoryData,
                icon: const Icon(Icons.refresh, size: 15),
                label: Text('TENTAR NOVAMENTE', style: GoogleFonts.shareTechMono(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _cardBg,
                  foregroundColor: _cyanColor,
                  side: const BorderSide(color: _cyanColor),
                ),
              )
            ],
          ),
        ),
      );
    }

    final pilot = _stationInfo?['pilot'] ?? {};
    final hangar = _stationInfo?['hangar'] ?? {};
    final stationType = pilot['station_type']?.toString().toLowerCase() ?? 'fabrica';
    final isFoundry = stationType == 'fundicao';

    return Container(
      color: _darkBg,
      child: Column(
        children: [
          // 1. Barra de Informação da Instação (Estação)
          _buildFacilityHeader(pilot, hangar, isFoundry),

          // 2. Abas de Navegação (Projetos vs Fila)
          _buildSubTabBar(),

          // 3. Barra de Categorias / Filtros (exibida quando na aba Projetos)
          if (_selectedSubTab == 0) _buildCategoryFilterBar(),

          // 4. Conteúdo Selecionado
          Expanded(
            child: _selectedSubTab == 0
                ? _buildRecipesView(isFoundry)
                : _buildQueueView(),
          ),
        ],
      ),
    );
  }

  Widget _buildFacilityHeader(Map<String, dynamic> pilot, Map<String, dynamic> hangar, bool isFoundry) {
    final stationName = pilot['station_name'] ?? 'ESTAÇÃO ESPACIAL';
    final credits = pilot['credits'] ?? 0;
    final usedVol = hangar['current_volume'] ?? 0;
    final maxVol = hangar['max_volume'] ?? 50000;

    // Label simplificado: FÁBRICA ou FUNDIÇÃO
    final typeLabel = isFoundry ? 'FUNDIÇÃO' : 'FÁBRICA';
    final typeColor = isFoundry ? _amberAccent : _cyanColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _panelBg,
        border: Border(
          bottom: BorderSide(color: _cyanColor.withValues(alpha: 0.25), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isFoundry ? Icons.local_fire_department : Icons.precision_manufacturing,
                      color: typeColor,
                      size: 14,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      typeLabel,
                      style: GoogleFonts.shareTechMono(
                        color: typeColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  stationName.toString().toUpperCase(),
                  style: GoogleFonts.shareTechMono(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'CRÉDITOS: $credits CR',
                style: GoogleFonts.shareTechMono(
                  color: _greenAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 1),
              // Palavra ESTOQUE no lugar de HANGAR
              Text(
                'ESTOQUE: $usedVol / $maxVol m³',
                style: GoogleFonts.shareTechMono(
                  color: Colors.white70,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubTabBar() {
    final inProgressCount = _queue.where((q) => q['status'] == 'in_progress').length;

    return Container(
      color: _darkBg,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: _buildSubTabButton(
              // Nome alterado de RECEITAS para PROJETOS
              label: 'PROJETOS DISPONÍVEIS',
              icon: Icons.architecture,
              isSelected: _selectedSubTab == 0,
              onTap: () => setState(() => _selectedSubTab = 0),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildSubTabButton(
              label: inProgressCount > 0 ? 'FILA ATIVA ($inProgressCount)' : 'FILA DE PRODUÇÃO',
              icon: Icons.hourglass_top_outlined,
              isSelected: _selectedSubTab == 1,
              badgeCount: inProgressCount,
              onTap: () => setState(() => _selectedSubTab = 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubTabButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? _panelBg : _cardBg.withValues(alpha: 0.5),
          border: Border.all(
            color: isSelected ? _cyanColor : Colors.white12,
            width: isSelected ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 13, color: isSelected ? _cyanColor : Colors.white60),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.shareTechMono(
                color: isSelected ? _cyanColor : Colors.white70,
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Barra de filtros de grupos idêntica à interface do Mercado
  Widget _buildCategoryFilterBar() {
    return Container(
      color: _darkBg,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        children: _categories.map((cat) {
          final int typeCode = cat['type'] as int;
          final String label = cat['label'] as String;
          final int flexWeight = (cat['flex'] as int?) ?? 10;
          final bool isSelected = _selectedItemType == typeCode;

          return Expanded(
            flex: flexWeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedItemType = typeCode;
                  });
                },
                borderRadius: BorderRadius.circular(3),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                  decoration: BoxDecoration(
                    color: isSelected ? _greenAccent : _panelBg,
                    border: Border.all(
                      color: isSelected ? _greenAccent : _cyanColor,
                      width: isSelected ? 1.6 : 1.0,
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      style: GoogleFonts.shareTechMono(
                        color: isSelected ? Colors.black : Colors.white,
                        fontSize: 9.5,
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
    );
  }

  Widget _buildRecipesView(bool isFoundry) {
    // Filtra pelo tipo de item selecionado
    final filtered = _recipes.where((r) => (r['item_type'] as int? ?? 1) == _selectedItemType).toList();

    if (filtered.isEmpty) {
      final currentCategory = _categories.firstWhere(
        (c) => c['type'] == _selectedItemType,
        orElse: () => {'label': 'CATEGORIA'},
      )['label'];

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            '// NENHUM PROJETO DE $currentCategory DISPONÍVEL NESTA ESTAÇÃO.',
            style: GoogleFonts.shareTechMono(color: Colors.white38, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final recipe = filtered[index];
        return _buildRecipeCard(recipe);
      },
    );
  }

  // Card do item com tamanho reduzido e botão no canto superior direito
  Widget _buildRecipeCard(Map<String, dynamic> recipe) {
    final name = recipe['name'] ?? 'Item';
    final timeSec = recipe['craft_time'] ?? 60;
    final cost = recipe['cost'] ?? 0;
    final canCraft = recipe['can_craft'] == true;
    final itemCode = recipe['item_code'];
    final ingredients = List<Map<String, dynamic>>.from(recipe['ingredients'] ?? []);

    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      decoration: BoxDecoration(
        color: _cardBg,
        border: Border.all(
          color: canCraft ? _greenAccent.withValues(alpha: 0.4) : Colors.white12,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Linha Superior: Nome do Item + Botão de Fabricar (posicionado no topo, 20% menor)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    name.toString().toUpperCase(),
                    style: GoogleFonts.shareTechMono(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                // Botão de Iniciar Fabricação reposicionado e reduzido em 20%
                ElevatedButton.icon(
                  onPressed: (canCraft && !_isSubmitting)
                      ? () => _startCrafting(itemCode, 1)
                      : null,
                  icon: const Icon(Icons.play_arrow_rounded, size: 13),
                  label: Text(
                    _isSubmitting ? 'AGUARDE' : 'FABRICAR',
                    style: GoogleFonts.shareTechMono(fontWeight: FontWeight.bold, fontSize: 9.5),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canCraft ? const Color(0xFF152A1E) : Colors.white.withValues(alpha: 0.05),
                    foregroundColor: canCraft ? _greenAccent : Colors.white24,
                    side: BorderSide(
                      color: canCraft ? _greenAccent : Colors.white12,
                      width: 1,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: const Size(0, 26),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            // Linha com tempo e custo
            Row(
              children: [
                const Icon(Icons.timer_outlined, size: 11, color: Colors.white60),
                const SizedBox(width: 3),
                Text(
                  _formatSeconds(timeSec),
                  style: GoogleFonts.shareTechMono(color: Colors.white70, fontSize: 10.5),
                ),
                const SizedBox(width: 14),
                const Icon(Icons.monetization_on_outlined, size: 11, color: _greenAccent),
                const SizedBox(width: 3),
                Text(
                  '$cost CR',
                  style: GoogleFonts.shareTechMono(color: _greenAccent, fontSize: 10.5),
                ),
              ],
            ),
            const Divider(color: Colors.white10, height: 10),
            // Seção de Insumos (Recursos exigidos no estoque)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'ESTOQUE: ',
                  style: GoogleFonts.shareTechMono(color: Colors.white38, fontSize: 9.5),
                ),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: ingredients.map((ing) {
                      final ingName = ing['name'] ?? 'Insumo';
                      final reqAmt = ing['required_amount'] ?? 1;
                      final availAmt = ing['available_amount'] ?? 0;
                      final sufficient = ing['sufficient'] == true;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _panelBg,
                          border: Border.all(
                            color: sufficient ? _greenAccent.withValues(alpha: 0.35) : _redAccent.withValues(alpha: 0.35),
                            width: 0.7,
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$ingName: ',
                              style: GoogleFonts.shareTechMono(color: Colors.white70, fontSize: 10),
                            ),
                            Text(
                              '$availAmt/$reqAmt',
                              style: GoogleFonts.shareTechMono(
                                color: sufficient ? _greenAccent : _redAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueView() {
    if (_queue.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.inbox_outlined, size: 32, color: Colors.white24),
              const SizedBox(height: 6),
              Text(
                '// NENHUMA ORDEM DE FABRICAÇÃO NA FILA',
                style: GoogleFonts.shareTechMono(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: _queue.length,
      itemBuilder: (context, index) {
        final item = _queue[index];
        return _buildQueueCard(item);
      },
    );
  }

  Widget _buildQueueCard(Map<String, dynamic> item) {
    final queueUid = item['queue_uid'];
    final name = item['item_name'] ?? 'Item';
    final amount = item['amount'] ?? 1;
    final stationName = item['station_name'] ?? 'Estação';
    final status = (item['status'] ?? 'in_progress').toString().toLowerCase();
    final remainingSec = (item['remaining_seconds'] as int? ?? 0);

    final isInProgress = status == 'in_progress';
    final isCompleted = status == 'completed';

    Color statusColor = _cyanColor;
    String statusLabel = 'EM ANDAMENTO';

    if (isCompleted || (isInProgress && remainingSec <= 0)) {
      statusColor = _greenAccent;
      statusLabel = 'PRONTO / ENTREGUE';
    } else if (status == 'cancelled') {
      statusColor = _redAccent;
      statusLabel = 'CANCELADO';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _cardBg,
        border: Border.all(color: statusColor.withValues(alpha: 0.4), width: 1),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ORDEM #$queueUid - ${amount}x ${name.toString().toUpperCase()}',
                style: GoogleFonts.shareTechMono(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: _panelBg,
                  border: Border.all(color: statusColor, width: 0.8),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  statusLabel,
                  style: GoogleFonts.shareTechMono(
                    color: statusColor,
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'LOCAL: ${stationName.toString().toUpperCase()}',
            style: GoogleFonts.shareTechMono(color: Colors.white60, fontSize: 10),
          ),
          const SizedBox(height: 6),
          if (isInProgress && remainingSec > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: const LinearProgressIndicator(
                backgroundColor: Colors.white12,
                color: _cyanColor,
                minHeight: 3.5,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TEMPO RESTANTE: ${_formatSeconds(remainingSec)}',
                  style: GoogleFonts.shareTechMono(
                    color: _cyanColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
                TextButton(
                  onPressed: _isSubmitting ? null : () => _cancelCrafting(queueUid),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    minimumSize: const Size(0, 24),
                  ),
                  child: Text(
                    'CANCELAR',
                    style: GoogleFonts.shareTechMono(color: _redAccent, fontSize: 10),
                  ),
                ),
              ],
            ),
          ] else if (isCompleted || remainingSec <= 0) ...[
            Text(
              '✓ Item concluído e entregue no estoque desta estação.',
              style: GoogleFonts.shareTechMono(color: _greenAccent, fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }
}
