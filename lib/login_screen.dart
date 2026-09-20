import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _operatorController = TextEditingController();
  final _accessKeyController = TextEditingController();
  bool _isLoading = false;

  void _autenticar() async {
    final operatorId = _operatorController.text.trim();
    final accessKey = _accessKeyController.text.trim();

    // Validação rápida de campos vazios
    if (operatorId.isEmpty || accessKey.isEmpty) {
      _exibirStatus('PREENCHA TODOS OS CAMPOS DE ACESSO', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Lógica de Hash SHA-256 com Salt (ID do Operador)
      final saltedKey = '$operatorId:$accessKey';
      final bytes = utf8.encode(saltedKey);
      final keyHash = sha256.convert(bytes).toString();

      // 2. Chamada HTTP para a API Node.js
      // Ajusta o IP/URL conforme o teu ambiente (ex: http://localhost:3000/api/login)
      final url = Uri.parse('http://localhost:3000/api/login');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'operatorId': operatorId, 'keyHash': keyHash}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        _exibirStatus('AUTENTICAÇÃO BEM-SUCEDIDA! ACESSO PERMITIDO.');
        // TODO: Navegar para a próxima tela do Companion App
      } else {
        final body = jsonDecode(response.body);
        final errorMsg = body['message'] ?? 'FALHA NA AUTENTICAÇÃO';
        _exibirStatus(errorMsg.toUpperCase(), isError: true);
      }
    } catch (e) {
      if (mounted) {
        _exibirStatus('ERRO DE CONEXÃO COM O SERVIDOR', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Helper para exibir feedback visual sci-fi na tela
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
        duration: const Duration(seconds: 3),
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
                        const Icon(Icons.security, color: colorCyan, size: 38),
                        const SizedBox(height: 8),
                        Text(
                          'COMPANION',
                          style: GoogleFonts.shareTechMono(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 3,
                          ),
                        ),
                        Text(
                          'AUTENTICAÇÃO DE OPERADOR v1.0',
                          style: GoogleFonts.shareTechMono(
                            fontSize: 10,
                            color: colorCyan.withValues(alpha: 0.8),
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // --- CAMPO: ID DO OPERADOR ---
                  _buildLabel('ID DO OPERADOR'),
                  const SizedBox(height: 6),
                  _buildTextField(
                    controller: _operatorController,
                    hintText: 'OP-XXXXX',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 20),

                  // --- CAMPO: CHAVE DE ACESSO ---
                  _buildLabel('CHAVE DE ACESSO'),
                  const SizedBox(height: 6),
                  _buildTextField(
                    controller: _accessKeyController,
                    hintText: '••••••••',
                    isPassword: true,
                    icon: Icons.key_outlined,
                  ),
                  const SizedBox(height: 28),

                  // --- BOTÃO DE AUTENTICAÇÃO ---
                  ElevatedButton(
                    onPressed: _isLoading ? null : _autenticar,
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
                              'AUTENTICAR',
                              style: GoogleFonts.shareTechMono(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                  ),
                  const SizedBox(height: 24),

                  // --- RODAPÉ DE AÇÕES ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildFooterLink('REDEFINIR CHAVE', () {}),
                      _buildFooterLink('NOVO OPERADOR?', () {}),
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
    bool isPassword = false,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        prefixIcon: Icon(
          icon,
          color: const Color(0xFF00D2FF).withValues(alpha: 0.6),
          size: 18,
        ),
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
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
