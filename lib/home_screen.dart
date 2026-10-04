import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'farm_service.dart';
import 'login_screen.dart';
import 'crop_overview_screen.dart';

//fixed crop list (3 crops only)
const List<String> kCropList = ['rice', 'wheat', 'potato'];

// ─────────────────────────────────────────
// Home screen
// ─────────────────────────────────────────
class HomeScreen extends StatefulWidget{
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>{
  final _authService = AuthService();
  final _farmService = FarmService();

  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _farmers = [];
  bool _isLoading = true;

  // ── farmer recommendation state ──────────
  String? _recommendedCrop;   // null = no suitable crops

  @override
  void initState(){
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async{
    final profile = await _authService.getCurrentProfile();
    if(profile?['role'] == 'local_gov' && profile?['location'] != null){
      _farmers = await _farmService.getFarmersInRegion(profile!['location']);
    }

    String? recommended;
    if(profile?['role'] == 'farmer'){
      recommended = await _loadRecommendation(profile!);
    }

    if(!mounted) return;
    setState((){
      _profile = profile;
      _recommendedCrop = recommended;
      _isLoading = false;
    });
  }

  /// Computes the max-gap crop recommendation for a farmer.
  Future<String?> _loadRecommendation(Map<String, dynamic> profile) async{
    final suitable = _toList(profile['suitable_crops']);
    if(suitable.isEmpty) return null;

    // fetch in parallel
    final results = await Future.wait([
      _farmService.getCropTotals(),
      _farmService.getCropDemand(),
    ]);
    final totals = results[0] as Map<String, double>;
    final demand = results[1] as Map<String, double>;

    // find crop with max gap (expected_demand − production)
    String? best;
    double bestGap = double.negativeInfinity;
    for(final crop in suitable){
      final production    = totals[crop] ?? 0.0;
      final expectedDemand = demand[crop] ?? 0.0;
      final gap = expectedDemand - production;
      if(gap > bestGap){
        bestGap = gap;
        best    = crop;
      }
    }
    return best;
  }

  Future<void> _logout() async{
    await _authService.signOut();
    if(!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _openEdit() async{
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FarmerEditScreen(
          profile: _profile!,
          authService: _authService,
          farmService: _farmService,
        ),
      ),
    );
    setState(() => _isLoading = true);
    await _loadProfile();
  }

  void _openCropOverview(){
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CropOverviewScreen(
        profile: _profile!,
        authService: _authService,
        farmService: _farmService,
      ),
    ));
  }

