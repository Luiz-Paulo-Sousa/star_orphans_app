import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'widgets/channel_left_panel.dart';
import 'views/readonly_chat_view.dart';

class MessagingModuleWidget extends StatefulWidget {
  final Map<String, dynamic>? profileData;
  final String apiBaseUrl;

  const MessagingModuleWidget({
    super.key,
    this.profileData,
    this.apiBaseUrl = 'http://26.239.180.177:8020',
  });

  @override
  State<MessagingModuleWidget> createState() => _MessagingModuleWidgetState();
}

class _MessagingModuleWidgetState extends State<MessagingModuleWidget> {
  static const Color _cyanColor = Color(0xFF00D2FF);
  static const Color _greenAccent = Color(0xFF00FF66);
  static const Color _panelBg = Color(0xD912161F);

  // Controle de abas principais
  String _activeTab = 'CONVERSAS';

  // Seleções ativas
  String _selectedChannel = 'EQUIPE';
  final String _selectedContact = 'BUSTER';

  // Estados para carregamento dinâmico dos canais
  List<dynamic> _channelsList = [];
  bool _isLoadingChannels = true;
  String? _channelsError;

  // Estados para carregamento dinâmico das facções / sub-canais de coalizão
  List<dynamic> _factionsList = [];
  bool _isLoadingFactions = false;
  int? _selectedFactionUid;

  // Estados para mensagens dinâmicas
  List<dynamic> _messagesList = [];
  bool _isLoadingMessages = false;

  // Controller para o campo de envio de texto
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchChannels();
    _fetchFactions();
  }

  Future<void> _fetchChannels() async {
    try {
      final response = await http.get(
        Uri.parse('${widget.apiBaseUrl}/api/message-channels'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _channelsList = data is List ? data : (data['channels'] ?? []);
          _isLoadingChannels = false;
          if (_channelsList.isNotEmpty) {
            _selectedChannel = _channelsList[0]['description'] ?? 'EQUIPE';
          }
        });
      } else {
        setState(() {
          _channelsError = 'Erro HTTP: ${response.statusCode}';
          _isLoadingChannels = false;
        });
      }
    } catch (e) {
      setState(() {
        _channelsError = 'Falha de conexão';
        _isLoadingChannels = false;
      });
    }
  }

  Future<void> _fetchFactions() async {
    setState(() {
      _isLoadingFactions = true;
    });

    try {
      final response = await http.get(
        Uri.parse('${widget.apiBaseUrl}/api/factions'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _factionsList = data is List ? data : [];
          if (_factionsList.isNotEmpty && _selectedFactionUid == null) {
            _selectedFactionUid = _factionsList[0]['faction_uid'];
            _fetchMessages(1, _selectedFactionUid!);
          }
        });
      }
    } catch (e) {
      print('Erro ao carregar facções: $e');
    } finally {
      setState(() {
        _isLoadingFactions = false;
      });
    }
  }

