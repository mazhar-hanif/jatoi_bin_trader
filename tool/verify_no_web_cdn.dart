import 'dart:convert';
import 'dart:io';

void main() {
  final webBuild = Directory('build/web');
  if (!webBuild.existsSync()) {
    stderr.writeln('build/web is missing; run the release build first.');
    exitCode = 1;
    return;
  }

  final requiredAssets = [
    File('build/web/canvaskit/chromium/canvaskit.js'),
    File('build/web/canvaskit/chromium/canvaskit.wasm'),
  ];
  for (final asset in requiredAssets) {
    if (!asset.existsSync()) {
      stderr.writeln(
        'Required local CanvasKit asset is missing: ${asset.path}',
      );
      exitCode = 1;
    }
  }

  final bootstrap = File('build/web/flutter_bootstrap.js');
  if (!bootstrap.existsSync()) {
    stderr.writeln('Generated flutter_bootstrap.js is missing.');
    exitCode = 1;
    return;
  }
  final configMatch = RegExp(
    r'_flutter\.buildConfig\s*=\s*(\{.*?\});',
    dotAll: true,
  ).firstMatch(bootstrap.readAsStringSync());
  if (configMatch == null) {
    stderr.writeln('Flutter build configuration is missing from bootstrap.');
    exitCode = 1;
    return;
  }
  final configJson = configMatch.group(1)!;
  final config = jsonDecode(configJson) as Map<String, dynamic>;
  if (config['useLocalCanvasKit'] != true ||
      configJson.contains('www.gstatic.com/flutter-canvaskit')) {
    stderr
        .writeln('Flutter bootstrap is not configured to use local CanvasKit.');
    exitCode = 1;
  }

  final references = <String>[];
  for (final file in webBuild.listSync(recursive: true).whereType<File>().where(
        (file) =>
            file.path.endsWith('.js') ||
            file.path.endsWith('.html') ||
            file.path.endsWith('.json'),
      )) {
    if (file.path.endsWith('flutter.js') ||
        file.path.endsWith('flutter_bootstrap.js')) {
      continue;
    }
    if (file.readAsStringSync().contains('www.gstatic.com/flutter-canvaskit')) {
      references.add(file.path);
    }
  }
  if (references.isNotEmpty) {
    stderr.writeln(
      'CDN CanvasKit references remain in:\n${references.join('\n')}',
    );
    exitCode = 1;
    return;
  }
  if (exitCode == 0) {
    stdout.writeln(
      'Local CanvasKit assets exist; buildConfig.useLocalCanvasKit=true; no CDN references in app assets.',
    );
  }
}
