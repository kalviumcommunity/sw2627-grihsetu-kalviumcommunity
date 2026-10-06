import 'package:flutter/material.dart';

class GrihSetuApp extends StatelessWidget {
  const GrihSetuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GrihSetu',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
        ),
      ),
      home: const Scaffold(
        body: Center(
          child: Text(
            'GrihSetu',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}