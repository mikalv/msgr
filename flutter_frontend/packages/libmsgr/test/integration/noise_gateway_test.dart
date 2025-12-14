/// Integration test for Noise Gateway
/// Tests full flow: Flutter Client -> Rust Gateway -> Elixir Backend
///
/// Run this test with:
/// dart test/integration/noise_gateway_test.dart --alice
/// dart test/integration/noise_gateway_test.dart --bob
///
/// Or run both together for full integration test

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

final logger = Logger('NoiseGatewayTest');

class NoiseClient {
  final String name;
  final String rustGatewayUrl;
  final http.Client client = http.Client();

  String? sessionId;
  String? sessionToken;
  String? accountId;
  String? profileId;

  NoiseClient({required this.name, this.rustGatewayUrl = 'http://localhost:8443'});

  /// Step 1: Create Noise handshake with Rust Gateway
  Future<bool> createNoiseHandshake() async {
    logger.info('[$name] Creating Noise handshake...');

    try {
      final url = Uri.parse('$rustGatewayUrl/noise/handshake');
      final response = await client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'pattern': 'NKpsk0', // Same pattern as Rust expects
          'psk': '29GIxHhIZtoOxJAcTWO+xj77TCJSHfFmERNDZBFASVQ=', // Test PSK
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        sessionId = data['session_id'];
        sessionToken = data['session_token'];

        logger.info('[$name] Handshake successful!');
        logger.info('[$name]   Session ID: $sessionId');
        logger.info('[$name]   Token: ${sessionToken?.substring(0, 16)}...');
        return true;
      } else {
        logger.severe('[$name] Handshake failed: ${response.statusCode}');
        logger.severe('[$name] Response: ${response.body}');
        return false;
      }
    } catch (e) {
      logger.severe('[$name] Error creating handshake: $e');
      return false;
    }
  }

  /// Step 2: Request OTP challenge
  Future<String?> requestChallenge(String email) async {
    logger.info('[$name] Requesting OTP challenge for $email...');

    try {
      final url = Uri.parse('$rustGatewayUrl/api/auth/challenge');
      final response = await client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Noise-Token': sessionToken!,
        },
        body: jsonEncode({
          'channel': 'email',
          'identifier': email,
          'device_id': 'test-device-$name',
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final challengeId = data['id'];
        logger.info('[$name] Challenge created: $challengeId');
        return challengeId;
      } else {
        logger.severe('[$name] Challenge request failed: ${response.statusCode}');
        logger.severe('[$name] Response: ${response.body}');
        return null;
      }
    } catch (e) {
      logger.severe('[$name] Error requesting challenge: $e');
      return null;
    }
  }

  /// Step 3: Verify OTP code (in real scenario, user enters code from email)
  Future<bool> verifyCode(String challengeId, String code) async {
    logger.info('[$name] Verifying OTP code...');

    try {
      final url = Uri.parse('$rustGatewayUrl/api/auth/verify');
      final response = await client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Noise-Token': sessionToken!,
        },
        body: jsonEncode({
          'challenge_id': challengeId,
          'code': code,
          'session_id': sessionId,
          'session_token': sessionToken,
          'display_name': name,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        accountId = data['account']?['id'];
        profileId = data['profile']?['id'];

        logger.info('[$name] OTP verified! Account linked to session.');
        logger.info('[$name]   Account ID: $accountId');
        logger.info('[$name]   Profile ID: $profileId');
        return true;
      } else {
        logger.severe('[$name] Verification failed: ${response.statusCode}');
        logger.severe('[$name] Response: ${response.body}');
        return false;
      }
    } catch (e) {
      logger.severe('[$name] Error verifying code: $e');
      return false;
    }
  }

  /// Step 4: Send a message (via Rust Gateway -> Elixir)
  Future<bool> sendMessage(String destProfileId, String message) async {
    logger.info('[$name] Sending message: "$message"');

    try {
      final url = Uri.parse('$rustGatewayUrl/api/messages');
      final response = await client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Noise-Token': sessionToken!,
        },
        body: jsonEncode({
          'to_profile_id': destProfileId,
          'content': message,
          'type': 'text',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        logger.info('[$name] Message sent successfully!');
        return true;
      } else {
        logger.severe('[$name] Message send failed: ${response.statusCode}');
        logger.severe('[$name] Response: ${response.body}');
        return false;
      }
    } catch (e) {
      logger.severe('[$name] Error sending message: $e');
      return false;
    }
  }

  void close() {
    client.close();
  }
}

