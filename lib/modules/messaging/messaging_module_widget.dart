import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

import 'views/readonly_chat_view.dart';

class MessagingModuleWidget extends StatefulWidget {
  final Map<String, dynamic>? profileData;
  final String apiBaseUrl;
  final String initialTab;
  final VoidCallback? onMessagesRead;

  const MessagingModuleWidget({
    super.key,
    this.profileData,
    this.apiBaseUrl = 'http://26.239.180.177:8020',
    this.initialTab = 'CONVERSAS',
    this.onMessagesRead,
  });

  @override
  State<MessagingModuleWidget> createState() => _MessagingModuleWidgetState();
}

class _MessagingModuleWidgetState extends State<MessagingModuleWidget> {
  static const Color _cyanColor = Color(0xFF00D2FF);
  static const Color _greenAccent = Color(0xFF00FF66);
  static const Color _yellowAccent = Color(0xFFFFD700);
  static const Color _panelBg = Color(0xD912161F);

  static const double _leftPanelWidth = 200.0;

  String _activeTab = 'CONVERSAS';

  List<dynamic> _channelsList = [];
  bool _isLoadingChannels = false;
  String _selectedChannel = 'COALIZÃO';

  List<dynamic> _subchannelsList = [];
  bool _isLoadingSubchannels = false;
  int? _selectedSubchannelUid;
  int? _groupChannelUid;
  String _dynamicSubchannelsLabel = 'SUB-CANAIS:';

  List<dynamic> _contactsList = [];
  int? _selectedContactUid;

  int _currentSectorUid = 2;

