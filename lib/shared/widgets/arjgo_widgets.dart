import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:arjgo/core/theme/app_theme.dart';

class ArjgoLogo extends StatelessWidget {
  final double fontSize;
  final Color color;

  const ArjgoLogo({
    super.key,
    this.fontSize = 11,
    this.color = AppColors.accent,
  });

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.dmSans(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      color: color,
      letterSpacing: 1.5,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('AR', style: style),
        Text('JG', style: style),
        Text('O', style: style),
      ],
    );
  }
}

class ArjgoLogoInline extends StatelessWidget {
  final double fontSize;
  final Color color;

  const ArjgoLogoInline({
    super.key,
    this.fontSize = 16,
    this.color = AppColors.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      'A R J G O',
      style: GoogleFonts.dmSans(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 6,
      ),
    );
  }
}

class ArjgoTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final bool obscureText;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const ArjgoTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: GoogleFonts.dmSans(
        fontSize: 15,
        fontWeight: FontWeight.w300,
        color: Theme.of(context).textTheme.bodyLarge?.color,
      ),
      decoration: InputDecoration(
        labelText: label.toUpperCase(),
        hintText: hint,
      ),
    );
  }
}
class VibeFooter extends StatelessWidget {
  const VibeFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'Built by Arjgorithmic with pure vibes ✨',
          style: GoogleFonts.dmSans(
            fontSize: 9,
            fontWeight: FontWeight.w400,
            color: AppColors.grey.withOpacity(0.6),
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}
