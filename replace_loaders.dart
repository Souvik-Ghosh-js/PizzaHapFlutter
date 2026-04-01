import 'dart:io';

void main() {
  final dir = Directory('lib');
  final entities = dir.listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  for (final file in entities) {
    if (file.path.contains('app_loader.dart')) continue;

    var content = file.readAsStringSync();
    if (content.contains('CircularProgressIndicator(') || content.contains('CircularProgressIndicator')) {
      if (!content.contains('package:pizzahap/widgets/app_loader.dart') && 
          !content.contains('../widgets/app_loader.dart') && 
          !content.contains('../../widgets/app_loader.dart')) {
        content = "import 'package:pizzahap/widgets/app_loader.dart';\n$content";
      }

      var newContent = content.replaceAllMapped(RegExp(r'CircularProgressIndicator\(([^)]*)\)'), (match) {
        String inner = match.group(1)!;
        if (inner.contains('Colors.white')) {
          return 'PizzaSpinner(size: 24, color: Colors.white)';
        } else if (inner.contains('AppColors.coins')) {
          return 'PizzaSpinner(size: 40, color: const Color(AppColors.coins))';
        } else {
          return 'PizzaSpinner(size: 40)';
        }
      });
      
      // Also catch any raw CircularProgressIndicator()
      newContent = newContent.replaceAll('CircularProgressIndicator()', 'PizzaSpinner(size: 40)');

      file.writeAsStringSync(newContent);
      stdout.writeln('Updated ${file.path}');
    }
  }
}
