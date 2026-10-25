import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const double _salonLat = 10.7769;
  static const double _salonLng = 106.7009;
  String _distanceInfo = 'Nhấn nút để kiểm tra khoảng cách';

  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _bookings = [];
  bool _loadingBookings = true;

  String _fullName = '';
  String _email = '';

  @override
  void initState() {
    super.initState();
    final user = _client.auth.currentUser;
    _email = user?.email ?? '';
    // Hiện tạm tên lấy lúc đăng ký, rồi _loadProfile sẽ lấy tên trong bảng profiles
    _fullName = (user?.userMetadata?['full_name'] as String?)?.trim() ?? '';
    if (_fullName.isEmpty) _fullName = _email.split('@').first;
    _loadProfile();
    _loadBookings();
  }

  // Lấy họ tên từ bảng profiles
  Future<void> _loadProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      final data = await _client
          .from('profiles')
          .select('full_name')
          .eq('id', user.id)
          .maybeSingle();
      final name = (data?['full_name'] as String?)?.trim() ?? '';
      if (!mounted || name.isEmpty) return;
      setState(() => _fullName = name);
    } catch (_) {
      // Không lấy được thì giữ tên tạm, không cần báo lỗi
    }
  }

  // Lấy lịch hẹn của người đang đăng nhập, mới nhất lên đầu
  Future<void> _loadBookings() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loadingBookings = false);
      return;
    }
    try {
      final data = await _client
          .from('bookings')
          .select()
          .eq('user_id', user.id)
          .order('booking_date', ascending: false)
          .order('booking_time', ascending: false);
      if (!mounted) return;
      setState(() {
        _bookings = List<Map<String, dynamic>>.from(data);
        _loadingBookings = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingBookings = false);
      EasyLoading.showError('Không tải được lịch sử đặt lịch.');
    }
  }

  // Đăng xuất, main.dart sẽ tự chuyển về màn đăng nhập
  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đăng xuất?'),
        content: const Text('Bạn có chắc muốn đăng xuất khỏi tài khoản này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Ở lại'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Đăng xuất',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    EasyLoading.show(status: 'Đang đăng xuất...');
    try {
      await _client.auth.signOut();
      EasyLoading.dismiss();
    } catch (_) {
      EasyLoading.showError('Không đăng xuất được, vui lòng thử lại.');
    }
  }

  // Thời điểm bắt đầu của lịch hẹn
  DateTime _bookingDateTime(Map<String, dynamic> booking) {
    final d = (booking['booking_date'] as String).split('-');
    final t = (booking['booking_time'] as String).split(':');
    return DateTime(int.parse(d[0]), int.parse(d[1]), int.parse(d[2]),
        int.parse(t[0]), int.parse(t[1]));
  }

  bool _canCancel(Map<String, dynamic> booking) =>
      booking['status'] == 'booked' &&
      _bookingDateTime(booking).isAfter(DateTime.now());

  Future<void> _cancelBooking(Map<String, dynamic> booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hủy lịch hẹn?'),
        content: Text(
            'Bạn muốn hủy lịch "${booking['service_name']}" lúc '
            '${booking['booking_time']} ngày ${_formatDate(booking['booking_date'])}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Giữ lại'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hủy lịch',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    EasyLoading.show(status: 'Đang hủy lịch...');
    try {
      await _client
          .from('bookings')
          .update({'status': 'cancelled'}).eq('id', booking['id']);
      await _loadBookings();
      EasyLoading.showSuccess('Đã hủy lịch hẹn.');
    } catch (_) {
      EasyLoading.showError('Không hủy được lịch, vui lòng thử lại.');
    }
  }

  // 2026-10-30 -> 30/10/2026
  String _formatDate(String dbDate) {
    final p = dbDate.split('-');
    return '${p[2]}/${p[1]}/${p[0]}';
  }

  String _formatPrice(int price) {
    final s = price.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write('.');
      buffer.write(s[i]);
    }
    return buffer.toString();
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      EasyLoading.showError('Không thể mở ứng dụng gọi điện.');
    }
  }

  Future<void> _calculateDistance() async {
    EasyLoading.show(status: 'Đang kiểm tra GPS...');
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        EasyLoading.showError('Vui lòng bật dịch vụ vị trí trên thiết bị.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        EasyLoading.showError('Quyền truy cập vị trí đã bị từ chối.');
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        EasyLoading.showError('Hãy cấp quyền vị trí trong phần cài đặt thiết bị.');
        return;
      }

      final userPosition = await Geolocator.getCurrentPosition();
      final distanceInMeters = Geolocator.distanceBetween(
        userPosition.latitude,
        userPosition.longitude,
        _salonLat,
        _salonLng,
      );
      if (!mounted) {
        EasyLoading.dismiss();
        return;
      }
      setState(() => _distanceInfo =
          'Bạn đang cách salon: ${(distanceInMeters / 1000).toStringAsFixed(1)} km');
      EasyLoading.dismiss();
    } catch (_) {
      EasyLoading.showError('Không lấy được vị trí. Vui lòng thử lại.');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Số lịch đã đặt, không tính lịch đã hủy
    final bookedCount =
        _bookings.where((b) => b['status'] != 'cancelled').length;
    final initial =
        _fullName.isNotEmpty ? _fullName.substring(0, 1).toUpperCase() : '?';

    return Scaffold(
      appBar: AppBar(
        title: const Text('TÀI KHOẢN & CHI NHÁNH',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _card(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.button(context),
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.amberAccent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppColors.muted(context)),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Đã đặt $bookedCount lịch',
                          style: const TextStyle(
                              color: Colors.deepOrange, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.phone_in_talk, color: Colors.green),
                    title: const Text('Hotline đặt hẹn nhanh'),
                    subtitle: const Text('1900 1234'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _makePhoneCall('19001234'),
                  ),
                  const Divider(height: 1),
                  const ListTile(
                    leading: Icon(Icons.location_on, color: Colors.redAccent),
                    title: Text('Địa chỉ salon trụ sở'),
                    subtitle: Text('123 Lê Lợi, Phường Bến Nghé, Quận 1'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.near_me, color: Colors.deepOrange),
                    title: const Text('Khoảng cách tới chi nhánh'),
                    subtitle: Text(_distanceInfo),
                    trailing: ElevatedButton(
                      onPressed: _calculateDistance,
                      child: const Text('Đo GPS'),
                    ),
                  ),
                  const Divider(height: 1),
                  // Công tắc chế độ tối
                  SwitchListTile(
                    secondary:
                        Icon(Icons.dark_mode, color: AppColors.title(context)),
                    title: const Text('Chế độ tối'),
                    value: AppColors.isDark(context),
                    onChanged: (value) {
                      themeNotifier.value =
                          value ? ThemeMode.dark : ThemeMode.light;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.content_cut, color: AppColors.title(context)),
                        const SizedBox(width: 10),
                        const Text('Lịch sử đặt lịch',
                            style: TextStyle(
                                fontSize: 17, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  if (_loadingBookings)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_bookings.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(
                        child: Text('Bạn chưa có lịch hẹn nào.',
                            style: TextStyle(color: Colors.grey)),
                      ),
                    )
                  else
                    ..._bookings.map(_bookingTile),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                ),
                onPressed: _signOut,
                icon: const Icon(Icons.logout),
                label: const Text('ĐĂNG XUẤT'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _bookingTile(Map<String, dynamic> booking) {
    final cancelled = booking['status'] == 'cancelled';
    final upcoming = !cancelled && _bookingDateTime(booking).isAfter(DateTime.now());

    final IconData icon;
    final Color color;
    final String statusText;
    if (cancelled) {
      icon = Icons.close;
      color = Colors.redAccent;
      statusText = 'Đã hủy';
    } else if (upcoming) {
      icon = Icons.schedule;
      color = Colors.orange;
      statusText = 'Sắp tới';
    } else {
      icon = Icons.check;
      color = Colors.green;
      statusText = 'Hoàn thành';
    }

    // Ghép các dòng mô tả, dòng nào không có dữ liệu thì bỏ qua
    final barberName = booking['barber_name'] as String?;
    final hairstyleName = booking['hairstyle_name'] as String?;
    final lines = <String>[
      '${_formatDate(booking['booking_date'])} • ${booking['booking_time']}',
      if (barberName != null && barberName.isNotEmpty) 'Thợ: $barberName',
      if (hairstyleName != null && hairstyleName.isNotEmpty)
        'Kiểu tóc: $hairstyleName',
      '${_formatPrice(booking['price'] as int)} đ • $statusText',
    ];

    return Column(
      children: [
        ListTile(
          isThreeLine: true,
          leading: CircleAvatar(
            backgroundColor: AppColors.background(context),
            child: Icon(icon, color: color),
          ),
          title: Text(
            booking['service_name'] as String,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              decoration: cancelled ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: Text(lines.join('\n')),
          trailing: _canCancel(booking)
              ? TextButton(
                  onPressed: () => _cancelBooking(booking),
                  child: const Text('Hủy',
                      style: TextStyle(color: Colors.redAccent)),
                )
              : null,
        ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _card({required Widget child}) => Material(
        color: AppColors.card(context),
        elevation: 2,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      );
}