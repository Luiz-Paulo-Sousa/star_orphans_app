import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _operatorController = TextEditingController();
  final _emailController = TextEditingController();
  final _accessKeyController = TextEditingController();
  final _confirmAccessKeyController = TextEditingController();
  bool _isLoading = false;

  Future<void> _cadastrarOperador() async {
    String username = _operatorController.text.trim();
    String email = _emailController.text.trim();
    String senhaPura = _accessKeyController.text;
    String confirmacaoSenha = _confirmAccessKeyController.text;

    // Validar preenchimento dos campos
    if (username.isEmpty ||
        email.isEmpty ||
        senhaPura.isEmpty ||
        confirmacaoSenha.isEmpty) {
      _exibirStatus('PREENCHA TODOS OS CAMPOS!', isError: true);
      return;
    }

    // Validar e-mail simples
    if (!email.contains('@') || !email.contains('.')) {
      _exibirStatus('INFORME UM E-MAIL VÁLIDO!', isError: true);
      return;
    }

    // Validar correspondência de senha
    if (senhaPura != confirmacaoSenha) {
      _exibirStatus('AS CHAVES DE ACESSO NÃO COINCIDEM!', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    // Hash da senha (SHA-256 com salt do username)
    String salt = username;
    String combinacao = senhaPura + salt;
    var bytes = utf8.encode(combinacao);
    var digest = sha256.convert(bytes);
    String passwordHash = digest.toString();

    // Endpoint de cadastro
    var url = Uri.parse('http://26.239.180.177:8020/register');

    try {
      var response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": username,
          "email": email,
          "password_hash": passwordHash,
        }),
      );

      if (!mounted) return;

      Map<String, dynamic> dados = {};
      try {
        dados = jsonDecode(response.body);
      } catch (_) {}

      if (response.statusCode == 200 || response.statusCode == 201) {
        String msgSucesso =
            dados['mensagem']?.toString() ??
            dados['message']?.toString() ??
            'OPERADOR CADASTRADO COM SUCESSO';
        _exibirStatus("SUCESSO: ${msgSucesso.toUpperCase()}");

        // Retorna para o Login após sucesso
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      } else {
        // Exibe mensagem de erro retornada pelo servidor
        String msg =
            dados['mensagem'] ??
            dados['message'] ??
            dados['error'] ??
            'FALHA NO CADASTRO DO OPERADOR';
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
                              Icons.star_outline,
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
                          'CADASTRO DE NOVO OPERADOR v1.0',
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

                  // --- CAMPO: ID DO OPERADOR ---
                  _buildLabel('ID DO NOVO OPERADOR'),
                  const SizedBox(height: 6),
                  _buildTextField(
                    controller: _operatorController,
                    hintText: 'Nome do jogador',
                    icon: Icons.person_add_outlined,
                  ),
                  const SizedBox(height: 14),

                  // --- CAMPO: E-MAIL DO OPERADOR ---
                  _buildLabel('E-MAIL DO OPERADOR'),
                  const SizedBox(height: 6),
                  _buildTextField(
                    controller: _emailController,
                    hintText: 'operador@dominio.com',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 14),

                  // --- CAMPO: CHAVE DE ACESSO ---
                  _buildLabel('CHAVE DE ACESSO'),
                  const SizedBox(height: 6),
                  _buildTextField(
                    controller: _accessKeyController,
                    hintText: '••••••••',
                    isPassword: true,
                    icon: Icons.key_outlined,
                  ),
                  const SizedBox(height: 14),

                  // --- CAMPO: CONFIRMAR CHAVE DE ACESSO ---
                  _buildLabel('CONFIRMAR CHAVE DE ACESSO'),
                  const SizedBox(height: 6),
                  _buildTextField(
                    controller: _confirmAccessKeyController,
                    hintText: '••••••••',
                    isPassword: true,
                    icon: Icons.lock_outline,
                  ),
                  const SizedBox(height: 24),

                  // --- BOTÃO CADASTRAR ---
                  ElevatedButton(
                    onPressed: _isLoading ? null : _cadastrarOperador,
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
                              'CADASTRAR OPERADOR',
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
                        Navigator.pop(context);
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
    bool isPassword = false,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: keyboardType,
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
          vertical: 12,
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
