import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app/modules/home/home_view.dart';

void main() => runApp(const NuraApp());

class NuraApp extends StatelessWidget {
  const NuraApp({super.key});

  @override
  Widget build(BuildContext context) =>
      const GetMaterialApp(title: 'Nura', home: HomeView());
}
