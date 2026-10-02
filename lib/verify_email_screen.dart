import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class VerifyEmailScreen extends StatefulWidget {
  final String username;

  const VerifyEmailScreen({super.key, required this.username});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;

  Future<void> _validarCodigo() async {
    String codigo = _codeController.text.trim();

    if (codigo.isEmpty) {
      _exibirStatus('DIGITE O CÓDIGO DE VALIDAÇÃO!', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    var url = Uri.parse('http://26.239.180.177:8020/verify-email');

    try {
      var response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"username": widget.username, "code": codigo}),
      );

      if (!mounted) return;

      Map<String, dynamic> dados = {};
      try {
        dados = jsonDecode(response.body);
      } catch (_) {}

      if (response.statusCode == 200) {
        String msgSucesso =
            dados['mensagem']?.toString() ?? 'E-MAIL VERIFICADO COM SUCESSO!';
        _exibirStatus("SUCESSO: ${msgSucesso.toUpperCase()}");

        // Retorna até a tela de Login (limpando a pilha de navegação)
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        });
      } else {
        String msg =
            dados['mensagem'] ??
            dados['message'] ??
            'CÓDIGO INVÁLIDO OU EXPIRADO';
        _exibirStatus("ERRO: ${msg.toString().toUpperCase()}", isError: true);
      }
    } catch (e) {
      if (mounted) {
        _exibirStatus("ERRO DE CONEXÃO: $e", isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _exibirStatus(String mensagem, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor:
            isError ? const Color(0xFFFF2A6D) : const Color(0xFF00D2FF),
        content: Text(
          mensagem,
          textAlign: TextAlign.center,
          style: GoogleFonts.shareTechMono(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const colorCyan = Color(0xFF00D2FF);
    const colorDarkBg = Color(0xFF12151A);
    const colorCardBg = Color(0xD9161B22);

    return Scaffold(
      backgroundColor: colorDarkBg,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [colorCyan.withValues(alpha: 0.08), colorDarkBg],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(28.0),
              decoration: BoxDecoration(
                color: colorCardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorCyan.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                  BoxShadow(
                    color: colorCyan.withValues(alpha: 0.05),
                    blurRadius: 15,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- CABEÇALHO ---
                  Center(
                    child: Column(
                      children: [
                        Image.asset(
                          'assets/images/star_orphans.png',
                          height: 80,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.mark_email_read_outlined,
                              color: colorCyan,
                              size: 48,
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'COMPANION',
                          style: GoogleFonts.shareTechMono(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 3,
                          ),
                        ),
                        Text(
                          'ATIVAÇÃO DE CONTA v1.0',
                          style: GoogleFonts.shareTechMono(
                            fontSize: 10,
                            color: colorCyan.withValues(alpha: 0.8),
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Mensagem Informativa
                  Text(
                    'Enviamos um código de 6 dígitos para o seu e-mail cadastrado. Informe o código abaixo para ativar o operador:',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.shareTechMono(
                      color: Colors.white70,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- CAMPO: CÓDIGO DE VALIDAÇÃO ---
                  _buildLabel('CÓDIGO DE VALIDAÇÃO'),
                  const SizedBox(height: 6),
                  _buildTextField(
                    controller: _codeController,
                    hintText: '123456',
                    icon: Icons.pin_outlined,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 24),

                  // --- BOTÃO VALIDAR ---
                  ElevatedButton(
                    onPressed: _isLoading ? null : _validarCodigo,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0066FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      elevation: 5,
                      shadowColor: colorCyan.withValues(alpha: 0.5),
                    ),
                    child:
                        _isLoading
                            ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : Text(
                              'ATIVAR CONTA',
                              style: GoogleFonts.shareTechMono(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                  ),
                  const SizedBox(height: 20),

                  // --- RODAPÉ ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildFooterLink('VOLTAR AO LOGIN', () {
                        Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst);
                      }),
                      Image.asset(
                        'assets/images/xama.png',
                        height: 52,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Text(
                            'XAMÃ',
                            style: GoogleFonts.shareTechMono(
                              color: Colors.white38,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.shareTechMono(
        color: const Color(0xFF00D2FF),
        fontSize: 11,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.shareTechMono(
        color: Colors.white,
        fontSize: 16,
        letterSpacing: 3.0,
      ),
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        prefixIcon: Icon(
          icon,
          color: const Color(0xFF00D2FF).withValues(alpha: 0.6),
          size: 18,
        ),
        hintText: hintText,
        hintStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.2),
          letterSpacing: 3.0,
        ),
        filled: true,
        fillColor: const Color(0xFF0A0E14),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFF00D2FF), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildFooterLink(String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Text(
        text,
        style: GoogleFonts.shareTechMono(
          color: Colors.white54,
          fontSize: 10,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}
