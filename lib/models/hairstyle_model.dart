class Hairstyle {
  final String id;
  final String name;
  final String description;
  final String imageUrl;

  const Hairstyle({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
  });
}

const List<Hairstyle> sampleHairstyles = [
  Hairstyle(
    id: '1',
    name: 'Kiểu Fade Master 1',
    description: 'Thời thượng • Lịch lãm',
    imageUrl:
        'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?w=800',
  ),
  Hairstyle(
    id: '2',
    name: 'Kiểu Fade Master 2',
    description: 'Thời thượng • Lịch lãm',
    imageUrl:
        'https://images.unsplash.com/photo-1621605815971-fbc98d665033?w=800',
  ),
  Hairstyle(
    id: '3',
    name: 'Kiểu Fade Master 3',
    description: 'Thời thượng • Lịch lãm',
    imageUrl:
        'https://images.unsplash.com/photo-1599351431202-1e0f0137899a?w=800',
  ),
  Hairstyle(
    id: '4',
    name: 'Kiểu Fade Master 4',
    description: 'Thời thượng • Lịch lãm',
    imageUrl:
        'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?w=800',
  ),
];