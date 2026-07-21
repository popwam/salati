import 'dart:io';

const _defaultRoots = ['lib', 'assets', 'android/app/src/main', 'public'];
const _extensions = {
  '.arb',
  '.dart',
  '.html',
  '.js',
  '.json',
  '.kt',
  '.ts',
  '.xml',
  '.yaml',
  '.yml',
};
const _ignoredPathParts = {
  '.dart_tool',
  '.firebase',
  'build',
  'functions/lib',
  'functions/node_modules',
  'ios/Pods',
  'node_modules',
};
const _patterns = [
  '\u00c3\u02dc',
  '\u00c3\u2122',
  '\u00c3\u00b0',
  '\u00c3\u00a2',
  '\u00c3',
  '\u00c2',
  '\u00d8',
  '\u00d9',
  '\u00e2',
  '\ufffd',
];
void main(List<String> args) {
  final roots = args.isEmpty ? _defaultRoots : args;
  var matches = 0;

  for (final root in roots) {
    final entity = Directory(root);
    if (!entity.existsSync()) {
      continue;
    }

    for (final file in entity.listSync(recursive: true).whereType<File>()) {
      if (_shouldIgnore(file)) {
        continue;
      }
      if (!_extensions.any((extension) => file.path.endsWith(extension))) {
        continue;
      }

      final lines = file.readAsLinesSync();
      for (var index = 0; index < lines.length; index += 1) {
        final line = lines[index];
        if (_patterns.any(line.contains)) {
          matches += 1;
          stdout.writeln('${file.path}:${index + 1}: ${_snippet(line.trim())}');
        }
      }
    }
  }

  if (matches == 0) {
    stdout.writeln('No mojibake patterns found.');
  } else {
    stdout.writeln('\nFound $matches possible mojibake line(s).');
    stdout.writeln('Review manually; do not apply broad automatic rewrites.');
  }
}

bool _shouldIgnore(File file) {
  final normalized = file.path.replaceAll('\\', '/');
  return _ignoredPathParts.any(
    (part) => normalized == part || normalized.contains('/$part/'),
  );
}

String _snippet(String value) {
  if (value.length <= 180) {
    return value;
  }
  return '${value.substring(0, 177)}...';
}
