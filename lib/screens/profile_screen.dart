import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import '../utils/booking_utils.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const double _salonLat = 10.7769;
  static const double _salonLng = 106.7009;

  // true  = cho bấm "Hoàn thành" cả khi chưa tới giờ hẹn
  // false = chỉ hiện nút này từ lúc tới giờ hẹn trở đi
  static const bool _allowEarlyComplete = true;

  String _distanceInfo = 'Nhấn nút để kiểm tra khoảng cách';

  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _bookings = [];
  bool _loadingBookings = true;

  String _fullName = '';
  String _email = '';
  String _phone = '';
  String? _avatarUrl;

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

  // Lấy họ tên, số điện thoại, ảnh đại diện từ bảng profiles
  Future<void> _loadProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      final data = await _client
          .from('profiles')
          .select('full_name, phone, avatar_url')
          .eq('id', user.id)
          .maybeSingle();
      if (!mounted || data == null) return;
      final name = (data['full_name'] as String?)?.trim() ?? '';
      final avatar = (data['avatar_url'] as String?)?.trim() ?? '';
      setState(() {
        if (name.isNotEmpty) _fullName = name;
        _phone = (data['phone'] as String?)?.trim() ?? '';
        _avatarUrl = avatar.isEmpty ? null : avatar;
      });
    } catch (_) {
      // Không lấy được thì giữ thông tin tạm, không cần báo lỗi
    }
  }

  // Mở màn sửa hồ sơ, lưu xong thì tải lại thông tin
  Future<void> _editProfile() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          initialName: _fullName,
          initialPhone: _phone,
          initialAvatarUrl: _avatarUrl,
        ),
      ),
    );
    if (changed == true) _loadProfile();
  }

  // Lấy lịch hẹn của người đang đăng nhập, mới nhất lên đầu
  Future<void> _loadBookings() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loadingBookings = false);
      return;
    }
    try {
      // Chuyển các lịch đã qua giờ kết thúc sang 'completed' trong database
      try {
        await _client.rpc('complete_past_bookings');
      } catch (_) {
        // Lỗi ở bước này không được chặn việc hiển thị danh sách lịch
      }
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

  DateTime _startOf(Map<String, dynamic> booking) => bookingStart(
      booking['booking_date'] as String, booking['booking_time'] as String);

  bool _canCancel(Map<String, dynamic> booking) =>
      booking['status'] == 'booked' && _startOf(booking).isAfter(DateTime.now());

  // Nút "Hoàn thành" chỉ hiện với lịch chưa hoàn thành và chưa hủy
  bool _canComplete(Map<String, dynamic> booking) =>
      booking['status'] == 'booked' &&
      (_allowEarlyComplete || !_startOf(booking).isAfter(DateTime.now()));

  Future<void> _cancelBooking(Map<String, dynamic> booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hủy lịch hẹn?'),
        content: Text(
            'Bạn muốn hủy lịch "${booking['service_name']}" lúc '
            '${shortTime(booking['booking_time'] as String)} ngày '
            '${formatDbDate(booking['booking_date'] as String)}?'),
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

  // Đánh dấu lịch hẹn đã hoàn thành
  Future<void> _completeBooking(Map<String, dynamic> booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đánh dấu hoàn thành?'),
        content: Text(
            'Xác nhận bạn đã hoàn thành dịch vụ "${booking['service_name']}" lúc '
            '${shortTime(booking['booking_time'] as String)} ngày '
            '${formatDbDate(booking['booking_date'] as String)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Chưa'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child:
                const Text('Hoàn thành', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    EasyLoading.show(status: 'Đang cập nhật...');
    try {
      await _client
          .from('bookings')
          .update({'status': 'completed'}).eq('id', booking['id']);
      await _loadBookings();
      EasyLoading.showSuccess('Đã đánh dấu hoàn thành.');
    } catch (_) {
      EasyLoading.showError('Không cập nhật được, vui lòng thử lại.');
    }
  }

  // Đánh giá thợ sau khi lịch đã hoàn thành
  Future<void> _reviewBooking(Map<String, dynamic> booking) async {
    int rating = 5;
    String comment = '';
    final barberName = booking['barber_name'] as String?;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(barberName == null || barberName.isEmpty
              ? 'Đánh giá buổi hẹn'
              : 'Đánh giá thợ $barberName'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (i) => IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(i < rating ? Icons.star : Icons.star_border,
                        color: Colors.amber, size: 34),
                    onPressed: () => setDialogState(() => rating = i + 1),
                  ),
                ),
              ),
              TextField(
                maxLines: 2,
                onChanged: (value) => comment = value,
                decoration: const InputDecoration(
                    hintText: 'Nhận xét (không bắt buộc)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Để sau'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Gửi'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    EasyLoading.show(status: 'Đang gửi đánh giá...');
    try {
      final text = comment.trim();
      await _client.from('bookings').update({
        'rating': rating,
        'review_comment': text.isEmpty ? null : text,
      }).eq('id', booking['id']);
      await _loadBookings();
      EasyLoading.showSuccess('Cảm ơn bạn đã đánh giá!');
    } catch (_) {
      EasyLoading.showError('Không gửi được đánh giá, vui lòng thử lại.');
    }
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
    final avatarUrl = _avatarUrl;

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
                    backgroundImage: avatarUrl == null
                        ? null
                        : CachedNetworkImageProvider(avatarUrl),
                    child: avatarUrl == null
                        ? Text(
                            initial,
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              color: Colors.amberAccent,
                            ),
                          )
                        : null,
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
                        if (_phone.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'SĐT: $_phone',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: AppColors.muted(context)),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          'Đã đặt $bookedCount lịch',
                          style: const TextStyle(
                              color: Colors.deepOrange, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Sửa hồ sơ',
                    icon: Icon(Icons.edit, color: AppColors.title(context)),
                    onPressed: _editProfile,
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

  // Kiểu nút nhỏ gọn để xếp hai nút chồng lên nhau trong một dòng lịch
  ButtonStyle get _compactButton => TextButton.styleFrom(
        minimumSize: Size.zero,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );

  Widget _bookingTile(Map<String, dynamic> booking) {
    final status = booking['status'] as String?;
    final cancelled = status == 'cancelled';
    final completed = status == 'completed';

    final IconData icon;
    final Color color;
    final String statusText;
    if (cancelled) {
      icon = Icons.close;
      color = Colors.redAccent;
      statusText = 'Đã hủy';
    } else if (completed) {
      icon = Icons.check;
      color = Colors.green;
      statusText = 'Hoàn thành';
    } else if (_startOf(booking).isAfter(DateTime.now())) {
      icon = Icons.schedule;
      color = Colors.orange;
      statusText = 'Sắp tới';
    } else {
      // Đã tới giờ hẹn nhưng chưa tới giờ kết thúc
      icon = Icons.timelapse;
      color = Colors.blue;
      statusText = 'Đang thực hiện';
    }

    // Ghép các dòng mô tả, dòng nào không có dữ liệu thì bỏ qua
    final barberName = booking['barber_name'] as String?;
    final hairstyleName = booking['hairstyle_name'] as String?;
    final rating = booking['rating'] as int?;
    final lines = <String>[
      '${formatDbDate(booking['booking_date'] as String)} • '
          '${shortTime(booking['booking_time'] as String)}',
      if (barberName != null && barberName.isNotEmpty) 'Thợ: $barberName',
      if (hairstyleName != null && hairstyleName.isNotEmpty)
        'Kiểu tóc: $hairstyleName',
      '${formatPrice(booking['price'] as int)} đ • $statusText',
      if (rating != null) 'Bạn đã đánh giá: $rating/5 ★',
    ];

    final canComplete = _canComplete(booking);
    final canCancel = _canCancel(booking);

    Widget? trailing;
    if (canComplete || canCancel) {
      // Nút Hoàn thành nằm trên nút Hủy
      trailing = Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (canComplete)
            TextButton(
              style: _compactButton,
              onPressed: () => _completeBooking(booking),
              child: const Text('Hoàn thành',
                  style: TextStyle(color: Colors.green)),
            ),
          if (canCancel)
            TextButton(
              style: _compactButton,
              onPressed: () => _cancelBooking(booking),
              child:
                  const Text('Hủy', style: TextStyle(color: Colors.redAccent)),
            ),
        ],
      );
    } else if (completed && rating == null) {
      trailing = TextButton(
        style: _compactButton,
        onPressed: () => _reviewBooking(booking),
        child: Text('Đánh giá',
            style: TextStyle(color: AppColors.title(context))),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: AppColors.background(context),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking['service_name'] as String,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        decoration:
                            cancelled ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(lines.join('\n')),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Align(
                    alignment: Alignment.topRight,
                    child: trailing,
                  ),
                ),
              ],
            ],
          ),
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
