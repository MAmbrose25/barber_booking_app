import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/barber_model.dart';
import '../models/hairstyle_model.dart';
import '../models/service_model.dart';

/// Lấy danh sách thợ, dịch vụ, kiểu tóc từ Supabase
class CatalogRepository {
  CatalogRepository._();

  static SupabaseClient get _client => Supabase.instance.client;

  static Future<List<Barber>> fetchBarbers() async {
    final rows = await _client.from('barbers').select().order('sort_order');
    final ratingRows = await _client.from('barber_ratings').select();
    final ratingByBarber = {
      for (final r in ratingRows) r['barber_id'] as String: r,
    };
    return rows
        .map((r) => Barber.fromMap(r, ratingRow: ratingByBarber[r['id']]))
        .toList();
  }

  static Future<List<BarberService>> fetchServices() async {
    final rows = await _client.from('services').select().order('sort_order');
    return rows.map(BarberService.fromMap).toList();
  }

  static Future<List<Hairstyle>> fetchHairstyles() async {
    final rows = await _client.from('hairstyles').select().order('sort_order');
    return rows.map(Hairstyle.fromMap).toList();
  }
}