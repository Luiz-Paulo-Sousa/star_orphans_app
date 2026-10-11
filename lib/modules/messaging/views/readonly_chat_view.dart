import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ReadonlyChatView extends StatelessWidget {
  final String channelName;
  final List<Map<String, dynamic>> messages;
  static const Color _cyanColor = Color(0xFF00D2FF);
  static const Color _greenAccent = Color(0xFF00FF66);
  static const Color _panelBg = Color(0xD912161F);

  const ReadonlyChatView({
    super.key,
    required this.channelName,
    required this.messages,
  });

  @override
  Widget build(BuildContext context) {
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
          Row(
            children: [
              Text(
                '$channelName (INFORMATIVO - APENAS LEITURA):',
                style: GoogleFonts.shareTechMono(
                  color: Colors.amberAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF191D33),
                      border: Border.all(color: _cyanColor, width: 0.8),
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
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(6),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black26,
              border: Border.all(color: Colors.white24),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'TRANSMISSÃO OFICIAL — CANAL SEM PERMISSÃO DE TRANSMISSÃO DE RESPOSTA',
              style: GoogleFonts.shareTechMono(
                color: Colors.grey,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
