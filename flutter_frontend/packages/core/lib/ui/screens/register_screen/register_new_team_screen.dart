import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:libmsgr/libmsgr.dart';
import 'package:core/config/AppNavigation.dart';
import 'package:core/config/themedata.dart';
import 'package:core/providers/auth_provider.dart';
import 'package:core/utils/lower_case_text_formatter.dart';

class RegisterNewTeamScreen extends ConsumerStatefulWidget {
  const RegisterNewTeamScreen({super.key});

  @override
  ConsumerState<RegisterNewTeamScreen> createState() => _RegisterNewTeamScreenState();
}

class _RegisterNewTeamScreenState extends ConsumerState<RegisterNewTeamScreen> {
  final teamNameCtrl = TextEditingController();
  final teamDescCtrl = TextEditingController();

  @override
  void dispose() {
    teamNameCtrl.dispose();
    teamDescCtrl.dispose();
    super.dispose();
  }

  Future<void> _createTeam(BuildContext context) async {
    final authState = ref.read(authProvider);
    final currentUser = authState.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in first')),
      );
      return;
    }

    final teamName = teamNameCtrl.text.trim();
    final teamDesc = teamDescCtrl.text.trim();

    if (teamName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a team name')),
      );
      return;
    }

    try {
      final reg = RegistrationService();
      final team = await reg.createNewTeam(
        teamName,
        teamDesc,
        currentUser.accessToken,
      );

      if (team != null && mounted) {
        ref.read(authProvider.notifier).setCurrentTeam(team);

        // Add team to the list
        final teams = List<Team>.from(authState.teams);
        if (!teams.any((t) => t.name == team.name)) {
          teams.add(team);
          ref.read(authProvider.notifier).setTeams(teams);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Team "${team.name}" created successfully!')),
        );

        // Navigate to create profile screen
        context.go(AppNavigation.createProfilePath);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create team: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: const [
          Icon(Icons.search),
          SizedBox(
            width: 10,
          )
        ],
        elevation: 3.0,
        centerTitle: true,
        title: const Text(
          'Create new team',
          style: TextStyle(
            fontSize: 25,
          ),
        ),
        backgroundColor: Colors.purple,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              child: SizedBox(
                width: 400,
                child: Column(
                  children: [
                    const Text(
                      'Create team',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 32),
                    ),
                    const SizedBox(height: 16.0),
                    TextFormField(
                        autofocus: true,
                        controller: teamNameCtrl,
                        maxLength: 20,
                        maxLines: 1,
                        autocorrect: true,
                        style: formTextStyle,
                        inputFormatters: [
                          LowerCaseTextFormatter(),
                          FilteringTextInputFormatter.allow(RegExp('[0-9a-z]')),
                        ],
                        textCapitalization: TextCapitalization.none,
                        decoration: InputDecoration(
                          labelText: 'Team name',
                          hintText: 'mitt-team-navn',
                          hintStyle: formHintTextStyle,
                          hintTextDirection: TextDirection.ltr,
                          focusedBorder: borderStyle,
                          enabledBorder: borderStyle,
                          errorBorder: borderStyle,
                          disabledBorder: borderStyle,
                          fillColor: Colors.white,
                          filled: true,
                          focusColor: Colors.white,
                          hoverColor: Colors.white,
                          border: borderStyle,
                        )),
                    const SizedBox(height: 16.0),
                    TextFormField(
                        autofocus: false,
                        controller: teamDescCtrl,
                        maxLength: 250,
                        maxLines: 10,
                        autocorrect: false,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                            labelText: 'Team description',
                            hintText: 'My company chat',
                            hintStyle: formHintTextStyle,
                            hintTextDirection: TextDirection.ltr,
                            focusedBorder: borderStyle,
                            enabledBorder: borderStyle,
                            errorBorder: borderStyle,
                            disabledBorder: borderStyle,
                            fillColor: Colors.white,
                            filled: true,
                            focusColor: Colors.white,
                            hoverColor: Colors.white,
                            border: borderStyle)),
                    const SizedBox(height: 16.0),
                    ElevatedButton(
                      child: const Text('Create new team'),
                      onPressed: () => _createTeam(context),
                    )
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
