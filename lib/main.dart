import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Companion',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  String _mensagemStatus = '';

  Future<void> _realizarLogin() async {
    setState(() {
      _isLoading = true;
      _mensagemStatus = '';
    });

    String username = _usernameController.text.trim();
    String senhaPura = _passwordController.text;

    if (username.isEmpty || senhaPura.isEmpty) {
      setState(() {
        _mensagemStatus = 'Preencha todos os campos!';
        _isLoading = false;
      });
      return;
    }

    // 1. O salt é o próprio username
    String salt = username;
    String combinacao = senhaPura + salt;

    // 2. Gera o Hash SHA-256
    var bytes = utf8.encode(combinacao);
    var digest = sha256.convert(bytes);
    String passwordHash = digest.toString();

    // 3. Endpoint da API
    // Para Emulador Android use '10.0.2.2'. Para Web ou Desktop use 'localhost'
    var url = Uri.parse('http://26.239.180.177:8020/login');

    try {
      var response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"username": username, "password_hash": passwordHash}),
      );

      var dados = jsonDecode(response.body);

      if (response.statusCode == 200) {
        setState(() {
          _mensagemStatus =
              "Sucesso: ${dados['mensagem']} (ID: ${dados['account_id']})";
        });
      } else {
        setState(() {
          _mensagemStatus = "Erro: ${dados['mensagem']}";
        });
      }
    } catch (e) {
      setState(() {
        _mensagemStatus = "Erro de conexão: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login - App Companion')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Senha',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                  onPressed: _realizarLogin,
                  child: const Text('Entrar'),
                ),
            const SizedBox(height: 16),
            Text(
              _mensagemStatus,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
