import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class PlayerProfileScreen extends StatefulWidget {
  final int accountId;
  final String apiBaseUrl;

  const PlayerProfileScreen({
    super.key,
    required this.accountId,
    this.apiBaseUrl = 'http://10.0.2.2:8020',
  });

  @override
  State<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends State<PlayerProfileScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _profileData;

  static const Color _cyanColor = Color(0xFF00D2FF);
  static const Color _darkBg = Color(0xFF0A0D12);
  static const Color _panelBg = Color(0xD912161F);

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  Future<void> _fetchProfileData() async {
    try {
      final response = await http.get(
        Uri.parse(
          '${widget.apiBaseUrl}/player-profile?account_id=${widget.accountId}',
        ),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['status'] == 'sucesso') {
          setState(() {
            _profileData = jsonResponse['data'];
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = jsonResponse['mensagem'] ?? 'Erro desconhecido.';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage =
              'Falha na comunicação com o servidor (${response.statusCode}).';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro de conexão: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      body: SafeArea(
        child:
            _isLoading
                ? const Center(
                  child: CircularProgressIndicator(color: _cyanColor),
                )
                : _errorMessage != null
                ? _buildErrorView()
                : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildHeader(),
                            const SizedBox(height: 12),
                            _buildLocationBar(),
                            const SizedBox(height: 12),
                            _buildCombatStatsBar(),
                            const SizedBox(height: 16),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                if (constraints.maxWidth >= 800) {
                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: _buildReputationPanel()),
                                      const SizedBox(width: 16),
                                      Expanded(child: _buildSkillsPanel()),
                                    ],
                                  );
                                } else {
                                  return Column(
                                    children: [
                                      _buildReputationPanel(),
                                      const SizedBox(height: 16),
                                      _buildSkillsPanel(),
                                    ],
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    _buildBottomNavigationBar(),
                  ],
                ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _errorMessage!,
            style: GoogleFonts.shareTechMono(
              color: Colors.redAccent,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchProfileData();
            },
            style: ElevatedButton.styleFrom(backgroundColor: _cyanColor),
            child: Text(
              'TENTAR NOVAMENTE',
              style: GoogleFonts.shareTechMono(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final op = _profileData!['operator'];
    final String? avatarUrl = op['avatar_url'];

    // Monta a URL da imagem. Se a API retornar ex: "/uploads/avatars/UID.png",
    // ela é concatenada com a URL base da API.
    final String fullAvatarUrl =
        (avatarUrl != null && avatarUrl.isNotEmpty)
            ? (avatarUrl.startsWith('http')
                ? avatarUrl
                : '${widget.apiBaseUrl}$avatarUrl')
            : '';

    return Row(
      children: [
        // Container do Avatar com borda ciano sci-fi
        Container(
          width: 50,
          height: 50,
          clipBehavior:
              Clip.antiAlias, // Garante que a imagem respeite as bordas arredondadas
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _cyanColor.withValues(alpha: 0.6),
              width: 1.2,
            ),
          ),
          child:
              fullAvatarUrl.isNotEmpty
                  ? Image.network(
                    fullAvatarUrl,
                    fit: BoxFit.cover,
                    // Caso falhe ao carregar a imagem por HTTP, exibe o ícone padrão
                    errorBuilder:
                        (context, error, stackTrace) => const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 30,
                        ),
                    // Efeito de carregamento suave
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: _cyanColor,
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    },
                  )
                  : const Icon(Icons.person, color: Colors.white, size: 30),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'OPERADOR: ${op['name']}',
                style: GoogleFonts.shareTechMono(
                  color: _cyanColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'CORPORAÇÃO: ${op['corporation']}',
                style: GoogleFonts.shareTechMono(
                  color: _cyanColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Text(
          'CRÉDITOS: ${_formatCredits(op['credits'])}',
          style: GoogleFonts.shareTechMono(
            color: _cyanColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationBar() {
    final op = _profileData!['operator'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: _cyanColor.withValues(alpha: 0.4)),
      ),
      child: Text(
        'LOCALIZAÇÃO: ${op['location']}',
        style: GoogleFonts.shareTechMono(
          color: Colors.white,
          fontSize: 13,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildCombatStatsBar() {
    final stats = _profileData!['stats'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: _cyanColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'VITÓRIAS: ${stats['kills']}',
            style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 13),
          ),
          Text(
            'DERROTAS: ${stats['deaths']}',
            style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 13),
          ),
          Text(
            'ASSISTÊNCIAS: ${stats['assists']}',
            style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildReputationPanel() {
    final List reputations = _profileData!['reputations'];
    return _buildOuterBox(
      title: 'REPUTAÇÃO:',
      child: Column(
        children:
            reputations.map((rep) {
              final int val = rep['percentage'];
              final bool isPositive = val >= 0;
              final Color barColor =
                  isPositive
                      ? const Color(0xFF00FF66)
                      : const Color(0xFFFF3333);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(
                        rep['faction_name'].toString().toUpperCase(),
                        style: GoogleFonts.shareTechMono(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      child:
                          val == 0
                              ? const SizedBox(height: 10)
                              : Align(
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: (val.abs() / 100).clamp(
                                    0.05,
                                    1.0,
                                  ),
                                  child: Container(
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: barColor,
                                      boxShadow: [
                                        BoxShadow(
                                          color: barColor.withValues(
                                            alpha: 0.6,
                                          ),
                                          blurRadius: 6,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 45,
                      child: Text(
                        '${isPositive ? '+' : ''}$val%',
                        textAlign: TextAlign.end,
                        style: GoogleFonts.shareTechMono(
                          color: barColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildSkillsPanel() {
    final skills = _profileData!['skills'];
    final skillList = [
      {'name': 'EXPLORADOR', 'val': skills['explorer']},
      {'name': 'MINERADOR', 'val': skills['extractor']},
      {'name': 'MERCADOR', 'val': skills['merchant']},
      {'name': 'ENGENHEIRO', 'val': skills['engineer']},
      {'name': 'MERCENÁRIO', 'val': skills['mercenary']},
    ];

    const Color skillColor = Color(0xFF00FF66);

    return _buildOuterBox(
      title: 'HABILIDADES:',
      child: Column(
        children:
            skillList.map((skill) {
              final int val = skill['val'];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(
                        skill['name'] as String,
                        style: GoogleFonts.shareTechMono(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      child:
                          val == 0
                              ? const SizedBox(height: 10)
                              : Align(
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: (val / 100).clamp(0.05, 1.0),
                                  child: Container(
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: skillColor,
                                      boxShadow: [
                                        BoxShadow(
                                          color: skillColor.withValues(
                                            alpha: 0.6,
                                          ),
                                          blurRadius: 6,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 45,
                      child: Text(
                        '$val%',
                        textAlign: TextAlign.end,
                        style: GoogleFonts.shareTechMono(
                          color: skillColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildOuterBox({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _panelBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _cyanColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.shareTechMono(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    final tabs = [
      'PERFIL',
      'MENSAGENS',
      'HANGAR',
      'CONTRATOS',
      'MERCADO',
      'ESTOQUE',
      'FÁBRICA',
    ];
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      color: _darkBg,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children:
            tabs.map((tab) {
              final isSelected = tab == 'PERFIL';
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSelected ? Colors.greenAccent : _cyanColor,
                      width: isSelected ? 2.0 : 1.0,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.square,
                        size: 10,
                        color: isSelected ? Colors.greenAccent : Colors.white,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tab,
                        style: GoogleFonts.shareTechMono(
                          color: isSelected ? Colors.greenAccent : Colors.white,
                          fontSize: 9,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  String _formatCredits(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }
}
