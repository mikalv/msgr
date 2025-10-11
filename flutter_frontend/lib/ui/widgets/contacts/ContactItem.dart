import 'package:flutter/material.dart';
import 'package:flutter_profile_picture/flutter_profile_picture.dart';
import 'package:messngr/config/AppNavigation.dart';

class ContactItem extends StatelessWidget {
  const ContactItem({super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
        child: const Row(
          children: [
            ProfilePicture(
              name: 'Unknown',
              radius: 35,
              fontsize: 21,
            ),
            SizedBox(width: 10.0),
            Column(
              children: [
                Text('Tester 1234',
                    style: TextStyle(
                        color: Colors.grey,
                        fontSize: 15.0,
                        fontWeight: FontWeight.bold)),
                SizedBox(height: 5.0),
                Text('Annen tekst...')
              ],
            )
          ],
        ),
        onTap: () {
          AppNavigation.router.push('${AppNavigation.conversationsPath}/');
        });
  }
}
