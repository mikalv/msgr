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
                      content: _FinalizeStep(
                        session: controller.session,
                        controller: controller,
                        bridge: widget.bridge,
                      ),
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

    final metadata = widget.controller.session.metadata;
    final oauthMeta = _asStringMap(metadata['oauth']);
    Map<String, dynamic> consentPlan = _asStringMap(metadata['consent_plan']);
    if (consentPlan.isEmpty) {
      consentPlan = _asStringMap(oauthMeta['consent_plan']);
    }

    final provider = _asStringMap(oauthMeta['provider']);
    final isRscRequired = _isTruthy(oauthMeta['requires_resource_specific_consent']) ||
        _isTruthy(provider['requires_resource_specific_consent']) ||
        _isTruthy(_asStringMap(consentPlan['resource_specific_consent'])['required']);
    final error = widget.controller.error;

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
        if (error != null) ...[
          _ErrorNotice(message: error.toString()),
          const SizedBox(height: 12),
        ],
        if (consentPlan.isNotEmpty) ...[
          _ConsentPlanCard(plan: consentPlan, isRscRequired: isRscRequired),
          const SizedBox(height: 12),
        ],
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

Map<String, dynamic> _asStringMap(dynamic value) {
  if (value is Map) {
    return value.map((key, dynamic val) => MapEntry(key.toString(), val));
  }
  return const <String, dynamic>{};
}

List<Map<String, dynamic>> _asMapList(dynamic value) {
  if (value is List) {
    return value
        .map((item) => _asStringMap(item))
        .where((map) => map.isNotEmpty)
        .toList(growable: false);
  }
  if (value is Map) {
    final map = _asStringMap(value);
    return map.isEmpty ? const [] : [map];
  }
  return const [];
}

List<String> _asStringList(dynamic value) {
  if (value is List) {
    return value
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  if (value is String && value.isNotEmpty) {
    return [value];
  }
  return const [];
}

bool _isTruthy(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is String) {
    final normalised = value.toLowerCase().trim();
    return {
      'true',
      '1',
      'yes',
      'required',
      'on',
    }.contains(normalised);
  }
  return false;
}

