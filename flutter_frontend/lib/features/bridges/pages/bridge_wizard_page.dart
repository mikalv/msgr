import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:messngr/features/bridges/models/bridge_auth_session.dart';
import 'package:messngr/features/bridges/models/bridge_catalog_entry.dart';
import 'package:messngr/features/bridges/state/bridge_session_controller.dart';
import 'package:messngr/services/api/bridge_api.dart';
import 'package:messngr/services/api/chat_api.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

class BridgeWizardPage extends StatefulWidget {
  const BridgeWizardPage({
    super.key,
    required this.bridge,
    required this.initialSession,
    required this.api,
  });

  final BridgeCatalogEntry bridge;
  final BridgeAuthSession initialSession;
  final BridgeApi api;

  @override
  State<BridgeWizardPage> createState() => _BridgeWizardPageState();
}

class _BridgeWizardPageState extends State<BridgeWizardPage> {
  int _currentStep = 0;
  final GlobalKey<_BridgeCredentialsFormState> _credentialsKey =
      GlobalKey<_BridgeCredentialsFormState>();

  @override
  Widget build(BuildContext context) {
    final identity = Provider.of<AccountIdentity>(context, listen: false);
    return ChangeNotifierProvider(
      create: (_) => BridgeSessionController(
        identity: identity,
        api: widget.api,
        initialSession: widget.initialSession,
        bridgeId: widget.bridge.id,
      ),
      child: Builder(builder: (context) {
        return Scaffold(
          appBar: AppBar(
            title: Text('Koble til ${widget.bridge.displayName}'),
          ),
          body: SafeArea(
            child: Consumer<BridgeSessionController>(
              builder: (context, controller, _) {
                return Stepper(
                  currentStep: _currentStep,
                  controlsBuilder: (context, details) {
                    return _WizardControls(
                      currentStep: _currentStep,
                      onStepContinue: () => _handleContinue(context, controller),
                      onStepCancel: _currentStep == 0
                          ? null
                          : () {
                              setState(() {
                                _currentStep -= 1;
                              });
                            },
                      isBusy: controller.isBusy,
                      isLinked: controller.session.isLinked,
                    );
                  },
                  steps: [
                    Step(
                      title: const Text('Oversikt'),
                      isActive: _currentStep >= 0,
                      state: _currentStep > 0
                          ? StepState.complete
                          : StepState.indexed,
                      content: _OverviewStep(entry: widget.bridge),
                    ),
                    Step(
                      title: const Text('Autentisering'),
                      isActive: _currentStep >= 1,
                      state: _currentStep > 1
                          ? StepState.complete
                          : StepState.indexed,
                      content: _AuthStep(
                        bridge: widget.bridge,
                        controller: controller,
                        credentialsKey: _credentialsKey,
                        onAuthCompleted: () async {
                          await controller.refresh();
                          if (!mounted) return;
                          if (controller.session.isCompleting ||
                              controller.session.isLinked) {
                            setState(() {
                              _currentStep = 2;
                            });
                          }
                        },
                      ),
                    ),
                    Step(
                      title: const Text('Ferdigstill'),
                      isActive: _currentStep >= 2,
                      state: controller.session.isLinked
                          ? StepState.complete
                          : StepState.indexed,
                      content: _FinalizeStep(session: controller.session),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      }),
    );
  }

  Future<void> _handleContinue(
    BuildContext context,
    BridgeSessionController controller,
  ) async {
    if (_currentStep == 0) {
      setState(() {
        _currentStep = 1;
      });
      return;
    }

    if (_currentStep == 1) {
      if (widget.bridge.authSurface == 'native_form') {
        final formState = _credentialsKey.currentState;
        if (formState == null) {
          setState(() => _currentStep = 2);
          return;
        }
        final valid = formState.validate();
        if (!valid) {
          return;
        }
        final values = formState.value;
        await controller.submitCredentials(values);
        if (!mounted) return;
        if (controller.session.isCompleting || controller.session.isLinked) {
          setState(() => _currentStep = 2);
        }
        return;
      }

      await controller.refresh();
      if (!mounted) return;
      if (controller.session.isCompleting || controller.session.isLinked) {
        setState(() => _currentStep = 2);
      }
      return;
    }

    if (_currentStep == 2) {
      Navigator.of(context).pop(controller.session);
    }
  }
}

class _OverviewStep extends StatelessWidget {
  const _OverviewStep({required this.entry});

  final BridgeCatalogEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          entry.description,
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 16),
        Text('Du trenger:', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final item in entry.prerequisites)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.check_circle_outline),
            title: Text(item),
          ),
        if (entry.oauthMetadata != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              'Vi åpner en sikker nettleser i appen slik at du kan logge inn '
              'hos ${entry.displayName}. Ingen passord lagres i Msgr-klienten.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
      ],
    );
  }
}

class _AuthStep extends StatelessWidget {
  const _AuthStep({
    required this.bridge,
    required this.controller,
    required this.credentialsKey,
    required this.onAuthCompleted,
  });

  final BridgeCatalogEntry bridge;
  final BridgeSessionController controller;
  final GlobalKey<_BridgeCredentialsFormState> credentialsKey;
  final Future<void> Function() onAuthCompleted;

  @override
  Widget build(BuildContext context) {
    switch (bridge.authSurface) {
      case 'embedded_browser':
        return _OAuthStep(
          controller: controller,
          onAuthCompleted: onAuthCompleted,
        );
      case 'native_form':
        return _BridgeCredentialsForm(
          key: credentialsKey,
          fields: bridge.formSchema?['fields'] as List<dynamic>? ?? const [],
        );
      case 'external_device':
        return _DeviceLinkStep(controller: controller);
      default:
        return const Text('Denne broen krever en fremtidig innloggingsflyt.');
    }
  }
}

class _OAuthStep extends StatefulWidget {
  const _OAuthStep({
    required this.controller,
    required this.onAuthCompleted,
  });

  final BridgeSessionController controller;
  final Future<void> Function() onAuthCompleted;

  @override
  State<_OAuthStep> createState() => _OAuthStepState();
}

class _OAuthStepState extends State<_OAuthStep> {
  WebViewController? _webViewController;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    final authUrl = widget.controller.authorizationUrl;
    if (authUrl == null) {
      setState(() {
        _loading = false;
      });
      return;
    }

    final callback = widget.controller.callbackUrl?.toString();
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            setState(() => _loading = false);
          },
          onNavigationRequest: (request) {
            if (callback != null && request.url.startsWith(callback)) {
              widget.onAuthCompleted();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(authUrl);
    _webViewController = controller;
  }

  @override
  Widget build(BuildContext context) {
    final authUrl = widget.controller.authorizationUrl;
    if (authUrl == null) {
      return const Text('Ingen innloggingsadresse tilgjengelig ennå.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Logg inn i det innebygde vinduet under. Vi lukker det automatisk '
          'når innloggingen er ferdig.',
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 360,
          child: Stack(
            children: [
              if (_webViewController != null)
                WebViewWidget(controller: _webViewController!),
              if (_loading)
                const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.tonal(
          onPressed: () async {
            await widget.controller.refresh();
            if (!mounted) return;
            if (widget.controller.session.isCompleting ||
                widget.controller.session.isLinked) {
              await widget.onAuthCompleted();
            }
          },
          child: const Text('Jeg er ferdig – sjekk status'),
        ),
      ],
    );
  }
}

class _BridgeCredentialsForm extends StatefulWidget {
  const _BridgeCredentialsForm({
    super.key,
    required this.fields,
  });

  final List<dynamic> fields;

  @override
  State<_BridgeCredentialsForm> createState() => _BridgeCredentialsFormState();
}

class _BridgeCredentialsFormState extends State<_BridgeCredentialsForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _values = {};

  Map<String, dynamic> get value => _values;

  bool validate() {
    final valid = _formKey.currentState?.validate() ?? false;
    if (valid) {
      _formKey.currentState?.save();
    }
    return valid;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          for (final field in widget.fields)
            _BridgeField(
              schema: field as Map<String, dynamic>? ?? const {},
              onSaved: (key, value) {
                if (key != null) {
                  _values[key] = value;
                }
              },
            ),
        ],
      ),
    );
  }
}

