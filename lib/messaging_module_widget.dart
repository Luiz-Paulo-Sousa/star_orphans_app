import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

  // Controle de abas principais: 'CONVERSAS' ou 'MENSAGENS'
  String _activeTab = 'CONVERSAS';

  // Seleções ativas
  String _selectedChannel = 'EQUIPE';
  String _selectedContact = 'BUSTER';

  // Controller para o campo de envio de texto
  final TextEditingController _messageController = TextEditingController();

  // Dados mockados de mensagens
  final List<Map<String, dynamic>> _teamMessages = [
    {
      'timestamp': '26-09-01 18:47:25',
      'sender': 'BUSTER',
      'isMe': false,
      'text': 'Núvem de anteroides de Cobre localizada em Asgard!!!',
      'color': Colors.amberAccent,
    },
    {
      'timestamp': '26-09-01 18:47:45',
      'sender': 'TROOPER',
      'isMe': true,
      'text': 'Passa as coordenadas!!!',
      'color': _greenAccent,
    },
    {
      'timestamp': '26-09-01 18:50:35',
      'sender': 'BUSTER',
      'isMe': false,
      'text': '-13782,+5290,+78492',
      'color': Colors.amberAccent,
    },
    {
      'timestamp': '26-09-01 18:51:14',
      'sender': 'TROOPER',
      'isMe': true,
      'text': 'Obrigado!',
      'color': _greenAccent,
    },
  ];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Cabeçalho HUD Idêntico
          _buildHeader(),
          const SizedBox(height: 12),
          _buildLocationBar(),
          const SizedBox(height: 12),

          // 2. Abas 'CONVERSAS' / 'MENSAGENS' com largura exata de 130px alinhada à esquerda
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 130, // Soma exata da largura do painel CANAIS abaixo
              child: Row(
                children: [
                  Expanded(child: _buildTopTab('CONVERSAS')),
                  const SizedBox(width: 2),
                  Expanded(child: _buildTopTab('MENSAGENS')),
                ],
              ),
            ),
          ),

          // 3. Corpo Principal Dividido (Painel esquerdo com 130px de largura)
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 130,
                  child:
                      _activeTab == 'CONVERSAS'
                          ? _buildConversationsLeftPanel()
                          : _buildDirectMessagesLeftPanel(),
                ),
                const SizedBox(width: 12),
                Expanded(child: _buildChatArea()),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 4. Input de Texto
          _buildMessageInputField(),
        ],
      ),
    );
  }

  // --- CABEÇALHO ---
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
        Tooltip(
          message: 'Avatar do Operador',
          child: Container(
            width: 50,
            height: 50,
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
                          (context, error, stackTrace) => const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 30,
                          ),
                    )
                    : const Icon(Icons.person, color: Colors.white, size: 30),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'OPERADOR: ${op['name'] ?? 'N/A'}',
                style: GoogleFonts.shareTechMono(
                  color: _cyanColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'CORPORAÇÃO: ${op['corporation'] ?? 'N/A'}',
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
    final op = widget.profileData?['operator'] ?? {};
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: _cyanColor.withValues(alpha: 0.4)),
      ),
      child: Text(
        'LOCALIZAÇÃO: ${op['location'] ?? 'DESCONHECIDA'}',
        style: GoogleFonts.shareTechMono(
          color: Colors.white,
          fontSize: 13,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  // --- ABAS SUPERIORES COM BORDA DESTAQUE NA ATIVA ---
  Widget _buildTopTab(String title) {
    final isSelected = _activeTab == title;
    return InkWell(
      onTap: () {
        setState(() {
          _activeTab = title;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? _greenAccent : _cyanColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(4),
          ),
          border: Border(
            top: BorderSide(
              color: isSelected ? _greenAccent : _cyanColor,
              width: 1.2,
            ),
            left: BorderSide(
              color: isSelected ? _greenAccent : _cyanColor,
              width: 1.2,
            ),
            right: BorderSide(
              color: isSelected ? _greenAccent : _cyanColor,
              width: 1.2,
            ),
            bottom:
                isSelected
                    ? BorderSide.none
                    : BorderSide(
                      color: isSelected ? _greenAccent : _cyanColor,
                      width: 1.2,
                    ),
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: Text(
              title,
              style: GoogleFonts.shareTechMono(
                color: Colors.black,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- PAINEL ESQUERDO: CONVERSAS (Raio superior direito zerado) ---
  Widget _buildConversationsLeftPanel() {
    final canais = ['GLOBAL', 'CORPORAÇÃO', 'EQUIPE', 'ESQUADRILHA'];
    final equipe = [
      {'name': 'BUSTER', 'online': true},
      {'name': 'DOOM', 'online': false},
      {'name': 'GUSTAVO', 'online': false},
      {'name': 'RAZEK', 'online': false},
    ];

    return Column(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _panelBg,
              border: Border.all(color: _greenAccent, width: 1.2),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.zero,
                topRight: Radius.zero, // Raio superior direito zerado
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CANAIS:',
                  style: GoogleFonts.shareTechMono(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                ...canais.map((canal) {
                  final isSel = _selectedChannel == canal;
                  return InkWell(
                    onTap: () => setState(() => _selectedChannel = canal),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          Icon(
                            Icons.circle,
                            size: 8,
                            color: isSel ? _greenAccent : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              canal,
                              style: GoogleFonts.shareTechMono(
                                color: isSel ? _greenAccent : _cyanColor,
                                fontSize: 11,
                                fontWeight:
                                    isSel ? FontWeight.bold : FontWeight.normal,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
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
                  'EQUIPE:',
                  style: GoogleFonts.shareTechMono(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                ...equipe.map((membro) {
                  final bool isOnline = membro['online'] as bool;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 8,
                          color: isOnline ? _greenAccent : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            membro['name'] as String,
                            style: GoogleFonts.shareTechMono(
                              color: isOnline ? _greenAccent : Colors.grey,
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- PAINEL ESQUERDO: MENSAGENS DIRETAS (Raio superior direito zerado) ---
  Widget _buildDirectMessagesLeftPanel() {
    final contatos = [
      {'name': 'BUSTER', 'online': true},
      {'name': 'DOOM', 'online': false},
      {'name': 'GUSTAVO', 'online': false},
      {'name': 'RAZEK', 'online': false},
    ];

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _panelBg,
        border: Border.all(color: _greenAccent, width: 1.2),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.zero,
          topRight: Radius.zero, // Raio superior direito zerado
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'CONTATOS:',
                style: GoogleFonts.shareTechMono(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              _buildMiniActionButton('+'),
              const SizedBox(width: 2),
              _buildMiniActionButton('/'),
              const SizedBox(width: 2),
              _buildMiniActionButton('X'),
            ],
          ),
          const SizedBox(height: 8),
          ...contatos.map((contato) {
            final String name = contato['name'] as String;
            final bool isOnline = contato['online'] as bool;
            final bool isSel = _selectedContact == name;

            return InkWell(
              onTap: () => setState(() => _selectedContact = name),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 8,
                      color: isOnline ? _greenAccent : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        name,
                        style: GoogleFonts.shareTechMono(
                          color: isSel ? _greenAccent : Colors.white,
                          fontSize: 11,
                          fontWeight:
                              isSel ? FontWeight.bold : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMiniActionButton(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white12,
        border: Border.all(color: Colors.white38),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        label,
        style: GoogleFonts.shareTechMono(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // --- ÁREA CENTRAL DO CHAT ---
  Widget _buildChatArea() {
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
              itemCount: _teamMessages.length,
              itemBuilder: (context, index) {
                final msg = _teamMessages[index];
                final bool isMe = msg['isMe'] as bool;

                return Align(
                  alignment:
                      isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:
                          isMe
                              ? const Color(0xFF0D2D23)
                              : const Color(0xFF191D33),
                      border: Border.all(
                        color: isMe ? _greenAccent : _cyanColor,
                        width: 0.8,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: RichText(
                      text: TextSpan(
                        style: GoogleFonts.shareTechMono(fontSize: 12),
                        children: [
                          TextSpan(
                            text: '${msg['timestamp']} ',
                            style: const TextStyle(color: _greenAccent),
                          ),
                          if (!isMe)
                            TextSpan(
                              text: '${msg['sender']}: ',
                              style: const TextStyle(
                                color: Colors.amberAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          TextSpan(
                            text: msg['text'] as String,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
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

  // --- INPUT DE TEXTO ---
  Widget _buildMessageInputField() {
    return Container(
      padding: const EdgeInsets.all(8),
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
            style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  style: GoogleFonts.shareTechMono(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Digite sua mensagem.',
                    hintStyle: GoogleFonts.shareTechMono(
                      color: Colors.grey,
                      fontSize: 13,
                    ),
                    isDense: true,
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  if (_messageController.text.trim().isNotEmpty) {
                    setState(() {
                      _teamMessages.add({
                        'timestamp': '26-09-01 18:52:00',
                        'sender': 'TROOPER',
                        'isMe': true,
                        'text': _messageController.text.trim(),
                        'color': _greenAccent,
                      });
                      _messageController.clear();
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: Text(
                  'Enviar',
                  style: GoogleFonts.shareTechMono(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatCredits(dynamic value) {
    if (value == null) return '0';
    final int parsedValue =
        (value is num) ? value.toInt() : int.tryParse(value.toString()) ?? 0;
    return parsedValue.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }
}
