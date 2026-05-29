import 'dart:io';

void main() {
  final dir = Directory('lib/screens');
  final entities = dir.listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  for (final file in entities) {
    if (file.path.contains('app_loader.dart')) continue;

    var content = file.readAsStringSync();
    if (content.contains('CircularProgressIndicator')) {
      if (!content.contains('package:pizzahap/widgets/app_loader.dart') && 
          !content.contains('../widgets/app_loader.dart') && 
          !content.contains('../../widgets/app_loader.dart')) {
        content = "import 'package:pizzahap/widgets/app_loader.dart';\n$content";
      }

      content = content.replaceAll(
        'CircularProgressIndicator(color: Color(AppColors.primary))',
        'PizzaSpinner(size: 40)'
      );
      content = content.replaceAll(
        'CircularProgressIndicator(color: Color(AppColors.coins))',
        'PizzaSpinner(size: 40, color: const Color(AppColors.coins))'
      );
      content = content.replaceAll(
        'CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)',
        'PizzaSpinner(size: 24, color: Colors.white)'
      );

      // Handle multiline by normalizing whitespace first for replacements
      content = content.replaceAll(RegExp(r'CircularProgressIndicator\s*\(\s*color:\s*Colors.white\s*,\s*strokeWidth:\s*2\s*\)'), 'PizzaSpinner(size: 20, color: Colors.white)');
      content = content.replaceAll(RegExp(r'CircularProgressIndicator\s*\(\s*color:\s*Colors.white\s*\)'), 'PizzaSpinner(size: 20, color: Colors.white)');
      content = content.replaceAll(RegExp(r'CircularProgressIndicator\s*\(\s*color:\s*Color\(AppColors\.primary\)\s*\)'), 'PizzaSpinner(size: 40)');

      file.writeAsStringSync(content);
      stdout.writeln('Updated ${file.path}');
    }
  }
}
