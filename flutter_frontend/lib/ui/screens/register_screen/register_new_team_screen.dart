import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:messngr/config/themedata.dart';
import 'package:messngr/redux/app_state.dart';
import 'package:messngr/redux/authentication/auth_actions.dart';
import 'package:messngr/utils/flutter_redux.dart';
import 'package:messngr/utils/lower_case_text_formatter.dart';

class RegisterNewTeamScreen extends StatelessWidget {
  const RegisterNewTeamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final teamNameCtrl = TextEditingController();
    final teamDescCtrl = TextEditingController();
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
                      onPressed: () => {
                        StoreProvider.of<AppState>(context).dispatch(
                            CreateTeamRequestAction(
                                teamName: teamNameCtrl.text,
                                teamDesc: teamDescCtrl.text))
                      },
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
