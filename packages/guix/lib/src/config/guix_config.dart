import 'dart:io';
import 'package:yaml/yaml.dart';
import 'package:path/path.dart' as p;

class GuixConfig {
  final String projectName;
  final FlutterConfig flutter;
  final String channelsPath;
  final Map<String, PlatformConfig> platforms;
  final Map<String, ProfileConfig> profiles;

  GuixConfig({
    required this.projectName,
    required this.flutter,
    required this.channelsPath,
    required this.platforms,
    this.profiles = const {},
  });

  /// Load config from a guix.yaml file path.
  static GuixConfig load([String path = 'guix.yaml']) {
    final file = File(path);
    if (!file.existsSync()) {
      throw FileSystemException('Config file not found', path);
    }
    final content = file.readAsStringSync();
    final yaml = loadYaml(content) as YamlMap;
    return GuixConfig.fromYaml(yaml);
  }

  /// Parse config from a parsed YAML map.
  factory GuixConfig.fromYaml(YamlMap yaml) {
    final project = yaml['project'] as YamlMap? ?? YamlMap();
    final flutter = yaml['flutter'] as YamlMap? ?? YamlMap();
    final guix = yaml['guix'] as YamlMap? ?? YamlMap();
    final platformsYaml = yaml['platforms'] as YamlMap? ?? YamlMap();
    final profilesYaml = yaml['profiles'] as YamlMap? ?? YamlMap();

    final platforms = <String, PlatformConfig>{};
    for (final entry in platformsYaml.entries) {
      final name = entry.key as String;
      platforms[name] = PlatformConfig.fromYaml(name, entry.value as YamlMap);
    }

    final profiles = <String, ProfileConfig>{};
    for (final entry in profilesYaml.entries) {
      final name = entry.key as String;
      profiles[name] = ProfileConfig.fromYaml(entry.value as YamlMap);
    }

    final checksums = flutter['checksums'] as YamlMap?;

    return GuixConfig(
      projectName: (project['name'] as String?) ?? p.basename(Directory.current.path),
      flutter: FlutterConfig(
        version: flutter['version'] as String? ?? '',
        channel: flutter['channel'] as String? ?? 'stable',
        checksumX64: checksums?['x86_64'] as String? ?? '',
        checksumArm64: checksums?['aarch64'] as String? ?? '',
      ),
      channelsPath: guix['channels'] as String? ?? 'guix/channels.scm',
      platforms: platforms,
      profiles: profiles,
    );
  }

  /// Get platform config, falling back to profile if name matches a profile.
  PlatformConfig? platformFor(String name) {
    if (platforms.containsKey(name)) return platforms[name];
    final profile = profiles[name];
    if (profile != null && platforms.containsKey(profile.platform)) {
      final base = platforms[profile.platform]!;
      return PlatformConfig(
        name: base.name,
        manifest: base.manifest,
        env: base.env,
        preserve: base.preserve,
        sdk: base.sdk,
        buildCommand: profile.command,
        buildOutput: profile.output ?? base.buildOutput,
      );
    }
    return null;
  }

  List<String> get platformNames => platforms.keys.toList();
}

class FlutterConfig {
  final String version;
  final String channel;
  final String checksumX64;
  final String checksumArm64;

  const FlutterConfig({
    required this.version,
    required this.channel,
    this.checksumX64 = '',
    this.checksumArm64 = '',
  });
}

class PlatformConfig {
  final String name;
  final String manifest;
  final Map<String, String> env;
  final List<String> preserve;
  final Map<String, String> sdk;
  final String buildCommand;
  final String buildOutput;

  const PlatformConfig({
    required this.name,
    required this.manifest,
    this.env = const {},
    this.preserve = const [],
    this.sdk = const {},
    required this.buildCommand,
    required this.buildOutput,
  });

  factory PlatformConfig.fromYaml(String name, YamlMap yaml) {
    final envYaml = yaml['env'] as YamlMap?;
    final preserveYaml = yaml['preserve'] as YamlList?;
    final sdkYaml = yaml['sdk'] as YamlMap?;
    final buildYaml = yaml['build'] as YamlMap? ?? YamlMap();

    return PlatformConfig(
      name: name,
      manifest: yaml['manifest'] as String? ?? 'guix/$name.scm',
      env: envYaml != null
          ? Map<String, String>.fromEntries(
              envYaml.entries.map((e) => MapEntry(e.key as String, '${e.value}')))
          : {},
      preserve: preserveYaml?.cast<String>().toList() ?? [],
      sdk: sdkYaml != null
          ? Map<String, String>.fromEntries(
              sdkYaml.entries.map((e) => MapEntry(e.key as String, '${e.value}')))
          : {},
      buildCommand: buildYaml['command'] as String? ?? 'flutter build $name --release',
      buildOutput: buildYaml['output'] as String? ?? 'build/',
    );
  }
}

class ProfileConfig {
  final String platform;
  final String command;
  final String? output;

  const ProfileConfig({
    required this.platform,
    required this.command,
    this.output,
  });

  factory ProfileConfig.fromYaml(YamlMap yaml) {
    return ProfileConfig(
      platform: yaml['platform'] as String,
      command: yaml['command'] as String,
      output: yaml['output'] as String?,
    );
  }
}
