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

  factory Hairstyle.fromMap(Map<String, dynamic> map) {
    return Hairstyle(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String,
      imageUrl: map['image_url'] as String,
    );
  }
}