import 'package:flutter/material.dart';

class SoundKey extends StatelessWidget {
  const SoundKey({super.key, required this.colour, this.onPress});
  // final makes the property immutable
  final Color colour;
  // Widget can't be null so the explicit non-null type ? is set
  final GestureTapCallback? onPress;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPress,
      child: Container(
        margin: const EdgeInsets.all(15.0),
        decoration: BoxDecoration(
          color: colour,
          borderRadius: BorderRadius.circular(10.0),
        ),
      ),
    );
  }
}

class SoundKeyConfig {
  final Color color;
  final String? soundPath;

  const SoundKeyConfig({
    required this.color,
    this.soundPath,
  });
}
