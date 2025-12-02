import 'package:flutter/material.dart';
/// This widget represents a key on the sound panel with a specific colour and an optional press handler. 
/// The key can be pressed by a user to perform a specific action.
class SoundKey extends StatelessWidget {
  /// The constructor for the SoundKey widget takes a colour `colour`, 
  /// which determines the background colour of the key and an optional `onPress` callback, which is called when the key is pressed. 
  const SoundKey({super.key, required this.colour, this.onPress});
  /// This final defines the background colour of the key.  
  final Color colour;
  /// This GestureTapCallback defines the callback that is called when the key is pressed.  
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
/// This class defines the configuration for a sound key, which includes the background colour and an optional sound path for the sound.  
class SoundKeyConfig {
  /// The constructor takes in a `Color` and an optional `String soundPath`.  
  const SoundKeyConfig({
    required this.color,
    this.soundPath,
  });
  /// This sets the background colour of the key to the specified `color `.  
  final Color color;
  /// This sets the String path for the sound to be played when the key is pressed.  
  final String? soundPath;
}
