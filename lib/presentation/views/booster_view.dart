import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../view_models/booster_view_model.dart';
import '../view_models/auth_view_model.dart';

class BoosterView extends StatefulWidget {
  const BoosterView({super.key});
  @override
  State<BoosterView> createState() => _BoosterViewState();
}

class _BoosterViewState extends State<BoosterView> {
  final _resume = TextEditingController();
  final _url = TextEditingController();
  final _job = TextEditingController();
  PlatformFile? _file;
  String? _fileError;
  bool _consent = false;

  @override
  void dispose() {
    _resume.dispose();
    _url.dispose();
    _job.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'txt'],
        withData: true,
      );
      if (!mounted || picked == null) return;
      final file = picked.files.single;
      setState(() {
        if (file.bytes == null || file.size > 2 * 1024 * 1024) {
          _file = null;
          _fileError = 'Choose a readable PDF, DOCX, or TXT file under 2 MB.';
        } else {
          _file = file;
          _fileError = null;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _fileError = 'Could not open the file picker. Try again.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<BoosterViewModel>();
    final result = vm.result;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Career Booster'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: vm.busy
                ? null
                : () {
                    vm.clear();
                    context.read<AuthViewModel>().signOut();
                  },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              Text(
                'Make your next move\nwith clarity.',
                style: Theme.of(context).textTheme.headlineLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                'Compare your resume with a job and get practical suggestions.',
                style: TextStyle(color: Color(0xFF59677C)),
              ),
              const SizedBox(height: 24),
              _section(
                '01',
                'Your resume',
                'Paste your resume, or choose a PDF, DOCX or TXT file.',
              ),
              const SizedBox(height: 12),
              if (_file == null)
                TextField(
                  controller: _resume,
                  enabled: !vm.busy,
                  minLines: 5,
                  maxLines: 10,
                  maxLength: 40000,
                  decoration: const InputDecoration(
                    hintText: 'Paste your resume here',
                    alignLabelWithHint: true,
                  ),
                ),
              if (_file != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.description_outlined),
                  title: Text(_file!.name),
                  subtitle: Text('${(_file!.size / 1024).ceil()} KB'),
                  trailing: IconButton(
                    tooltip: 'Remove file',
                    onPressed: vm.busy
                        ? null
                        : () => setState(() => _file = null),
                    icon: const Icon(Icons.close),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: vm.busy ? null : _pickFile,
                icon: const Icon(Icons.upload_file),
                label: Text(
                  _file == null ? 'Choose resume file' : 'Choose another file',
                ),
              ),
              if (_fileError != null)
                Text(
                  _fileError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 28),
              _section(
                '02',
                'The opportunity',
                'Add a public job posting URL or paste the job description.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _url,
                enabled: !vm.busy,
                keyboardType: TextInputType.url,
                maxLength: 2048,
                decoration: const InputDecoration(
                  labelText: 'Job posting URL',
                  hintText: 'https://...',
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('OR', textAlign: TextAlign.center),
              ),
              TextField(
                controller: _job,
                enabled: !vm.busy,
                minLines: 4,
                maxLines: 8,
                maxLength: 30000,
                decoration: const InputDecoration(
                  labelText: 'Job description',
                  alignLabelWithHint: true,
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _consent,
                onChanged: vm.busy
                    ? null
                    : (value) => setState(() => _consent = value ?? false),
                title: const Text(
                  'I agree to send my resume and job details to the server and Gemini for analysis.',
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              if (vm.error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    vm.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (vm.busy)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: LinearProgressIndicator(),
                ),
              FilledButton.icon(
                onPressed: vm.busy || !_consent
                    ? null
                    : () => vm.analyze(
                        resume: _resume.text,
                        jobUrl: _url.text,
                        jobText: _job.text,
                        filename: _file?.name,
                        fileBytes: _file?.bytes,
                      ),
                icon: const Icon(Icons.auto_awesome),
                label: Text(vm.busy ? 'Analyzing...' : 'Analyze my match'),
              ),
              if (result != null) ...[
                const SizedBox(height: 32),
                Text(
                  'Your results',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${result.score}% estimated match',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(value: result.score / 100),
                        const SizedBox(height: 16),
                        Text(result.summary),
                        const SizedBox(height: 8),
                        const Text(
                          'This is an AI estimate, not a hiring prediction. Check every suggestion for accuracy.',
                          style: TextStyle(color: Color(0xFF59677C)),
                        ),
                      ],
                    ),
                  ),
                ),
                _resultList('Keywords already present', result.matched),
                _resultList('Keywords to review', result.missing),
                _resultList('Suggested resume bullets', result.bullets),
                _resultList('Things to check', result.cautions),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Cover letter draft',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy cover letter',
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: result.coverLetter),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Cover letter copied.'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy_outlined),
                    ),
                  ],
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: SelectableText(result.coverLetter),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String number, String title, String subtitle) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      CircleAvatar(radius: 18, child: Text(number)),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: Color(0xFF59677C))),
          ],
        ),
      ),
    ],
  );

  Widget _resultList(String title, List<String> items) => items.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SelectableText('• $item'),
                ),
            ],
          ),
        );
}
