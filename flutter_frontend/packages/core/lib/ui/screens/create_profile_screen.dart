import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:libmsgr/libmsgr.dart';
import 'package:messngr/config/app_constants.dart';
import 'package:messngr/config/AppNavigation.dart';
import 'package:messngr/providers/auth_provider.dart';

class CreateProfileScreen extends ConsumerStatefulWidget {
  const CreateProfileScreen({super.key});

  @override
  ConsumerState<CreateProfileScreen> createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends ConsumerState<CreateProfileScreen> {
  final _userNameCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final borderColor = messngrGrey.withOpacity(0.2);
    final borderStyle = OutlineInputBorder(
      borderRadius: const BorderRadius.all(
        Radius.circular(10.0),
      ),
      borderSide: BorderSide(color: borderColor, width: 0.0),
    );
    return Scaffold(
      appBar: AppBar(
        actions: const [],
        elevation: 3.0,
        centerTitle: true,
        title: const Text(
          'Create profile',
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
            TextFormField(
                autofocus: true,
                controller: _userNameCtrl,
                maxLength: 20,
                maxLines: 1,
                autocorrect: false,
                textCapitalization: TextCapitalization.none,
                decoration: InputDecoration(
                    labelText: 'Username',
                    hintText: 'myname',
                    hintTextDirection: TextDirection.ltr,
                    hintStyle: const TextStyle(
                        letterSpacing: 1,
                        height: 0.0,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w400,
                        color: messngrGrey),
                    focusedBorder: borderStyle,
                    enabledBorder: borderStyle,
                    errorBorder: borderStyle,
                    disabledBorder: borderStyle,
                    fillColor: Colors.white,
                    filled: true,
                    focusColor: Colors.white,
                    hoverColor: Colors.white,
                    border: borderStyle)),
            TextFormField(
                autofocus: true,
                controller: _firstNameCtrl,
                maxLength: 20,
                maxLines: 1,
                autocorrect: false,
                textCapitalization: TextCapitalization.none,
                decoration: InputDecoration(
                    labelText: 'First name',
                    hintText: 'Ola',
                    hintTextDirection: TextDirection.ltr,
                    hintStyle: const TextStyle(
                        letterSpacing: 1,
                        height: 0.0,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w400,
                        color: messngrGrey),
                    focusedBorder: borderStyle,
                    enabledBorder: borderStyle,
                    errorBorder: borderStyle,
                    disabledBorder: borderStyle,
                    fillColor: Colors.white,
                    filled: true,
                    focusColor: Colors.white,
                    hoverColor: Colors.white,
                    border: borderStyle)),
            TextFormField(
                autofocus: true,
                controller: _lastNameCtrl,
                maxLength: 20,
                maxLines: 1,
                autocorrect: false,
                textCapitalization: TextCapitalization.none,
                decoration: InputDecoration(
                    labelText: 'Last name',
                    hintText: 'Nordmann',
                    hintTextDirection: TextDirection.ltr,
                    hintStyle: const TextStyle(
                        letterSpacing: 1,
                        height: 0.0,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w400,
                        color: messngrGrey),
                    focusedBorder: borderStyle,
                    enabledBorder: borderStyle,
                    errorBorder: borderStyle,
                    disabledBorder: borderStyle,
                    fillColor: Colors.white,
                    filled: true,
                    focusColor: Colors.white,
                    hoverColor: Colors.white,
                    border: borderStyle)),
            ElevatedButton(
              child: const Text('Create profile and start chat'),
              onPressed: () async {
                final authState = ref.read(authProvider);
                final currentTeam = authState.currentTeam;
                final currentUser = authState.currentUser;

                if (currentTeam == null || currentUser == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a team first')),
                  );
                  return;
                }

                try {
                  final reg = RegistrationService();
                  final profile = await reg.createProfileForTeam(
                    teamName: currentTeam.name,
                    token: currentUser.accessToken,
                    username: _userNameCtrl.text,
                    firstName: _firstNameCtrl.text,
                    lastName: _lastNameCtrl.text,
                  );

                  if (profile != null && mounted) {
                    ref.read(authProvider.notifier).setCurrentProfile(profile);
                    context.go(AppNavigation.dashboardPath);
                  }
                } catch (error) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to create profile: $error')),
                    );
                  }
                }
              },
            )
          ],
        ),
      ),
    );
  }
}
