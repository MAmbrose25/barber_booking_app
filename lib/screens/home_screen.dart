import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:badges/badges.dart' as badges;
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  final List<String> banners = const [
    'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?w=800',
    'https://images.unsplash.com/photo-1621605815971-fbc98d665033?w=800',
    'https://images.unsplash.com/photo-1599351431202-1e0f0137899a?w=800',
  ];

  @override
  Widget build(BuildContext context) {
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
              position: badges.BadgePosition.topEnd(top: 2, end: 2),
              badgeContent: const Text('1',
                  style: TextStyle(color: Colors.white, fontSize: 10)),
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
                  Text('Xem tất cả',
                      style: TextStyle(
                          color: AppColors.title(context),
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Lưới mẫu tóc dạng thẻ đổ bóng Card sạch đẹp
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
              itemCount: 4,
              itemBuilder: (context, index) {
                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.card(context),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        // ignore: deprecated_member_use
                        color: Colors.brown.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(14)),
                          child: CachedNetworkImage(
                            imageUrl: banners[index % banners.length],
                            fit: BoxFit.cover,
                            width: double.infinity,
                            // Hiệu ứng Shimmer cho từng ô ảnh
                            placeholder: (context, url) => Shimmer.fromColors(
                              baseColor: AppColors.shimmerBase(context),
                              highlightColor: AppColors.shimmerHighlight(context),
                              child: Container(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Kiểu Fade Master ${index + 1}',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.title(context)),
                            ),
                            const SizedBox(height: 4),
                            Text('Thời thượng • Lịch lãm',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.muted(context))),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
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
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.local_offer, color: Colors.deepOrange),
                title: Text('Ưu đãi tại Classic Barber Shop'),
                subtitle: Text('Đặt lịch ngay để trải nghiệm các dịch vụ mới.'),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.calendar_month,
                    color: AppColors.title(sheetContext)),
                title: const Text('Đặt lịch thuận tiện'),
                subtitle:
                    const Text('Chọn ngày và giờ phù hợp trong mục Đặt lịch.'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}