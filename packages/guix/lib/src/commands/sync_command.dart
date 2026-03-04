import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:guix/src/config/guix_config.dart';

class SyncCommand extends Command<int> {
  @override
  final String name = 'sync';

  @override
  final String description =
      'Write .env files from guix.yaml for standalone script users.';

  SyncCommand() {
    argParser
      ..addFlag('dry-run',
          abbr: 'n', help: 'Print what would be written without writing');
  }

  @override
  Future<int> run() async {
    final dryRun = argResults!['dry-run'] as bool;
    final config = GuixConfig.load();
    writeEnvFiles(config, dryRun: dryRun);
    return 0;
  }
}

/// Write flutter_version.env and (if android platform present) android_sdk_version.env.
///
/// Called from both [SyncCommand] and eject_command.dart so both workflows
/// stay in sync after a config change.
void writeEnvFiles(GuixConfig config, {bool dryRun = false, String dir = '.'}) {
  final flutterEnv = _flutterEnvContent(config);
  final flutterPath = '$dir/flutter_version.env';
  if (dryRun) {
    print('# flutter_version.env');
    print(flutterEnv);
  } else {
    File(flutterPath).writeAsStringSync(flutterEnv);
    print('  wrote flutter_version.env');
  }

  final android = config.platforms['android'];
  if (android != null && android.sdk.isNotEmpty) {
    final androidEnv = _androidEnvContent(android);
    final androidPath = '$dir/android_sdk_version.env';
    if (dryRun) {
      print('# android_sdk_version.env');
      print(androidEnv);
    } else {
      File(androidPath).writeAsStringSync(androidEnv);
      print('  wrote android_sdk_version.env');
    }
  }
}

String _flutterEnvContent(GuixConfig config) {
  final f = config.flutter;
  return 'FLUTTER_VERSION="${f.version}"\n'
      'FLUTTER_CHANNEL="${f.channel}"\n'
      'FLUTTER_SHA256_X64="${f.checksumX64}"\n'
      'FLUTTER_SHA256_ARM64="${f.checksumArm64}"\n';
}

String _androidEnvContent(PlatformConfig android) {
  final sdk = android.sdk;
  return 'ANDROID_CMDLINE_TOOLS_BUILD="${sdk['cmdline_tools_build'] ?? ''}"\n'
      'ANDROID_CMDLINE_TOOLS_SHA256="${sdk['cmdline_tools_sha256'] ?? ''}"\n'
      'ANDROID_PLATFORM_VERSION="${sdk['platform_version'] ?? ''}"\n'
      'ANDROID_BUILD_TOOLS_VERSION="${sdk['build_tools_version'] ?? ''}"\n'
      'ANDROID_NDK_VERSION="${sdk['ndk_version'] ?? ''}"\n';
}
