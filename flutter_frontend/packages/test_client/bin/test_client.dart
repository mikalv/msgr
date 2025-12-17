import 'dart:io';
import 'package:logging/logging.dart';
import 'package:libmsgr/src/registration_service.dart';

void main(List<String> arguments) async {
  // Setup logging
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('[${record.level.name}] ${record.loggerName}: ${record.message}');
    if (record.error != null) {
      print('  Error: ${record.error}');
    }
    if (record.stackTrace != null) {
      print('  Stack trace: ${record.stackTrace}');
    }
  });

  final log = Logger('TestClient');

  log.info('=== LibMsgr Test Client ===');
  log.info('Testing authentication flow against backend');

  try {

    // Test 1: Request authentication code
    log.info('\n--- Test 1: Request Authentication Code ---');
    final reg = RegistrationService();

    // Use email for testing (easier than SMS)
    final testEmail = 'test+${DateTime.now().millisecondsSinceEpoch}@example.com';
    log.info('Requesting code for email: $testEmail');

    final challenge = await reg.requestForSignInCodeEmail(testEmail);

    if (challenge == null) {
      log.severe('Failed to request authentication code');
      exit(1);
    }

    log.info('✅ Authentication challenge created:');
    log.info('  Challenge ID: ${challenge.id}');
    log.info('  Channel: ${challenge.channel}');
    log.info('  Target: ${challenge.targetHint}');
    log.info('  Debug Code: ${challenge.debugCode}');
    log.info('  Expires at: ${challenge.expiresAt}');

    // Test 2: Verify code and get user token
    log.info('\n--- Test 2: Verify Code ---');

    if (challenge.debugCode == null) {
      log.severe('No debug code available. Please check backend configuration.');
      exit(1);
    }

    log.info('Submitting verification code: ${challenge.debugCode}');
    final user = await reg.submitEmailCodeForToken(
      challengeId: challenge.id,
      code: challenge.debugCode!,
      displayName: 'Test User',
    );

    if (user == null) {
      log.severe('Failed to verify code and get user token');
      exit(1);
    }

    log.info('✅ User authenticated:');
    log.info('  User ID: ${user.id}');
    log.info('  Email: ${user.email}');
    log.info('  Display Name: ${user.displayName}');
    log.info('  Access Token: ${user.accessToken.substring(0, 20)}...');
    log.info('  Refresh Token: ${user.refreshToken.substring(0, 20)}...');

    // Test 3: List teams
    log.info('\n--- Test 3: List Teams ---');
    final teams = await reg.listMyTeams(user.accessToken);

    log.info('✅ User has ${teams.length} team(s):');
    for (final team in teams) {
      log.info('  - ${team.name}: ${team.description}');
    }

    // Test 4: Create a new team
    log.info('\n--- Test 4: Create New Team ---');
    final teamName = 'test-team-${DateTime.now().millisecondsSinceEpoch}';
    final teamDesc = 'Test team created by test client';

    log.info('Creating team: $teamName');
    final newTeam = await reg.createNewTeam(
      teamName,
      teamDesc,
      user.accessToken,
    );

    if (newTeam == null) {
      log.severe('Failed to create team');
      exit(1);
    }

    log.info('✅ Team created:');
    log.info('  Team ID: ${newTeam.id}');
    log.info('  Name: ${newTeam.name}');
    log.info('  Description: ${newTeam.description}');

    // Test 5: Select team and get team token
    log.info('\n--- Test 5: Select Team ---');
    log.info('Selecting team: ${newTeam.name}');

    final selectResponse = await reg.selectTeamForToken(
      teamName: newTeam.name,
      token: user.accessToken,
    );

    if (selectResponse == null) {
      log.severe('Failed to select team');
      exit(1);
    }

    final teamAccessToken = selectResponse['teamAccessToken'] as String?;
    if (teamAccessToken == null) {
      log.severe('No team access token in response');
      exit(1);
    }

    log.info('✅ Team selected:');
    log.info('  Team Access Token: ${teamAccessToken.substring(0, 20)}...');

    // Test 6: Create profile for team
    log.info('\n--- Test 6: Create Profile ---');
    final username = 'testuser${DateTime.now().millisecondsSinceEpoch}';

    log.info('Creating profile with username: $username');
    final profile = await reg.createProfileForTeam(
      teamName: newTeam.name,
      token: user.accessToken,
      username: username,
      firstName: 'Test',
      lastName: 'User',
    );

    if (profile == null) {
      log.severe('Failed to create profile');
      exit(1);
    }

    log.info('✅ Profile created:');
    log.info('  Profile ID: ${profile.id}');
    log.info('  Username: ${profile.username}');
    log.info('  Display Name: ${profile.displayName}');
    log.info('  Mode: ${profile.mode}');

    // Test 7: Verify we can list teams again and see the new team
    log.info('\n--- Test 7: Verify Team List ---');
    final teamsAfter = await reg.listMyTeams(user.accessToken);

    final foundTeam = teamsAfter.any((t) => t.name == newTeam.name);
    if (!foundTeam) {
      log.severe('New team not found in team list!');
      exit(1);
    }

    log.info('✅ Team list verified - new team is present');

    // All tests passed!
    log.info('\n=== ✅ All Tests Passed! ===');
    log.info('Summary:');
    log.info('  ✅ Authentication challenge created');
    log.info('  ✅ Code verified and user token obtained');
    log.info('  ✅ Teams listed');
    log.info('  ✅ New team created');
    log.info('  ✅ Team selected and team token obtained');
    log.info('  ✅ Profile created for team');
    log.info('  ✅ Team list verified');

  } catch (error, stackTrace) {
    final log = Logger('TestClient');
    log.severe('Test failed with error: $error');
    log.severe('Stack trace: $stackTrace');
    exit(1);
  }
}
