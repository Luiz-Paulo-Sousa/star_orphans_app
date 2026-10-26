import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:image_picker/image_picker.dart';

import 'player_profile_screen.dart';
import 'modules/messaging/messaging_module_widget.dart';
import 'modules/hangar/hangar_module_widget.dart';
import 'services/notification_websocket_service.dart';

class MainLayoutScreen extends StatefulWidget {
  final Map<String, dynamic> profileData;
  final String apiBaseUrl;

  const MainLayoutScreen({
    super.key,
    required this.profileData,
    this.apiBaseUrl = 'http://26.239.180.177:8020',
  });

  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> {
  int _selectedIndex = 0;
  String _messagingInitialTab = 'CONVERSAS';

  bool _hasUnreadChat = false;
  bool _hasUnreadEmail = false;
  bool _isUploadingAvatar = false;
  Timer? _unreadSyncTimer;

  late Map<String, dynamic> _currentProfileData;

  static const Color _cyanColor = Color(0xFF00D2FF);
  static const Color _darkBg = Color(0xFF0A0D12);
  static const Color _panelBg = Color(0xD912161F);

  @override
  void initState() {
    super.initState();
    _currentProfileData = Map<String, dynamic>.from(widget.profileData);
    _initRealtimeConnection();
    _checkUnreadMessagesOnStartup();
    // Heartbeat a cada 10 segundos para manter os ícones de notificação 100% sincronizados
    _unreadSyncTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkUnreadMessagesOnStartup();
    });
  }

  @override
  void dispose() {
    _unreadSyncTimer?.cancel();
    super.dispose();
  }

  int _getAccountId() {
    final operatorData = _currentProfileData['operator'] ?? {};
    final dynamic rawUid =
        operatorData['account_id'] ??
        operatorData['operator_uid'] ??
        operatorData['pilot_uid'] ??
        operatorData['uid'] ??
        _currentProfileData['account_id'] ??
        _currentProfileData['uid'];

    if (rawUid != null) {
      if (rawUid is int) return rawUid;
      return int.tryParse(rawUid.toString()) ?? 0;
    }
    return 0;
  }

  /// Verifica no banco ao iniciar se existem mensagens não lidas para o piloto
  Future<void> _checkUnreadMessagesOnStartup() async {
    final accountId = _getAccountId();
    debugPrint('=== [DEBUG GLOBAL] Account ID obtido no início = $accountId ===');
    
    if (accountId == 0) {
      debugPrint('=== [DEBUG GLOBAL] ATENÇÃO: Account ID é 0! A abortar checagem. ===');
      return;
    }

    try {
      final url = '${widget.apiBaseUrl}/api/messages/unread-status/$accountId';
      debugPrint('=== [DEBUG GLOBAL] A fazer GET em: $url ===');

      final response = await http.get(Uri.parse(url));
      
      debugPrint('=== [DEBUG GLOBAL] Status Code retornado = ${response.statusCode} ===');
      debugPrint('=== [DEBUG GLOBAL] Body retornado = ${response.body} ===');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final data =
            decoded is Map
                ? Map<String, dynamic>.from(decoded)
                : <String, dynamic>{};

        if (mounted) {
          setState(() {
            _hasUnreadChat = data['has_unread_chat'] == true;
            _hasUnreadEmail = data['has_unread_email'] == true;
          });
          debugPrint('=== [DEBUG GLOBAL] Estados finais -> Chat: $_hasUnreadChat | Email: $_hasUnreadEmail ===');
        }
      }
    } catch (e) {
      debugPrint('=== [ERRO CRÍTICO] Falha ao checar mensagens não lidas: $e ===');
    }
}

  /// Marca as mensagens como lidas na API
  Future<void> _markAsReadOnApi({required int type}) async {
    final accountId = _getAccountId();
    if (accountId == 0) return;

    try {
      // Dispara a rota para marcar todas as mensagens daquele tipo como lidas para o piloto
      await http.put(
        Uri.parse(
          '${widget.apiBaseUrl}/api/messages/mark-all-read/$accountId?type=$type',
        ),
      );
    } catch (e) {
      debugPrint('Erro ao marcar mensagens como lidas na API: $e');
    }
  }

  Future<void> _refreshProfileData() async {
    final accountId = _getAccountId();
    if (accountId == 0) return;

    try {
      final response = await http.get(
        Uri.parse('${widget.apiBaseUrl}/player-profile?account_id=$accountId'),
      );
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['status'] == 'sucesso') {
          setState(() {
            _currentProfileData = jsonResponse['data'];
          });
        }
      }
    } catch (e) {
      debugPrint('Erro ao atualizar dados do perfil: $e');
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    setState(() {
      _isUploadingAvatar = true;
    });

    try {
      final accountId = _getAccountId();
      if (accountId == 0) return;

      final uri = Uri.parse('${widget.apiBaseUrl}/upload-avatar');
      var request = http.MultipartRequest('POST', uri);

      request.fields['account_id'] = accountId.toString();

      final bytes = await image.readAsBytes();
      final multipartFile = http.MultipartFile.fromBytes(
        'avatar',
        bytes,
        filename: image.name.isNotEmpty ? image.name : 'avatar.jpg',
      );

      request.files.add(multipartFile);

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (!mounted) return;

      if (response.statusCode == 200) {
        await _refreshProfileData();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF00D2FF),
            content: Text('AVATAR ATUALIZADO COM SUCESSO!'),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFFF2A6D),
            content: Text('FALHA NO UPLOAD (${response.statusCode})'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFFF2A6D),
          content: Text('ERRO NO UPLOAD: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingAvatar = false;
        });
      }
    }
  }

  Future<void> _initRealtimeConnection() async {
    final accountId = _getAccountId();
    if (accountId == 0) return;

    await NotificationWebSocketService.instance.initialize();

    NotificationWebSocketService.instance.connect(
      apiBaseUrl: widget.apiBaseUrl,
      pilotUid: accountId,
      onEvent: (eventType, data) {
        if (!mounted) return;
        setState(() {
          if (eventType == 'CHAT_NOTIFICATION') {
            _hasUnreadChat = true;
          } else if (eventType == 'EMAIL_NOTIFICATION') {
            _hasUnreadEmail = true;
          }
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bool isKeyboardOpen = bottomInset > 60;
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    final bool hideBottomBar = isKeyboardOpen && isMobile;

    return Scaffold(
      backgroundColor: _darkBg,
      body: SafeArea(
        bottom: !hideBottomBar,
        child: Column(
          children: [
            _buildGlobalHeader(),
            _buildLocationBar(),
            Expanded(
              child: _buildSelectedTabContent(),
            ),
            hideBottomBar
                ? const SizedBox.shrink()
                : _buildBottomNavigationBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalHeader() {
    final op = _currentProfileData['operator'] ?? {};
    final String opName = op['name'] ?? 'Trooper';
    final String corpName = op['corporation'] ?? 'Atlas';
    final String creditsStr = _formatCredits(op['credits']);

    final String? avatarUrl = op['avatar_url'];
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final String fullAvatarUrl =
        (avatarUrl != null && avatarUrl.isNotEmpty)
            ? (avatarUrl.startsWith('http')
                ? '$avatarUrl?t=$timestamp'
                : '${widget.apiBaseUrl}$avatarUrl?t=$timestamp')
            : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: _panelBg,
        border: Border(
          bottom: BorderSide(
            color: _cyanColor.withValues(alpha: 0.4),
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          Tooltip(
            message: 'Clique para alterar a imagem do avatar',
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                child: Container(
                  width: 38,
                  height: 38,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: _cyanColor, width: 1.0),
                  ),
                  child:
                      _isUploadingAvatar
                          ? const Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: _cyanColor,
                                strokeWidth: 2,
                              ),
                            ),
                          )
                          : fullAvatarUrl.isNotEmpty
                          ? Image.network(
                            fullAvatarUrl,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (_, __, ___) => const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 22,
                                ),
                          )
                          : const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 22,
                          ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'OPERADOR: $opName',
                  style: GoogleFonts.shareTechMono(
                    color: _cyanColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'CORPORAÇÃO: $corpName',
                  style: GoogleFonts.shareTechMono(
                    color: _cyanColor,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Row(
            children: [
              // Ícone de Chat: Exibido APENAS se houver mensagens de chat não lidas (_hasUnreadChat == true)
              if (_hasUnreadChat)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: InkWell(
                    onTap: () async {
                      await _markAsReadOnApi(type: 0);
                      setState(() {
                        _messagingInitialTab = 'CONVERSAS';
                        _selectedIndex = 1;
                        _hasUnreadChat = false;
                      });
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4.0),
                      child: Text('🗨️', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ),
              // Ícone de E-mail: Exibido APENAS se houver e-mails não lidos (_hasUnreadEmail == true)
              if (_hasUnreadEmail)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: InkWell(
                    onTap: () async {
                      await _markAsReadOnApi(type: 1);
                      setState(() {
                        _messagingInitialTab = 'MENSAGENS';
                        _selectedIndex = 1;
                        _hasUnreadEmail = false;
                      });
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4.0),
                      child: Text('📧', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              Text(
                'CRÉDITOS: $creditsStr',
                style: GoogleFonts.shareTechMono(
                  color: _cyanColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationBar() {
    final op = _currentProfileData['operator'] ?? {};
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _panelBg,
        border: Border(
          bottom: BorderSide(
            color: _cyanColor.withValues(alpha: 0.4),
            width: 1.0,
          ),
        ),
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

  Widget _buildSelectedTabContent() {
    switch (_selectedIndex) {
      case 0:
        return PlayerProfileScreen(
          accountId: _getAccountId(),
          apiBaseUrl: widget.apiBaseUrl,
          profileData: _currentProfileData,
        );
      case 1:
        return MessagingModuleWidget(
          key: const PageStorageKey('messaging_module_widget'),
          profileData: _currentProfileData,
          apiBaseUrl: widget.apiBaseUrl,
          initialTab: _messagingInitialTab,
          onTabChanged: (tab) {
            _messagingInitialTab = tab;
          },
          onMessagesRead: _checkUnreadMessagesOnStartup,
        );
      case 2:
        return HangarModuleWidget(
          profileData: _currentProfileData,
          apiBaseUrl: widget.apiBaseUrl,
        );
      case 3:
        return _buildPlaceholderScreen('QUADRO DE CONTRATOS E MISSÕES');
      case 4:
        return _buildPlaceholderScreen('MERCADO GALÁCTICO DE SUPRIMENTOS');
      case 5:
        return _buildPlaceholderScreen('ESTOQUE DE CARGA E RECURSOS');
      case 6:
        return _buildPlaceholderScreen('FÁBRICA E LINHA DE PRODUÇÃO');
      default:
        return _buildPlaceholderScreen('TELA DESCONHECIDA');
    }
  }

  Widget _buildPlaceholderScreen(String title) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _panelBg,
          border: Border.all(color: _cyanColor, width: 1.2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '// STATUS DO SISTEMA:',
              style: GoogleFonts.shareTechMono(
                color: Colors.white,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.shareTechMono(
                color: _cyanColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '[ MÓDULO EM DESENVOLVIMENTO ]',
              style: GoogleFonts.shareTechMono(
                color: Colors.greenAccent,
                fontSize: 11,
              ),
            ),
          ],
        ),
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
        children: List.generate(tabs.length, (index) {
          final isSelected = index == _selectedIndex;
          return Expanded(
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedIndex = index;
                });
                _checkUnreadMessagesOnStartup();
              },
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
                      tabs[index],
                      style: GoogleFonts.shareTechMono(
                        color: isSelected ? Colors.greenAccent : Colors.white,
                        fontSize: 9,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
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
