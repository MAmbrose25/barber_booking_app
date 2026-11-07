import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';

import '../data/catalog_repository.dart';
import '../models/barber_model.dart';
import '../models/hairstyle_model.dart';
import '../models/service_model.dart';
import '../theme/app_theme.dart';
import '../utils/booking_utils.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _client = Supabase.instance.client;

  // Danh mục lấy từ Supabase
  List<Barber> _barbers = [];
  List<BarberService> _services = [];
  List<Hairstyle> _hairstyles = [];
  bool _loadingCatalog = true;
  bool _catalogError = false;

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  String? _selectedTime;
  String? _selectedBarberId;
  String? _selectedHairstyleId; // không bắt buộc, bấm lần nữa để bỏ chọn
  String? _selectedServiceId;
  String _paymentMethod = 'MOMO';

  // Các khoảng thời gian đã có người đặt của thợ trong ngày, tính bằng phút từ 0h
  List<(int, int)> _busy = [];

  final List<String> _timeSlots = const [
    '08:30', '09:30', '10:30', '13:30', '14:30', '15:30', '16:30', '17:30',
  ];

  // Salon đóng cửa lúc 19:00, dịch vụ không được kéo dài quá giờ này
  static const int _closeMinutes = 19 * 60;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    try {
      final barbers = await CatalogRepository.fetchBarbers();
      final services = await CatalogRepository.fetchServices();
      final hairstyles = await CatalogRepository.fetchHairstyles();
      if (!mounted) return;
      setState(() {
        _barbers = barbers;
        _services = services;
        _hairstyles = hairstyles;
        _selectedBarberId ??= barbers.isNotEmpty ? barbers.first.id : null;
        _selectedServiceId ??= services.isNotEmpty ? services.first.id : null;
        _loadingCatalog = false;
        _catalogError = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingCatalog = false;
        _catalogError = true;
      });
    }
  }

  BarberService? get _selectedService {
    for (final s in _services) {
      if (s.id == _selectedServiceId) return s;
    }
    return null;
  }

  Barber? get _selectedBarber {
    for (final b in _barbers) {
      if (b.id == _selectedBarberId) return b;
    }
    return null;
  }

  Hairstyle? get _selectedHairstyle {
    for (final h in _hairstyles) {
      if (h.id == _selectedHairstyleId) return h;
    }
    return null;
  }

  String _dateToDb(DateTime day) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  // Khung giờ đã qua trong ngày hôm nay thì không cho chọn
  bool _isPastSlot(String time) {
    final day = _selectedDay;
    if (day == null || !isSameDay(day, DateTime.now())) return false;
    final parts = time.split(':');
    final slot = DateTime(
        day.year, day.month, day.day, int.parse(parts[0]), int.parse(parts[1]));
    return slot.isBefore(DateTime.now());
  }

  // Khung giờ bị khóa nếu đã qua, vượt giờ đóng cửa, hoặc đụng lịch khác của thợ
  // (tính theo thời lượng của gói dịch vụ đang chọn)
  bool _isSlotDisabled(String time) {
    if (_isPastSlot(time)) return true;
    final duration = _selectedService?.durationMinutes ?? 60;
    final start = minutesOfDay(time);
    final end = start + duration;
    if (end > _closeMinutes) return true;
    return _busy.any((b) => start < b.$2 && end > b.$1);
  }

  // Tải các lịch đã có của thợ đang chọn trong ngày
  Future<void> _loadBookedSlots(DateTime day) async {
    final barberId = _selectedBarberId;
    if (barberId == null) return;
    try {
      final data = await _client
          .from('bookings')
          .select('booking_time, duration_minutes')
          .eq('booking_date', _dateToDb(day))
          .eq('barber_id', barberId)
          .neq('status', 'cancelled'); // lịch đã hủy thì giờ đó trống lại
      // Nếu trong lúc chờ người dùng đã đổi thợ hoặc đổi ngày thì bỏ kết quả này
      if (!mounted ||
          _selectedBarberId != barberId ||
          !isSameDay(_selectedDay, day)) {
        return;
      }
      setState(() {
        _busy = data.map<(int, int)>((row) {
          final start = minutesOfDay(row['booking_time'] as String);
          final duration = (row['duration_minutes'] as num?)?.toInt() ?? 60;
          return (start, start + duration);
        }).toList();
      });
    } catch (_) {
      EasyLoading.showError('Không tải được các khung giờ đã đặt.');
    }
  }

  void _selectBarber(Barber barber) {
    if (_selectedBarberId == barber.id) return;
    setState(() {
      _selectedBarberId = barber.id;
      _selectedTime = null;
      _busy = [];
    });
    if (_selectedDay != null) _loadBookedSlots(_selectedDay!);
  }

  // Đổi gói dịch vụ có thể làm khung giờ đang chọn không còn đủ thời gian
  void _selectService(BarberService service) {
    final hadTime = _selectedTime != null;
    setState(() {
      _selectedServiceId = service.id;
      final time = _selectedTime;
      if (time != null && _isSlotDisabled(time)) _selectedTime = null;
    });
    if (hadTime && _selectedTime == null) {
      EasyLoading.showInfo('Gói này cần nhiều thời gian hơn, hãy chọn lại giờ.');
    }
  }

  Future<void> _confirmBooking() async {
    final day = _selectedDay;
    final time = _selectedTime;
    final service = _selectedService;
    final barber = _selectedBarber;
    if (day == null || time == null || service == null || barber == null) {
      EasyLoading.showError('Vui lòng chọn thợ, ngày, giờ và gói dịch vụ.');
      return;
    }

    final hairstyle = _selectedHairstyle;
    final date = '${day.day.toString().padLeft(2, '0')}/'
        '${day.month.toString().padLeft(2, '0')}/${day.year}';
    final paymentLabel = switch (_paymentMethod) {
      'MOMO' => 'MoMo (bản demo)',
      'VNPAY' => 'VNPay (bản demo)',
      _ => 'Thanh toán tại salon',
    };

    EasyLoading.show(status: 'Đang lưu lịch hẹn...');
    try {
      await _client.from('bookings').insert({
        'booking_date': _dateToDb(day),
        'booking_time': time,
        'duration_minutes': service.durationMinutes,
        'barber_id': barber.id,
        'barber_name': barber.name,
        'hairstyle_name': hairstyle?.name,
        'service_id': service.id,
        'service_name': service.name,
        'price': service.price,
        'payment_method': _paymentMethod,
      });
      EasyLoading.dismiss();
      if (!mounted) return;

      await _loadBookedSlots(day);
      if (!mounted) return;
      setState(() => _selectedTime = null);

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Đặt lịch thành công'),
          content: Text(
            'Ngày: $date\nGiờ: $time (${service.durationLabel})\n'
            'Thợ: ${barber.name}\n'
            'Kiểu tóc: ${hairstyle?.name ?? 'Tư vấn tại salon'}\n'
            'Dịch vụ: ${service.name}\n'
            'Giá: ${formatPrice(service.price)} đ\nThanh toán: $paymentLabel\n\n'
            'Lịch hẹn đã được lưu, bạn xem và hủy lịch trong mục Tài khoản. '
            'Phần thanh toán MoMo/VNPay chỉ là demo, chưa có giao dịch thật.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
    } on PostgrestException catch (e) {
      // 23505 = trùng đúng giờ bắt đầu, 23P01 = thời gian bị chồng với lịch khác của thợ
      if (e.code == '23505' || e.code == '23P01') {
        EasyLoading.showError('Khung giờ này vừa có người đặt, hãy chọn giờ khác.');
        await _loadBookedSlots(day);
        if (mounted) setState(() => _selectedTime = null);
      } else {
        EasyLoading.showError('Không lưu được lịch hẹn: ${e.message}');
      }
    } catch (_) {
      EasyLoading.showError('Có lỗi xảy ra, vui lòng thử lại.');
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loadingCatalog) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_catalogError) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Không tải được dữ liệu đặt lịch.'),
            TextButton(
              onPressed: () {
                setState(() {
                  _loadingCatalog = true;
                  _catalogError = false;
                });
                _loadCatalog();
              },
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    } else {
      body = _buildForm(context);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('ĐẶT LỊCH & THANH TOÁN',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
      ),
      body: body,
    );
  }

  Widget _buildForm(BuildContext context) {
    final selectedService = _selectedService;
    final isDark = AppColors.isDark(context);
    final textColor = Theme.of(context).colorScheme.onSurface;
    final mutedColor = AppColors.muted(context);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('1. Chọn thợ cắt tóc'),
          const SizedBox(height: 10),
          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _barbers.length,
              itemBuilder: (context, index) => _barberCard(_barbers[index]),
            ),
          ),
          const SizedBox(height: 16),
          _sectionTitle('2. Chọn ngày cắt tóc'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: TableCalendar(
              firstDay: DateUtils.dateOnly(DateTime.now()),
              lastDay: DateUtils.dateOnly(
                  DateTime.now().add(const Duration(days: 30))),
              focusedDay: _focusedDay,
              calendarFormat: CalendarFormat.twoWeeks,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                  _selectedTime = null;
                  _busy = [];
                });
                _loadBookedSlots(selectedDay);
              },
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(fontSize: 17, color: textColor),
                leftChevronIcon: Icon(Icons.chevron_left, color: textColor),
                rightChevronIcon: Icon(Icons.chevron_right, color: textColor),
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: TextStyle(color: textColor),
                weekendStyle: TextStyle(color: mutedColor),
              ),
              calendarStyle: CalendarStyle(
                defaultTextStyle: TextStyle(color: textColor),
                weekendTextStyle: TextStyle(color: mutedColor),
                todayDecoration: BoxDecoration(
                    color:
                        isDark ? Colors.brown.shade700 : Colors.brown.shade200,
                    shape: BoxShape.circle),
                selectedDecoration: BoxDecoration(
                    color: AppColors.button(context), shape: BoxShape.circle),
                selectedTextStyle: const TextStyle(
                    color: Colors.amber, fontWeight: FontWeight.bold),
              ),
            ),
          ).animate().fadeIn(),
          const SizedBox(height: 20),
          _sectionTitle('3. Chọn khung giờ trống'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _timeSlots.map((time) {
              final isSelected = _selectedTime == time;
              final isDisabled = _isSlotDisabled(time);
              return ChoiceChip(
                label: Text(time),
                selected: isSelected,
                selectedColor: AppColors.button(context),
                labelStyle: TextStyle(
                  color: isDisabled
                      ? Colors.grey
                      : (isSelected ? Colors.amberAccent : textColor),
                  decoration: isDisabled ? TextDecoration.lineThrough : null,
                ),
                onSelected: isDisabled
                    ? null
                    : (_) => setState(() => _selectedTime = time),
              );
            }).toList(),
          ),
          if (selectedService != null && selectedService.durationMinutes > 60)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Gói "${selectedService.name}" kéo dài ${selectedService.durationLabel}, '
                'nên các khung giờ vướng lịch khác của thợ sẽ bị gạch.',
                style: TextStyle(fontSize: 12, color: mutedColor),
              ),
            ),
          const SizedBox(height: 24),
          _sectionTitle('4. Chọn kiểu tóc (không bắt buộc)'),
          const SizedBox(height: 10),
          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _hairstyles.length,
              itemBuilder: (context, index) =>
                  _hairstyleCard(_hairstyles[index]),
            ),
          ),
          const SizedBox(height: 24),
          _sectionTitle('5. Chọn gói dịch vụ'),
          const SizedBox(height: 10),
          ..._services.map((service) {
            final isSelected = _selectedServiceId == service.id;
            return Card(
              color: AppColors.card(context),
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: isSelected
                      ? AppColors.title(context)
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ListTile(
                leading: Icon(
                  isSelected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: isSelected ? AppColors.title(context) : Colors.grey,
                ),
                title: Text(service.name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Thời lượng: ${service.durationLabel}'),
                trailing: Text('${formatPrice(service.price)} đ',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                onTap: () => _selectService(service),
              ),
            );
          }),
          const SizedBox(height: 16),
          _sectionTitle('6. Phương thức thanh toán'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _paymentChoice('MOMO', 'MoMo (demo)'),
              _paymentChoice('VNPAY', 'VNPay (demo)'),
              _paymentChoice('TIEN_MAT', 'Tại salon'),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.button(context),
                foregroundColor: Colors.amberAccent,
              ),
              onPressed: _confirmBooking,
              child: Text(selectedService == null
                  ? 'XÁC NHẬN'
                  : 'XÁC NHẬN (${formatPrice(selectedService.price)} Đ)'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _barberCard(Barber barber) {
    final isSelected = _selectedBarberId == barber.id;
    final rating = barber.rating;
    return GestureDetector(
      onTap: () => _selectBarber(barber),
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.title(context) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: Colors.brown.shade200,
              backgroundImage: CachedNetworkImageProvider(barber.avatarUrl),
            ),
            const SizedBox(height: 8),
            Text(
              barber.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              barber.role,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: AppColors.muted(context)),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(rating == null ? Icons.star_border : Icons.star,
                    size: 14, color: Colors.amber),
                const SizedBox(width: 4),
                Text(
                  rating == null
                      ? 'Mới'
                      : '${rating.toStringAsFixed(1)} (${barber.reviewCount})',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _hairstyleCard(Hairstyle style) {
    final isSelected = _selectedHairstyleId == style.id;
    return GestureDetector(
      // bấm vào kiểu đang chọn thì bỏ chọn
      onTap: () =>
          setState(() => _selectedHairstyleId = isSelected ? null : style.id),
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 12),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.title(context) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: CachedNetworkImage(
                  imageUrl: style.imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      Container(color: AppColors.shimmerBase(context)),
                  errorWidget: (context, url, error) =>
                      const Icon(Icons.broken_image),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      style.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle,
                        size: 16, color: AppColors.title(context)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppColors.title(context),
        ),
      );

  Widget _paymentChoice(String value, String label) => ChoiceChip(
        label: Text(label),
        selected: _paymentMethod == value,
        onSelected: (_) => setState(() => _paymentMethod = value),
      );
}