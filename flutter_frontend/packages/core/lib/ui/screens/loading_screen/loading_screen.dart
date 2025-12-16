import 'package:flutter/material.dart';
import 'package:messngr/ui/widgets/scaffolds/base_scaffold.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      child: Container(),
    );
  }
}
