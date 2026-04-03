import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Shows a warning when the app is running in a browser (CORS blocks API calls).
/// The app is designed for Android. On web, API calls will fail unless the
/// backend has CORS headers configured.
class WebCorsBanner extends StatelessWidget {
  final Widget child;
  const WebCorsBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;
    return Stack(
      children: [
        child,
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFFEF3C7),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFD97706), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Running in browser  API calls may fail due to CORS. Use Android app for full functionality.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF92400E),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
