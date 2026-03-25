import 'dart:io';
import 'package:arjgo/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';

// ── Model ────────────────────────────────────────────────────────────────────
class Skill {
  final String name;
  final String description;
  final bool isLocal;

  const Skill({
    required this.name,
    required this.description,
    this.isLocal = false,
  });
}

// ── Provider ─────────────────────────────────────────────────────────────────
final skillsProvider =
    AsyncNotifierProvider<SkillsNotifier, List<Skill>>(SkillsNotifier.new);

class SkillsNotifier extends AsyncNotifier<List<Skill>> {
  @override
  Future<List<Skill>> build() async {
    return _loadFromAsset();
  }

  Future<List<Skill>> _loadFromAsset() async {
    try {
      final raw = await rootBundle.loadString('assets/skills/skill.md');
      return _parse(raw);
    } catch (_) {
      return [];
    }
  }

  List<Skill> _parse(String raw) {
    final skills = <Skill>[];
    final lines = raw.split('\n');
    String? currentName;
    final descBuf = StringBuffer();

    for (final line in lines) {
      if (line.startsWith('## ')) {
        if (currentName != null) {
          skills.add(Skill(
              name: currentName, description: descBuf.toString().trim()));
          descBuf.clear();
        }
        currentName = line.substring(3).trim();
      } else if (currentName != null && line.isNotEmpty) {
        if (descBuf.isNotEmpty) descBuf.write(' ');
        descBuf.write(line.trim());
      }
    }
    if (currentName != null) {
      skills.add(
          Skill(name: currentName, description: descBuf.toString().trim()));
    }
    return skills;
  }

  Future<void> addSkill(
      {required String name, required String description}) async {
    final current = state.valueOrNull ?? [];
    state = AsyncData(
        [...current, Skill(name: name, description: description, isLocal: true)]);
  }

  Future<void> deleteSkill(String name) async {
    final current = state.valueOrNull ?? [];
    state = AsyncData(current.where((s) => s.name != name).toList());
  }

  Future<bool> addSkillFromZip() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result == null || result.files.single.path == null) return false;

      final file = File(result.files.single.path!);
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final appDir = await getApplicationDocumentsDirectory();
      final skillName = result.files.single.name.split('.').first;
      final skillDir = Directory('${appDir.path}/skills/$skillName');

      if (!skillDir.existsSync()) skillDir.createSync(recursive: true);

      for (final file in archive) {
        final filename = file.name;
        if (file.isFile) {
          final data = file.content as List<int>;
          File('${skillDir.path}/$filename')
            ..createSync(recursive: true)
            ..writeAsBytesSync(data);
        }
      }

      final current = state.valueOrNull ?? [];
      state = AsyncData([
        ...current,
        Skill(
          name: skillName,
          description: 'Imported package (${archive.length} files)',
          isLocal: true,
        ),
      ]);
      return true;
    } catch (e) {
      debugPrint('Error unzipping: $e');
      return false;
    }
  }
}

// ── Screen ───────────────────────────────────────────────────────────────────
class SkillsScreen extends ConsumerWidget {
  const SkillsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skillsAsync = ref.watch(skillsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text(
                'Skills',
                style: GoogleFonts.dmSans(
                  fontSize: 36,
                  fontWeight: FontWeight.w200,
                  color: Theme.of(context).textTheme.headlineLarge?.color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'YOUR LIBRARY',
                style: GoogleFonts.dmSans(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: AppColors.grey,
                  letterSpacing: 2.5,
                ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: skillsAsync.when(
                  loading: () => const Center(
                      child: CircularProgressIndicator(strokeWidth: 1)),
                  error: (e, _) => const Text('Error loading skills'),
                  data: (skills) => skills.isEmpty
                      ? const Center(child: Text('No skills yet'))
                      : ListView.separated(
                          itemCount: skills.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, i) {
                            final skill = skills[i];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                skill.name,
                                style: GoogleFonts.dmSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                skill.description,
                                style: GoogleFonts.dmSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w300,
                                  color: AppColors.grey,
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    size: 18, color: Colors.redAccent),
                                onPressed: () => ref
                                    .read(skillsProvider.notifier)
                                    .deleteSkill(skill.name),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 72, right: 8),
        child: GestureDetector(
          onTap: () => _showAddSkill(context, ref),
          child: Text(
            '+',
            style: GoogleFonts.dmSans(
              fontSize: 32,
              fontWeight: FontWeight.w300,
              color: AppColors.accent,
              height: 1.0,
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  void _showAddSkill(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 32,
          right: 32,
          top: 32,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NEW SKILL',
              style: GoogleFonts.dmSans(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.grey,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'NAME'),
              style: GoogleFonts.dmSans(fontSize: 15),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'DESCRIPTION'),
              style: GoogleFonts.dmSans(fontSize: 14),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final ok = await ref
                          .read(skillsProvider.notifier)
                          .addSkillFromZip();
                      if (ctx.mounted && ok) Navigator.pop(ctx);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.divider),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'UPLOAD ZIP',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (nameCtrl.text.isNotEmpty) {
                        ref.read(skillsProvider.notifier).addSkill(
                              name: nameCtrl.text,
                              description: descCtrl.text,
                            );
                        Navigator.pop(ctx);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      color: AppColors.accent,
                      alignment: Alignment.center,
                      child: Text(
                        'CREATE',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.white,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
