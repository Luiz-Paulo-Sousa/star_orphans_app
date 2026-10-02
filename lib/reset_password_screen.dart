import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  // Passos do fluxo: 1 = Username, 2 = Código + Timer, 3 = Nova Senha
  int _step = 1;

  final _usernameController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  // Cronômetro de 2 minutos (120s)
  Timer? _timer;
  int _startSeconds = 120;

  // URL do backend
  final String baseUrl = 'http://26.239.180.177:8020';

  @override
  void dispose() {
    _timer?.cancel();
    _usernameController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _startSeconds = 120;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_startSeconds == 0) {
        if (mounted) {
          setState(() {
            timer.cancel();
            _abortOperation('TEMPO ESGOTADO! A OPERAÇÃO DE 2 MINUTOS EXPIROU.');
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _startSeconds--;
          });
        }
      }
    });
  }

  void _abortOperation(String message) {
    setState(() {
      _step = 1;
      _codeController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
      _errorMessage = message;
    });
  }

  String get _timerFormatted {
    final minutes = (_startSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_startSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // --- REQUISIÇÕES HTTP ---

  Future<void> _requestCode() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      setState(() => _errorMessage = 'INFORME O ID DO OPERADOR.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/request-reset'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == 'sucesso') {
        setState(() => _step = 2);
        _startTimer();
      } else {
        setState(
          () =>
              _errorMessage =
                  (data['mensagem'] ?? 'USUÁRIO NÃO ENCONTRADO.')
                      .toString()
                      .toUpperCase(),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = 'ERRO DE CONEXÃO COM O SERVIDOR DO JOGO.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _errorMessage = 'INFORME O CÓDIGO RECEBIDO POR E-MAIL.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/validate-code'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': _usernameController.text.trim(),
          'code': code,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == 'sucesso') {
        _timer?.cancel();
        setState(() => _step = 3);
      } else {
        setState(
          () =>
              _errorMessage =
                  (data['mensagem'] ?? 'CÓDIGO INCORRETO OU EXPIRADO.')
                      .toString()
                      .toUpperCase(),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = 'ERRO AO COMUNICAR COM O SERVIDOR.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final pass = _passwordController.text;
    final confirmPass = _confirmPasswordController.text;
    final username = _usernameController.text.trim();

    if (pass.isEmpty || confirmPass.isEmpty) {
      setState(() => _errorMessage = 'PREENCHA OS DOIS CAMPOS DE SENHA.');
      return;
    }

    if (pass != confirmPass) {
      setState(() {
        _errorMessage = 'AS SENHAS NÃO COINCIDEM. TENTE NOVAMENTE.';
        _passwordController.clear();
        _confirmPasswordController.clear();
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // [MODIFICADO] Salt descontinuado: o hash agora é gerado apenas com a senha pura
      final bytes = utf8.encode(pass);
      final passwordHash = sha256.convert(bytes).toString();

      final response = await http.post(
        Uri.parse('$baseUrl/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'code': _codeController.text.trim(),
          'new_password_hash': passwordHash,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == 'sucesso') {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF00D2FF),
            content: Text(
              'SENHA REDEFINIDA COM SUCESSO! FAÇA LOGIN COM A NOVA SENHA.',
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
        Navigator.pop(context);
      } else {
        setState(
          () =>
              _errorMessage =
                  (data['mensagem'] ?? 'ERRO AO REDEFINIR A SENHA.')
                      .toString()
                      .toUpperCase(),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = 'ERRO DE COMUNICAÇÃO NO SALVAMENTO.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- HELPERS DE INTERFACE ---

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
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
    TextInputType? keyboardType,
    TextAlign textAlign = TextAlign.start,
    double? letterSpacing,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: keyboardType,
      textAlign: textAlign,
      style: GoogleFonts.shareTechMono(
        color: Colors.white,
        fontSize: 14,
        letterSpacing: letterSpacing,
      ),
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
                  // --- CABEÇALHO COM O LOGO DO STAR ORPHANS ---
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
                          'REDEFINIÇÃO DE CREDENCIAIS v1.0',
                          style: GoogleFonts.shareTechMono(
                            fontSize: 10,
                            color: colorCyan.withValues(alpha: 0.8),
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // --- MENSAGEM DE ERRO ---
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF2A6D).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFFFF2A6D).withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.shareTechMono(
                          color: const Color(0xFFFF2A6D),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // --- PASSO 1: USERNAME ---
                  if (_step == 1) ...[
                    _buildFieldLabel('ID DO OPERADOR'),
                    const SizedBox(height: 6),
                    _buildTextField(
                      controller: _usernameController,
                      hintText: 'Nome',
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 28),
                    _buildPrimaryButton(
                      text: 'SOLICITAR CÓDIGO',
                      onPressed: _isLoading ? null : _requestCode,
                    ),
                  ],

                  // --- PASSO 2: CÓDIGO + TIMER ---
                  if (_step == 2) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A0E14),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.amberAccent.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        'TEMPO RESTANTE: $_timerFormatted',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.shareTechMono(
                          color: Colors.amberAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildFieldLabel('CÓDIGO DE SEGURANÇA'),
                    const SizedBox(height: 6),
                    _buildTextField(
                      controller: _codeController,
                      hintText: '000000',
                      icon: Icons.vpn_key_outlined,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      letterSpacing: 4.0,
                    ),
                    const SizedBox(height: 28),
                    _buildPrimaryButton(
                      text: 'VALIDAR CÓDIGO',
                      onPressed: _isLoading ? null : _verifyCode,
                    ),
                  ],

                  // --- PASSO 3: NOVA SENHA ---
                  if (_step == 3) ...[
                    _buildFieldLabel('NOVA CHAVE DE ACESSO'),
                    const SizedBox(height: 6),
                    _buildTextField(
                      controller: _passwordController,
                      hintText: '••••••••',
                      isPassword: true,
                      icon: Icons.lock_outline,
                    ),
                    const SizedBox(height: 20),
                    _buildFieldLabel('CONFIRMAR NOVA CHAVE DE ACESSO'),
                    const SizedBox(height: 6),
                    _buildTextField(
                      controller: _confirmPasswordController,
                      hintText: '••••••••',
                      isPassword: true,
                      icon: Icons.lock_reset,
                    ),
                    const SizedBox(height: 28),
                    _buildPrimaryButton(
                      text: 'ATUALIZAR CHAVE',
                      onPressed: _isLoading ? null : _resetPassword,
                    ),
                  ],

                  const SizedBox(height: 24),

                  // --- RODAPÉ COM LOGO DA XAMÃ CENTRALIZADO ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        child: Text(
                          'VOLTAR AO LOGIN',
                          style: GoogleFonts.shareTechMono(
                            color: Colors.white54,
                            fontSize: 10,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
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

  // Botão Padrão Cyberpunk
  Widget _buildPrimaryButton({
    required String text,
    required VoidCallback? onPressed,
  }) {
    const colorCyan = Color(0xFF00D2FF);

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF0066FF),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
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
                text,
                style: GoogleFonts.shareTechMono(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
    );
  }
}
