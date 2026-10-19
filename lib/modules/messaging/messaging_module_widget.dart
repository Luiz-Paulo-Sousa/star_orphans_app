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

  // Controle de abas principais
  String _activeTab = 'CONVERSAS';

  // Canais vindos dinamicamente do banco de dados (message_channels)
  List<dynamic> _channelsList = [];
  bool _isLoadingChannels = false;
  String _selectedChannel = 'COALIZÃO';

  // Sub-canais dinâmicos de acordo com o canal selecionado
  List<dynamic> _subchannelsList = [];
  bool _isLoadingSubchannels = false;
  int? _selectedSubchannelUid;
  String _dynamicSubchannelsLabel = 'SUB-CANAIS:';

  // Estado para o setor atual
  String _currentSectorName = 'AGARTHA';
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
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  // Busca a lista de canais cadastrados na tabela 'message_channels'
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

  Future<void> _fetchPilotSector() async {
    final profile = widget.profileData ?? {};
    final operatorData = profile['operator'] ?? {};
    final pilotUid =
        operatorData['account_id'] ?? operatorData['uid'] ?? 536870915;

    try {
      final response = await http.get(
        Uri.parse('${widget.apiBaseUrl}/api/channels/pilot-sector/$pilotUid'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _currentSectorName = data['sectorName'] ?? 'AGARTHA';
          _currentSectorUid = data['sectorUid'] ?? 2;
        });
      }
    } catch (e) {
      print('Erro ao buscar setor do piloto: $e');
    }
  }

  // Consulta o banco de dados dinamicamente com base no canal selecionado
  Future<void> _fetchSubchannelsForCurrentChannel() async {
    setState(() {
      _isLoadingSubchannels = true;
      _subchannelsList = [];
      _selectedSubchannelUid = null;
      _dynamicSubchannelsLabel = 'SUB-CANAIS:';
    });

    final channelUpper = _selectedChannel.toUpperCase();
    final profile = widget.profileData ?? {};
    final operatorData = profile['operator'] ?? {};
    final pilotUid =
        operatorData['account_id'] ?? operatorData['uid'] ?? 536870915;

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
          setState(() {
            _dynamicSubchannelsLabel = data['channel_label'] ?? 'SETOR:';
            _subchannelsList = list;
            if (list.isNotEmpty) {
              _selectedSubchannelUid = list[0]['pilot_uid'];
            }
          });
          int sectorSubchannelId = data['channel_uid'] ?? _currentSectorUid;
          _fetchMessages(2, sectorSubchannelId);
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
          setState(() {
            _dynamicSubchannelsLabel = data['channel_label'] ?? 'CORPORAÇÃO:';
            _subchannelsList = list;
            if (list.isNotEmpty) {
              _selectedSubchannelUid = list[0]['pilot_uid'];
            }
          });
          int corpSubchannelId = data['channel_uid'] ?? 1;
          if (_selectedSubchannelUid != null) {
            _fetchMessages(3, _selectedSubchannelUid!);
          } else {
            _fetchMessages(3, corpSubchannelId);
          }
        }
      } else if (channelUpper == 'EQUIPE') {
        final response = await http.get(
          Uri.parse('${widget.apiBaseUrl}/api/channels/members/team/$pilotUid'),
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final list = data['pilots'] ?? [];
          setState(() {
            _dynamicSubchannelsLabel = data['channel_label'] ?? 'EQUIPE:';
            _subchannelsList = list;
            if (list.isNotEmpty) {
              _selectedSubchannelUid = list[0]['pilot_uid'] ?? list[0]['uid'];
            }
          });
          int channelUid = data['channel_uid'] ?? 4;
          int subUid = _selectedSubchannelUid ?? 1;
          _fetchMessages(channelUid, subUid);
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
          setState(() {
            _dynamicSubchannelsLabel = data['channel_label'] ?? 'ESQUADRILHA:';
            _subchannelsList = list;
            if (list.isNotEmpty) {
              _selectedSubchannelUid = list[0]['pilot_uid'] ?? list[0]['uid'];
            }
          });
          int channelUid = data['channel_uid'] ?? 5;
          int subUid = _selectedSubchannelUid ?? 1;
          _fetchMessages(channelUid, subUid);
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
          int channelUid = data['channel_uid'] ?? 6;
          int subUid = _selectedSubchannelUid ?? 1;
          _fetchMessages(channelUid, subUid);
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
          int channelUid = data['channel_uid'] ?? 7;
          int subUid = _selectedSubchannelUid ?? 1;
          _fetchMessages(channelUid, subUid);
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

    final profile = widget.profileData ?? {};
    final operatorData = profile['operator'] ?? {};
    final accountUid =
        operatorData['account_id'] ?? operatorData['uid'] ?? 536870915;

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

    final channelUpper = _selectedChannel.toUpperCase();
    if (channelUpper == 'COALIZÃO') return;

    setState(() {
      _isSendingMessage = true;
    });

    int channelUid = 2;
    String channelType = 'sector';
    int targetSubchannel = _currentSectorUid;

    if (channelUpper == 'SETOR') {
      channelUid = 2;
      channelType = 'sector';
      targetSubchannel = _currentSectorUid;
    } else if (channelUpper == 'CORPORAÇÃO') {
      channelUid = 3;
      channelType = 'corporation';
      targetSubchannel = _selectedSubchannelUid ?? 1;
    } else if (channelUpper == 'EQUIPE') {
      channelUid = 4;
      channelType = 'team';
      targetSubchannel = 1;
    } else if (channelUpper == 'ESQUADRILHA') {
      channelUid = 5;
      channelType = 'squadron';
      targetSubchannel = 1;
    } else if (channelUpper == 'CONTATOS') {
      channelUid = 6;
      channelType = 'contact';
      targetSubchannel = _selectedSubchannelUid ?? 1;
    } else if (channelUpper == 'SUPORTE') {
      channelUid = 7;
      channelType = 'support';
      targetSubchannel = 1;
    }

    final opData = widget.profileData?['operator'] ?? {};
    final senderId = opData['account_id'] ?? opData['uid'] ?? 536870915;

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

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isReadonlyChannel =
        _activeTab == 'CONVERSAS' &&
        _selectedChannel.toUpperCase() == 'COALIZÃO';

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
                        : _buildInteractiveChatArea(formattedMessages);

                Widget leftPanelsWidget = _buildLeftPanelsContainer(isMobile);

                if (isMobile) {
                  return Column(
                    children: [
                      SizedBox(height: 100, child: leftPanelsWidget),
                      const SizedBox(height: 8),
                      Expanded(child: chatWidget),
                    ],
                  );
                } else {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: 260, child: leftPanelsWidget),
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
            Text(
              channelName,
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

  Widget _buildSubchannelsPanelContent() {
    final channelUpper = _selectedChannel.toUpperCase();
    final bool isSectorChannel = channelUpper == 'SETOR';

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
                    channelUpper == 'CORPORAÇÃO'
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
                              isSectorChannel ? false : isSelected;

                          int channelId = 1;
                          if (channelUpper == 'SETOR') channelId = 2;
                          if (channelUpper == 'CORPORAÇÃO') channelId = 3;
                          if (channelUpper == 'EQUIPE') channelId = 4;
                          if (channelUpper == 'ESQUADRILHA') channelId = 5;
                          if (channelUpper == 'CONTATOS') channelId = 6;
                          if (channelUpper == 'SUPORTE') channelId = 7;

                          return InkWell(
                            onTap: () {
                              setState(() {
                                _selectedSubchannelUid = itemId;
                              });
                              _fetchMessages(channelId, itemId);
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
            _activeTab == 'CONVERSAS' ? '$_selectedChannel:' : 'CONTATO:',
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
                          fontSize: 11,
                        ),
                      ),
                    )
                    : ListView.builder(
                      controller: _scrollController,
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '[${msg['timestamp']}] ',
                                    style: GoogleFonts.shareTechMono(
                                      color: Colors.white38,
                                      fontSize: 10,
                                    ),
                                  ),
                                  Text(
                                    '${msg['sender']}:',
                                    style: GoogleFonts.shareTechMono(
                                      color:
                                          msg['isMe']
                                              ? _greenAccent
                                              : _cyanColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                msg['text'],
                                style: GoogleFonts.shareTechMono(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        );
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
              decoration: InputDecoration(
                hintText: 'Transmitir mensagem para o canal...',
                hintStyle: GoogleFonts.shareTechMono(
                  color: Colors.white38,
                  fontSize: 13,
                ),
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          _isSendingMessage
              ? const Padding(
                padding: EdgeInsets.all(8.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: _cyanColor,
                    strokeWidth: 2,
                  ),
                ),
              )
              : IconButton(
                icon: const Icon(Icons.send, color: _cyanColor, size: 20),
                onPressed: _sendMessage,
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
