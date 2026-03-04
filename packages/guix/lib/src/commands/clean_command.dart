import 'dart:io';
import 'package:args/command_runner.dart';

class CleanCommand extends Command<int> {
  @override
  final String name = 'clean';

  @override
  final String description = 'Remove fetched SDKs and build artifacts.';

  CleanCommand() {
    argParser
      ..addFlag('all', abbr: 'a', help: 'Remove everything (SDKs + build artifacts)');
  }

  @override
  Future<int> run() async {
    final all = argResults!['all'] as bool;
    final targets = argResults!.rest;

    final dirs = <String>[];

    if (all || targets.isEmpty) {
      dirs.addAll(['.flutter-sdk', '.android-sdk', 'build']);
    } else {
      // Platform-specific clean
      for (final target in targets) {
        switch (target) {
          case 'linux':
            dirs.add('build/linux');
          case 'android':
            dirs.addAll(['.android-sdk', 'build/app']);
          case 'flutter':
            dirs.add('.flutter-sdk');
          default:
            dirs.add('build/$target');
        }
      }
    }

    var cleaned = 0;
    for (final path in dirs) {
      final dir = Directory(path);
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
        print('Removed $path');
        cleaned++;
      }
    }

    if (cleaned == 0) {
      print('Nothing to clean.');
    } else {
      print('Cleaned $cleaned director${cleaned == 1 ? 'y' : 'ies'}.');
    }
    return 0;
  }
}
