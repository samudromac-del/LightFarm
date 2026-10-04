import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'farm_service.dart';
import 'home_screen.dart'; // for kCropList

//assumed yield constants (tons per acre) — tune as needed
const Map<String, double> kYieldPerAcre = {
  'rice':   1.5,
  'wheat':  1.2,
  'potato': 8.0,
};

class CropOverviewScreen extends StatefulWidget{
  final Map<String, dynamic> profile;
  final AuthService authService;
  final FarmService farmService;

  const CropOverviewScreen({
    super.key,
    required this.profile,
    required this.authService,
    required this.farmService,
  });

  @override
  State<CropOverviewScreen> createState() => _CropOverviewScreenState();
}

class _CropOverviewScreenState extends State<CropOverviewScreen>{
  bool _isLoading = true;
  //grouped: crop name (or 'Not decided') → list of farmer profiles
  Map<String, List<Map<String, dynamic>>> _groups = {};

  // admin supply/demand data (from RPC + crop_demand table)
  Map<String, double> _supply = {};   // crop → production tons (from get_crop_totals)
  Map<String, double> _demand = {};   // crop → expected_demand tons

  @override
  void initState(){
    super.initState();
    _load();
  }

  Future<void> _load() async{
    List<Map<String, dynamic>> farmers;

    final role = widget.profile['role'];
    if(role == 'admin'){
      farmers = await widget.authService.getAllFarmers();
    }else{
      //local_gov — own region only
      final location = widget.profile['location'] as String?;
      if(location == null){
        farmers = [];
      }else{
        farmers = await widget.farmService.getFarmersInRegion(location);
      }
    }

    //group by planning_this_season; null → 'Not decided'
    final Map<String, List<Map<String, dynamic>>> groups = {};
    for(final crop in kCropList){
      groups[crop] = [];
    }
    groups['Not decided'] = [];

    for(final f in farmers){
      final plan = f['planning_this_season'] as String?;
      final key  = (plan != null && kCropList.contains(plan)) ? plan : 'Not decided';
      groups[key]!.add(f);
    }

    // admin-only: fetch supply (via RPC) and demand in parallel
    Map<String, double> supply = {};
    Map<String, double> demand = {};
    if(role == 'admin'){
      final results = await Future.wait([
        widget.farmService.getCropTotals(),
        widget.farmService.getCropDemand(),
      ]);
      supply = results[0] as Map<String, double>;
      demand = results[1] as Map<String, double>;
    }

    if(!mounted) return;
    setState((){
      _groups   = groups;
      _supply   = supply;
      _demand   = demand;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context){
    final role  = widget.profile['role'];
    final title = role == 'admin' ? 'Crop Overview — All Regions' : 'Crop Overview';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                //── admin supply/demand/gap table ─────────────
                if(role == 'admin') ...[
                  _supplyDemandTable(),
                  const SizedBox(height: 20),
                ],

                //── known crops ──────────────────────────
                for(final crop in kCropList) _cropSection(crop, role),

                //── not decided bucket ────────────────────
                _notDecidedSection(),
              ],
            ),
    );
  }

  // ── Supply / Demand / Gap table (admin only) ──────────────
  Widget _supplyDemandTable(){
    // header + one row per crop
    const headerStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 13);
    const cellStyle   = TextStyle(fontSize: 13);

    TableRow headerRow = TableRow(
      decoration: BoxDecoration(color: Colors.grey.shade200),
      children: [
        _cell('Crop',    headerStyle),
        _cell('Supply',  headerStyle, align: TextAlign.right),
        _cell('Demand',  headerStyle, align: TextAlign.right),
        _cell('Gap',     headerStyle, align: TextAlign.right),
      ],
    );

    final dataRows = kCropList.map((crop){
      final supply = _supply[crop] ?? 0.0;
      final demand = _demand[crop] ?? 0.0;
      final gap    = demand - supply;

      // positive gap = shortage (red), negative = surplus (green)
      final gapColor = gap > 0 ? Colors.red.shade700 : Colors.green.shade700;
      final gapText  = '${gap >= 0 ? '+' : ''}${gap.toStringAsFixed(1)}';
      final cropName = crop[0].toUpperCase() + crop.substring(1);

      return TableRow(children: [
        _cell(cropName,                          cellStyle),
        _cell('${supply.toStringAsFixed(1)} t',  cellStyle, align: TextAlign.right),
        _cell('${demand.toStringAsFixed(1)} t',  cellStyle, align: TextAlign.right),
        _cell(gapText,  cellStyle.copyWith(color: gapColor, fontWeight: FontWeight.w600),
              align: TextAlign.right),
      ]);
    }).toList();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Supply / Demand / Gap',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            const Text(
              'Gap = Demand − Supply  ·  + shortage  ·  − surplus',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(2),
                3: FlexColumnWidth(2),
              },
              border: TableBorder.all(color: Colors.grey.shade300, width: 0.8),
              children: [headerRow, ...dataRows],
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell(String text, TextStyle style,
      {TextAlign align = TextAlign.left}) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(text, style: style, textAlign: align),
      );

  // ─────────────────────────────────────────────────────────

  Widget _cropSection(String crop, String role){
    final farmers  = _groups[crop] ?? [];
    final total    = farmers.fold<double>(
        0, (s, f) => s + ((f['area'] as num?)?.toDouble() ?? 0));
    final yield_   = (kYieldPerAcre[crop] ?? 0) * total;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            //heading row
            Row(
              children: [
                Text(
                  crop[0].toUpperCase() + crop.substring(1),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text('${farmers.length} farmer${farmers.length == 1 ? '' : 's'}'),
              ],
            ),

            if(role == 'admin') ...[
              const SizedBox(height: 4),
              Text('Total land: ${total.toStringAsFixed(1)} acres'),
              Text(
                'Est. production: ${yield_.toStringAsFixed(1)} tons'
                ' (${kYieldPerAcre[crop]} t/acre)',
                style: const TextStyle(color: Colors.green),
              ),
            ],

            if(farmers.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('No farmers planning this crop.',
                    style: TextStyle(color: Colors.grey)),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: farmers.map((f){
                    final name   = f['full_name'] ?? 'Unknown';
                    final area   = f['area'] ?? 0;
                    final region = f['location'] ?? '—';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: role == 'admin'
                          ? Text('• $name ($region · $area acres)')
                          : Text('• $name ($area acres)'),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _notDecidedSection(){
    final farmers = _groups['Not decided'] ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Not decided',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold,
                        color: Colors.grey)),
                const Spacer(),
                Text('${farmers.length} farmer${farmers.length == 1 ? '' : 's'}',
                    style: const TextStyle(color: Colors.grey)),
              ],
            ),
            if(farmers.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('None.', style: TextStyle(color: Colors.grey)),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: farmers.map((f){
                    final name   = f['full_name'] ?? 'Unknown';
                    final region = f['location'] ?? '—';
                    final role   = widget.profile['role'];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        role == 'admin' ? '• $name ($region)' : '• $name',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
