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
}
