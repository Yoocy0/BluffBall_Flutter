import 'dart:io';

import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_auth/kakao_flutter_sdk_auth.dart';

import '../core/api_client.dart';
import '../models/login_response.dart';
import 'token_storage.dart';
import 'match_session_storage.dart';

/// ─── TODO: 아래 상수들을 실제 값으로 교체 ────────────────────────────────────
///
/// [카카오]
///   1. 카카오 개발자 콘솔(https://developers.kakao.com) → 앱 → 앱 키 → Native App Key 복사
///   2. 카카오 개발자 콘솔 → 내 애플리케이션 → 플랫폼 → Redirect URI 등록
///   3. 백엔드 허용 목록에 동일한 URI 추가 요청
///   4. Android: AndroidManifest.xml에 kakao${NATIVE_APP_KEY} 스킴 등록
///   5. iOS: Info.plist에 LSApplicationQueriesSchemes + URL Scheme 등록
///
/// [구글]
///   1. Google Cloud Console → OAuth 2.0 클라이언트 → Web 클라이언트 ID 복사
///   2. Android: google-services.json 추가 (android/app/)
///   3. iOS: GoogleService-Info.plist 추가 (ios/Runner/)
///   4. 백엔드 허용 목록에 redirectUri 추가 요청
///
/// [애플 (iOS 전용)]
///   1. Apple Developer → Certificates → Sign In with Apple 활성화
///   2. ios/Runner.xcodeproj → Signing & Capabilities → Sign In with Apple 추가
///   3. 백엔드에 'apple' provider 구현 필요 (현재 백엔드 미지원)

// 모바일 SDK는 커스텀 스킴 필수: kakao{NATIVE_APP_KEY}://oauth
// 백엔드 허용 목록에도 동일한 값 추가 필요 (백엔드 팀에 전달)
const _kakaoRedirectUri = 'kakao2def6584659ee97c1e077fc441a58480://oauth';

const _googleServerClientId =
    '666225781663-ntm56okujop1k74lkg9rrdsl6b1s0hci.apps.googleusercontent.com';
const _googleRedirectUri =
    'https://bluffball.p-e.kr/api/v1/auth/login/google';

// ─────────────────────────────────────────────────────────────────────────────

class AuthService {
  final _dio = ApiClient().dio;
  final _tokenStorage = TokenStorage();

  late final _googleSignIn = GoogleSignIn(
    serverClientId: _googleServerClientId,
    scopes: ['email', 'profile'],
  );

  // ─── 카카오 로그인 ───────────────────────────────────────────────────────────

  Future<LoginResponse> signInWithKakao() async {
    String authCode;

    try {
      if (await isKakaoTalkInstalled()) {
        // 카카오톡 앱으로 로그인
        authCode = await AuthCodeClient.instance.authorizeWithTalk(
          redirectUri: _kakaoRedirectUri,
        );
      } else {
        // 카카오 웹뷰로 로그인
        authCode = await AuthCodeClient.instance.authorize(
          redirectUri: _kakaoRedirectUri,
        );
      }
    } on KakaoAuthException catch (e) {
      throw AuthException('카카오 로그인 실패: ${e.error}');
    } on KakaoClientException catch (e) {
      throw AuthException('카카오 SDK 오류: ${e.message}');
    } catch (e) {
      throw AuthException('카카오 로그인이 취소되었습니다.');
    }

    return _callLoginApi(
      provider: 'kakao',
      authCode: authCode,
      redirectUri: _kakaoRedirectUri,
    );
  }

  // ─── 구글 로그인 ─────────────────────────────────────────────────────────────

  Future<LoginResponse> signInWithGoogle() async {
    try {
      await _googleSignIn.signOut(); // 이전 세션 초기화
      final account = await _googleSignIn.signIn();
      if (account == null) throw AuthException('구글 로그인이 취소되었습니다.');

      final authCode = account.serverAuthCode;
      if (authCode == null) {
        throw AuthException(
          'serverAuthCode를 받지 못했습니다.\n'
          'googleServerClientId 설정을 확인해주세요.',
        );
      }

      return _callLoginApi(
        provider: 'google',
        authCode: authCode,
        redirectUri: _googleRedirectUri,
      );
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException('구글 로그인 실패: $e');
    }
  }

  // ─── Apple 로그인 (iOS 전용) ─────────────────────────────────────────────────

