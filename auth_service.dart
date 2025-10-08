import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/account_model.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Lấy user hiện tại
  User? get currentUser => _client.auth.currentUser;

  /// Lấy session hiện tại
  Session? get currentSession => _client.auth.currentSession;

  /// Stream theo dõi thay đổi trạng thái đăng nhập
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Đăng nhập bằng Email & Password
  Future<String?> signIn(Account account) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: account.email.trim(),
        password: account.password.trim(),
      );

      if (response.user == null) {
        return 'Đăng nhập thất bại';
      }

      return null; // ✅ Thành công
    } on AuthException catch (e) {
      return _handleAuthError(e);
    } catch (e) {
      return 'Lỗi không xác định: ${e.toString()}';
    }
  }

  /// Đăng ký tài khoản mới bằng Email & Password
  Future<String?> signUp(Account account) async {
    try {
      final response = await _client.auth.signUp(
        email: account.email.trim(),
        password: account.password.trim(),
      );

      if (response.user == null) {
        return 'Đăng ký thất bại';
      }

      return null; // ✅ Thành công
    } on AuthException catch (e) {
      return _handleAuthError(e);
    } catch (e) {
      return 'Lỗi không xác định: ${e.toString()}';
    }
  }

  /// Đăng nhập với Google
  Future<String?> signInWithGoogle() async {
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'com.example.my_new_app://login-callback/',
        queryParams: {
          'prompt': 'select_account', // 👈 Hiển thị chọn tài khoản Google
        },
      );
      return null;
    } on AuthException catch (e) {
      return _handleAuthError(e);
    } catch (e) {
      return 'Lỗi không xác định: ${e.toString()}';
    }
  }

  /// Đăng nhập với GitHub
  Future<String?> signInWithGitHub() async {
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.github,
        redirectTo: 'com.example.my_new_app://login-callback/',
        queryParams: {
          'prompt': 'select_account', // 👈 Hiển thị chọn tài khoản GitHub
        },
      );
      return null;
    } on AuthException catch (e) {
      return _handleAuthError(e);
    } catch (e) {
      return 'Lỗi không xác định: ${e.toString()}';
    }
  }

  /// Đăng xuất
  Future<String?> signOut() async {
    try {
      await _client.auth.signOut();
      return null; // ✅ Thành công
    } on AuthException catch (e) {
      return _handleAuthError(e);
    } catch (e) {
      return 'Lỗi không xác định: ${e.toString()}';
    }
  }

  /// Gửi email quên mật khẩu (reset password)
  Future<String?> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'com.example.my_new_app://reset-password/',
      );
      return null; // Success
    } on AuthException catch (e) {
      return _handleAuthError(e);
    } catch (e) {
      return 'Lỗi không xác định: ${e.toString()}';
    }
  }


  /// Xử lý lỗi auth chi tiết
  String _handleAuthError(AuthException e) {
    switch (e.statusCode) {
      case '400':
        if (e.message.contains('Invalid login credentials')) {
          return 'Email hoặc mật khẩu không đúng';
        } else if (e.message.contains('Email not confirmed')) {
          return 'Vui lòng xác nhận email trước khi đăng nhập';
        } else if (e.message.contains('User already registered')) {
          return 'Email này đã được đăng ký';
        }
        return 'Thông tin không hợp lệ';

      case '422':
        if (e.message.contains('Password should be at least')) {
          return 'Mật khẩu phải có ít nhất 6 ký tự';
        } else if (e.message.contains('Email')) {
          return 'Email không hợp lệ';
        }
        return 'Dữ liệu không hợp lệ';

      case '429':
        return 'Quá nhiều yêu cầu. Vui lòng thử lại sau';

      case '500':
        return 'Lỗi server. Vui lòng thử lại sau';

      default:
        return e.message;
    }
  }
}
