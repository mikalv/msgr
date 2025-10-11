import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:messngr/config/app_constants.dart';
import 'package:messngr/services/localization/translator.dart';
import 'package:messngr/ui/widgets/PhoneField/intl_phone_field.dart';
import 'package:messngr/ui/widgets/PhoneField/phone_number.dart';

class MobileInputWithOutline extends StatefulWidget {
  final String? initialCountryCode;
  final String? hintText;
  final double? height;
  final double? width;
  final TextEditingController? controller;
  final Color? borderColor;
  final Color? buttonTextColor;
  final Color? buttonhintTextColor;
  final TextStyle? hintStyle;
  final String? buttonText;
  final Function(PhoneNumber? phone)? onSaved;
  final void Function(String)? onSubmitted;
  final bool autofocus;
  final Color? backgroundColor;
  final Color? fillColor;
  final TextStyle? textStyle;
  final double? borderWidth;

  const MobileInputWithOutline(
      {super.key,
      this.height,
      this.width,
      this.borderColor,
      this.buttonhintTextColor,
      this.hintStyle,
      this.buttonTextColor,
      this.onSaved,
      this.hintText,
      this.controller,
      this.initialCountryCode,
      this.buttonText,
      this.autofocus = true,
      this.onSubmitted,
      this.backgroundColor,
      this.fillColor,
      this.textStyle,
      this.borderWidth});
  @override
  _MobileInputWithOutlineState createState() => _MobileInputWithOutlineState();
}

class _MobileInputWithOutlineState extends State<MobileInputWithOutline> {
  BoxDecoration boxDecoration(
      {double radius = 5,
      Color bgColor = Colors.white,
      var showShadow = false}) {
    return BoxDecoration(
        color: bgColor,
        boxShadow: showShadow
            ? [
                const BoxShadow(
                    color: messngrgreen, blurRadius: 10, spreadRadius: 2)
              ]
            : [const BoxShadow(color: Colors.transparent)],
        border:
            Border.all(
                color: widget.borderColor ?? Colors.grey,
                width: widget.borderWidth ?? 1.5),
        borderRadius: BorderRadius.all(Radius.circular(radius)));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          padding: const EdgeInsetsDirectional.only(bottom: 7, top: 5),
          height: widget.height ?? 50,
          width: widget.width ?? MediaQuery.of(this.context).size.width,
          decoration: boxDecoration(
            bgColor: widget.backgroundColor ?? Colors.white,
          ),
          child: IntlPhoneField(
              onSubmitted: widget.onSubmitted,
              dropDownArrowColor:
                  widget.buttonhintTextColor ?? Colors.grey[300],
              textAlign: TextAlign.left,
              initialCountryCode: widget.initialCountryCode,
              controller: widget.controller,
              autofocus: widget.autofocus,
              style: widget.textStyle ??
                  TextStyle(
                      height: 1.35,
                      letterSpacing: 1,
                      fontSize: 16.0,
                      color: widget.buttonTextColor ?? Colors.black87,
                      fontWeight: FontWeight.bold),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: InputDecoration(
                  contentPadding: const EdgeInsets.fromLTRB(3, 15, 8, 0),
                  hintText: widget.hintText ??
                      getTranslated(this.context, 'enter_mobilenumber'),
                  hintStyle: widget.hintStyle ??
                      TextStyle(
                          letterSpacing: 1,
                          height: 0.0,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w400,
                          color: widget.buttonhintTextColor ?? messngrGrey),
                  fillColor: widget.fillColor ??
                      widget.backgroundColor ?? Colors.white,
                  filled: true,
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(
                      Radius.circular(10.0),
                    ),
                    borderSide: BorderSide.none,
                  )),
              onChanged: (phone) {
                widget.onSaved!(phone);
              },
              validator: (v) {
                return null;
              },
              onSaved: widget.onSaved),
        ),
        // Positioned(
        //     left: 110,
        //     child: Container(
        //       width: 1.5,
        //       height: widget.height ?? 48,
        //       color: widget.borderColor ?? Colors.grey,
        //     ))
      ],
    );
  }
}
