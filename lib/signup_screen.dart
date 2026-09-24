import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import 'home_screen.dart';

class SignupScreen extends StatefulWidget{
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>{
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  String _role = 'farmer';
  String _region = 'Rangpur';
  String? _error;

  final _roles ={'farmer': 'Farmer', 'local_gov': 'Local Government'};
  final _regions =['Rangpur', 'Rajshahi', 'Dhaka'];

  @override
  void dispose(){
    _fullNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async{
    try{
      await _authService.signUp(
        fullName: _fullNameController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        role: _role,
        location: _region,
      );
      if(!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } on AuthException catch(e){
      setState(() => _error = e.message);
    } catch(e){
      setState(() => _error = 'Signup failed. Try again.');
    }
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if(_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
              if(_error != null) const SizedBox(height: 12),
              TextField(
                controller: _fullNameController,
                decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
                items: _roles.entries.map((e) =>
                  DropdownMenuItem(value: e.key, child: Text(e.value))
                ).toList(),
                onChanged: (v) => setState(() => _role = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _region,
                decoration: const InputDecoration(labelText: 'Region', border: OutlineInputBorder()),
                items: _regions.map((r) =>
                  DropdownMenuItem(value: r, child: Text(r))
                ).toList(),
                onChanged: (v) => setState(() => _region = v!),
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _signUp, child: const Text('Sign Up')),
            ],
          ),
        ),
      ),
    );
  }
}
