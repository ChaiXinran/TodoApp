import 'package:flutter/material.dart';

/// Use the supplied illustration intact; fit it without cropping or repainting.
class AppCover extends StatelessWidget {
  const AppCover({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFFFF8EE),
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Image.asset(
                    'assets/branding/richang_cover.png',
                    fit: BoxFit.contain,
                    semanticLabel: '日常，猫咪和兔子的启动封面',
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFAB6478),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
