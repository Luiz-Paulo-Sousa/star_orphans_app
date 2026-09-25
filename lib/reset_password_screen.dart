import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:crypto/crypto.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({Key? key}) : super(key: key);

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

  // URL do backend no seu servidor/Docker
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
        setState(() {
          timer.cancel();
          _abortOperation('Tempo esgotado! A operação de 2 minutos expirou.');
        });
      } else {
        setState(() {
          _startSeconds--;
        });
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
      setState(() => _errorMessage = 'Informe o username do jogador.');
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
          () => _errorMessage = data['mensagem'] ?? 'Usuário não encontrado.',
        );
      }
    } catch (e) {
      setState(() => _errorMessage = 'Erro de conexão com o servidor do jogo.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _errorMessage = 'Informe o código recebido por e-mail.');
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
                  data['mensagem'] ?? 'Código incorreto ou expirado.',
        );
      }
    } catch (e) {
      setState(() => _errorMessage = 'Erro ao comunicar com o servidor.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final pass = _passwordController.text;
    final confirmPass = _confirmPasswordController.text;
    final username = _usernameController.text.trim();

    if (pass.isEmpty || confirmPass.isEmpty) {
      setState(() => _errorMessage = 'Preencha os dois campos de senha.');
      return;
    }

    if (pass != confirmPass) {
      setState(() {
        _errorMessage = 'As senhas não coincidem. Tente novamente.';
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
      // 1. Aplica o Salt (senha + username) idêntico ao processo de Login
      final combinacao = pass + username;
      final bytes = utf8.encode(combinacao);
      final passwordHash = sha256.convert(bytes).toString();

      // 2. Envia o hash ajustado para o servidor
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
          const SnackBar(
            content: Text(
              'Senha redefinida com sucesso! Faça login com a nova senha.',
            ),
            backgroundColor: Colors.cyan,
          ),
        );
        Navigator.pop(context); // Retorna para a tela de Login
      } else {
        setState(
          () =>
              _errorMessage = data['mensagem'] ?? 'Erro ao redefinir a senha.',
        );
      }
    } catch (e) {
      setState(() => _errorMessage = 'Erro de comunicação no salvamento.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- ELEMENTOS VISUAIS STAR ORPHANS ---

  InputDecoration _buildInputDecoration(String labelText, IconData icon) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(color: Colors.white70),
      prefixIcon: Icon(icon, color: Colors.cyanAccent),
      filled: true,
      fillColor: const Color(0xFF161B22),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF30363D)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.cyanAccent, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14), // Fundo espaço profundo
      appBar: AppBar(
        title: const Text(
          'REDEFINIÇÃO DE CREDENCIAIS',
          style: TextStyle(
            letterSpacing: 1.2,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22).withOpacity(0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.cyanAccent.withOpacity(0.05),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Ícone do topo estilo Sci-Fi
                const Icon(
                  Icons.security_rounded,
                  size: 48,
                  color: Colors.cyanAccent,
                ),
                const SizedBox(height: 16),

                // Mensagem de Erro se houver
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.redAccent),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // --- PASSO 1: INFORMAR USERNAME ---
                if (_step == 1) ...[
                  const Text(
                    'Informe seu username para enviarmos um código de validação ao e-mail cadastrado.',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _usernameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _buildInputDecoration(
                      'Username do Jogador',
                      Icons.person_outline,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildGlowButton(
                    text: 'SOLICITAR CÓDIGO',
                    onPressed: _isLoading ? null : _requestCode,
                  ),
                ],

                // --- PASSO 2: CÓDIGO + TIMEOUT ---
                if (_step == 2) ...[
                  const Text(
                    'Código enviado ao e-mail da conta!',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  // Display do Cronômetro sci-fi
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.amberAccent.withOpacity(0.5),
                      ),
                    ),
                    child: Text(
                      'TEMPO RESTANTE: $_timerFormatted',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.amberAccent,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      color: Colors.white,
                      letterSpacing: 4.0,
                    ),
                    textAlign: TextAlign.center,
                    decoration: _buildInputDecoration(
                      'Código de 6 dígitos',
                      Icons.vpn_key_outlined,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildGlowButton(
                    text: 'VALIDAR CÓDIGO',
                    onPressed: _isLoading ? null : _verifyCode,
                  ),
                ],

                // --- PASSO 3: DIGITAR NOVA SENHA ---
                if (_step == 3) ...[
                  const Text(
                    'Código validado com sucesso. Defina sua nova senha de acesso ao jogo:',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: _buildInputDecoration(
                      'Nova Senha',
                      Icons.lock_outline,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: _buildInputDecoration(
                      'Repetir Nova Senha',
                      Icons.lock_reset,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildGlowButton(
                    text: 'ATUALIZAR SENHA',
                    onPressed: _isLoading ? null : _resetPassword,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Botão em Gradiente Sci-Fi
  Widget _buildGlowButton({
    required String text,
    required VoidCallback? onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          colors: [Color(0xFF7B2CBF), Color(0xFF00B4D8)], // Roxo para Ciano
        ),
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child:
            _isLoading
                ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                : Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
      ),
    );
  }
}
