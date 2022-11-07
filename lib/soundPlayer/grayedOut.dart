import 'package:flutter/material.dart';

class GrayedOut extends StatelessWidget {
  final Widget child;
  final bool grayedOut;
  final double opacity;

  GrayedOut({required this.child, this.grayedOut = true})
      : opacity = grayedOut == true ? 1.0 /*0.4*/: 1.0;

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
        absorbing: grayedOut,
        child: Opacity(
            opacity: opacity,
            child: child,
        )
    );
  }
}