  Future<LoginResponse> signInWithApple() async {
    if (!Platform.isIOS) {
      throw AuthException('Apple 로그인은 iOS에서만 지원됩니다.');
    }

    // TODO: 백엔드에 'apple' provider 연동 후 아래 코드 활성화
    // TODO: _appleRedirectUri = '백엔드 Apple redirect URI'
    throw AuthException('Apple 로그인은 현재 준비 중입니다.');

    // 구현 예시 (백엔드 지원 후 활성화):
    // try {
    //   final credential = await SignInWithApple.getAppleIDCredential(
    //     scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
    //   );
    //   return _callLoginApi(
    //     provider: 'apple',
    //     authCode: credential.authorizationCode,
    //     redirectUri: _appleRedirectUri,
    //   );
    // } on SignInWithAppleAuthorizationException catch (e) {
    //   if (e.code == AuthorizationErrorCode.canceled) {
    //     throw AuthException('Apple 로그인이 취소되었습니다.');
    //   }
    //   throw AuthException('Apple 로그인 실패: ${e.message}');
    // }
  }

  // ─── 백엔드 API 호출 ─────────────────────────────────────────────────────────

  Future<LoginResponse> _callLoginApi({
    required String provider,
    required String authCode,
    required String redirectUri,
  }) async {
    try {
      final response = await _dio.post(
        '/api/v1/auth/login/$provider',
        data: {
          'authorizationCode': authCode,
          'redirectUri': redirectUri,
        },
      );

      final loginResponse =
          LoginResponse.fromJson(response.data as Map<String, dynamic>);

      await _tokenStorage.save(
        accessToken: loginResponse.accessToken,
        refreshToken: loginResponse.refreshToken,
      );

      return loginResponse;
    } on DioException catch (e) {
      throw switch (e.response?.statusCode) {
        400 => AuthException('유효하지 않은 인가 코드 또는 redirect URI입니다.'),
        403 => AuthException('정지된 계정입니다. 고객센터에 문의해주세요.'),
        503 => AuthException('소셜 플랫폼 서버에 연결할 수 없습니다.\n잠시 후 다시 시도해주세요.'),
        _ => AuthException('로그인에 실패했습니다.\n네트워크 연결을 확인해주세요.'),
      };
    }
  }

  // ─── 세션 복원 (앱 시작) ───────────────────────────────────────────────────

  /// 로컬 토큰이 있으면 서버에 유효성을 확인한다.
  ///
  /// 1. Access Token으로 `GET /api/v1/users/me` 호출
  /// 2. 401이면 Refresh Token으로 `POST /api/v1/auth/refresh` 시도
  /// 3. refresh 성공 시 새 토큰 저장 후 true
  /// 4. 인증 실패 시 로컬 토큰 삭제 후 false
  /// 5. 네트워크 오류 시 토큰은 유지하고 false (다음 실행에서 재시도)
  Future<bool> restoreSession() async {
    final accessToken = await _tokenStorage.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      await _tokenStorage.clear();
      return false;
    }

    final accessValid = await _validateAccessToken(accessToken);
    if (accessValid == true) return true;
    if (accessValid == null) return false; // 네트워크 등 — 토큰 유지

    // Access Token 만료/무효 → Refresh 시도
    final refreshed = await _refreshTokens();
    if (refreshed == true) return true;
    if (refreshed == null) return false; // 네트워크 등 — 토큰 유지

    await _tokenStorage.clear();
    return false;
  }

  /// true: 유효 / false: 401 등 인증 실패 / null: 네트워크·기타
  Future<bool?> _validateAccessToken(String accessToken) async {
    try {
      await _dio.get(
        '/api/v1/users/me',
        options: Options(
          headers: {'Authorization': 'Bearer $accessToken'},
        ),
      );
      return true;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) return false;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// true: 재발급 성공 / false: refresh 무효 / null: 네트워크·기타
  Future<bool?> _refreshTokens() async {
    final refreshToken = await _tokenStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;

    try {
      final response = await _dio.post(
        '/api/v1/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) return false;

      final newAccess = data['accessToken'] as String?;
      final newRefresh = data['refreshToken'] as String?;
      if (newAccess == null ||
          newAccess.isEmpty ||
          newRefresh == null ||
          newRefresh.isEmpty) {
        return false;
      }

      await _tokenStorage.save(
        accessToken: newAccess,
        refreshToken: newRefresh,
      );
      return true;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 403 || status == 400) return false;
      return null;
    } catch (_) {
      return null;
    }
  }

  // ─── 로그아웃 ────────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await _tokenStorage.clear();
    await MatchSessionCoordinator.onSessionEnd();
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
  }
}

/// 인증 관련 예외
class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}