  // ── farmer read view ──────────────────
  Widget _farmerView(){
    final suitable = _toList(_profile?['suitable_crops']);
    final planning = _profile?['planning_this_season'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoRow('Region',    _profile?['location'] ?? '—'),
        _infoRow('Land area', '${_profile?['area'] ?? 0} acres'),
        const SizedBox(height: 16),

        const Text('Suitable crops', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        suitable.isEmpty
            ? const Text('None selected', style: TextStyle(color: Colors.grey))
            : Wrap(
                spacing: 6, runSpacing: 4,
                children: suitable.map((c) => Chip(label: Text(c))).toList(),
              ),

        const SizedBox(height: 16),
        const Text('Planning this season', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Chip(
          label: Text(planning ?? 'Not decided'),
          backgroundColor: planning == null ? Colors.grey.shade200 : null,
        ),

        // ── Recommendation banner ─────────────────────────────
        // Only shown when: suitable crops selected AND not yet decided
        if(suitable.isNotEmpty && planning == null && _recommendedCrop != null) ...[
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              border: Border.all(color: Colors.green.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.eco, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Recommended: ${_recommendedCrop![0].toUpperCase()}${_recommendedCrop!.substring(1)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
        ],
        // ─────────────────────────────────────────────────────

        const SizedBox(height: 28),
        ElevatedButton.icon(
          onPressed: _openEdit,
          icon: const Icon(Icons.edit),
          label: const Text('Update'),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(value),
      ],
    ),
  );

  // ── local gov view ────────────────────
  Widget _govView(){
    final total = _farmers.fold<double>(
      0, (sum, f) => sum + ((f['area'] as num?)?.toDouble() ?? 0),
    );
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${_farmers.length} farmers · ${total.toStringAsFixed(1)} acres total'),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _openCropOverview,
            icon: const Icon(Icons.bar_chart),
            label: const Text('Crop Overview'),
          ),
          const SizedBox(height: 12),
          if(_farmers.isEmpty) const Text('No farmers found in your region.'),
          Expanded(
            child: ListView(
              children: [
                for(int i = 0; i < _farmers.length; i++)
                  ListTile(
                    leading: Text('${i + 1}.'),
                    title: Text(_farmers[i]['full_name'] ?? 'Unknown'),
                    subtitle: Text('${_farmers[i]['area'] ?? 0} acres'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── admin view ────────────────────────
  Widget _adminView(){
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Admin Dashboard',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _openCropOverview,
          icon: const Icon(Icons.bar_chart),
          label: const Text('Crop Overview (All Regions)'),
        ),
        const SizedBox(height: 24),
        const Text('Manage Crop Demand',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _CropDemandForm(farmService: _farmService),
      ],
    );
  }

  @override
  Widget build(BuildContext context){
    if(_isLoading){
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final role = _profile?['role'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('LightFarm'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, ${_profile?['full_name'] ?? 'User'}!',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            if(role == 'farmer')   _farmerView(),
            if(role == 'local_gov') _govView(),
            if(role == 'admin')    _adminView(),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Admin: crop demand form
// ─────────────────────────────────────────
class _CropDemandForm extends StatefulWidget{
  final FarmService farmService;
  const _CropDemandForm({required this.farmService});

  @override
  State<_CropDemandForm> createState() => _CropDemandFormState();
}

class _CropDemandFormState extends State<_CropDemandForm>{
  final Map<String, TextEditingController> _controllers = {
    for(final c in kCropList) c: TextEditingController(),
  };
  bool _loading = true;
  bool _saving  = false;

  @override
  void initState(){
    super.initState();
    _loadDemand();
  }

  @override
  void dispose(){
    for(final c in _controllers.values) c.dispose();
    super.dispose();
  }

  Future<void> _loadDemand() async{
    final demand = await widget.farmService.getCropDemand();
    for(final crop in kCropList){
      _controllers[crop]!.text = (demand[crop] ?? 0).toStringAsFixed(0);
    }
    if(!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _save() async{
    setState(() => _saving = true);
    try{
      for(final crop in kCropList){
        final val = double.tryParse(_controllers[crop]!.text.trim()) ?? 0;
        await widget.farmService.upsertCropDemand(crop, val);
      }
      if(!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Demand updated')),
      );
    }catch(e){
      if(!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }finally{
      if(mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context){
    if(_loading) return const CircularProgressIndicator();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for(final crop in kCropList) ...[
          Text(
            '${crop[0].toUpperCase()}${crop.substring(1)} expected demand (tons)',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _controllers[crop],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              isDense: true,
              hintText: '0',
              suffixText: 'tons',
            ),
          ),
          const SizedBox(height: 12),
        ],
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 18, width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save Demand'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
// Farmer edit screen (all fields, one Save)
// ─────────────────────────────────────────
class FarmerEditScreen extends StatefulWidget{
  final Map<String, dynamic> profile;
  final AuthService authService;
  final FarmService farmService;

  const FarmerEditScreen({
    super.key,
    required this.profile,
    required this.authService,
    required this.farmService,
  });

  @override
  State<FarmerEditScreen> createState() => _FarmerEditScreenState();
}

class _FarmerEditScreenState extends State<FarmerEditScreen>{
  late final TextEditingController _areaController;
  late Set<String> _suitable;
  String? _planning;   // null = "Not decided"
  bool _saving = false;

  @override
  void initState(){
    super.initState();
    _areaController = TextEditingController(
      text: (widget.profile['area'] ?? '').toString(),
    );
    _suitable = _toSet(widget.profile['suitable_crops']);
    _planning = widget.profile['planning_this_season'] as String?;
    //if saved value is no longer in suitable list, reset
    if(_planning != null && !_suitable.contains(_planning)) _planning = null;
  }

  @override
  void dispose(){
    _areaController.dispose();
    super.dispose();
  }

  Future<void> _save() async{
    final area = double.tryParse(_areaController.text.trim());
    if(area == null){
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid area')),
      );
      return;
    }

    setState(() => _saving = true);
    try{
      await widget.farmService.updateArea(area);
      await widget.authService.updateCropData(
        suitableCrops: _suitable.toList(),
        planningThisSeason: _planning,   // String? — null saved as SQL NULL
      );
      if(!mounted) return;
      Navigator.of(context).pop();
    }catch(e){
      if(!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context){
    //radio options = suitable crops + "Not decided"
    final radioOptions = ['Not decided', ..._suitable];

    return Scaffold(
      appBar: AppBar(title: const Text('Update Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            //── area ──────────────────────────────
            const Text('Land area (acres)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _areaController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),

            const SizedBox(height: 28),

            //── suitable crops ────────────────────
            const Text('Land suited for',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Column(
              children: kCropList.map((crop) => CheckboxListTile(
                dense: true,
                title: Text(crop),
                value: _suitable.contains(crop),
                onChanged: (checked){
                  setState((){
                    if(checked == true){
                      _suitable.add(crop);
                    }else{
                      _suitable.remove(crop);
                      //if planning was this crop, reset to Not decided
                      if(_planning == crop) _planning = null;
                    }
                  });
                },
              )).toList(),
            ),

            const SizedBox(height: 20),

            //── planning this season (single radio) ──
            const Text('Planning to grow this season',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            RadioGroup<String?>(
              groupValue: _planning,
              onChanged: (v) => setState(() => _planning = v),
              child: Column(
                children: radioOptions.map((option){
                  final value = option == 'Not decided' ? null : option;
                  return RadioListTile<String?>(
                    dense: true,
                    title: Text(option),
                    value: value,
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 32),

            //── save ──────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//helpers
List<String> _toList(dynamic raw){
  if(raw == null) return [];
  return List<dynamic>.from(raw).map((e) => e.toString()).toList();
}

Set<String> _toSet(dynamic raw) => _toList(raw).toSet();
