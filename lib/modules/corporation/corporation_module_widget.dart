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

  @override
  void initState() {
    super.initState();
    _fetchCorporationStatus();
  }

  int get _pilotUid {
    final op = widget.profileData?['operator'];
    if (op != null) {
      final uid = op['account_id'] ?? op['pilot_uid'] ?? op['id'];
      if (uid != null) return int.tryParse(uid.toString()) ?? 536870915;
    }
    return 536870915;
  }

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

  /// Visão do jogador Freelancer (SEM corporação) - PASSO 1
  Widget _buildFreelancerView() {
    if (_currentView == 'apply') {
      return _buildPlaceholderSubView(
        'INSCREVER-SE NUMA CORPORAÇÃO',
        'Etapa 2 em desenvolvimento: aqui será exibida a lista de corporações ativas com filtro por nome e taxa de admissão.',
        Icons.group_add_outlined,
      );
    }

    if (_currentView == 'create') {
      return _buildPlaceholderSubView(
        'CRIAR UMA CORPORAÇÃO',
        'Etapa 4 em desenvolvimento: aqui será selecionada a estação base com validação da taxa de abertura de 1.000.000 CR.',
        Icons.add_business_outlined,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Badge de status
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
                  if (_hasPendingApplication && _pendingApplication != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _cyanColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: _cyanColor.withOpacity(0.6)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.hourglass_top, color: _cyanColor, size: 13),
                          const SizedBox(width: 6),
                          Text(
                            'SOLICITAÇÃO PENDENTE: ${_pendingApplication!['corporation_name'] ?? ''}',
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
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Card de ação reutilizável
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

  /// Visão temporária para telas filhas (preparação para passos 2 e 4)
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
