import 'package:flutter/material.dart';
import 'package:messngr/config/themedata.dart';
import 'package:messngr/ui/widgets/scaffolds/base_scaffold.dart';

class ErrorScreen extends StatefulWidget {
  final dynamic error;
  const ErrorScreen({super.key, required this.error});

  @override
  State<ErrorScreen> createState() => _ErrorScreenState();
}

class _ErrorScreenState extends State<ErrorScreen> {
  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      appBar: AppBar(
        title: const Text('Whops! An error occurred'),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: 400,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  'Error: ${widget.error.toString()}',
                  style: errorTextStyle,
                ),
                const SizedBox(height: 16.0),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Go back'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
