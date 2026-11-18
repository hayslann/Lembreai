import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Firebase Identity Toolkit. Nao armazena senhas no dispositivo.
class AccountService {
  static const firebaseApiKey = String.fromEnvironment('FIREBASE_WEB_API_KEY');
  static const googleClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  static const backendUrl = String.fromEnvironment('AI_SERVER_URL',
    defaultValue:'https://lembreai-ia.hayslan08.workers.dev');
  static const secure = FlutterSecureStorage();
  static const tokenKey='lembreai_auth_refresh_token';
  static const idTokenKey='lembreai_auth_id_token';
  static const tokenExpiryKey='lembreai_auth_token_expiry';
  static const emailKey='lembreai_auth_email';
  static const uidKey='lembreai_auth_uid';
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
    await _storeSession(result, email);
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
    await _storeSession(response, account.email);
    final email=response['email'] as String? ?? account.email;
    return email;
  }

  static Future<void> _storeSession(Map<String,dynamic> result,
      String fallbackEmail) async {
    final refresh=result['refreshToken'];
    final idToken=result['idToken'];
    if(refresh is! String || refresh.isEmpty ||
        idToken is! String || idToken.isEmpty) {
      throw StateError('Sessão segura não recebida.');
    }
    final expiresIn=int.tryParse(result['expiresIn']?.toString() ?? '') ?? 3600;
    await secure.write(key:tokenKey,value:refresh);
    await secure.write(key:idTokenKey,value:idToken);
    await secure.write(key:tokenExpiryKey,value:
      DateTime.now().add(Duration(seconds:expiresIn)).millisecondsSinceEpoch.toString());
    await secure.write(key:emailKey,value:result['email'] as String? ?? fallbackEmail);
    final uid=result['localId'];
    if(uid is String && uid.isNotEmpty) await secure.write(key:uidKey,value:uid);
  }

  /// Retorna um Firebase ID token válido e o renova antes do vencimento.
  static Future<String?> validIdToken() async {
    if(!enabled) return null;
    final stored=await secure.read(key:idTokenKey);
    final expiry=int.tryParse(await secure.read(key:tokenExpiryKey) ?? '') ?? 0;
    if(stored!=null && expiry>DateTime.now().add(const Duration(minutes:5)).millisecondsSinceEpoch) {
      return stored;
    }
    final refresh=await secure.read(key:tokenKey);
    if(refresh==null || refresh.isEmpty) return null;
    final uri=Uri.parse('https://securetoken.googleapis.com/v1/token'
      '?key=${Uri.encodeQueryComponent(firebaseApiKey)}');
    try {
      final response=await http.post(uri,
        headers:{'Content-Type':'application/x-www-form-urlencoded'},
        body:{'grant_type':'refresh_token','refresh_token':refresh})
        .timeout(const Duration(seconds:20));
      final data=jsonDecode(response.body);
      if(response.statusCode!=200 || data is! Map<String,dynamic>) return null;
      final token=data['id_token'];
      if(token is! String || token.isEmpty) return null;
      final seconds=int.tryParse(data['expires_in']?.toString() ?? '') ?? 3600;
      await secure.write(key:idTokenKey,value:token);
      await secure.write(key:tokenKey,value:data['refresh_token'] as String? ?? refresh);
      await secure.write(key:tokenExpiryKey,value:
        DateTime.now().add(Duration(seconds:seconds)).millisecondsSinceEpoch.toString());
      if(data['user_id'] is String) await secure.write(key:uidKey,value:data['user_id'] as String);
      if(data['user_id'] is String) return token;
      return token;
    } catch (_) {return null;}
  }

  static Future<String?> savedEmail() => secure.read(key:emailKey);

  static Future<Map<String,dynamic>?> _backend(String path,
      {String method='GET',Map<String,dynamic>? body}) async {
    final token=await validIdToken();
    if(token==null)return null;
    final base=Uri.tryParse(backendUrl);
    if(base==null||base.scheme!='https'||base.host.isEmpty)return null;
    try {
      final uri=base.resolve(path);
      final response=method=='POST'
        ? await http.post(uri,headers:{'Authorization':'Bearer $token',
            'Content-Type':'application/json'},body:jsonEncode(body??{}))
        : await http.get(uri,headers:{'Authorization':'Bearer $token'});
      final decoded=jsonDecode(response.body);
      if(response.statusCode<200||response.statusCode>=300||decoded is! Map) return null;
      return Map<String,dynamic>.from(decoded);
    } catch (_) {return null;}
  }

  static Future<int?> availableCredits() async {
    final data=await _backend('/account/me');
    final account=data?['account'];
    return account is Map ? int.tryParse(account['credit_balance']?.toString()??'') : null;
  }

  static Future<bool> consumeCredits(int count) async {
    if(count<1)return true;
    final data=await _backend('/account/credits/use',method:'POST',body:{'count':count});
    return data?['ok']==true;
  }

  static Future<Map<String,dynamic>?> startRewardSession() =>
      _backend('/rewards/start',method:'POST');

  static Future<Map<String,dynamic>?> rewardStatus(String customData) =>
      _backend('/rewards/status?custom_data=${Uri.encodeQueryComponent(customData)}');

  static Future<void> signOut() async {
    await secure.delete(key:tokenKey);
    await secure.delete(key:idTokenKey);
    await secure.delete(key:tokenExpiryKey);
    await secure.delete(key:emailKey);
    await secure.delete(key:uidKey);
    if (googleEnabled) await GoogleSignIn().signOut();
  }
}
