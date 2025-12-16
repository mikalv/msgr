import 'package:flutter/material.dart';
import 'package:messngr/ui/widgets/dropdown_search/dropdown_search.dart';

class DropdownSuffixProps {
  final ClearButtonProps clearButtonProps;
  final DropdownButtonProps dropdownButtonProps;
  final TextDirection? direction;

  const DropdownSuffixProps({
    this.clearButtonProps = const ClearButtonProps(),
    this.dropdownButtonProps = const DropdownButtonProps(),
    this.direction = TextDirection.ltr,
  });
}
