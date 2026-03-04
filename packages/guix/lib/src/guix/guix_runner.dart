import 'dart:io';

/// Wraps invocations of the `guix` system binary.
class GuixRunner {
  final bool verbose;

  const GuixRunner({this.verbose = false});

  /// Check if `guix` is on PATH.
  Future<bool> isInstalled() async {
    try {
      final result = await Process.run('guix', ['--version']);
      return result.exitCode == 0;
    } on ProcessException {
      return false;
    }
  }

  /// Get the guix version string, or null if not installed.
  Future<String?> version() async {
    try {
      final result = await Process.run('guix', ['--version']);
      if (result.exitCode != 0) return null;
      // First line is like "guix (GNU Guix) 1.4.0-29.abcdef"
      final output = (result.stdout as String).trim();
      return output.split('\n').first;
    } on ProcessException {
      return null;
    }
  }

  /// Pin current Guix channels to a file.
  /// Runs: guix describe -f channels > outputPath
  Future<ProcessResult> pinChannels(String outputPath) async {
    final args = ['describe', '-f', 'channels'];
    _log('guix ${args.join(' ')} > $outputPath');
    final result = await Process.run('guix', args);
    if (result.exitCode == 0) {
      File(outputPath).writeAsStringSync(result.stdout as String);
    }
    return result;
  }

  /// Build the full command args for a guix shell invocation.
  /// If [channelsFile] is provided, wraps with `guix time-machine`.
  List<String> shellArgs({
    required String manifest,
    String? channelsFile,
  }) {
    if (channelsFile != null) {
      return [
        'time-machine', '-C', channelsFile,
        '--', 'shell', '-m', manifest,
      ];
    }
    return ['shell', '-m', manifest];
  }

  /// Returns the bash portion of args for an interactive shell invocation.
  List<String> enterShellBashArgs(String? flutterSdkPath) {
    if (flutterSdkPath != null) {
      return ['--', 'bash', '-c', 'export PATH="$flutterSdkPath/bin:\$PATH"; exec bash'];
    }
    return ['--', 'bash'];
  }

  /// Enter an interactive shell.
  /// This replaces the current process (exec-style) by spawning and inheriting stdio.
  Future<int> enterShell({
    required String manifest,
    String? channelsFile,
    Map<String, String> env = const {},
    List<String> preserveVars = const [],
    String? flutterSdkPath,
  }) async {
    final args = shellArgs(manifest: manifest, channelsFile: channelsFile);

    // Build the environment setup that will run inside the shell
    final shellEnv = <String, String>{};
    // Merge explicit env vars
    shellEnv.addAll(env);
    // Add Flutter to PATH if SDK path provided
    if (flutterSdkPath != null) {
      shellEnv['FLUTTER_ROOT'] = flutterSdkPath;
    }
    // Preserve host vars
    for (final v in preserveVars) {
      final val = Platform.environment[v];
      if (val != null) shellEnv[v] = val;
    }

    // Pass env vars as -- env KEY=VAL ... bash
    final envArgs = <String>[];
    for (final e in shellEnv.entries) {
      envArgs.addAll(['--setenv=${e.key}=${e.value}']);
    }

    // Launch bash; if flutter SDK is provided, prepend it to PATH inside the
    // shell so $PATH expands in the shell context (not at guix --setenv time).
    final bashArgs = enterShellBashArgs(flutterSdkPath);
    final fullArgs = [...args, ...envArgs, ...bashArgs];
    _log('guix ${fullArgs.join(' ')}');

    final process = await Process.start(
      'guix', fullArgs,
      mode: ProcessStartMode.inheritStdio,
    );
    return process.exitCode;
  }

  /// Run a command inside a guix shell (non-interactive, for builds).
  Future<int> runInShell({
    required String manifest,
    String? channelsFile,
    Map<String, String> env = const {},
    List<String> preserveVars = const [],
    String? flutterSdkPath,
    required String command,
  }) async {
    final args = shellArgs(manifest: manifest, channelsFile: channelsFile);

    // Build env string for the inner command
    final envParts = <String>[];
    env.forEach((k, v) => envParts.add('$k=$v'));
    if (flutterSdkPath != null) {
      envParts.add('FLUTTER_ROOT=$flutterSdkPath');
      envParts.add('PATH=$flutterSdkPath/bin:\$PATH');
    }
    for (final v in preserveVars) {
      final val = Platform.environment[v];
      if (val != null) envParts.add('$v=$val');
    }

    final envPrefix = envParts.isNotEmpty ? '${envParts.join(' ')} ' : '';
    final innerCmd = '${envPrefix}bash -c \'$command\'';

    final fullArgs = [...args, '--', 'bash', '-c', innerCmd];
    _log('guix ${fullArgs.join(' ')}');

    final process = await Process.start(
      'guix', fullArgs,
      mode: ProcessStartMode.inheritStdio,
    );
    return process.exitCode;
  }

  void _log(String msg) {
    if (verbose) {
      print('  \$ $msg');
    }
  }
}
