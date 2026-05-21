import 'package:flutter/material.dart';

class PrysmTvFocusBorder extends StatelessWidget {
  const PrysmTvFocusBorder({
    required this.focused,
    required this.child,
    super.key,
  });

  final bool focused;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        border: Border.all(
          color: focused ? Colors.white : Colors.transparent,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}
