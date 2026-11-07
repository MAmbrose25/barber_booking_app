import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Quản lý danh sách kiểu tóc yêu thích của người đang đăng nhập.
/// favoriteIds là ValueNotifier nên trang chủ và màn "Xem tất cả"
/// tự cập nhật trái tim cùng lúc khi một nơi thay đổi.
class FavoritesRepository {
  FavoritesRepository._();

  static SupabaseClient get _client => Supabase.instance.client;

  static final ValueNotifier<Set<String>> favoriteIds = ValueNotifier({});

  // Tài khoản mà favoriteIds đang chứa dữ liệu của họ
  static String? _loadedUserId;

  /// Tải danh sách yêu thích một lần cho mỗi tài khoản.
  /// Đổi tài khoản thì tự xóa dữ liệu cũ và tải lại.
  static Future<void> ensureLoaded() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      _loadedUserId = null;
      favoriteIds.value = {};
      return;
    }
    if (_loadedUserId == user.id) return;

    _loadedUserId = user.id;
    favoriteIds.value = {};
    try {
      final rows = await _client
          .from('favorites')
          .select('hairstyle_id')
          .eq('user_id', user.id);
      favoriteIds.value = {for (final r in rows) r['hairstyle_id'] as String};
    } catch (_) {
      // Tải lỗi thì lần sau thử lại
      _loadedUserId = null;
    }
  }

  /// Thả tim hoặc bỏ tim. Trả về false nếu lưu lên Supabase thất bại.
  static Future<bool> toggle(String hairstyleId) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    final isFavorite = favoriteIds.value.contains(hairstyleId);

    // Cập nhật giao diện trước cho mượt, lỗi thì hoàn lại
    _setLocal(hairstyleId, !isFavorite);
    try {
      if (isFavorite) {
        await _client
            .from('favorites')
            .delete()
            .eq('user_id', user.id)
            .eq('hairstyle_id', hairstyleId);
      } else {
        await _client.from('favorites').insert({
          'user_id': user.id,
          'hairstyle_id': hairstyleId,
        });
      }
      return true;
    } catch (_) {
      _setLocal(hairstyleId, isFavorite);
      return false;
    }
  }

  static void _setLocal(String hairstyleId, bool favorite) {
    final next = {...favoriteIds.value};
    if (favorite) {
      next.add(hairstyleId);
    } else {
      next.remove(hairstyleId);
    }
    favoriteIds.value = next;
  }
}