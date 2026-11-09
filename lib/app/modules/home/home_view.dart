import 'package:flutter/material.dart';

class HomeView extends StatelessWidget {
  const HomeView({required this.dataVersion, super.key});

  final String dataVersion;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Beranda'),
          Text(
            'data_version $dataVersion',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}
