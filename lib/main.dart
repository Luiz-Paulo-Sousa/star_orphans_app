import 'package:flutter/material.dart';
import 'login_screen.dart'; // Importa o arquivo da tela que criamos

void main() {
  runApp(const CompanionApp());
}

class CompanionApp extends StatelessWidget {
  const CompanionApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Companion',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF12151A),
      ),
      home: const LoginScreen(), // Define a tela inicial
    );
  }
}
