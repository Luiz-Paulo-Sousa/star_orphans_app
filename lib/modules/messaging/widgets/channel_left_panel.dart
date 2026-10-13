import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ChannelLeftPanel extends StatelessWidget {
  final List<dynamic> channelsList;
  final bool isLoading;
  final String? error;
  final String selectedChannel;
  final ValueChanged<String> onChannelSelected;

  // Novos parâmetros para as facções/coalizões
  final List<dynamic> factionsList;
  final bool isLoadingFactions;
  final int? selectedFactionUid;
  final ValueChanged<int> onFactionSelected;

  static const Color _cyanColor = Color(0xFF00D2FF);
  static const Color _greenAccent = Color(0xFF00FF66);
  static const Color _panelBg = Color(0xD912161F);

  const ChannelLeftPanel({
    super.key,
    required this.channelsList,
    required this.isLoading,
    required this.error,
    required this.selectedChannel,
    required this.onChannelSelected,
    required this.factionsList,
    required this.isLoadingFactions,
    required this.selectedFactionUid,
    required this.onFactionSelected,
  });

  @override
  Widget build(BuildContext context) {
    // Verifica se o canal selecionado é Coalizão (ajuste o texto conforme está no banco, ex: 'COALIZÃO')
    final bool isCoalition = selectedChannel.toUpperCase().contains('COALIZÃO');

    return Column(
      children: [
        // Painel Superior: Canais Principais
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _panelBg,
              border: Border.all(color: _greenAccent, width: 1.2),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.zero,
                topRight: Radius.zero,
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
                Expanded(
                  child:
                      isLoading
                          ? const Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _greenAccent,
                              ),
                            ),
                          )
                          : error != null
                          ? Center(
                            child: Text(
                              'Erro ao carregar',
                              style: GoogleFonts.shareTechMono(
                                color: Colors.redAccent,
                                fontSize: 10,
                              ),
                            ),
                          )
                          : ListView.builder(
                            itemCount: channelsList.length,
                            itemBuilder: (context, index) {
                              final channelData = channelsList[index];
                              final String canal =
                                  channelData['description'] ?? 'CANAL';
                              final isSel = selectedChannel == canal;

                              return InkWell(
                                onTap: () => onChannelSelected(canal),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4.0,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.circle,
                                        size: 8,
                                        color:
                                            isSel ? _greenAccent : Colors.grey,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          canal,
                                          style: GoogleFonts.shareTechMono(
                                            color:
                                                isSel
                                                    ? _greenAccent
                                                    : _cyanColor,
                                            fontSize: 11,
                                            fontWeight:
                                                isSel
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
                            },
                          ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Painel Inferior: Dinâmico (Exibe Coalizões se for o canal COALIZÃO, senão exibe Equipe padrão)
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
                  isCoalition ? 'COALIZÕES:' : 'EQUIPE:',
                  style: GoogleFonts.shareTechMono(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child:
                      isCoalition
                          ? (isLoadingFactions
                              ? const Center(
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _greenAccent,
                                  ),
                                ),
                              )
                              : ListView.builder(
                                itemCount: factionsList.length,
                                itemBuilder: (context, index) {
                                  final faction = factionsList[index];
                                  final int factionUid = faction['faction_uid'];
                                  final String factionName =
                                      faction['name'] ?? '';
                                  final bool isSelFaction =
                                      selectedFactionUid == factionUid;

                                  return InkWell(
                                    onTap: () => onFactionSelected(factionUid),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4.0,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.circle,
                                            size: 8,
                                            color:
                                                isSelFaction
                                                    ? _greenAccent
                                                    : Colors.grey,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              factionName,
                                              style: GoogleFonts.shareTechMono(
                                                color:
                                                    isSelFaction
                                                        ? _greenAccent
                                                        : _cyanColor,
                                                fontSize: 11,
                                                fontWeight:
                                                    isSelFaction
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
                                },
                              ))
                          : ListView(
                            children: const [
                              // Fallback temporário para os membros da equipe nos outros canais
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 4.0),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.circle,
                                      size: 8,
                                      color: Colors.greenAccent,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'BUSTER',
                                      style: TextStyle(
                                        color: Colors.greenAccent,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
