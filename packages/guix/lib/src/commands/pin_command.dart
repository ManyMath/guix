import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:guix/src/config/guix_config.dart';
import 'package:guix/src/guix/guix_runner.dart';

class PinCommand extends Command<int> {
  @override
  final String name = 'pin';

  @override
  final String description = 'Pin current Guix channels to channels.scm.';

  @override
  Future<int> run() async {
    final verbose = globalResults!['verbose'] as bool;

    // Try to read config for channels path, fall back to default
    String channelsPath;
    try {
      final config = GuixConfig.load();
      channelsPath = config.channelsPath;
    } on FileSystemException {
      channelsPath = 'guix/channels.scm';
    }

    final guix = GuixRunner(verbose: verbose);

    if (!await guix.isInstalled()) {
      stderr.writeln('Error: guix not found on PATH.');
      return 1;
    }

    // Ensure parent directory exists
    final dir = File(channelsPath).parent;
    if (!dir.existsSync()) dir.createSync(recursive: true);

    print('Pinning channels to $channelsPath...');
    final result = await guix.pinChannels(channelsPath);

    if (result.exitCode == 0) {
      print('Channels pinned successfully.');
      // Show the commit
      final content = File(channelsPath).readAsStringSync();
      final match = RegExp(r'\(commit\s+"([a-f0-9]+)"\)').firstMatch(content);
      if (match != null) {
        print('Commit: ${match.group(1)}');
      }
      return 0;
    } else {
      stderr.writeln('Failed to pin channels.');
      stderr.writeln(result.stderr);
      return 1;
    }
  }
}
