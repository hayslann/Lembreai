import 'package:flutter_test/flutter_test.dart';
import '../lib/app_update_service.dart';

Map<String,dynamic> release({int build=6,String? url,String? digest}) => {
  'body':'LembreAI beta\nLEMBREAI_VERSION_CODE=$build\n'
    'LEMBREAI_VERSION_NAME=0.6.0',
  'assets':[
    {'name':'LembreAI.apk',
     'browser_download_url':url??AppUpdateService.trustedDownload,
     'size':45000000,
     'digest':digest ?? ('sha256:' + 'a'.padRight(64, 'a'))}
  ],
};

void main(){
  test('tem atualizacao apenas se versao remota maior',(){
    expect(AppUpdateService.parseRelease(release(),5)?.versionCode,6);
    expect(AppUpdateService.parseRelease(release(),6),isNull);
    expect(AppUpdateService.parseRelease(release(),7),isNull);
  });
  test('nunca baixa um APK fora do repositorio oficial',(){
    expect(AppUpdateService.parseRelease(
      release(url:'https://evil.example/LembreAI.apk'),5),isNull);
  });
  test('rejeita digest ausente ou invalido',(){
    expect(AppUpdateService.parseRelease(release(digest:'sha256:123'),5),isNull);
    expect(AppUpdateService.parseRelease({'body':'outdated','assets':[]},5),isNull);
  });
}