class _BridgeField extends StatelessWidget {
  const _BridgeField({required this.schema, required this.onSaved});

  final Map<String, dynamic> schema;
  final void Function(String?, String?) onSaved;

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController();
    final name = schema['name']?.toString();
    final label = schema['label']?.toString() ?? name ?? 'Felt';
    final type = schema['type']?.toString() ?? 'text';
    final optional = schema['optional'] == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        obscureText: type == 'password',
        keyboardType:
            type == 'number' ? TextInputType.number : TextInputType.text,
        validator: (value) {
          if (!optional && (value == null || value.isEmpty)) {
            return 'Dette feltet må fylles ut';
          }
          return null;
        },
        onSaved: (value) => onSaved(name, value ?? ''),
      ),
    );
  }
}

class _DeviceLinkStep extends StatelessWidget {
  const _DeviceLinkStep({required this.controller});

  final BridgeSessionController controller;

  @override
  Widget build(BuildContext context) {
    final metadata = controller.session.metadata;
    final pollInfo = metadata['poll'] ?? metadata['device_link'];
    final formatted = const JsonEncoder.withIndent('  ').convert(metadata);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Åpne appen du vil koble til og skriv inn koden som vises.'),
        const SizedBox(height: 12),
        if (pollInfo is Map<String, dynamic>)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (pollInfo['code'] != null)
                    Text(
                      pollInfo['code'].toString(),
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(letterSpacing: 2),
                    ),
                  if (pollInfo['expires_at'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Gyldig til: ${pollInfo['expires_at']}',
                      ),
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        FilledButton.tonal(
          onPressed: controller.refresh,
          child: const Text('Oppdater status'),
        ),
        const SizedBox(height: 24),
        ExpansionTile(
          title: const Text('Tekniske detaljer'),
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(formatted),
            ),
          ],
        ),
      ],
    );
  }
}

