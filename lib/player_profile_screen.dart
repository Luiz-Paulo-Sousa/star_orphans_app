import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class PlayerProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? profileData;
  final String apiBaseUrl;
  final int? accountId;

  const PlayerProfileScreen({
    super.key,
    this.profileData,
    this.apiBaseUrl = 'http://26.239.180.177:8020',
    this.accountId,
  });

  @override
  State<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends State<PlayerProfileScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  late Map<String, dynamic>? _profileData;

  static const Color _cyanColor = Color(0xFF00D2FF);
  static const Color _panelBg = Color(0xD912161F);

  @override
  void initState() {
    super.initState();
    _profileData = widget.profileData;

    if (_profileData == null && widget.accountId != null) {
      _fetchProfileData();
    }
  }

  @override
  void didUpdateWidget(covariant PlayerProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.profileData != oldWidget.profileData) {
      setState(() {
        _profileData = widget.profileData;
      });
    }
  }

  Future<void> _fetchProfileData() async {
    setState(() => _isLoading = true);
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _cyanColor));
    }

    if (_errorMessage != null) {
      return _buildErrorView();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCombatStatsBar(),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 800) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
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

  Widget _buildCombatStatsBar() {
    final stats = _profileData?['stats'] ?? {};
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _panelBg,
        border: Border.all(color: _cyanColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'VITÓRIAS: ${stats['kills'] ?? 0}',
            style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 13),
          ),
          Text(
            'DERROTAS: ${stats['deaths'] ?? 0}',
            style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 13),
          ),
          Text(
            'ASSISTÊNCIAS: ${stats['assists'] ?? 0}',
            style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildReputationPanel() {
    final List reputations = _profileData?['reputations'] ?? [];
    return _buildOuterBox(
      title: 'REPUTAÇÃO:',
      child: Column(
        children:
            reputations.map((rep) {
              final int val = (rep['percentage'] ?? 0) as int;
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
                        (rep['faction_name'] ?? 'N/A').toString().toUpperCase(),
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
    final skills = _profileData?['skills'] ?? {};
    final skillList = [
      {'name': 'EXPLORADOR', 'val': skills['explorer'] ?? 0},
      {'name': 'MINERADOR', 'val': skills['extractor'] ?? 0},
      {'name': 'MERCADOR', 'val': skills['merchant'] ?? 0},
      {'name': 'ENGENHEIRO', 'val': skills['engineer'] ?? 0},
      {'name': 'MERCENÁRIO', 'val': skills['mercenary'] ?? 0},
    ];

    const Color skillColor = Color(0xFF00FF66);

    return _buildOuterBox(
      title: 'HABILIDADES:',
      child: Column(
        children:
            skillList.map((skill) {
              final int val = (skill['val'] as num).toInt();
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
}
