import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService{
  //supabase connection
  final supabase = Supabase.instance.client;

  //sign up
  Future signUp({
    required String fullName,
    required String username,
    required String password,
    required String role,
    required String location,
  }) async{
    //supabase needs email address. So dummy email is added.
    String email = '$username@lightfarm.com';

    var res = await supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'username': username,
        'full_name': fullName,
        'role': role,
        'location': location,
      },
    );
    return res;
  }

  //login
  Future signIn({required String username, required String password}) async{
    String email = '$username@lightfarm.com';

    var res = await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return res;
  }

  //logout
  Future signOut() async{
    await supabase.auth.signOut();
  }

  //get profile of logged in user
  Future<Map<String, dynamic>?> getCurrentProfile() async{
    var user = supabase.auth.currentUser;

    //if nobody is logged in
    if(user == null){
      return null;
    }

    try{
      var data = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();
      return data;
    }catch (e){
      return null;
    }
  }
}