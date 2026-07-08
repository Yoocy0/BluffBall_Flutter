import 'package:flutter/material.dart';

class GameBackground extends StatelessWidget {
  const GameBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;

    // 이미지 표시 높이를 화면보다 크게 설정 → 하단(관중석)이 ClipRect에 의해 잘림
    // 1.32배 = 화면에서 이미지 하단 약 24% 잘라냄
    final expandedH = screenH * 1.32;

    return ClipRect(
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          height: expandedH,
          width: double.infinity,
          child: Image.asset(
            'assets/images/stadium.png',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),
      ),
    );
  }
}
