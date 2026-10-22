import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class NotificationWebSocketService {
  // Instância singleton para fácil acesso global no app
  static final NotificationWebSocketService instance =
      NotificationWebSocketService._internal();
  factory NotificationWebSocketService() => instance;
  NotificationWebSocketService._internal();

  WebSocketChannel? _channel;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  Function(String eventType, Map<String, dynamic> data)? onMessageReceived;

  // Inicializa o sistema de notificações locais
  Future<void> initialize() async {
    if (_isInitialized) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Configuração para Windows (usa o ícone padrão da aplicação)
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();
    const LinuxInitializationSettings initializationSettingsLinux =
        LinuxInitializationSettings(defaultActionName: 'Open notification');

    // Para Windows a partir do pubspec, as notificações nativas usam a API Win32 do pacote
    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
          linux: initializationSettingsLinux,
        );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Ação ao clicar na notificação (opcional)
        debugPrint('Notificação clicada: ${response.payload}');
      },
    );

    // Criação do canal de notificações de alta prioridade para o Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'star_orphans_channel', // id
      'Star Orphans Alertas', // nome
      description: 'Canal para alertas de chat e e-mails em tempo real',
      importance: Importance.max,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    _isInitialized = true;
  }

  // Conecta ao WebSocket do backend
  void connect({
    required String apiBaseUrl,
    required int pilotUid,
    required Function(String eventType, Map<String, dynamic> data) onEvent,
  }) {
    onMessageReceived = onEvent;

    // Converte http:// para ws:// (ou https:// para wss://)
    final wsUrl = apiBaseUrl.replaceFirst('http', 'ws');

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      // Envia o registro do piloto assim que conectar
      _channel!.sink.add(
        jsonEncode({'type': 'REGISTER', 'pilot_uid': pilotUid}),
      );

      // Escuta as mensagens vindas do servidor
      _channel!.stream.listen(
        (message) {
          try {
            final parsed = jsonDecode(message);
            final type = parsed['type'];
            final data = parsed['data'] ?? {};

            if (type == 'CHAT_NOTIFICATION' || type == 'EMAIL_NOTIFICATION') {
              // Dispara notificação nativa visual e sonora
              _showNativeNotification(type, data);
            }

            // Repassa para a UI atualizar os ícones (🗨️ / 📧)
            if (onMessageReceived != null) {
              onMessageReceived!(type, data);
            }
          } catch (e) {
            debugPrint('Erro ao decodificar mensagem do WebSocket: $e');
          }
        },
        onError: (error) => debugPrint('Erro no WebSocket: $error'),
        onDone: () => debugPrint('Conexão WebSocket fechada.'),
      );
    } catch (e) {
      debugPrint('Falha ao conectar no WebSocket: $e');
    }
  }

  // Dispara a notificação flutuante nativa (Windows Toast ou Android Heads-up)
  Future<void> _showNativeNotification(
    String type,
    Map<String, dynamic> data,
  ) async {
    bool isEmail = type == 'EMAIL_NOTIFICATION';

    String title =
        isEmail ? '📧 Novo E-mail Recebido!' : '🗨️ Nova Mensagem no Chat!';
    String body =
        isEmail
            ? (data['subject'] ?? 'Você recebeu uma correspondência da Frota.')
            : (data['message_text'] ?? 'Nova transmissão recebida.');

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'star_orphans_channel',
          'Star Orphans Alertas',
          channelDescription:
              'Canal para alertas de chat e e-mails em tempo real',
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'ticker',
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      // Windows e Linux utilizam padrões nativos suportados pelo plugin
    );

    await _localNotifications.show(
      DateTime.now().millisecond, // ID único da notificação
      title,
      body,
      platformChannelSpecifics,
      payload: jsonEncode(data),
    );
  }

  void disconnect() {
    _channel?.sink.close();
  }
}