String? _stringValue(dynamic value) {
  if (value == null) {
    return null;
  }
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

class _ConsentPlanCard extends StatelessWidget {
  const _ConsentPlanCard({required this.plan, required this.isRscRequired});

  final Map<String, dynamic> plan;
  final bool isRscRequired;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final steps = _asMapList(plan['steps']);
    final rsc = _asStringMap(plan['resource_specific_consent']);
    final headline = plan['title']?.toString() ?? 'Samtykkeveiledning';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(headline, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            for (var index = 0; index < steps.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        '${index + 1}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            steps[index]['title']?.toString() ?? 'Steg ${index + 1}',
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            steps[index]['description']?.toString() ??
                                steps[index]['note']?.toString() ??
                                'Følg instruksjonen i dialogen.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (rsc.isNotEmpty)
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isRscRequired
                      ? theme.colorScheme.errorContainer
                      : theme.colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.admin_panel_settings,
                          color: isRscRequired
                              ? theme.colorScheme.onErrorContainer
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            rsc['title']?.toString() ?? 'Resource-specific consent',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: isRscRequired
                                  ? theme.colorScheme.onErrorContainer
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      rsc['summary']?.toString() ??
                          rsc['note']?.toString() ??
                          'Velg team/kanaler når Microsoft ber om det.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isRscRequired
                            ? theme.colorScheme.onErrorContainer
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (isRscRequired) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Denne leietakeren krever at du velger ressurser før Msgr kan synkronisere Teams.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium,
            ),
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
  const _FinalizeStep({
    required this.session,
    required this.controller,
    required this.bridge,
  });

  final BridgeAuthSession session;
  final BridgeSessionController controller;
  final BridgeCatalogEntry bridge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metadata = session.metadata;
    final oauthMeta = _asStringMap(metadata['oauth']);
    final provider = _asStringMap(oauthMeta['provider']);
    final plan = _asStringMap(metadata['consent_plan']);
    final scopes = _asStringList(metadata['scopes']);
    final rawMetadata = metadata.isEmpty
        ? null
        : const JsonEncoder.withIndent('  ').convert(metadata);

    final bool isRscRequired = _isTruthy(oauthMeta['requires_resource_specific_consent']) ||
        _isTruthy(provider['requires_resource_specific_consent']) ||
        _isTruthy(_asStringMap(plan['resource_specific_consent'])['required']);

    String _credentialStatusLabel(String? status) {
      switch (status) {
        case 'token_stored':
          return 'Token lagret i credential vault';
        case 'awaiting_consent':
        case 'awaiting_user':
          return 'Venter på administrator-samtykke';
        case 'completing':
          return 'Fullfører kobling';
        default:
          return status ?? (session.isLinked ? 'Koblet' : 'Ikke klart ennå');
      }
    }

    final statusLabel =
        oauthMeta.isEmpty ? null : _credentialStatusLabel(_stringValue(oauthMeta['status']));
    final initiatedAt = _stringValue(oauthMeta['initiated_at']);
    final completedAt = _stringValue(oauthMeta['completed_at']);
    final credentialRef = _stringValue(oauthMeta['credential_ref']);
    final providerName =
        _stringValue(provider['display_name']) ?? _stringValue(provider['tenant']);

    final infoRows = <_InfoRow>[];
    if (statusLabel != null) {
      infoRows.add(_InfoRow(label: 'Status', value: statusLabel));
    }
    if (initiatedAt != null) {
      infoRows.add(_InfoRow(label: 'Startet', value: initiatedAt));
    }
    if (completedAt != null) {
      infoRows.add(_InfoRow(label: 'Fullført', value: completedAt));
    }
    if (credentialRef != null) {
      infoRows.add(_InfoRow(label: 'Credential-ref', value: credentialRef));
    }
    if (providerName != null) {
      infoRows.add(_InfoRow(label: 'Leverandør', value: providerName));
    }

    final statusText = session.isLinked
        ? 'Broen er koblet! Vi synkroniserer nå Teams-samtalene dine.'
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
        Text(statusText, style: theme.textTheme.titleMedium),
        const SizedBox(height: 16),
        if (controller.error != null) ...[
          _ErrorNotice(message: controller.error.toString()),
          const SizedBox(height: 16),
        ],
        if (oauthMeta.isNotEmpty || infoRows.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Credentialstatus', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (infoRows.isEmpty)
                    Text(
                      'Ingen token er lagret ennå. Fullfør samtykkedialogen i nettleseren.',
                      style: theme.textTheme.bodySmall,
                    )
                  else
                    ...infoRows,
                  if (isRscRequired) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Denne leietakeren krever Resource-Specific Consent. '
                      'Opphev tilgangen og start på nytt dersom scope-valget ble feil.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        if (scopes.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Scope som Msgr ber om', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: scopes.map((scope) => Chip(label: Text(scope))).toList(),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: controller.isBusy
                  ? null
                  : () async {
                      await controller.unlink();
                      if (!context.mounted) return;
                      final messenger = ScaffoldMessenger.of(context);
                      final error = controller.error;
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            error == null
                                ? 'Tilgangen til ${bridge.displayName} er tilbakekalt.'
                                : 'Klarte ikke å oppheve tilgangen: $error',
                          ),
                        ),
                      );
                    },
              icon: controller.isBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.gpp_bad),
              label: Text(controller.isBusy ? 'Opphever…' : 'Opphev tilgang'),
            ),
            const SizedBox(width: 12),
            TextButton.icon(
              onPressed: controller.isBusy
                  ? null
                  : () async {
                      await controller.refresh();
                      if (!context.mounted) return;
                      final messenger = ScaffoldMessenger.of(context);
                      final error = controller.error;
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            error == null
                                ? 'Status oppdatert for ${bridge.displayName}.'
                                : 'Klarte ikke å oppdatere status: $error',
                          ),
                        ),
                      );
                    },
              icon: const Icon(Icons.refresh),
              label: const Text('Oppdater status'),
            ),
          ],
        ),
        if (rawMetadata != null) ...[
          const SizedBox(height: 24),
          ExpansionTile(
            title: const Text('Tekniske detaljer'),
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SelectableText(rawMetadata),
              ),
            ],
          ),
        ],
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
