import 'package:flutter/material.dart';
import 'package:messngr/config/app_constants.dart';
import 'package:messngr/redux/app_state.dart';
import 'package:messngr/redux/profile/profile_actions.dart';
import 'package:messngr/utils/flutter_redux.dart';

class CreateProfileScreen extends StatefulWidget {
  const CreateProfileScreen({super.key});

  @override
  State<CreateProfileScreen> createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends State<CreateProfileScreen> {
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
              onPressed: () => {
                StoreProvider.of<AppState>(context).dispatch(
                    CreateProfileAction(
                        username: _userNameCtrl.text,
                        firstName: _firstNameCtrl.text,
                        lastName: _lastNameCtrl.text))
              },
            )
          ],
        ),
      ),
    );
  }
}
