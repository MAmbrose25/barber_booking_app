class BarberService {
  final String id;
  final String name;
  final int price;
  final int durationMinutes;

  const BarberService({
    required this.id,
    required this.name,
    required this.price,
    required this.durationMinutes,
  });

  String get durationLabel => '$durationMinutes phút';

  factory BarberService.fromMap(Map<String, dynamic> map) {
    return BarberService(
      id: map['id'] as String,
      name: map['name'] as String,
      price: (map['price'] as num).toInt(),
      durationMinutes: (map['duration_minutes'] as num).toInt(),
    );
  }
}