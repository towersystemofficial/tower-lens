import 'package:flutter/material.dart';

class PlannedFeaturesScreen extends StatelessWidget {
  const PlannedFeaturesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Planned Features')),
      body: const SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [],
        ),
      ),
    );
  }
}
