import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'farm_service.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget{
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>{
  final _authService = AuthService();
  final _farmService = FarmService();
  final _areaController = TextEditingController();

  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _farmers = [];
  bool _isLoading = true;

  @override
  void initState(){
    super.initState();
    _loadProfile();
  }

  @override
  void dispose(){
    _areaController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async{
    final profile = await _authService.getCurrentProfile();
    if(profile?['role'] == 'local_gov' && profile?['location'] != null){
      _farmers = await _farmService.getFarmersInRegion(profile!['location']);
    }
    if(!mounted) return;
    setState((){
      _profile = profile;
      _isLoading = false;
    });
  }

  Future<void> _updateArea() async{
    final area = double.tryParse(_areaController.text.trim());
    if(area == null) return;

    try{
      await _farmService.updateArea(area);
      await _loadProfile();
      _areaController.clear();
      _showMessage('Area updated');
    }catch(e){
      _showMessage('Error: $e');
    }
  }

  void _showMessage(String text){
    if(!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _logout() async{
    await _authService.signOut();
    if(!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Widget _farmerView(){
    return Column(
      children: [
        Text('Region: ${_profile?['location'] ?? 'Unknown'}'),
        Text('Land area: ${_profile?['area'] ?? 0} acres'),
        const SizedBox(height: 24),
        TextField(
          controller: _areaController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'New area (acres)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: _updateArea, child: const Text('Save')),
      ],
    );
  }

  Widget _govView(){
    final total = _farmers.fold<double>(
      0,
      (sum, f) => sum + ((f['area'] as num?)?.toDouble() ?? 0),
    );

    return Expanded(
      child: Column(
        children: [
          Text('${_farmers.length} farmers, ${total.toStringAsFixed(1)} acres total'),
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
          children: [
            Text(
              'Welcome ${_profile?['full_name'] ?? 'User'}!',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            if(role == 'farmer') _farmerView(),
            if(role == 'local_gov') _govView(),
            if(role == 'admin') const Text('Admin Dashboard'),
          ],
        ),
      ),
    );
  }
}
