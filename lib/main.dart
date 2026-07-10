import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_auth/kakao_flutter_sdk_auth.dart';

import 'screens/landing_screen.dart';

const _kakaoNativeAppKey = '2def6584659ee97c1e077fc441a58480';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 카카오 SDK 초기화
  KakaoSdk.init(nativeAppKey: _kakaoNativeAppKey);

  runApp(const BluffBallApp());
}

class BluffBallApp extends StatelessWidget {
  const BluffBallApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BluffBall',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF556B2F),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const LandingScreen(),
    );
  }
}
