import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:lottie/lottie.dart';

class AnimationWidget {
  static Widget loadingAnimation(double size, {Color color = Colors.white}) {
    return Center(
      child: LoadingAnimationWidget.inkDrop(color: color, size: size),
    );
  }

  static Widget boxLoading(double size) {
    return Lottie.asset(
      'assets/animation/box_loading.json',
      fit: BoxFit.cover,
      repeat: true,
      reverse: true,
      height: size,
      width: size,
    );
  }

  ///Users/axon/Desktop/my_project/moamen_project/assets/animation/congratolation.json
  static Widget congratolation({
    required double size,
    required bool isPlaying,
  }) {
    return Lottie.asset(
      'assets/animation/congratolation.json',
      fit: BoxFit.cover,
      repeat: isPlaying,
      reverse: true,
      height: size,
      width: size,
    );
  }

  ///Users/axon/Desktop/my_project/moamen_project/assets/animation/hi_animathion.json
  static Widget hiAnimation(double size) {
    return Lottie.asset(
      'assets/animation/hi_animathion.json',
      fit: BoxFit.cover,
      repeat: true,
      reverse: true,
      height: size,
      width: size,
    );
  }
}
