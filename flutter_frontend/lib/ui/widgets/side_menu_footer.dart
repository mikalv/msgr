import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:messngr/config/app_constants.dart';

class SideMenuFooter extends StatelessWidget {
  final List<FooterOption> options;

  const SideMenuFooter({Key? key, required this.options}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Spacer(),
        Divider(
          color: isDarkMode ? Colors.black12 : Colors.white12,
        ),
        ...options
            .map(
              (e) => footerItem(e),
            )
            .toList(),
        const SizedBox(
          height: 24,
        )
      ],
    );
  }

  Widget footerItem(FooterOption e) {
    return ListTile(
      leading: Icon(
        e.icon,
      ),
      title: Text(e.name,
          style:
              GoogleFonts.notoSans(textStyle: const TextStyle(fontSize: 16))),
    );
  }
}

class FooterOption {
  IconData icon;
  String name;

  FooterOption(this.icon, this.name);
}