  List<dynamic> _messagesList = [];
  bool _isLoadingMessages = false;
  bool _isSendingMessage = false;

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
    _fetchPilotSector();
    _fetchMessageChannels();
    _fetchContactsList();
  }

  @override
  void didUpdateWidget(covariant MessagingModuleWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != oldWidget.initialTab && widget.initialTab != _activeTab) {
      _switchTab(widget.initialTab);
    }
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
      debugPrint('Erro ao buscar canais de mensagens: $e');
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
          final bool isCurrentSelectedValid = list.any(
            (c) => (c['pilot_uid'] ?? c['uid']) == _selectedContactUid,
          );
          if (!isCurrentSelectedValid) {
            if (list.isNotEmpty) {
              _selectedContactUid = list[0]['pilot_uid'] ?? list[0]['uid'];
              if (_activeTab == 'MENSAGENS') {
                _fetchMessages(6, _selectedContactUid!);
              }
            } else {
              _selectedContactUid = null;
              if (_activeTab == 'MENSAGENS') {
                _messagesList = [];
              }
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Erro ao buscar contatos: $e');
    }
  }

  Future<void> _addContact(int contactUid) async {
    final pilotUid = _getPilotUid();
    if (pilotUid == 0) return;

    try {
      final response = await http.post(
        Uri.parse('${widget.apiBaseUrl}/api/contacts/add'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'pilot_uid': pilotUid, 'contact_uid': contactUid}),
      );

      if (response.statusCode == 201) {
        await _fetchContactsList();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contato adicionado com sucesso!')),
          );
        }
      } else {
        final err = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(err['error'] ?? 'Erro ao adicionar contato.'),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Erro ao adicionar contato: $e');
    }
  }

  Future<void> _removeContact(int contactUid) async {
    final pilotUid = _getPilotUid();
    if (pilotUid == 0) return;

    try {
      final response = await http.delete(
        Uri.parse(
          '${widget.apiBaseUrl}/api/contacts/remove/$pilotUid/$contactUid',
        ),
      );

      if (response.statusCode == 200) {
        await _fetchContactsList();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contato removido com sucesso!')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erro ao remover contato.')),
          );
        }
      }
    } catch (e) {
      debugPrint('Erro ao remover contato: $e');
    }
  }

  void _showPilotContextMenu(
    BuildContext context,
    Offset position,
    int pilotUid,
    String pilotName,
    bool isContactList,
  ) async {
    if (!isContactList && pilotUid == _getPilotUid()) return;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    final List<PopupMenuEntry<String>> menuItems = [];

    if (isContactList) {
      menuItems.add(
        PopupMenuItem<String>(
          value: 'remove',
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              const Icon(Icons.person_remove, color: _yellowAccent, size: 16),
              const SizedBox(width: 8),
              Text(
                'Remover dos Contatos',
                style: GoogleFonts.shareTechMono(
                  color: _yellowAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      final bool isAlreadyContact = _contactsList.any(
        (c) => (c['pilot_uid'] ?? c['uid']) == pilotUid,
      );
      if (!isAlreadyContact) {
        menuItems.add(
          PopupMenuItem<String>(
            value: 'add',
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Icon(Icons.person_add, color: _greenAccent, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Adicionar aos Contatos',
                  style: GoogleFonts.shareTechMono(
                    color: _greenAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    if (menuItems.isEmpty) return;

    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(20, 20),
        Offset.zero & overlay.size,
      ),
      color: const Color(0xFF12161F),
      elevation: 8,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: _cyanColor, width: 1.0),
        borderRadius: BorderRadius.circular(4),
      ),
      items: menuItems,
    );

    if (result == 'add') {
      _addContact(pilotUid);
    } else if (result == 'remove') {
      _removeContact(pilotUid);
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
      debugPrint('Erro ao buscar setor do piloto: $e');
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
      debugPrint('Erro ao carregar sub-canais para $_selectedChannel: $e');
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
        // Marca as mensagens exibidas como lidas automaticamente
        _markCurrentMessagesAsRead(channelUid, subchannelUid, accountUid, messageType);
      } else {
        setState(() {
          _messagesList = [];
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar mensagens: $e');
      setState(() {
        _messagesList = [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMessages = false;
        });
      }
    }
  }

  /// Marca mensagens recebidas como lidas na API e notifica a tela principal
  Future<void> _markCurrentMessagesAsRead(
    int channelUid,
    int subchannelUid,
    int accountUid,
    int messageType,
  ) async {
    if (accountUid == 0) return;

    // Verifica se há alguma mensagem recebida não lida na lista
    final hasUnread = _messagesList.any((m) {
      if (m is Map) {
        final isRead = m['is_read'];
        return isRead == 0 || isRead == '0' || isRead == false;
      }
      return false;
    });

    if (!hasUnread) return;

    try {
      final response = await http.put(
        Uri.parse(
          '${widget.apiBaseUrl}/api/messages/mark-read/$channelUid/$subchannelUid?destinationUid=$accountUid&type=$messageType',
        ),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            for (var m in _messagesList) {
              if (m is Map) {
                m['is_read'] = 1;
              }
            }
          });
        }
        // Notifica o componente pai para atualizar os ícones de notificação
        widget.onMessagesRead?.call();
      }
    } catch (e) {
      debugPrint('Erro ao marcar mensagens como lidas: $e');
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
      debugPrint('Exceção ao enviar mensagem: $e');
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

  void _switchTab(String tabName) {
    if (_activeTab == tabName) return;
    setState(() {
      _activeTab = tabName;
    });

    if (tabName == 'MENSAGENS') {
      if (_selectedContactUid != null) {
        _fetchMessages(6, _selectedContactUid!);
      } else if (_contactsList.isNotEmpty) {
        final firstContact = _contactsList[0];
        _selectedContactUid = firstContact['pilot_uid'] ?? firstContact['uid'];
        if (_selectedContactUid != null) {
          _fetchMessages(6, _selectedContactUid!);
        }
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

                            return _ContactListTile(
                              key: ValueKey('contact_tile_$contactId'),
                              contactUid: contactId,
                              contactName: contactName,
                              isSelected: isSelected,
                              onTap: () {
                                setState(() {
                                  _selectedContactUid = contactId;
                                });
                                _fetchMessages(6, contactId);
                              },
                              onRemoveContact: () {
                                _removeContact(contactId);
                              },
                              onContextMenu: (position) {
                                _showPilotContextMenu(
                                  context,
                                  position,
                                  contactId,
                                  contactName,
                                  true,
                                );
                              },
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

                          final String chUpper = _selectedChannel.toUpperCase();
                          final bool isTargetChannel =
                              chUpper == 'SETOR' ||
                              chUpper == 'CORPORAÇÃO' ||
                              chUpper == 'EQUIPE' ||
                              chUpper == 'ESQUADRILHA';

                          if (isTargetChannel && itemId != null) {
                            final int currentPilotUid = _getPilotUid();
                            final int pilotId =
                                itemId is int
                                    ? itemId
                                    : int.tryParse(itemId.toString()) ?? 0;
                            final bool isSelf = (pilotId == currentPilotUid);
                            final bool isAlreadyContact = _contactsList.any(
                              (c) => (c['pilot_uid'] ?? c['uid']) == pilotId,
                            );

                            return _PilotListTile(
                              key: ValueKey('pilot_tile_$pilotId'),
                              pilotUid: pilotId,
                              pilotName: itemName,
                              isSelected: highlightSelected,
                              isSelf: isSelf,
                              isAlreadyContact: isAlreadyContact,
                              canAddContact: !isSelf && !isAlreadyContact,
                              onContextMenu: (Offset position) {
                                _showPilotContextMenu(
                                  context,
                                  position,
                                  pilotId,
                                  itemName,
                                  false,
                                );
                              },
                              onAddContact: () {
                                _addContact(pilotId);
                              },
                            );
                          }

                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (!isBroadcast) {
                                setState(() {
                                  _selectedSubchannelUid = itemId;
                                });
                                int channelId = 6;
                                if (chUpper == 'SUPORTE') {
                                  channelId = 7;
                                } else if (chUpper == 'COALIZÃO') {
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

class _PilotListTile extends StatefulWidget {
  final int pilotUid;
  final String pilotName;
  final bool isSelected;
  final bool isSelf;
  final bool isAlreadyContact;
  final bool canAddContact;
  final void Function(Offset position) onContextMenu;
  final VoidCallback onAddContact;

  const _PilotListTile({
    super.key,
    required this.pilotUid,
    required this.pilotName,
    required this.isSelected,
    required this.isSelf,
    required this.isAlreadyContact,
    required this.canAddContact,
    required this.onContextMenu,
    required this.onAddContact,
  });

  @override
  State<_PilotListTile> createState() => _PilotListTileState();
}

class _PilotListTileState extends State<_PilotListTile> {
  bool _isHovered = false;
  bool _showMobileAction = false;

  @override
  Widget build(BuildContext context) {
    const Color greenAccent = Color(0xFF00FF66);
    final bool showAddButton =
        widget.canAddContact && (_isHovered || _showMobileAction);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_showMobileAction) {
            setState(() => _showMobileAction = false);
          }
        },
        onSecondaryTapUp: (details) {
          if (widget.canAddContact) {
            widget.onContextMenu(details.globalPosition);
          }
        },
        onLongPress: () {
          if (widget.canAddContact) {
            setState(() => _showMobileAction = !_showMobileAction);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 3.0, horizontal: 2.0),
          decoration: BoxDecoration(
            color:
                _isHovered
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: widget.isSelected ? greenAccent : Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.pilotName,
                        style: GoogleFonts.shareTechMono(
                          color:
                              widget.isSelected
                                  ? greenAccent
                                  : (widget.isSelf
                                      ? Colors.white70
                                      : Colors.white),
                          fontSize: 11,
                          fontWeight:
                              widget.isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.isSelf) ...[
                      const SizedBox(width: 4),
                      Text(
                        '(VOCÊ)',
                        style: GoogleFonts.shareTechMono(
                          color: Colors.white38,
                          fontSize: 9,
                        ),
                      ),
                    ] else if (widget.isAlreadyContact) ...[
                      const SizedBox(width: 4),
                      const Tooltip(
                        message: 'Já está nos seus contatos',
                        child: Icon(Icons.check, color: greenAccent, size: 11),
                      ),
                    ],
                  ],
                ),
              ),
              if (showAddButton) ...[
                const SizedBox(width: 4),
                Tooltip(
                  message: 'Adicionar aos Contatos',
                  child: InkWell(
                    onTap: () {
                      setState(() => _showMobileAction = false);
                      widget.onAddContact();
                    },
                    borderRadius: BorderRadius.circular(3),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: greenAccent.withValues(alpha: 0.18),
                        border: Border.all(color: greenAccent, width: 0.8),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.person_add_alt_1,
                            color: greenAccent,
                            size: 10,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '+ CONTATO',
                            style: GoogleFonts.shareTechMono(
                              color: greenAccent,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactListTile extends StatefulWidget {
  final int contactUid;
  final String contactName;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onRemoveContact;
  final void Function(Offset position)? onContextMenu;

  const _ContactListTile({
    super.key,
    required this.contactUid,
    required this.contactName,
    required this.isSelected,
    required this.onTap,
    required this.onRemoveContact,
    this.onContextMenu,
  });

  @override
  State<_ContactListTile> createState() => _ContactListTileState();
}

class _ContactListTileState extends State<_ContactListTile> {
  bool _isHovered = false;
  bool _showMobileAction = false;

  @override
  Widget build(BuildContext context) {
    const Color greenAccent = Color(0xFF00FF66);
    const Color yellowAccent = Color(0xFFFFD700);
    final bool showRemoveButton = _isHovered || _showMobileAction;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_showMobileAction) {
            setState(() => _showMobileAction = false);
          }
          widget.onTap();
        },
        onSecondaryTapUp: (details) {
          if (widget.onContextMenu != null) {
            widget.onContextMenu!(details.globalPosition);
          }
        },
        onLongPress: () {
          setState(() => _showMobileAction = !_showMobileAction);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 3.0, horizontal: 2.0),
          decoration: BoxDecoration(
            color:
                _isHovered
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: widget.isSelected ? greenAccent : Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.contactName,
                  style: GoogleFonts.shareTechMono(
                    color: widget.isSelected ? greenAccent : Colors.white,
                    fontSize: 11,
                    fontWeight:
                        widget.isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (showRemoveButton) ...[
                const SizedBox(width: 4),
                Tooltip(
                  message: 'Remover dos Contatos',
                  child: InkWell(
                    onTap: () {
                      setState(() => _showMobileAction = false);
                      widget.onRemoveContact();
                    },
                    borderRadius: BorderRadius.circular(3),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: yellowAccent.withValues(alpha: 0.18),
                        border: Border.all(color: yellowAccent, width: 0.8),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.person_remove_alt_1,
                            color: yellowAccent,
                            size: 10,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '- CONTATO',
                            style: GoogleFonts.shareTechMono(
                              color: yellowAccent,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
