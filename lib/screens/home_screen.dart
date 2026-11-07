import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:badges/badges.dart' as badges;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/catalog_repository.dart';
import '../models/hairstyle_model.dart';
import '../theme/app_theme.dart';
import '../utils/booking_utils.dart';
import 'all_hairstyles_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _client = Supabase.instance.client;

  final List<String> banners = const [
    'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?w=800',
    'https://images.unsplash.com/photo-1621605815971-fbc98d665033?w=800',
    'https://images.unsplash.com/photo-1599351431202-1e0f0137899a?w=800',
  ];

  List<Hairstyle> _hairstyles = [];
  bool _loadingHairstyles = true;
  bool _hairstyleError = false;

  // Lịch hẹn sắp tới của người dùng, dùng làm thông báo nhắc lịch
  List<Map<String, dynamic>> _upcoming = [];

  @override
  void initState() {
    super.initState();
    _loadHairstyles();
    _loadUpcoming();
  }

  Future<void> _loadHairstyles() async {
    try {
      final data = await CatalogRepository.fetchHairstyles();
      if (!mounted) return;
      setState(() {
        _hairstyles = data;
        _loadingHairstyles = false;
        _hairstyleError = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingHairstyles = false;
        _hairstyleError = true;
      });
    }
  }

  Future<void> _loadUpcoming() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      final data = await _client
          .from('bookings')
          .select('service_name, booking_date, booking_time, barber_name')
          .eq('user_id', user.id)
          .eq('status', 'booked')
          .order('booking_date')
          .order('booking_time');
      final now = DateTime.now();
      final upcoming = List<Map<String, dynamic>>.from(data)
          .where((b) => bookingStart(
                  b['booking_date'] as String, b['booking_time'] as String)
              .isAfter(now))
          .toList();
      if (!mounted) return;
      setState(() => _upcoming = upcoming);
    } catch (_) {
      // Không tải được thì để trống, không cần báo lỗi ở trang chủ
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleHairstyles = _hairstyles.take(4).toList();

    return Scaffold(
      // Màu nền và màu AppBar lấy từ theme trong app_theme.dart
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'CLASSIC BARBER SHOP',
          style: TextStyle(
            letterSpacing: 1.2,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: badges.Badge(
              showBadge: _upcoming.isNotEmpty,
              position: badges.BadgePosition.topEnd(top: 2, end: 2),
              badgeContent: Text('${_upcoming.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 10)),
              badgeStyle:
                  const badges.BadgeStyle(badgeColor: Colors.deepOrangeAccent),
              child: IconButton(
                icon: const Icon(Icons.notifications_none, color: Colors.white),
                tooltip: 'Thông báo',
                onPressed: () => _showNotifications(context),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            // Slider ảnh banner khuyến mãi (Chủ đề 2)
            CarouselSlider(
              options: CarouselOptions(
                height: 190.0,
                autoPlay: true,
                enlargeCenterPage: true,
                viewportFraction: 0.9,
                autoPlayCurve: Curves.fastOutSlowIn,
              ),
              items: banners.map((url) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    // Hiệu ứng Shimmer khi đang tải ảnh từ mạng (Chủ đề 1)
                    placeholder: (context, url) => Shimmer.fromColors(
                      baseColor: AppColors.shimmerBase(context),
                      highlightColor: AppColors.shimmerHighlight(context),
                      child: Container(
                          color: Colors.white,
                          width: double.infinity,
                          height: 190),
                    ),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.broken_image),
                  ),
                );
              }).toList(),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),

            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Mẫu tóc xu hướng 2026',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.title(context)),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.title(context),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AllHairstylesScreen()),
                    ),
                    child: const Text('Xem tất cả',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            if (_hairstyleError)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text('Không tải được mẫu tóc.',
                        style: TextStyle(color: AppColors.muted(context))),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _loadingHairstyles = true;
                          _hairstyleError = false;
                        });
                        _loadHairstyles();
                      },
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              )
            else if (!_loadingHairstyles && visibleHairstyles.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text('Chưa có mẫu tóc nào.',
                    style: TextStyle(color: AppColors.muted(context))),
              )
            else
              // Lưới mẫu tóc lấy từ bảng hairstyles trên Supabase
              GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.85,
                ),
                itemCount: _loadingHairstyles ? 4 : visibleHairstyles.length,
                itemBuilder: (context, index) {
                  final Widget tile = _loadingHairstyles
                      ? _skeletonTile(context)
                      : HairstyleTile(style: visibleHairstyles[index]);
                  return tile
                      .animate()
                      .fadeIn(delay: (100 * index).ms)
                      .scale(begin: const Offset(0.95, 0.95));
                },
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Ô giữ chỗ trong lúc đang tải danh sách kiểu tóc
  Widget _skeletonTile(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Shimmer.fromColors(
          baseColor: AppColors.shimmerBase(context),
          highlightColor: AppColors.shimmerHighlight(context),
          child: Container(color: Colors.white),
        ),
      );

  void _showNotifications(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.background(context),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Thông báo',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (_upcoming.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text('Chưa có thông báo mới.',
                      style: TextStyle(color: AppColors.muted(sheetContext))),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _upcoming.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final b = _upcoming[index];
                      final barberName = b['barber_name'] as String?;
                      final hasBarber =
                          barberName != null && barberName.isNotEmpty;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.calendar_month,
                            color: AppColors.title(sheetContext)),
                        title: Text('Lịch hẹn sắp tới: ${b['service_name']}'),
                        subtitle: Text(
                          '${shortTime(b['booking_time'] as String)} ngày '
                          '${formatDbDate(b['booking_date'] as String)}'
                          '${hasBarber ? ' • Thợ: $barberName' : ''}',
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}