/// Interactive CLI mode
Future<void> runInteractive(String name) async {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });

  final client = NoiseClient(name: name);

  print('\n=== $name\'s Noise Gateway Integration Test ===\n');

  // Step 1: Noise handshake
  print('Step 1: Creating Noise handshake with Rust Gateway...');
  if (!await client.createNoiseHandshake()) {
    print('❌ Failed to create handshake');
    return;
  }
  print('✅ Noise handshake successful!\n');

  // Step 2: Request OTP
  stdout.write('Enter email address: ');
  final email = stdin.readLineSync()?.trim() ?? '';

  final challengeId = await client.requestChallenge(email);
  if (challengeId == null) {
    print('❌ Failed to request challenge');
    return;
  }
  print('✅ Challenge requested!\n');

  // Step 3: Verify OTP
  stdout.write('Enter OTP code from email: ');
  final code = stdin.readLineSync()?.trim() ?? '';

  if (!await client.verifyCode(challengeId, code)) {
    print('❌ Failed to verify code');
    return;
  }
  print('✅ Authenticated!\n');

  // Step 4: Send messages
  print('Session Info:');
  print('  Session ID: ${client.sessionId}');
  print('  Account ID: ${client.accountId}');
  print('  Profile ID: ${client.profileId}');
  print('  Token: ${client.sessionToken?.substring(0, 20)}...\n');

  // Interactive message loop
  while (true) {
    stdout.write('\nEnter message (or "quit"): ');
    final message = stdin.readLineSync()?.trim() ?? '';

    if (message.toLowerCase() == 'quit') {
      break;
    }

    stdout.write('To profile ID: ');
    final destProfileId = stdin.readLineSync()?.trim() ?? '';

    await client.sendMessage(destProfileId, message);
  }

  client.close();
  print('\n👋 Goodbye!');
}

/// Automated test mode (for CI)
Future<void> runAutomated() async {
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.message}');
  });

  print('\n=== Running Automated Integration Test ===\n');

  // Create two clients
  final alice = NoiseClient(name: 'Alice');
  final bob = NoiseClient(name: 'Bob');

  try {
    // Both create handshakes
    print('\n--- Phase 1: Noise Handshakes ---');
    if (!await alice.createNoiseHandshake()) {
      throw Exception('Alice handshake failed');
    }
    if (!await bob.createNoiseHandshake()) {
      throw Exception('Bob handshake failed');
    }
    print('✅ Both handshakes successful\n');

    // Note: In automated mode, we can't complete OTP verification
    // This would require either:
    // 1. A test mode in Elixir that auto-approves
    // 2. Mock email service that we can read from
    // 3. Pre-created test accounts

    print('⚠️  Automated test limited to handshake verification');
    print('   Full flow requires OTP verification');
    print('   Run with --alice or --bob for interactive mode\n');

  } finally {
    alice.close();
    bob.close();
  }
}

void main(List<String> args) async {
  if (args.contains('--alice')) {
    await runInteractive('Alice');
  } else if (args.contains('--bob')) {
    await runInteractive('Bob');
  } else if (args.contains('--help')) {
    print('''
Noise Gateway Integration Test

Usage:
  dart test/integration/noise_gateway_test.dart [OPTIONS]

Options:
  --alice       Run as Alice (interactive)
  --bob         Run as Bob (interactive)
  --help        Show this help message

Interactive Mode:
  1. Creates Noise handshake with Rust Gateway
  2. Requests OTP challenge
  3. Verifies OTP code
  4. Sends messages through the gateway

Example:
  # Terminal 1
  dart test/integration/noise_gateway_test.dart --alice

  # Terminal 2
  dart test/integration/noise_gateway_test.dart --bob
''');
  } else {
    await runAutomated();
  }
}
