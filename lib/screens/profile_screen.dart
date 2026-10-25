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

  @override
  void initState() {
    super.initState();
    _loadBookings();
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
                    child: const Icon(Icons.person,
                        size: 42, color: Colors.amberAccent),
                  ),
                  const SizedBox(width: 16),
                  // Cả Column này cố định nên đặt const ở đây, các con bên trong không cần const nữa
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Khách hàng VIP',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text('0901 234 567',
                          style: TextStyle(color: Colors.grey)),
                      SizedBox(height: 6),
                      Text('Hạng: Gold Member ⭐',
                          style: TextStyle(
                              color: Colors.deepOrange, fontSize: 12)),
                    ],
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
          subtitle: Text(
            '${_formatDate(booking['booking_date'])} • ${booking['booking_time']}\n'
            '${_formatPrice(booking['price'] as int)} đ • $statusText',
          ),
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