import 'package:flutter/material.dart';

void main() {
  runApp(const StarOrphansApp());
}

class StarOrphansApp extends StatelessWidget {
  const StarOrphansApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Star Orphans Companion',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF12161A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          surface: Color(0xFF1D232A),
        ),
      ),
      home: const AuthScreen(),
    );
  }
}

// -----------------------------------------------------------------------------
// TELA DE LOGIN / AUTENTICAÇÃO
// -----------------------------------------------------------------------------
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _operatorController = TextEditingController();
  final _keyController = TextEditingController();

  void _authenticate() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          width: 340,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1D232A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF2A3441), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              TextField(
                controller: _operatorController,
                style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
                decoration: const InputDecoration(
                  labelText: 'ID DO OPERADOR :',
                  labelStyle: TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace'),
                  filled: true,
                  fillColor: Color(0xFF12161A),
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF00E5FF))),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _keyController,
                obscureText: true,
                style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
                decoration: const InputDecoration(
                  labelText: 'CHAVE DE ACESSO :',
                  labelStyle: TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace'),
                  filled: true,
                  fillColor: Color(0xFF12161A),
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF00E5FF))),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0088FF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  onPressed: _authenticate,
                  child: const Text('AUTENTICAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {},
                    child: const Text('REDEFINIR CHAVE', style: TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'monospace')),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text('NOVO OPERADOR?', style: TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'monospace')),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// SHELL PRINCIPAL (CABEÇALHO + DOCK INFERIOR)