class _FinalizeStep extends StatelessWidget {
  const _FinalizeStep({required this.session});

  final BridgeAuthSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusText = session.isLinked
        ? 'Broen er koblet! Vi synker nå dine samtaler.'
        : 'Vi fullfører koblingen i bakgrunnen. Dette kan ta litt tid.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          session.isLinked ? Icons.verified : Icons.cloud_sync,
          size: 72,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          statusText,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        if (session.metadata.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: session.metadata.entries
                    .map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text('${entry.key}: ${entry.value}'),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
      ],
    );
  }
}

class _WizardControls extends StatelessWidget {
  const _WizardControls({
    required this.currentStep,
    required this.onStepContinue,
    required this.onStepCancel,
    required this.isBusy,
    required this.isLinked,
  });

  final int currentStep;
  final VoidCallback? onStepContinue;
  final VoidCallback? onStepCancel;
  final bool isBusy;
  final bool isLinked;

  @override
  Widget build(BuildContext context) {
    final continueLabel = switch (currentStep) {
      0 => 'Kom i gang',
      1 => 'Neste',
      _ => isLinked ? 'Fullfør' : 'Lukk',
    };

    return Row(
      children: [
        FilledButton(
          onPressed: isBusy ? null : onStepContinue,
          child: isBusy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(continueLabel),
        ),
        if (onStepCancel != null) ...[
          const SizedBox(width: 12),
          TextButton(
            onPressed: isBusy ? null : onStepCancel,
            child: const Text('Tilbake'),
          ),
        ],
      ],
    );
  }
}