Future<void> _fetchMessages(int channelUid, int subchannelUid) async {
    setState(() {
      _isLoadingMessages = true;
    });

    final profile = widget.profileData ?? {};
    final accountData = profile['account'] ?? {};
    final operatorData = profile['operator'] ?? {};

    // Captura o ID correto a partir de operator['account_id']
    final accountUid =
        operatorData['account_id'] ??
        profile['uid'] ??
        accountData['uid'] ??
        operatorData['account_uid'] ??
        operatorData['uid'] ??
        profile['account_uid'] ??
        '';

    print('DEBUG MENSAGENS -> accountUid extraído: "$accountUid"');

    if (accountUid.toString().trim().isEmpty) {
      setState(() {
        _messagesList = [];
        _isLoadingMessages = false;
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(
          '${widget.apiBaseUrl}/api/messages/$channelUid/$subchannelUid?destinationUid=$accountUid',
        ),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _messagesList = data is List ? data : [];
        });
      }
    } catch (e) {
      print('Erro ao carregar mensagens: $e');
    } finally {
      setState(() {
        _isLoadingMessages = false;
      });
    }
  }
    
  String _getSelectedFactionName() {
    if (_factionsList.isEmpty || _selectedFactionUid == null) return 'CENTRAL';
    final faction = _factionsList.firstWhere(
      (f) => f['faction_uid'] == _selectedFactionUid,
      orElse: () => _factionsList[0],
    );
    return faction['name'] ?? 'CENTRAL';
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isReadonlyChannel =
        _activeTab == 'CONVERSAS' &&
        (_selectedChannel == 'COALIZÃO' || _selectedChannel == 'SETOR');

    final formattedMessages =
        _messagesList.map((m) {
          final senderName =
              m['sender_account'] ?? m['sender_name'] ?? 'SISTEMA';

          final opData = widget.profileData?['operator'] ?? {};
          final myAccount = opData['name'] ?? '';

          final isMe =
              senderName.toString().toUpperCase() ==
              myAccount.toString().toUpperCase();

          String rawDate = m['date_time'] ?? '';
          if (rawDate.length > 19) {
            rawDate = rawDate.substring(0, 19).replaceAll('T', ' ');
          }

          return {
            'timestamp': rawDate,
            'sender': senderName,
            'isMe': isMe,
            'text': m['text'] ?? '',
          };
        }).toList();

    final readonlyTitle = '${_getSelectedFactionName()} - INFORMA';

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          const SizedBox(height: 8),
          _buildLocationBar(),
          const SizedBox(height: 8),

          // Abas superiores (CONVERSAS / MENSAGENS)
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 140,
              child: Row(
                children: [
                  Expanded(child: _buildTopTab('CONVERSAS')),
                  const SizedBox(width: 2),
                  Expanded(child: _buildTopTab('MENSAGENS')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Layout Responsivo: verifica se a tela é estreita (Mobile < 600px) ou ampla (Desktop)
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool isMobile = constraints.maxWidth < 600;

                Widget chatWidget =
                    isReadonlyChannel
                        ? (_isLoadingMessages
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: _greenAccent,
                                ),
                              )
                            : ReadonlyChatView(
                                channelName: readonlyTitle,
                                messages: formattedMessages,
                              ))
                        : _buildInteractiveChatArea();

                if (isMobile) {
                  // MODO MOBILE: Seletores lado a lado no topo com altura ajustada para 100 e Chat embaixo
                  return Column(
                    children: [
                      SizedBox(
                        height:
                            100, // Altura exata para acomodar as 4 linhas com rolagem
                        child:
                            _activeTab == 'CONVERSAS'
                                ? ChannelLeftPanel(
                                    channelsList: _channelsList,
                                    isLoading: _isLoadingChannels,
                                    error: _channelsError,
                                    selectedChannel: _selectedChannel,
                                    onChannelSelected: (canal) {
                                      setState(
                                        () => _selectedChannel = canal,
                                      );
                                    },
                                    factionsList: _factionsList,
                                    isLoadingFactions: _isLoadingFactions,
                                    selectedFactionUid: _selectedFactionUid,
                                    onFactionSelected: (factionUid) {
                                      setState(() {
                                        _selectedFactionUid = factionUid;
                                      });
                                      _fetchMessages(1, factionUid);
                                    },
                                    isMobileLayout: true,
                                  )
                                : _buildDirectMessagesLeftPanel(),
                      ),
                      const SizedBox(height: 8),
                      Expanded(child: chatWidget),
                    ],
                  );
                } else {
                  // MODO DESKTOP: Painel na esquerda, Chat na direita
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 160,
                        child:
                            _activeTab == 'CONVERSAS'
                                ? ChannelLeftPanel(
                                    channelsList: _channelsList,
                                    isLoading: _isLoadingChannels,
                                    error: _channelsError,
                                    selectedChannel: _selectedChannel,
                                    onChannelSelected: (canal) {
                                      setState(
                                        () => _selectedChannel = canal,
                                      );
                                    },
                                    factionsList: _factionsList,
                                    isLoadingFactions: _isLoadingFactions,
                                    selectedFactionUid: _selectedFactionUid,
                                    onFactionSelected: (factionUid) {
                                      setState(() {
                                        _selectedFactionUid = factionUid;
                                      });
                                      _fetchMessages(1, factionUid);
                                    },
                                    isMobileLayout: false,
                                  )
                                : _buildDirectMessagesLeftPanel(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: chatWidget),
                    ],
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 8),

          if (!isReadonlyChannel) _buildMessageInputField(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final op = widget.profileData?['operator'] ?? {};
    final String? avatarUrl = op['avatar_url'];
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final String fullAvatarUrl =
        (avatarUrl != null && avatarUrl.isNotEmpty)
            ? (avatarUrl.startsWith('http')
                ? '$avatarUrl?t=$timestamp'
                : '${widget.apiBaseUrl}$avatarUrl?t=$timestamp')
            : '';

    return Row(
      children: [
        Container(
          width: 45,
          height: 45,
          clipBehavior: Clip.antiAlias,
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
                    errorBuilder:
                        (_, __, ___) => const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 26,
                        ),
                  )
                  : const Icon(Icons.person, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'OPERADOR: ${op['name'] ?? 'N/A'}',
                style: GoogleFonts.shareTechMono(
                  color: _cyanColor,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'CORPORAÇÃO: ${op['corporation'] ?? 'N/A'}',
                style: GoogleFonts.shareTechMono(
                  color: _cyanColor,
                  fontSize: 13,
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
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationBar() {
    final op = widget.profileData?['operator'] ?? {};
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: _cyanColor.withValues(alpha: 0.4)),
      ),
      child: Text(
        'LOCALIZAÇÃO: ${op['location'] ?? 'DESCONHECIDA'}',
        style: GoogleFonts.shareTechMono(
          color: Colors.white,
          fontSize: 12,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildTopTab(String title) {
    final isSelected = _activeTab == title;
    return InkWell(
      onTap: () => setState(() => _activeTab = title),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? _greenAccent : _cyanColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(4),
          ),
        ),
        child: Text(
          title,
          style: GoogleFonts.shareTechMono(
            color: Colors.black,
            fontSize: 8,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildDirectMessagesLeftPanel() {
    final contatos = [
      {'name': 'BUSTER', 'online': true},
      {'name': 'DOOM', 'online': false},
    ];
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _panelBg,
        border: Border.all(color: _greenAccent, width: 1.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CONTATOS:',
            style: GoogleFonts.shareTechMono(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          ...contatos.map(
            (c) => Text(
              c['name'] as String,
              style: GoogleFonts.shareTechMono(
                color: Colors.white,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveChatArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _panelBg,
        border: Border.all(color: _cyanColor, width: 1.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _activeTab == 'CONVERSAS'
                ? '$_selectedChannel:'
                : '$_selectedContact:',
            style: GoogleFonts.shareTechMono(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: 0,
              itemBuilder: (context, index) {
                return Container();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInputField() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _panelBg,
        border: Border.all(color: _cyanColor, width: 1.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: GoogleFonts.shareTechMono(
                color: Colors.white,
                fontSize: 13,
              ),
              decoration: const InputDecoration(
                hintText: 'Digite sua mensagem...',
                border: InputBorder.none,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (_messageController.text.trim().isNotEmpty) {
                _messageController.clear();
              }
            },
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }

  String _formatCredits(dynamic value) {
    if (value == null) return '0';
    int parsed =
        value is num ? value.toInt() : int.tryParse(value.toString()) ?? 0;
    return parsed.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
  }
}