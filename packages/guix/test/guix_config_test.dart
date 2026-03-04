import 'package:test/test.dart';
import 'package:yaml/yaml.dart';
import 'package:guix/src/config/guix_config.dart';

void main() {
  group('GuixConfig.fromYaml', () {
    test('parses minimal config with defaults', () {
      final yaml = loadYaml('''
project:
  name: my_app
flutter:
  version: "3.24.5"
  channel: stable
guix:
  channels: guix/channels.scm
platforms: {}
''') as YamlMap;

      final config = GuixConfig.fromYaml(yaml);
      expect(config.projectName, 'my_app');
      expect(config.flutter.version, '3.24.5');
      expect(config.flutter.channel, 'stable');
      expect(config.channelsPath, 'guix/channels.scm');
      expect(config.platforms, isEmpty);
      expect(config.profiles, isEmpty);
    });

    test('parses linux platform config', () {
      final yaml = loadYaml('''
project:
  name: test_app
flutter:
  version: "3.24.5"
  channel: stable
  checksums:
    x86_64: "abc123"
    aarch64: "def456"
guix:
  channels: guix/channels.scm
platforms:
  linux:
    manifest: guix/linux.scm
    env:
      CC: clang
      CXX: clang++
    preserve:
      - DISPLAY
      - WAYLAND_DISPLAY
    build:
      command: flutter build linux --release
      output: build/linux/release/bundle
''') as YamlMap;

      final config = GuixConfig.fromYaml(yaml);
      expect(config.flutter.checksumX64, 'abc123');
      expect(config.flutter.checksumArm64, 'def456');

      final linux = config.platforms['linux']!;
      expect(linux.manifest, 'guix/linux.scm');
      expect(linux.env['CC'], 'clang');
      expect(linux.env['CXX'], 'clang++');
      expect(linux.preserve, containsAll(['DISPLAY', 'WAYLAND_DISPLAY']));
      expect(linux.buildCommand, 'flutter build linux --release');
      expect(linux.buildOutput, 'build/linux/release/bundle');
    });

    test('parses android platform config with sdk map', () {
      final yaml = loadYaml('''
project:
  name: test_app
flutter:
  version: "3.24.5"
  channel: stable
guix:
  channels: guix/channels.scm
platforms:
  android:
    manifest: guix/android.scm
    sdk:
      platform_version: android-34
      ndk_version: "23.1.7779620"
    build:
      command: flutter build apk --release
      output: build/app/outputs/flutter-apk/app-release.apk
''') as YamlMap;

      final config = GuixConfig.fromYaml(yaml);
      final android = config.platforms['android']!;
      expect(android.sdk['platform_version'], 'android-34');
      expect(android.sdk['ndk_version'], '23.1.7779620');
    });

    test('parses profiles and resolves via platformFor', () {
      final yaml = loadYaml('''
project:
  name: test_app
flutter:
  version: "3.24.5"
  channel: stable
guix:
  channels: guix/channels.scm
platforms:
  linux:
    manifest: guix/linux.scm
    build:
      command: flutter build linux --release
      output: build/linux/release/bundle
profiles:
  staging:
    platform: linux
    command: flutter build linux --release --dart-define=FLAVOR=staging
    output: build/linux/staging/bundle
''') as YamlMap;

      final config = GuixConfig.fromYaml(yaml);

      // Direct platform lookup
      expect(config.platformFor('linux'), isNotNull);

      // Profile lookup inherits base manifest but uses profile command/output
      final resolved = config.platformFor('staging')!;
      expect(resolved.manifest, 'guix/linux.scm');
      expect(resolved.buildCommand,
          'flutter build linux --release --dart-define=FLAVOR=staging');
      expect(resolved.buildOutput, 'build/linux/staging/bundle');
    });

    test('profile without output falls back to base output', () {
      final yaml = loadYaml('''
project:
  name: test_app
flutter:
  version: "3.24.5"
  channel: stable
guix:
  channels: guix/channels.scm
platforms:
  linux:
    manifest: guix/linux.scm
    build:
      command: flutter build linux --release
      output: build/linux/release/bundle
profiles:
  fast:
    platform: linux
    command: flutter build linux --debug
''') as YamlMap;

      final config = GuixConfig.fromYaml(yaml);
      final resolved = config.platformFor('fast')!;
      expect(resolved.buildOutput, 'build/linux/release/bundle');
    });

    test('returns null for unknown platform or profile', () {
      final yaml = loadYaml('''
project:
  name: test_app
flutter:
  version: "3.24.5"
  channel: stable
guix:
  channels: guix/channels.scm
platforms: {}
''') as YamlMap;

      final config = GuixConfig.fromYaml(yaml);
      expect(config.platformFor('windows'), isNull);
    });

    test('uses empty strings for missing checksums', () {
      final yaml = loadYaml('''
flutter:
  version: "3.24.5"
  channel: stable
guix:
  channels: guix/channels.scm
platforms: {}
''') as YamlMap;

      final config = GuixConfig.fromYaml(yaml);
      expect(config.flutter.checksumX64, '');
      expect(config.flutter.checksumArm64, '');
    });

    test('defaults channel to stable when omitted', () {
      final yaml = loadYaml('''
flutter:
  version: "3.24.5"
guix:
  channels: guix/channels.scm
platforms: {}
''') as YamlMap;

      final config = GuixConfig.fromYaml(yaml);
      expect(config.flutter.channel, 'stable');
    });

    test('platformNames returns all platform keys', () {
      final yaml = loadYaml('''
flutter:
  version: "3.24.5"
  channel: stable
guix:
  channels: guix/channels.scm
platforms:
  linux:
    manifest: guix/linux.scm
    build:
      command: flutter build linux --release
      output: build/
  android:
    manifest: guix/android.scm
    build:
      command: flutter build apk --release
      output: build/
''') as YamlMap;

      final config = GuixConfig.fromYaml(yaml);
      expect(config.platformNames, containsAll(['linux', 'android']));
      expect(config.platformNames.length, 2);
    });
  });

  group('PlatformConfig.fromYaml', () {
    test('defaults manifest to guix/<name>.scm when omitted', () {
      final yaml = loadYaml('''
build:
  command: flutter build linux --release
  output: build/
''') as YamlMap;

      final platform = PlatformConfig.fromYaml('linux', yaml);
      expect(platform.manifest, 'guix/linux.scm');
    });

    test('defaults build command when omitted', () {
      final yaml = loadYaml('''
manifest: guix/linux.scm
build:
  output: build/
''') as YamlMap;

      final platform = PlatformConfig.fromYaml('linux', yaml);
      expect(platform.buildCommand, 'flutter build linux --release');
    });

    test('empty env, preserve, sdk when omitted', () {
      final yaml = loadYaml('''
manifest: guix/linux.scm
build:
  command: flutter build linux --release
  output: build/
''') as YamlMap;

      final platform = PlatformConfig.fromYaml('linux', yaml);
      expect(platform.env, isEmpty);
      expect(platform.preserve, isEmpty);
      expect(platform.sdk, isEmpty);
    });
  });
}
