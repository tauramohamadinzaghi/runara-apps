import 'package:flutter/material.dart';

class TunanetraPageScreen extends StatelessWidget {
  const TunanetraPageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tunanetra Page'),
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: const Text(
          'This is the Tunanetra page.',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}