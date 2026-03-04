import 'dart:io';
import 'package:test/test.dart';
import 'package:guix/src/commands/eject_command.dart';
import 'package:guix/src/commands/sync_command.dart';
import 'package:guix/src/config/guix_config.dart';
import 'package:yaml/yaml.dart';

GuixConfig _configFromYaml(String yaml) =>
    GuixConfig.fromYaml(loadYaml(yaml) as YamlMap);

void main() {
  group('generateFetchFlutterScript', () {
    test('uses ARCH variable in archive name (not hard-coded suffix)', () {
      final config = _configFromYaml('''
flutter:
  version: "3.24.5"
  channel: stable
''');
      final script = generateFetchFlutterScript(config);

      // The archive name must use the runtime-detected ARCH variable.
      expect(script, contains(r'flutter_linux${ARCH}_${FLUTTER_VERSION}-${FLUTTER_CHANNEL}.tar.xz'));
    });

    test('arm64 arch detection sets ARCH to _arm64', () {
      final config = _configFromYaml('''
flutter:
  version: "3.24.5"
  channel: stable
''');
      final script = generateFetchFlutterScript(config);

      // Case statement must map aarch64/arm64 to _arm64.
      expect(script, contains('aarch64|arm64) ARCH="_arm64"'));
    });

    test('x64 arch detection sets ARCH to empty string', () {
      final config = _configFromYaml('''
flutter:
  version: "3.24.5"
  channel: stable
''');
      final script = generateFetchFlutterScript(config);

      // Wildcard case must set ARCH to empty string.
      expect(script, contains('*)             ARCH=""'));
    });

    test('URL includes the ARCHIVE variable', () {
      final config = _configFromYaml('''
flutter:
  version: "3.27.1"
  channel: beta
''');
      final script = generateFetchFlutterScript(config);

      // URL must reference the computed ARCHIVE variable.
      expect(script, contains(r'URL="https://storage.googleapis.com/flutter_infra_release/releases/$FLUTTER_CHANNEL/linux/$ARCHIVE"'));
    });

    test('version and channel are baked in for the early-exit check', () {
      final config = _configFromYaml('''
flutter:
  version: "3.27.1"
  channel: beta
''');
      final script = generateFetchFlutterScript(config);

      expect(script, contains('FLUTTER_VERSION="3.27.1"'));
      expect(script, contains('FLUTTER_CHANNEL="beta"'));
    });

    test('no legacy ARCH_SUFFIX variable present', () {
      final config = _configFromYaml('''
flutter:
  version: "3.24.5"
  channel: stable
''');
      final script = generateFetchFlutterScript(config);

      // The old buggy variable name must not appear.
      expect(script, isNot(contains('ARCH_SUFFIX')));
    });
  });

  group('writeEnvFiles during eject', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('eject_test_');
    });

    tearDown(() {
      tmp.deleteSync(recursive: true);
    });

    test('flutter_version.env written from android+linux config', () {
      final config = _configFromYaml('''
flutter:
  version: "3.24.5"
  channel: stable
  checksums:
    x86_64: "deadbeef"
    aarch64: ""
platforms:
  android:
    manifest: guix/android.scm
    sdk:
      cmdline_tools_build: "14742923"
      cmdline_tools_sha256: ""
      platform_version: android-34
      build_tools_version: "34.0.0"
      ndk_version: "23.1.7779620"
    build:
      command: flutter build apk --release
      output: build/app/outputs/flutter-apk/app-release.apk
''');

      writeEnvFiles(config, dir: tmp.path);

      final flutterEnv =
          File('${tmp.path}/flutter_version.env').readAsStringSync();
      expect(flutterEnv, contains('FLUTTER_VERSION="3.24.5"'));
      expect(flutterEnv, contains('FLUTTER_SHA256_X64="deadbeef"'));

      final androidEnv =
          File('${tmp.path}/android_sdk_version.env').readAsStringSync();
      expect(androidEnv, contains('ANDROID_CMDLINE_TOOLS_BUILD="14742923"'));
      expect(androidEnv, contains('ANDROID_NDK_VERSION="23.1.7779620"'));
    });
  });
}
