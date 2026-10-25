class Barber {
  final String id;
  final String name;
  final String role;
  final double rating;
  final String avatarUrl;

  Barber({
    required this.id,
    required this.name,
    required this.role,
    required this.rating,
    required this.avatarUrl,
  });
}

final List<Barber> sampleBarbers = [
  Barber(
    id: '1',
    name: 'Alex Nguyễn',
    role: 'Master Barber',
    rating: 4.9,
    avatarUrl:
        'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400',
  ),
  Barber(
    id: '2',
    name: 'Hoàng Trần',
    role: 'Top Stylist',
    rating: 4.8,
    avatarUrl:
        'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400',
  ),
];
