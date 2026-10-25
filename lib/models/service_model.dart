class BarberService {
  final String id;
  final String name;
  final int price;
  final String duration;

  BarberService({
    required this.id,
    required this.name,
    required this.price,
    required this.duration,
  });
}

final List<BarberService> sampleServices = [
  BarberService(
    id: '1',
    name: 'Cắt tóc Standard Combo',
    price: 100000,
    duration: '45 phút',
  ),
  BarberService(
    id: '2',
    name: 'Uốn tóc Texture/Premlock',
    price: 300000,
    duration: '90 phút',
  ),
  BarberService(
    id: '3',
    name: 'Nhuộm màu thời trang',
    price: 250000,
    duration: '60 phút',
  ),
  BarberService(
    id: '4',
    name: 'Cạo râu & Massage mặt',
    price: 50000,
    duration: '20 phút',
  ),
];
