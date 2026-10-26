import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HangarModuleWidget extends StatefulWidget {
  final Map<String, dynamic>? profileData;
  final String apiBaseUrl;

  const HangarModuleWidget({
    super.key,
    this.profileData,
    this.apiBaseUrl = 'http://26.239.180.177:8020',
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
  int _selectedCatalogItemIndex = 1;

  // Mock fiel da Frota de naves
  final List<Map<String, dynamic>> _fleet = [
    {
      'id': 'v0',
      'name': 'NX-77 VESPERA',
      'registry': 'Registro #101 · item NX77',
      'integrity': 94.2,
      'status': 'ATIVA',
      'hold': '38 / 60 T',
      'color': _cyanColor,
      'subsystems': [
        {'name': 'Integridade do Casco', 'val': 96.0, 'status': 'NOMINAL'},
        {'name': 'Motores de Empuxo', 'val': 102.5, 'status': 'SOBRECARGA'},
        {'name': 'Sensores Orbitais', 'val': 78.4, 'status': 'ATENÇÃO'},
        {'name': 'Suporte de Vida', 'val': 100.0, 'status': 'NOMINAL'},
        {'name': 'Amortecedores Inerciais', 'val': 94.1, 'status': 'NOMINAL'},
      ],
      'stats': {
        'dps': 790,
        'energyUsed': 127,
        'energyMax': 650,
        'mass': 18.5,
      },
    },
    {
      'id': 'v1',
      'name': 'KR-12 CORVO NEGRO',
      'registry': 'Registro #102 · item KR12',
      'integrity': 76.5,
      'status': 'ATRACADA',
      'hold': '20 / 45 T',
      'color': _amberAccent,
      'subsystems': [
        {'name': 'Integridade do Casco', 'val': 76.5, 'status': 'ATENÇÃO'},
        {'name': 'Motores de Empuxo', 'val': 85.0, 'status': 'NOMINAL'},
        {'name': 'Sensores Orbitais', 'val': 92.0, 'status': 'NOMINAL'},
        {'name': 'Suporte de Vida', 'val': 88.0, 'status': 'NOMINAL'},
        {'name': 'Amortecedores Inerciais', 'val': 70.0, 'status': 'ATENÇÃO'},
      ],
      'stats': {
        'dps': 540,
        'energyUsed': 95,
        'energyMax': 500,
        'mass': 14.2,
      },
    },
    {
      'id': 'v2',
      'name': 'HX-03 HALCYON',
      'registry': 'Registro #103 · item HX03',
      'integrity': 104.0,
      'status': 'ATRACADA',
      'hold': '55 / 120 T',
      'color': _greenAccent,
      'subsystems': [
        {'name': 'Integridade do Casco', 'val': 100.0, 'status': 'NOMINAL'},
        {'name': 'Motores de Empuxo', 'val': 104.0, 'status': 'SOBRECARGA'},
        {'name': 'Sensores Orbitais', 'val': 100.0, 'status': 'NOMINAL'},
        {'name': 'Suporte de Vida', 'val': 100.0, 'status': 'NOMINAL'},
        {'name': 'Amortecedores Inerciais', 'val': 102.0, 'status': 'SOBRECARGA'},
      ],
      'stats': {
        'dps': 1120,
        'energyUsed': 310,
        'energyMax': 850,
        'mass': 42.0,
      },
    },
    {
      'id': 'v3',
      'name': 'LT-9 MARIPOSA',
      'registry': 'Registro #104 · item LT09',
      'integrity': 88.0,
      'status': 'ATRACADA',
      'hold': '12 / 30 T',
      'color': _cyanColor,
      'subsystems': [
        {'name': 'Integridade do Casco', 'val': 88.0, 'status': 'NOMINAL'},
        {'name': 'Motores de Empuxo', 'val': 95.0, 'status': 'NOMINAL'},
        {'name': 'Sensores Orbitais', 'val': 82.0, 'status': 'NOMINAL'},
        {'name': 'Suporte de Vida', 'val': 90.0, 'status': 'NOMINAL'},
        {'name': 'Amortecedores Inerciais', 'val': 85.0, 'status': 'NOMINAL'},
      ],
      'stats': {
        'dps': 320,
        'energyUsed': 60,
        'energyMax': 400,
        'mass': 9.8,
      },
    },
  ];

  // Hardpoints equipados na nave ativa (mock)
  final Map<String, List<Map<String, dynamic>>> _hardpoints = {
    'CANHÕES': [
      {'id': 'can:0', 'name': 'Pulsar MK-I', 'dps': 180, 'energy': 42, 'range': 1200, 'free': false},
      {'id': 'can:1', 'name': 'Autocanhão Vespa', 'dps': 150, 'energy': 30, 'range': 800, 'free': false},
      {'id': 'can:2', 'name': '+ SLOT LIVRE', 'free': true},
    ],
    'MÍSSEIS': [
      {'id': 'mis:0', 'name': 'Víbora', 'qty': 8, 'dps': 220, 'energy': 18, 'range': 3500, 'free': false},
      {'id': 'mis:1', 'name': 'Enxame', 'qty': 12, 'dps': 310, 'energy': 24, 'range': 2800, 'free': false},
    ],
    'DISPOSITIVOS': [
      {'id': 'dev:0', 'name': 'Escudo Égide', 'energy': 85, 'free': false},
      {'id': 'dev:1', 'name': 'Overclock Ω', 'energy': 110, 'free': false},
      {'id': 'dev:2', 'name': '+ SLOT LIVRE', 'free': true},
    ],
    'UTILITÁRIOS': [
      {'id': 'uti:0', 'name': 'Nanitas', 'qty': 5, 'free': false},
      {'id': 'uti:1', 'name': 'Chaff', 'qty': 20, 'free': false},
      {'id': 'uti:2', 'name': 'Célula', 'qty': 4, 'free': false},
      {'id': 'uti:3', 'name': '+ SLOT LIVRE', 'free': true},
      {'id': 'uti:4', 'name': '+ SLOT LIVRE', 'free': true},
    ],
  };

  // Catálogo de itens disponíveis (mock)
  final Map<String, List<Map<String, dynamic>>> _catalog = {
    'CANHÕES': [
      {
        'name': 'Canhão Pulsar MK-I',
        'dps': 180,
        'energy': 42,
        'range': 1200,
        'stock': 3,
        'inStock': true,
      },
      {
        'name': 'Canhão de Plasma MK-II',
        'dps': 265,
        'energy': 68,
        'range': 950,
        'stock': 1,
        'inStock': true,
      },
      {
        'name': 'Railgun Lança',
        'dps': 410,
        'energy': 120,
        'range': 2600,
        'stock': 0,
        'inStock': false,
      },
      {
        'name': 'Autocanhão Vespa',
        'dps': 150,
        'energy': 30,
        'range': 800,
        'stock': 5,
        'inStock': true,
      },
    ],
    'MÍSSEIS': [
      {
        'name': 'Míssil Víbora',
        'dps': 220,
        'energy': 18,
        'range': 3500,
        'stock': 8,
        'inStock': true,
      },
      {
        'name': 'Míssil Enxame',
        'dps': 310,
        'energy': 24,
        'range': 2800,
        'stock': 12,
        'inStock': true,
      },
      {
        'name': 'Torpedo Caelum',
        'dps': 600,
        'energy': 45,
        'range': 1800,
        'stock': 0,
        'inStock': false,
      },
    ],
    'DISPOSITIVOS': [
      {
        'name': 'Escudo Égide MK-II',
        'dps': 0,
        'energy': 85,
        'range': 0,
        'stock': 1,
        'inStock': true,
      },
      {
        'name': 'Overclock Ω Tático',
        'dps': 50,
        'energy': 110,
        'range': 0,
        'stock': 2,
        'inStock': true,
      },
    ],
    'UTILITÁRIOS': [
      {
        'name': 'Nanitas de Reparo Rápido',
        'dps': 0,
        'energy': 15,
        'range': 0,
        'stock': 5,
        'inStock': true,
      },
      {
        'name': 'Chaff Contramedida',
        'dps': 0,
        'energy': 5,
        'range': 0,
        'stock': 20,
        'inStock': true,
      },
    ],
  };

  @override
  Widget build(BuildContext context) {
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
                height: 220,
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
                final bool isActive = ship['status'] == 'ATIVA';
                final Color shipColor = ship['color'] as Color;
                final double integrity = (ship['integrity'] as num).toDouble();

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
                              Icons.navigation,
                              size: 14,
                              color: shipColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                ship['name'],
                                style: GoogleFonts.shareTechMono(
                                  color: isSelected ? Colors.white : Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? _greenAccent.withValues(alpha: 0.15)
                                    : Colors.white10,
                                border: Border.all(
                                  color: isActive ? _greenAccent : Colors.white24,
                                  width: 0.8,
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: Text(
                                ship['status'],
                                style: GoogleFonts.shareTechMono(
                                  color: isActive ? _greenAccent : Colors.white54,
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
  // CARROSSEL DE SELEÇÃO RÁPIDA DE NAVE
  // =========================================================================
  Widget _buildShipCarouselSelector() {
    final currentShip = _fleet[_selectedShipIndex];
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
            onPressed: () {
              setState(() {
                _selectedShipIndex =
                    (_selectedShipIndex - 1 + _fleet.length) % _fleet.length;
              });
            },
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  currentShip['name'],
                  style: GoogleFonts.shareTechMono(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                  textAlign: TextAlign.center,
                ),
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
            onPressed: () {
              setState(() {
                _selectedShipIndex =
                    (_selectedShipIndex + 1) % _fleet.length;
              });
            },
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
    return Center(
      child: AspectRatio(
        aspectRatio: 600 / 260,
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                _cyanColor.withValues(alpha: 0.10),
                Colors.transparent,
              ],
              radius: 0.8,
            ),
          ),
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
  Widget _buildLoadoutFullView({required bool isDesktop}) {
    final currentShip = _fleet[_selectedShipIndex];
    final stats = currentShip['stats'] as Map<String, dynamic>;

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

        ..._hardpoints.entries.map((entry) {
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
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: slots.map((slot) {
                  final bool isFree = slot['free'] == true;
                  final bool isSelected = _selectedSlotId == slot['id'];

                  return InkWell(
                    onTap: () {
                      if (!isFree) {
                        setState(() {
                          _selectedSlotId = slot['id'];
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _cyanColor.withValues(alpha: 0.2)
                            : (isFree ? Colors.transparent : _cardBg),
                        border: Border.all(
                          color: isSelected
                              ? _cyanColor
                              : (isFree ? Colors.white24 : Colors.white38),
                          width: isSelected ? 1.5 : 0.8,
                          style: isFree ? BorderStyle.solid : BorderStyle.solid,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isFree ? Icons.add : Icons.check_circle_outline,
                            size: 11,
                            color: isFree ? Colors.white38 : _cyanColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            slot['name'],
                            style: GoogleFonts.shareTechMono(
                              color: isFree ? Colors.white38 : Colors.white,
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
                _cyanColor,
              ),
              _buildStatCol('CARGA/MASSA', '${stats['mass']} T', Colors.white),
            ],
          ),
        ),
      ],
    );

    Widget catalogSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CATÁLOGO DE MÓDULOS',
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
                    setState(() {
                      _selectedLoadoutCategory = cat;
                      _selectedCatalogItemIndex = 0;
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

        // Lista de Itens do catálogo
        ...(_catalog[_selectedLoadoutCategory] ?? []).asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final bool isSel = _selectedCatalogItemIndex == index;
          final bool inStock = item['inStock'] == true;

          return Container(
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
                        item['name'],
                        style: GoogleFonts.shareTechMono(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'DPS ${item['dps']} · ${item['energy']} MW · ${item['range']} m',
                        style: GoogleFonts.shareTechMono(
                          color: Colors.white54,
                          fontSize: 9,
                        ),
                      ),
                      Text(
                        inStock ? '${item['stock']} no inventário' : 'sem estoque',
                        style: GoogleFonts.shareTechMono(
                          color: inStock ? _greenAccent : _amberAccent,
                          fontSize: 8,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedCatalogItemIndex = index;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: inStock ? _cyanColor : _amberAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                  ),
                  child: Text(
                    inStock ? 'EQUIPAR' : 'COMPRAR',
                    style: GoogleFonts.shareTechMono(
                      color: Colors.black,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
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

  Widget _buildComparisonBox() {
    final catItems = _catalog[_selectedLoadoutCategory] ?? [];
    final selectedItem =
        catItems.isNotEmpty && _selectedCatalogItemIndex < catItems.length
            ? catItems[_selectedCatalogItemIndex]
            : null;

    if (selectedItem == null) return const SizedBox.shrink();

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
            '// COMPARAÇÃO DE MÓDULOS',
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
                    Text('ATUAL (CAN:0)', style: GoogleFonts.shareTechMono(color: Colors.white38, fontSize: 8)),
                    Text('Pulsar MK-I', style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    Text('DPS: 180', style: GoogleFonts.shareTechMono(color: Colors.white70, fontSize: 9)),
                    Text('Energia: 42 MW', style: GoogleFonts.shareTechMono(color: Colors.white70, fontSize: 9)),
                    Text('Alcance: 1200 m', style: GoogleFonts.shareTechMono(color: Colors.white70, fontSize: 9)),
                  ],
                ),
              ),
              Text(
                'VS',
                style: GoogleFonts.shareTechMono(
                  color: _amberAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('SELECIONADO', style: GoogleFonts.shareTechMono(color: _cyanColor, fontSize: 8)),
                    Text(selectedItem['name'], style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                    Text('DPS: ${selectedItem['dps']} ▲', style: GoogleFonts.shareTechMono(color: _greenAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                    Text('Energia: ${selectedItem['energy']} MW ▲', style: GoogleFonts.shareTechMono(color: _redAccent, fontSize: 9)),
                    Text('Alcance: ${selectedItem['range']} m ▼', style: GoogleFonts.shareTechMono(color: _amberAccent, fontSize: 9)),
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
        return Dialog(
          backgroundColor: const Color(0xFF0A0D12),
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            width: 900,
            height: 600,
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
                      onPressed: () => Navigator.pop(context),
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
