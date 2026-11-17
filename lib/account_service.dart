import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Firebase Identity Toolkit. Nao armazena senhas no dispositivo.
class AccountService {
  static const firebaseApiKey = String.fromEnvironment('FIREBASE_WEB_API_KEY');
  static const googleClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  static const secure = FlutterSecureStorage();
  static const tokenKey='lembreai_auth_refresh_token';
  static const emailKey='lembreai_auth_email';
  static bool get enabled => firebaseApiKey.isNotEmpty;
  static bool get googleEnabled => enabled && googleClientId.isNotEmpty;

  static String explain(Object error) {
    final raw=error.toString().toUpperCase();
    if(raw.contains('EMAIL_EXISTS')) return 'Este e-mail já possui uma conta.';
    if(raw.contains('INVALID_LOGIN_CREDENTIALS') ||
        raw.contains('INVALID_PASSWORD')) return 'E-mail ou senha inválidos.';
    if(raw.contains('WEAK_PASSWORD')) return 'Senha fraca. Use ao menos 8 caracteres.';
    if(raw.contains('INVALID_EMAIL')) return 'Digite um e-mail válido.';
    if(raw.contains('TOO_MANY_ATTEMPTS')) return 'Muitas tentativas. Aguarde.';
    if(raw.contains('NETWORK') || raw.contains('SOCKET')) {
      return 'Sem conexão com a internet. Tente novamente.';
    }
    return 'Não foi possível autenticar. Verifique os dados e tente novamente.';
  }

  static Future<Map<String,dynamic>> _post(String action, Map<String,dynamic> body) async {
    if(!enabled) throw StateError('Autenticação ainda não configurada.');
    final uri=Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:$action'
      '?key=${Uri.encodeQueryComponent(firebaseApiKey)}');
    final res=await http.post(uri,
      headers:{'Content-Type':'application/json'},
      body:jsonEncode(body)).timeout(const Duration(seconds:25));
    final data=jsonDecode(res.body) as Map<String,dynamic>;
    if(res.statusCode!=200) {
      throw StateError(data['error']?['message']?.toString() ?? 'Falha ao autenticar');
    }
    return data;
  }

  static Future<String> signInEmail(String email,String password,
      {bool create=false}) async {
    final result=await _post(create?'signUp':'signInWithPassword',{
      'email':email.trim(),'password':password,'returnSecureToken':true,
    });
    final refresh=result['refreshToken'];
    if(refresh is! String || refresh.isEmpty) {
      throw StateError('Sessão não recebida.');
    }
    await secure.write(key:tokenKey,value:refresh);
    await secure.write(key:emailKey,value:result['email'] as String? ?? email);
    return result['email'] as String? ?? email;
  }

  static Future<String> signInGoogle() async {
    if(!googleEnabled) throw StateError('Login Google indisponível.');
    final signIn=GoogleSignIn(
      scopes:['email'],
      serverClientId:googleClientId,
    );
    final account=await signIn.signIn();
    if(account==null) throw StateError('Login cancelado.');
    final auth=await account.authentication;
    final idToken=auth.idToken;
    if(idToken==null || idToken.isEmpty) throw StateError('Token Google indisponível.');
    final response=await _post('signInWithIdp',{
      'postBody':'id_token=${Uri.encodeQueryComponent(idToken)}&providerId=google.com',
      'requestUri':'http://localhost',
      'returnSecureToken':true,
      'returnIdpCredential':false,
    });
    final refresh=response['refreshToken'];
    if(refresh is! String || refresh.isEmpty) throw StateError('Sessão inválida.');
    await secure.write(key:tokenKey,value:refresh);
    final email=response['email'] as String? ?? account.email;
    await secure.write(key:emailKey,value:email);
    return email;
  }

  static Future<String?> savedEmail() => secure.read(key:emailKey);

  static Future<void> signOut() async {
    await secure.delete(key:tokenKey);
    await secure.delete(key:emailKey);
    if (googleEnabled) await GoogleSignIn().signOut();
  }
}
