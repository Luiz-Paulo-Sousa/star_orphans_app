import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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

  // Largura definida para alinhar o painel de contatos e abas no modo mobile
  static const double _leftPanelWidth = 200.0;

  // Controle de abas principais: 'CONVERSAS' ou 'MENSAGENS'
  String _activeTab = 'CONVERSAS';

  // Canais vindos dinamicamente do banco de dados (message_channels)
  List<dynamic> _channelsList = [];
  bool _isLoadingChannels = false;
  String _selectedChannel = 'COALIZÃO';

  // Sub-canais dinâmicos de acordo com o canal selecionado
  List<dynamic> _subchannelsList = [];
  bool _isLoadingSubchannels = false;
  int? _selectedSubchannelUid;
  int? _groupChannelUid;
  String _dynamicSubchannelsLabel = 'SUB-CANAIS:';

  // Lista específica de Contatos para a aba MENSAGENS
  List<dynamic> _contactsList = [];
  int? _selectedContactUid;

  // Estado para o setor atual
  int _currentSectorUid = 2;

  // Estados para mensagens dinâmicas
  List<dynamic> _messagesList = [];
  bool _isLoadingMessages = false;
  bool _isSendingMessage = false;

  // Controller para o campo de envio de texto
  final TextEditingController _messageController = TextEditingController();

  // Controller de scroll para manter o chat nas mensagens mais recentes
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchPilotSector();
    _fetchMessageChannels();
    _fetchContactsList();
  }

  int _getPilotUid() {
    final profile = widget.profileData ?? {};
    final operatorData = profile['operator'] ?? {};

    final dynamic rawUid =
        operatorData['operator_uid'] ??
        operatorData['pilot_uid'] ??
        operatorData['account_id'] ??
        operatorData['uid'] ??
        profile['account_id'] ??
        profile['uid'];

    if (rawUid != null) {
      if (rawUid is int) return rawUid;
      return int.tryParse(rawUid.toString()) ?? 0;
    }
    return 0;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  bool _isBroadcastChannel(String channelName) {
    final upper = channelName.toUpperCase();
    return upper == 'SETOR' ||
        upper == 'CORPORAÇÃO' ||
        upper == 'EQUIPE' ||
        upper == 'ESQUADRILHA';
  }

  Future<void> _fetchMessageChannels() async {
    setState(() {
      _isLoadingChannels = true;
    });

    try {
      final response = await http.get(
        Uri.parse('${widget.apiBaseUrl}/api/message-channels'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data is List ? data : [];

        setState(() {
          _channelsList = list;
          if (list.isNotEmpty && _selectedChannel.isEmpty) {
            _selectedChannel = list[0]['description'] ?? 'COALIZÃO';
          }
        });
      }
    } catch (e) {
      print('Erro ao buscar canais de mensagens: $e');
      setState(() {
        _channelsList = [
          {'uid': 1, 'description': 'COALIZÃO'},
          {'uid': 2, 'description': 'SETOR'},
          {'uid': 3, 'description': 'CORPORAÇÃO'},
          {'uid': 4, 'description': 'EQUIPE'},
          {'uid': 5, 'description': 'ESQUADRILHA'},
          {'uid': 6, 'description': 'CONTATOS'},
          {'uid': 7, 'description': 'SUPORTE'},
        ];
      });
    } finally {
      setState(() {
        _isLoadingChannels = false;
      });
      _fetchSubchannelsForCurrentChannel();
    }
  }

  Future<void> _fetchContactsList() async {
    final pilotUid = _getPilotUid();
    try {
      final response = await http.get(
        Uri.parse(
          '${widget.apiBaseUrl}/api/channels/members/contact/$pilotUid',
        ),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data['pilots'] ?? [];
        setState(() {
          _contactsList = list;
          if (list.isNotEmpty && _selectedContactUid == null) {
            _selectedContactUid = list[0]['pilot_uid'] ?? list[0]['uid'];
            if (_activeTab == 'MENSAGENS') {
              _fetchMessages(6, _selectedContactUid!);
            }
          }
        });
      }
    } catch (e) {
      print('Erro ao buscar contatos: $e');
    }
  }

  Future<void> _fetchPilotSector() async {
    final pilotUid = _getPilotUid();
    if (pilotUid == 0) return;

    try {
      final response = await http.get(
        Uri.parse('${widget.apiBaseUrl}/api/channels/pilot-sector/$pilotUid'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _currentSectorUid = data['sectorUid'] ?? 2;
        });
      }
    } catch (e) {
      print('Erro ao buscar setor do piloto: $e');
    }
  }

  Future<void> _fetchSubchannelsForCurrentChannel() async {
    setState(() {
      _isLoadingSubchannels = true;
      _subchannelsList = [];
      _selectedSubchannelUid = null;
      _groupChannelUid = null;
      _dynamicSubchannelsLabel = 'SUB-CANAIS:';
      _messagesList = [];
    });

    final channelUpper = _selectedChannel.toUpperCase();
    final pilotUid = _getPilotUid();

    try {
      if (channelUpper == 'COALIZÃO') {
        _dynamicSubchannelsLabel = 'COALIZÕES:';
        final response = await http.get(
          Uri.parse('${widget.apiBaseUrl}/api/factions'),
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final list = data is List ? data : [];
          setState(() {
            _subchannelsList = list;
            if (list.isNotEmpty) {
              _selectedSubchannelUid = list[0]['faction_uid'];
              _fetchMessages(1, _selectedSubchannelUid!);
            }
          });
        }
      } else if (channelUpper == 'SETOR') {
        final response = await http.get(
          Uri.parse(
            '${widget.apiBaseUrl}/api/channels/members/sector/$pilotUid',
          ),
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final list = data['pilots'] ?? [];
          final int sectorUid = data['channel_uid'] ?? _currentSectorUid;
          setState(() {
            _dynamicSubchannelsLabel =
                data['channel_label'] ?? 'SETOR: AGARTHA';
            _subchannelsList = list;
            _groupChannelUid = sectorUid;
          });
          _fetchMessages(2, sectorUid);
        }
      } else if (channelUpper == 'CORPORAÇÃO') {
        final response = await http.get(
          Uri.parse(
            '${widget.apiBaseUrl}/api/channels/members/corporation/$pilotUid',
          ),
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final list = data['pilots'] ?? [];
          final int corpUid = data['channel_uid'] ?? 1;
          setState(() {
            _dynamicSubchannelsLabel = data['channel_label'] ?? 'CORPORAÇÃO:';
            _subchannelsList = list;
            _groupChannelUid = corpUid;
          });
          _fetchMessages(3, corpUid);
        }
      } else if (channelUpper == 'EQUIPE') {
        final response = await http.get(
          Uri.parse('${widget.apiBaseUrl}/api/channels/members/team/$pilotUid'),
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final list = data['pilots'] ?? [];
          final int teamUid = data['channel_uid'] ?? 1;
          setState(() {
            _dynamicSubchannelsLabel = data['channel_label'] ?? 'EQUIPE:';
            _subchannelsList = list;
            _groupChannelUid = teamUid;
          });
          _fetchMessages(4, teamUid);
        }
      } else if (channelUpper == 'ESQUADRILHA') {
        final response = await http.get(
          Uri.parse(
            '${widget.apiBaseUrl}/api/channels/members/squad/$pilotUid',
          ),
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final list = data['pilots'] ?? [];
          final int squadUid = data['channel_uid'] ?? 1;
          setState(() {
            _dynamicSubchannelsLabel = data['channel_label'] ?? 'ESQUADRILHA:';
            _subchannelsList = list;
            _groupChannelUid = squadUid;
          });
          _fetchMessages(5, squadUid);
        }
      } else if (channelUpper == 'CONTATOS') {
        final response = await http.get(
          Uri.parse(
            '${widget.apiBaseUrl}/api/channels/members/contact/$pilotUid',
          ),
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final list = data['pilots'] ?? [];
          setState(() {
            _dynamicSubchannelsLabel = data['channel_label'] ?? 'CONTATOS:';
            _subchannelsList = list;
            if (list.isNotEmpty) {
              _selectedSubchannelUid = list[0]['pilot_uid'] ?? list[0]['uid'];
            }
          });
          if (_selectedSubchannelUid != null) {
            _fetchMessages(6, _selectedSubchannelUid!);
          }
        }
      } else if (channelUpper == 'SUPORTE') {
        final response = await http.get(
          Uri.parse(
            '${widget.apiBaseUrl}/api/channels/members/support/$pilotUid',
          ),
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final list = data['pilots'] ?? [];
          setState(() {
            _dynamicSubchannelsLabel = data['channel_label'] ?? 'SUPORTE:';
            _subchannelsList = list;
            if (list.isNotEmpty) {
              _selectedSubchannelUid = list[0]['pilot_uid'] ?? list[0]['uid'];
            }
          });
          if (_selectedSubchannelUid != null) {
            _fetchMessages(7, _selectedSubchannelUid!);
          }
        }
      } else {
        setState(() {
          _dynamicSubchannelsLabel = '$channelUpper:';
          _subchannelsList = [];
          _messagesList = [];
        });
      }
    } catch (e) {
      print('Erro ao carregar sub-canais para $_selectedChannel: $e');
    } finally {
      setState(() {
        _isLoadingSubchannels = false;
      });
    }
  }

  Future<void> _fetchMessages(int channelUid, int subchannelUid) async {
    setState(() {
      _isLoadingMessages = true;
    });

    final accountUid = _getPilotUid();

    // Na aba CONVERSAS buscamos mensagens do tipo 0 (chat em tempo real).
    // Na aba MENSAGENS buscamos mensagens do tipo 1 (e-mails/mensagens longas).
    final int messageType = _activeTab == 'CONVERSAS' ? 0 : 1;

    try {
      final response = await http.get(
        Uri.parse(
          '${widget.apiBaseUrl}/api/messages/$channelUid/$subchannelUid?destinationUid=$accountUid&type=$messageType',
        ),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _messagesList = data is List ? data : [];
        });
        _scrollToBottom();
      } else {
        setState(() {
          _messagesList = [];
        });
      }
    } catch (e) {
      print('Erro ao carregar mensagens: $e');
      setState(() {
        _messagesList = [];
      });
    } finally {
      setState(() {
        _isLoadingMessages = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSendingMessage) return;

    setState(() {
      _isSendingMessage = true;
    });

    int channelUid = 6;
    String channelType = 'contact';
    int targetSubchannel = _selectedContactUid ?? 1;

    if (_activeTab == 'CONVERSAS') {
      final channelUpper = _selectedChannel.toUpperCase();
      if (channelUpper == 'COALIZÃO') {
        setState(() => _isSendingMessage = false);
        return;
      }
      if (channelUpper == 'SETOR') {
        channelUid = 2;
        channelType = 'sector';
        targetSubchannel = _groupChannelUid ?? _currentSectorUid;
      } else if (channelUpper == 'CORPORAÇÃO') {
        channelUid = 3;
        channelType = 'corporation';
        targetSubchannel = _groupChannelUid ?? 1;
      } else if (channelUpper == 'EQUIPE') {
        channelUid = 4;
        channelType = 'team';
        targetSubchannel = _groupChannelUid ?? 1;
      } else if (channelUpper == 'ESQUADRILHA') {
        channelUid = 5;
        channelType = 'squad';
        targetSubchannel = _groupChannelUid ?? 1;
      } else if (channelUpper == 'CONTATOS') {
        channelUid = 6;
        channelType = 'contact';
        targetSubchannel = _selectedSubchannelUid ?? 1;
      } else if (channelUpper == 'SUPORTE') {
        channelUid = 7;
        channelType = 'support';
        targetSubchannel = _selectedSubchannelUid ?? 1;
      }
    }

    final senderId = _getPilotUid();

    try {
      final response = await http.post(
        Uri.parse('${widget.apiBaseUrl}/api/messages/broadcast'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'channel_type': channelType,
          'channel_id': channelUid,
          'subchannel_id': targetSubchannel,
          'sender_id': senderId,
          'content': text,
        }),
      );

      if (response.statusCode == 201) {
        _messageController.clear();
        _fetchMessages(channelUid, targetSubchannel);
      }
    } catch (e) {
      print('Exceção ao enviar mensagem: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSendingMessage = false;
        });
      }
    }
  }

  String _getSelectedSubchannelName() {
    if (_subchannelsList.isEmpty || _selectedSubchannelUid == null) {
      return 'CENTRAL';
    }
    try {
      final sub = _subchannelsList.firstWhere(
        (s) =>
            (s['faction_uid'] ??
                s['pilot_uid'] ??
                s['uid'] ??
                s['member_uid']) ==
            _selectedSubchannelUid,
        orElse: () => _subchannelsList[0],
      );
      return (sub['pilot'] ??
              sub['name'] ??
              sub['pilot_name'] ??
              sub['username'] ??
              'CENTRAL')
          .toString();
    } catch (_) {
      return 'CENTRAL';
    }
  }

  String _formatCredits(dynamic credits) {
    if (credits == null) return '0';
    final n = int.tryParse(credits.toString()) ?? 0;
    return n.toString();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _switchTab(String tabName) {
    if (_activeTab == tabName) return;
    setState(() {
      _activeTab = tabName;
    });

    if (tabName == 'MENSAGENS') {
      if (_selectedContactUid != null) {
        _fetchMessages(6, _selectedContactUid!);
      }
    } else {
      _fetchSubchannelsForCurrentChannel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isReadonlyChannel =
        _activeTab == 'CONVERSAS' &&
        _selectedChannel.toUpperCase() == 'COALIZÃO';

    final bool isBroadcast = _isBroadcastChannel(_selectedChannel);
    final bool canShowInput =
        _activeTab != 'CONVERSAS' || isBroadcast || _subchannelsList.isNotEmpty;

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

    final readonlyTitle = '${_getSelectedSubchannelName()} INFORMA';

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          const SizedBox(height: 8),
          _buildLocationBar(),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: _leftPanelWidth,
              child: Row(
                children: [
                  Expanded(child: _buildTopTab('CONVERSAS')),
                  const SizedBox(width: 4),
                  Expanded(child: _buildTopTab('MENSAGENS')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool isMobile = constraints.maxWidth < 600;

                // Na aba MENSAGENS usamos a tela dividida 50%/50%
                // Na aba CONVERSAS usamos a lista inteira + barra simples no rodapé
                Widget mainChatContent =
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
                        : (_activeTab == 'MENSAGENS'
                            ? _buildSplitChatArea(
                              formattedMessages,
                              canShowInput,
                            )
                            : _buildInteractiveChatArea(formattedMessages));

                Widget leftPanelsWidget = _buildLeftPanelsContainer(isMobile);

                if (isMobile) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width:
                            _activeTab != 'CONVERSAS'
                                ? _leftPanelWidth
                                : double.infinity,
                        height: 120,
                        child: leftPanelsWidget,
                      ),
                      const SizedBox(height: 8),
                      Expanded(child: mainChatContent),
                    ],
                  );
                } else {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: _leftPanelWidth, child: leftPanelsWidget),
                      const SizedBox(width: 12),
                      Expanded(child: mainChatContent),
                    ],
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 8),
          // Barra de digitação simples para a aba CONVERSAS
          if (_activeTab == 'CONVERSAS' && !isReadonlyChannel && canShowInput)
            _buildMessageInputField(),
        ],
      ),
    );
  }

  Widget _buildLeftPanelsContainer(bool isMobile) {
    if (_activeTab != 'CONVERSAS') {
      return _buildDirectMessagesLeftPanel();
    }

    final channelsPanel = Container(
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
            'CANAIS:',
            style: GoogleFonts.shareTechMono(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child:
                _isLoadingChannels
                    ? const Center(
                      child: CircularProgressIndicator(
                        color: _greenAccent,
                        strokeWidth: 2,
                      ),
                    )
                    : ListView(
                      children:
                          _channelsList.map((ch) {
                            final name = (ch['description'] ?? '').toString();
                            return _buildChannelItem(name);
                          }).toList(),
                    ),
          ),
        ],
      ),
    );

    final subchannelsPanel = Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _panelBg,
        border: Border.all(color: _greenAccent, width: 1.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: _buildSubchannelsPanelContent(),
    );

    if (isMobile) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: channelsPanel),
          const SizedBox(width: 8),
          Expanded(child: subchannelsPanel),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 1, child: channelsPanel),
          const SizedBox(height: 8),
          Expanded(flex: 1, child: subchannelsPanel),
        ],
      );
    }
  }

  Widget _buildDirectMessagesLeftPanel() {
    return Container(
      width: _leftPanelWidth,
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
          Expanded(
            child:
                _contactsList.isEmpty
                    ? Text(
                      'Nenhum contato',
                      style: GoogleFonts.shareTechMono(
                        color: Colors.white54,
                        fontSize: 10,
                      ),
                    )
                    : ListView(
                      children:
                          _contactsList.map((contact) {
                            final contactId =
                                contact['pilot_uid'] ?? contact['uid'];
                            final contactName =
                                (contact['pilot'] ??
                                        contact['name'] ??
                                        contact['username'] ??
                                        'DESCONHECIDO')
                                    .toString()
                                    .toUpperCase();

                            final isSelected = contactId == _selectedContactUid;

                            return InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedContactUid = contactId;
                                });
                                _fetchMessages(6, contactId);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 3.0,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color:
                                            isSelected
                                                ? _greenAccent
                                                : Colors.transparent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        contactName,
                                        style: GoogleFonts.shareTechMono(
                                          color:
                                              isSelected
                                                  ? _greenAccent
                                                  : Colors.white,
                                          fontSize: 11,
                                          fontWeight:
                                              isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelItem(String channelName) {
    final isSelected =
        _selectedChannel.toUpperCase() == channelName.toUpperCase();
    return InkWell(
      onTap: () {
        setState(() {
          _selectedChannel = channelName;
        });
        _fetchSubchannelsForCurrentChannel();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3.0),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: isSelected ? _greenAccent : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                channelName,
                style: GoogleFonts.shareTechMono(
                  color: isSelected ? _greenAccent : Colors.white,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubchannelsPanelContent() {
    final bool isBroadcast = _isBroadcastChannel(_selectedChannel);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _dynamicSubchannelsLabel.toUpperCase(),
          style: GoogleFonts.shareTechMono(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Expanded(
          child:
              _isLoadingSubchannels
                  ? const Center(
                    child: CircularProgressIndicator(
                      color: _greenAccent,
                      strokeWidth: 2,
                    ),
                  )
                  : _subchannelsList.isEmpty
                  ? Text(
                    _selectedChannel.toUpperCase() == 'CORPORAÇÃO'
                        ? 'Nenhum membro'
                        : 'Nenhum registro',
                    style: GoogleFonts.shareTechMono(
                      color: Colors.white54,
                      fontSize: 10,
                    ),
                  )
                  : ListView(
                    children:
                        _subchannelsList.map((item) {
                          final itemId =
                              item['faction_uid'] ??
                              item['pilot_uid'] ??
                              item['uid'] ??
                              item['member_uid'];

                          final itemName =
                              (item['pilot'] ??
                                      item['name'] ??
                                      item['pilot_name'] ??
                                      item['username'] ??
                                      'DESCONHECIDO')
                                  .toString()
                                  .toUpperCase();

                          final isSelected = itemId == _selectedSubchannelUid;
                          final bool highlightSelected =
                              isBroadcast ? false : isSelected;

                          return InkWell(
                            onTap: () {
                              if (!isBroadcast) {
                                setState(() {
                                  _selectedSubchannelUid = itemId;
                                });
                                int channelId = 6;
                                if (_selectedChannel.toUpperCase() ==
                                    'SUPORTE') {
                                  channelId = 7;
                                } else if (_selectedChannel.toUpperCase() ==
                                    'COALIZÃO') {
                                  channelId = 1;
                                }
                                _fetchMessages(channelId, itemId);
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 3.0,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color:
                                          highlightSelected
                                              ? _greenAccent
                                              : Colors.transparent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      itemName,
                                      style: GoogleFonts.shareTechMono(
                                        color:
                                            highlightSelected
                                                ? _greenAccent
                                                : Colors.white,
                                        fontSize: 11,
                                        fontWeight:
                                            highlightSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                  ),
        ),
      ],
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
      onTap: () => _switchTab(title),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
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
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // Janela de Leitura que Ocupa a Altura Inteira na aba CONVERSAS
  Widget _buildInteractiveChatArea(List<Map<String, dynamic>> messages) {
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
            '$_selectedChannel:',
            style: GoogleFonts.shareTechMono(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child:
                _isLoadingMessages
                    ? const Center(
                      child: CircularProgressIndicator(color: _cyanColor),
                    )
                    : messages.isEmpty
                    ? Center(
                      child: Text(
                        _selectedChannel.toUpperCase() == 'CORPORAÇÃO'
                            ? 'NENHUM MEMBRO NA CORPORAÇÃO'
                            : 'NENHUMA TRANSMISSÃO REGISTRADA',
                        style: GoogleFonts.shareTechMono(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    )
                    : ListView.builder(
                      controller: _scrollController,
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final isMe = msg['isMe'] == true;
                        return Align(
                          alignment:
                              isMe
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(maxWidth: 280),
                            decoration: BoxDecoration(
                              color:
                                  isMe
                                      ? _cyanColor.withValues(alpha: 0.2)
                                      : Colors.grey.shade900,
                              border: Border.all(
                                color: isMe ? _cyanColor : Colors.white24,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      msg['sender'],
                                      style: GoogleFonts.shareTechMono(
                                        color: isMe ? _cyanColor : _greenAccent,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      msg['timestamp'],
                                      style: GoogleFonts.shareTechMono(
                                        color: Colors.white54,
                                        fontSize: 9,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  msg['text'],
                                  style: GoogleFonts.shareTechMono(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
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

  // Divisão em 50% Leitura e 50% Digitação na aba MENSAGENS
  Widget _buildSplitChatArea(
    List<Map<String, dynamic>> messages,
    bool canShowInput,
  ) {
    return Column(
      children: [
        Expanded(
          flex: 1,
          child: Container(
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
                  'CONTATO:',
                  style: GoogleFonts.shareTechMono(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child:
                      _isLoadingMessages
                          ? const Center(
                            child: CircularProgressIndicator(color: _cyanColor),
                          )
                          : messages.isEmpty
                          ? Center(
                            child: Text(
                              'NENHUMA TRANSMISSÃO REGISTRADA',
                              style: GoogleFonts.shareTechMono(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          )
                          : ListView.builder(
                            controller: _scrollController,
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final msg = messages[index];
                              final isMe = msg['isMe'] == true;
                              return Align(
                                alignment:
                                    isMe
                                        ? Alignment.centerRight
                                        : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  padding: const EdgeInsets.all(8),
                                  constraints: const BoxConstraints(
                                    maxWidth: 280,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        isMe
                                            ? _cyanColor.withValues(alpha: 0.2)
                                            : Colors.grey.shade900,
                                    border: Border.all(
                                      color: isMe ? _cyanColor : Colors.white24,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            msg['sender'],
                                            style: GoogleFonts.shareTechMono(
                                              color:
                                                  isMe
                                                      ? _cyanColor
                                                      : _greenAccent,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            msg['timestamp'],
                                            style: GoogleFonts.shareTechMono(
                                              color: Colors.white54,
                                              fontSize: 9,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        msg['text'],
                                        style: GoogleFonts.shareTechMono(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
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
        ),

        const SizedBox(height: 8),

        if (canShowInput)
          Expanded(
            flex: 1,
            child: Container(
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
                    'TEXTO:',
                    style: GoogleFonts.shareTechMono(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      maxLines: null,
                      expands: true,
                      keyboardType: TextInputType.multiline,
                      textAlignVertical: TextAlignVertical.top,
                      style: GoogleFonts.shareTechMono(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Digite sua mensagem...',
                        hintStyle: GoogleFonts.shareTechMono(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomRight,
                    child:
                        _isSendingMessage
                            ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: _cyanColor,
                                strokeWidth: 2,
                              ),
                            )
                            : ElevatedButton.icon(
                              onPressed: _sendMessage,
                              icon: const Icon(
                                Icons.send,
                                size: 16,
                                color: Colors.black,
                              ),
                              label: Text(
                                'Enviar',
                                style: GoogleFonts.shareTechMono(
                                  color: Colors.black,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey.shade300,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // Barra de digitação simples para a aba CONVERSAS
  Widget _buildMessageInputField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                fontSize: 12,
              ),
              decoration: InputDecoration(
                hintText: 'Transmitir mensagem para o canal...',
                hintStyle: GoogleFonts.shareTechMono(
                  color: Colors.white38,
                  fontSize: 12,
                ),
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          IconButton(
            icon:
                _isSendingMessage
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: _cyanColor,
                        strokeWidth: 2,
                      ),
                    )
                    : const Icon(Icons.send, color: _cyanColor, size: 20),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}
