import 'package:flutter/material.dart';

/// Decorative only; today's selectable mood remains a separate control.
class HeaderCompanions extends StatelessWidget {
  const HeaderCompanions({super.key, this.width = 104});
  final double width;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Image.asset(
      'assets/branding/cat_rabbit_heads.png',
      width: width,
      height: width * .66,
      fit: BoxFit.contain,
    ),
  );
}
