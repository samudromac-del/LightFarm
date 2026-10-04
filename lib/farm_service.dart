import 'package:supabase_flutter/supabase_flutter.dart';

class FarmService{
  //supabase connection
  final supabase = Supabase.instance.client;

  //update farm area
  Future<void> updateArea(double area) async {
    var user = supabase.auth.currentUser;
    if (user == null) return;

    await supabase.from('profiles').update({'area': area}).eq('id', user.id);
  }

  //get all farmers in a region
  Future<List<Map<String, dynamic>>> getFarmersInRegion(String region) async {
    final data = await supabase
        .from('profiles')
        .select()
        .eq('role', 'farmer')
        .eq('location', region);
    return List<Map<String, dynamic>>.from(data);
  }

  // ── Crop recommendation helpers ──────────────────────────

  /// Calls the SECURITY DEFINER function get_crop_totals().
  /// Returns a map: crop → production (tons).
  Future<Map<String, double>> getCropTotals() async {
    final rows = await supabase.rpc('get_crop_totals');
    final Map<String, double> result = {};
    for (final row in (rows as List<dynamic>)) {
      final crop       = row['crop']       as String?;
      final production = row['production'] as num?;
      if (crop != null) result[crop] = (production ?? 0).toDouble();
    }
    return result;
  }

  /// Reads the crop_demand table. Returns map: crop → expected_demand.
  Future<Map<String, double>> getCropDemand() async {
    final data = await supabase.from('crop_demand').select();
    final Map<String, double> result = {};
    for (final row in (data as List<dynamic>)) {
      final crop   = row['crop']            as String?;
      final demand = row['expected_demand'] as num?;
      if (crop != null) result[crop] = (demand ?? 0).toDouble();
    }
    return result;
  }

  /// Upserts a single crop's expected_demand (admin only).
  Future<void> upsertCropDemand(String crop, double demand) async {
    await supabase.from('crop_demand').upsert(
      {'crop': crop, 'expected_demand': demand},
      onConflict: 'crop',
    );
  }
}
