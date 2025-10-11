import 'package:flutter/material.dart';
import 'package:messngr/features/chat/widgets/chat_composer.dart';

class ChatComposerDemo extends StatefulWidget {
  const ChatComposerDemo({super.key});

  @override
  State<ChatComposerDemo> createState() => _ChatComposerDemoState();
}

class _ChatComposerDemoState extends State<ChatComposerDemo> {
  late final ChatComposerController _controller;
  final ValueNotifier<ChatComposerResult?> _lastResult = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    _controller = ChatComposerController();
  }

  @override
  void dispose() {
    _controller.dispose();
    _lastResult.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ChatComposer-demo')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ValueListenableBuilder<ChatComposerResult?>(
                valueListenable: _lastResult,
                builder: (context, result, _) {
                  if (result == null) {
                    return const Center(
                      child: Text('Send en melding for å se resultater her.'),
                    );
                  }
                  return _ComposerResultView(result: result);
                },
              ),
            ),
            ChatComposer(
              controller: _controller,
              onSubmit: (result) {
                debugPrint('Sendt: ${result.text}');
                debugPrint('Vedlegg: ${result.attachments.length}');
                debugPrint('Kommando: ${result.command?.name}');
                debugPrint('Voice note: ${result.voiceNote?.formattedDuration}');
                _lastResult.value = result;
              },
              isSending: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposerResultView extends StatelessWidget {
  const _ComposerResultView({required this.result});

  final ChatComposerResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      children: [
        Text('Tekst: ${result.text}', style: theme.textTheme.bodyLarge),
        const SizedBox(height: 8),
        Text('Kommando: ${result.command?.name ?? '-'}'),
        const SizedBox(height: 8),
        Text('Vedlegg (${result.attachments.length}):'),
        for (final attachment in result.attachments)
          ListTile(
            leading: const Icon(Icons.attachment),
            title: Text(attachment.name),
            subtitle: Text(attachment.humanSize),
          ),
        const SizedBox(height: 8),
        Text('Voice note: ${result.voiceNote?.formattedDuration ?? 'Ingen'}'),
      ],
    );
  }
}

void main() {
  runApp(const MaterialApp(home: ChatComposerDemo()));
}
