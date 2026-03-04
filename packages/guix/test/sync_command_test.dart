import 'dart:io';
import 'package:test/test.dart';
import 'package:guix/src/commands/sync_command.dart';
import 'package:guix/src/config/guix_config.dart';
import 'package:yaml/yaml.dart';

GuixConfig _configFromYaml(String yaml) =>
    GuixConfig.fromYaml(loadYaml(yaml) as YamlMap);

void main() {
  group('writeEnvFiles', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('sync_test_');
    });

    tearDown(() {
      tmp.deleteSync(recursive: true);
    });

    test('flutter_version.env contains all four fields', () {
      final config = _configFromYaml('''
flutter:
  version: "3.27.1"
  channel: beta
  checksums:
    x86_64: "aaabbb"
    aarch64: "cccddd"
''');

      writeEnvFiles(config, dir: tmp.path);

      final content = File('${tmp.path}/flutter_version.env').readAsStringSync();
      expect(content, contains('FLUTTER_VERSION="3.27.1"'));
      expect(content, contains('FLUTTER_CHANNEL="beta"'));
      expect(content, contains('FLUTTER_SHA256_X64="aaabbb"'));
      expect(content, contains('FLUTTER_SHA256_ARM64="cccddd"'));
    });

    test('flutter_version.env empty checksums produce empty-string values', () {
      final config = _configFromYaml('''
flutter:
  version: "3.24.5"
  channel: stable
''');

      writeEnvFiles(config, dir: tmp.path);

      final content = File('${tmp.path}/flutter_version.env').readAsStringSync();
      expect(content, contains('FLUTTER_SHA256_X64=""'));
      expect(content, contains('FLUTTER_SHA256_ARM64=""'));
    });

    test('android_sdk_version.env written when android platform present', () {
      final config = _configFromYaml('''
flutter:
  version: "3.24.5"
  channel: stable
platforms:
  android:
    manifest: guix/android.scm
    sdk:
      cmdline_tools_build: "14742923"
      cmdline_tools_sha256: "abc123"
      platform_version: android-34
      build_tools_version: "34.0.0"
      ndk_version: "23.1.7779620"
    build:
      command: flutter build apk --release
      output: build/app/outputs/flutter-apk/app-release.apk
''');

      writeEnvFiles(config, dir: tmp.path);

      final content =
          File('${tmp.path}/android_sdk_version.env').readAsStringSync();
      expect(content, contains('ANDROID_CMDLINE_TOOLS_BUILD="14742923"'));
      expect(content, contains('ANDROID_CMDLINE_TOOLS_SHA256="abc123"'));
      expect(content, contains('ANDROID_PLATFORM_VERSION="android-34"'));
      expect(content, contains('ANDROID_BUILD_TOOLS_VERSION="34.0.0"'));
      expect(content, contains('ANDROID_NDK_VERSION="23.1.7779620"'));
    });

    test('android_sdk_version.env not written when no android platform', () {
      final config = _configFromYaml('''
flutter:
  version: "3.24.5"
  channel: stable
platforms:
  linux:
    manifest: guix/linux.scm
    build:
      command: flutter build linux --release
      output: build/linux/release/bundle
''');

      writeEnvFiles(config, dir: tmp.path);

      expect(File('${tmp.path}/android_sdk_version.env').existsSync(), isFalse);
    });

    test('writeEnvFiles is idempotent: re-running overwrites with same content', () {
      final config = _configFromYaml('''
flutter:
  version: "3.24.5"
  channel: stable
''');

      writeEnvFiles(config, dir: tmp.path);
      final first = File('${tmp.path}/flutter_version.env').readAsStringSync();
      writeEnvFiles(config, dir: tmp.path);
      final second = File('${tmp.path}/flutter_version.env').readAsStringSync();
      expect(first, equals(second));
    });
  });
}
