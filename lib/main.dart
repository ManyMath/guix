import 'package:flutter/material.dart';

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PoC Host App',
      home: Scaffold(
        appBar: AppBar(title: const Text('guix-flutter-scripts PoC')),
        body: const Center(child: Text('It works!')),
      ),
    );
  }
}
