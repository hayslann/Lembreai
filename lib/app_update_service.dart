import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Atualiza o APK distribuido fora da Play Store, com confirmacao do Android.
/// O APK precisa manter o mesmo packageName E assinatura para preservar dados.
class AppUpdate {
  final String version;
  final int versionCode;
  final String downloadUrl;
  final String sha256Hex;
  final int sizeBytes;

  const AppUpdate({
    required this.version,
    required this.versionCode,
    required this.downloadUrl,
    required this.sha256Hex,
    required this.sizeBytes,
  });
}

class AppUpdateService {
  static const releaseApi =
    'https://api.github.com/repos/hayslann/Lembreai/releases/tags/teste-android';
  static const trustedDownload =
    'https://github.com/hayslann/Lembreai/releases/download/teste-android/LembreAI.apk';
  static const _maxSize = 350 * 1024 * 1024;

  /// Usa metadados assinados pelo fluxo de publicacao do repositorio.
  /// Versoes antigas sem metadados simplesmente nao exibem falsa atualizacao.
  static AppUpdate? parseRelease(Object? raw, int currentBuild) {
    if (raw is! Map) return null;
    final notes=raw['body'];
    final assets=raw['assets'];
    if (notes is! String || assets is! List) return null;
    final buildMatch=RegExp(r'LEMBREAI_VERSION_CODE=(\d+)').firstMatch(notes);
    final nameMatch=RegExp(r'LEMBREAI_VERSION_NAME=([0-9]+\.[0-9]+\.[0-9]+)')
      .firstMatch(notes);
    final build=int.tryParse(buildMatch?.group(1) ?? '');
    final name=nameMatch?.group(1);
    if (build==null || build<=currentBuild || build>2147483647 ||
        name==null) return null;
    for (final value in assets) {
      if (value is! Map || value['name'] != 'LembreAI.apk' ||
          value['browser_download_url'] != trustedDownload) continue;
      final digest=value['digest'];
      final size=value['size'];
      if (digest is! String || !RegExp(r'^sha256:[0-9a-fA-F]{64}$')
            .hasMatch(digest) || size is! int ||
          size<1000000 || size>_maxSize) continue;
      return AppUpdate(version:name,versionCode:build,
        downloadUrl:trustedDownload,
        sha256Hex:digest.substring(7).toLowerCase(),sizeBytes:size);
    }
    return null;
  }

  static Future<AppUpdate?> check() async {
    final package=await PackageInfo.fromPlatform();
    final currentBuild=int.tryParse(package.buildNumber) ?? 0;
    final response=await http.get(Uri.parse(releaseApi),headers:{
      'Accept':'application/vnd.github+json',
    }).timeout(const Duration(seconds:15));
    if(response.statusCode!=200) {
      throw StateError('Não consegui consultar a versão agora.');
    }
    return parseRelease(
      // Somente resposta pequena: impede uso abusivo de memoria.
      response.body.length<500000 ? _decode(response.body) : null,
      currentBuild,
    );
  }

  static Object? _decode(String text) {
    try { return jsonDecodeRelease(text); } catch (_) { return null; }
  }

  // Dart:convert mantido em funcao especifica para teste puro.
  static Object? jsonDecodeRelease(String text) => jsonDecode(text);

  /// Baixa na pasta temporaria privada, verifica SHA256 antes de instalar.
  /// Usa streaming, sem carregar centenas de MB na memoria.
  static Future<void> downloadAndInstall(AppUpdate version, {
    void Function(double)? onProgress,
  }) async {
    if(version.downloadUrl!=trustedDownload) {
      throw StateError('Origem da atualização não confiável.');
    }
    final folder=await getTemporaryDirectory();
    final file=File('${folder.path}/lembreai-${version.versionCode}.apk');
    if(await file.exists()) await file.delete();
    final client=http.Client();
    try {
      final request=http.Request('GET', Uri.parse(trustedDownload));
      final response=await client.send(request).timeout(const Duration(seconds:30));
      if(response.statusCode!=200) {
        throw StateError('Não consegui baixar a atualização.');
      }
      final sink=file.openWrite();
      var received=0;
      try {
        await for(final part in response.stream.timeout(
            const Duration(seconds:60))) {
          received+=part.length;
          if(received>_maxSize) throw StateError('APK acima do limite.');
          sink.add(part);
          onProgress?.call((received/version.sizeBytes).clamp(0.0,1.0).toDouble());
        }
      } finally {
        await sink.flush();
        await sink.close();
      }
      if(received!=version.sizeBytes) {
        throw StateError('O download ficou incompleto.');
      }
      final actual=(await sha256.bind(file.openRead()).first).toString();
      if(actual!=version.sha256Hex) {
        throw StateError('A verificação de segurança do APK falhou.');
      }
      onProgress?.call(1.0);
      final result=await OpenFilex.open(file.path,
        type:'application/vnd.android.package-archive');
      if(result.type!=ResultType.done) {
        throw StateError('O Android não abriu o instalador. '
          'Confira a permissão para instalar aplicativos dessa origem.');
      }
    } finally {
      client.close();
      // Nao apagamos aqui porque o instalador abre o arquivo depois.
    }
  }
}
