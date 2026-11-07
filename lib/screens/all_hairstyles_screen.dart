import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:shimmer/shimmer.dart';

import '../data/catalog_repository.dart';
import '../data/favorites_repository.dart';
import '../models/hairstyle_model.dart';
import '../theme/app_theme.dart';

/// Thẻ một kiểu tóc có nút thả tim, bấm vào thẻ thì mở ảnh lớn
class HairstyleTile extends StatefulWidget {
  final Hairstyle style;
  const HairstyleTile({super.key, required this.style});

  @override
  State<HairstyleTile> createState() => _HairstyleTileState();
}

class _HairstyleTileState extends State<HairstyleTile> {
  @override
  void initState() {
    super.initState();
    FavoritesRepository.ensureLoaded();
  }

  Future<void> _toggleFavorite() async {
    final ok = await FavoritesRepository.toggle(widget.style.id);
    if (!ok) EasyLoading.showError('Không cập nhật được mục yêu thích.');
  }

  Widget _heartButton() => ValueListenableBuilder<Set<String>>(
        valueListenable: FavoritesRepository.favoriteIds,
        builder: (context, ids, _) {
          final isFavorite = ids.contains(widget.style.id);
          return GestureDetector(
            onTap: _toggleFavorite,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.black45,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                size: 20,
                color: isFavorite ? Colors.redAccent : Colors.white,
              ),
            ),
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    return GestureDetector(
      onTap: () => showHairstyleDetail(context, style),
      child: Container(
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
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(14)),
                    child: CachedNetworkImage(
                      imageUrl: style.imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (context, url) => Shimmer.fromColors(
                        baseColor: AppColors.shimmerBase(context),
                        highlightColor: AppColors.shimmerHighlight(context),
                        child: Container(color: Colors.white),
                      ),
                      errorWidget: (context, url, error) =>
                          const Center(child: Icon(Icons.broken_image)),
                    ),
                  ),
                  Positioned(top: 8, right: 8, child: _heartButton()),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    style.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.title(context)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    style.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11, color: AppColors.muted(context)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void showHairstyleDetail(BuildContext context, Hairstyle style) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: AppColors.background(context),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: CachedNetworkImage(
                  imageUrl: style.imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      Container(color: AppColors.shimmerBase(context)),
                  errorWidget: (context, url, error) =>
                      const Center(child: Icon(Icons.broken_image)),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              style.name,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.title(sheetContext)),
            ),
            const SizedBox(height: 4),
            Text(style.description,
                style: TextStyle(color: AppColors.muted(sheetContext))),
          ],
        ),
      ),
    ),
  );
}

class AllHairstylesScreen extends StatefulWidget {
  const AllHairstylesScreen({super.key});

  @override
  State<AllHairstylesScreen> createState() => _AllHairstylesScreenState();
}

class _AllHairstylesScreenState extends State<AllHairstylesScreen> {
  List<Hairstyle> _hairstyles = [];
  bool _loading = true;
  bool _error = false;
  bool _onlyFavorites = false; // true = chỉ hiện các kiểu đã thả tim

  @override
  void initState() {
    super.initState();
    FavoritesRepository.ensureLoaded();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await CatalogRepository.fetchHairstyles();
      if (!mounted) return;
      setState(() {
        _hairstyles = data;
        _loading = false;
        _error = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Không tải được danh sách kiểu tóc.'),
            TextButton(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _error = false;
                });
                _load();
              },
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    } else {
      body = ValueListenableBuilder<Set<String>>(
        valueListenable: FavoritesRepository.favoriteIds,
        builder: (context, ids, _) {
          final list = _onlyFavorites
              ? _hairstyles.where((h) => ids.contains(h.id)).toList()
              : _hairstyles;
          if (list.isEmpty) {
            return Center(
              child: Text(
                _onlyFavorites
                    ? 'Bạn chưa thả tim kiểu tóc nào.'
                    : 'Chưa có kiểu tóc nào.',
                style: TextStyle(color: AppColors.muted(context)),
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 0.85,
            ),
            itemCount: list.length,
            itemBuilder: (context, index) => HairstyleTile(
              key: ValueKey(list[index].id),
              style: list[index],
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('MẪU TÓC XU HƯỚNG',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        actions: [
          IconButton(
            tooltip: _onlyFavorites ? 'Xem tất cả' : 'Chỉ xem kiểu đã thích',
            icon: Icon(
              _onlyFavorites ? Icons.favorite : Icons.favorite_border,
              color: _onlyFavorites ? Colors.redAccent : Colors.white,
            ),
            onPressed: () => setState(() => _onlyFavorites = !_onlyFavorites),
          ),
        ],
      ),
      body: body,
    );
  }
}