// -----------------------------------------------------------------------------
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 1; // Inicia em Mensagens conforme Figma

  final List<String> _tabs = [
    'PERFIL',
    'MENSAGENS',
    'HANGAR',
    'CONTRATOS',
    'MERCADO',
    'ESTOQUE',
    'FÁBRICA',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Cabeçalho Superior
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFF12161A),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('OPERADOR: TROOPER', style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                          SizedBox(height: 4),
                          Text('CORPORAÇÃO: ATLAS', style: TextStyle(color: Color(0xFF00E5FF), fontFamily: 'monospace', fontSize: 12)),
                        ],
                      ),
                      const Spacer(),
                      const Text('CRÉDITOS: 999.999.999,99', style: TextStyle(color: Color(0xFF00E5FF), fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(color: Color(0xFF00E5FF), height: 1),
                  const SizedBox(height: 6),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('LOCALIZAÇÃO: SISTEMA - SETOR - ESTAÇÃO', style: TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace')),
                  ),
                  const SizedBox(height: 6),
                  const Divider(color: Color(0xFF00E5FF), height: 1),
                ],
              ),
            ),

            // Área Central Dinâmica
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: [
                  const ProfileView(),
                  const MessagesView(),
                  _buildPlaceholder('HANGAR'),
                  _buildPlaceholder('CONTRATOS'),
                  _buildPlaceholder('MERCADO'),
                  _buildPlaceholder('ESTOQUE'),
                  _buildPlaceholder('FÁBRICA'),
                ],
              ),
            ),

            // Dock Inferior de Navegação
            Container(
              padding: const EdgeInsets.all(8),
              color: const Color(0xFF12161A),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(_tabs.length, (index) {
                    final isSelected = _currentIndex == index;
                    final activeColor = index == 0 || index == 1 ? const Color(0xFF00FF66) : const Color(0xFF00E5FF);

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: InkWell(
                        onTap: () => setState(() => _currentIndex = index),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1D232A),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? activeColor : const Color(0xFF00E5FF).withOpacity(0.4),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: isSelected ? activeColor : Colors.white70,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _tabs[index],
                                style: TextStyle(
                                  color: isSelected ? activeColor : Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(String title) {
    return Center(
      child: Text(
        'MÓDULO DE $title EM DESENVOLVIMENTO',
        style: const TextStyle(color: Colors.white54, fontFamily: 'monospace'),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// VISÃO: MENSAGENS
// -----------------------------------------------------------------------------
class MessagesView extends StatefulWidget {
  const MessagesView({super.key});

  @override
  State<MessagesView> createState() => _MessagesViewState();
}

class _MessagesViewState extends State<MessagesView> {
  final TextEditingController _msgController = TextEditingController();
  String _selectedChannel = 'CORPORAÇÃO';

  final List<Map<String, dynamic>> _messages = [
    {'time': '26-09-01 18:47:25', 'sender': 'BUSTER', 'text': 'Nuvem de anteroides de Cobre localizada em Asgard!!!', 'isMe': false},
    {'time': '26-09-01 18:47:45', 'sender': '', 'text': 'Passa as coordenadas!!!', 'isMe': true},
    {'time': '26-09-01 18:50:35', 'sender': 'BUSTER', 'text': '-13782,+5290,+78492', 'isMe': false},
    {'time': '26-09-01 18:51:14', 'sender': '', 'text': 'Obrigado!', 'isMe': true},
  ];

  void _sendMessage() {
    if (_msgController.text.trim().isEmpty) return;
    setState(() {
      _messages.add({
        'time': '26-09-01 18:55:00',
        'sender': '',
        'text': _msgController.text,
        'isMe': true,
      });
      _msgController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Painel de Canais
                Container(
                  width: 140,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D232A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF00E5FF), width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('CANAIS:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                      const SizedBox(height: 12),
                      _buildChannelItem('GLOBAL', Colors.grey),
                      _buildChannelItem('CORPORAÇÃO', const Color(0xFF00FF66)),
                      _buildChannelItem('EQUIPE', const Color(0xFF00E5FF)),
                      _buildChannelItem('ESQUADRILHA', Colors.grey),
                      _buildChannelItem('DIRETA', Colors.grey),
                      _buildChannelItem('SISTEMA', const Color(0xFF00E5FF)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Área do Chat
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D232A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF00E5FF), width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$_selectedChannel:', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                        const SizedBox(height: 12),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final msg = _messages[index];
                              final isMe = msg['isMe'] as bool;

                              return Align(
                                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isMe ? const Color(0xFF0D2818) : const Color(0xFF19122B),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: RichText(
                                    text: TextSpan(
                                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                                      children: [
                                        TextSpan(text: '${msg['time']} ', style: TextStyle(color: isMe ? const Color(0xFF00FF66) : const Color(0xFF00FF66))),
                                        if (!isMe) TextSpan(text: '${msg['sender']}: ', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                                        TextSpan(text: msg['text'], style: const TextStyle(color: Colors.white)),
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
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Campo de Entrada de Mensagem (Rodapé)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1D232A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF00E5FF), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('MENSAGEM:', style: TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace')),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _msgController,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
                        decoration: const InputDecoration(
                          hintText: 'Digite sua mensagem...',
                          hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE0E0E0),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      onPressed: _sendMessage,
                      child: const Text('Enviar', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelItem(String name, Color indicatorColor) {
    final isSelected = _selectedChannel == name;
    return InkWell(
      onTap: () => setState(() => _selectedChannel = name),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: indicatorColor, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(
              name,
              style: TextStyle(
                color: isSelected ? const Color(0xFF00FF66) : Colors.white70,
                fontSize: 11,
                fontFamily: 'monospace',
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// VISÃO: PERFIL
// -----------------------------------------------------------------------------
class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          // Reputação
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1D232A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF00E5FF), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('REPUTAÇÃO:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                  const SizedBox(height: 12),
                  _buildRepBar('ARCA', 1.0, '+100%', Colors.green),
                  _buildRepBar('DISSIDENTES', 0.15, '-15%', Colors.red),
                  _buildRepBar('MÃO DA VERDADE', 0.61, '-61%', Colors.red),
                  _buildRepBar('EXTRATORES', 0.44, '+44%', Colors.green),
                  _buildRepBar('CONSTRUTORES', 0.44, '+44%', Colors.green),
                  _buildRepBar('MERCENÁRIOS', 0.59, '+59%', Colors.green),
                  _buildRepBar('PIRATAS', 1.0, '-100%', Colors.red),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Habilidades
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1D232A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF00E5FF), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('HABILIDADES:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                  const SizedBox(height: 12),
                  _buildSkillBar('EXPLORADOR', 0.9),
                  _buildSkillBar('MINERADOR', 0.75),
                  _buildSkillBar('MERCADOR', 0.4),
                  _buildSkillBar('ENGENHEIRO', 0.35),
                  _buildSkillBar('MERCENÁRIO', 0.35),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRepBar(String label, double val, String percentText, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'monospace'))),
          Expanded(
            child: LinearProgressIndicator(value: val, backgroundColor: Colors.black26, color: color, minHeight: 8),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 40, child: Text(percentText, style: TextStyle(color: color, fontSize: 10, fontFamily: 'monospace'))),
        ],
      ),
    );
  }

  Widget _buildSkillBar(String label, double val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'monospace'))),
          Expanded(
            child: LinearProgressIndicator(value: val, backgroundColor: Colors.black26, color: const Color(0xFF00FF66), minHeight: 8),
          ),
        ],
      ),
    );
  }
}