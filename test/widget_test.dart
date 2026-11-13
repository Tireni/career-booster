import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:career_booster/models/analysis_repository.dart';
import 'package:career_booster/models/analysis_result.dart';
import 'package:career_booster/presentation/view_models/booster_view_model.dart';
import 'package:career_booster/presentation/view_models/auth_view_model.dart';
import 'package:career_booster/presentation/views/auth_view.dart';
import 'package:career_booster/presentation/views/booster_view.dart';

import 'dart:typed_data';

class FakeRepository implements AnalysisRepository {
  @override
  Future<AnalysisResult> analyze({
    required String resume,
    required String jobUrl,
    required String jobText,
    String? filename,
    Uint8List? fileBytes,
  }) async => const AnalysisResult(
    score: 70,
    summary: 'Good overlap',
    matched: ['Dart'],
    missing: ['Docker'],
    bullets: ['Built Flutter apps'],
    coverLetter: 'Dear hiring team',
    cautions: ['Review facts'],
  );
}

void main() {
  testWidgets('registration form checks required account details', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthViewModel(Dio(), const FlutterSecureStorage()),
        child: const MaterialApp(home: AuthView()),
      ),
    );
    await tester.tap(find.text('New here? Create an account'));
    await tester.pumpAndSettle();
    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Create account'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your full name.'), findsOneWidget);
  });
  test('view model validates input and returns structured results', () async {
    final vm = BoosterViewModel(FakeRepository());
    expect(await vm.analyze(resume: '', jobUrl: '', jobText: ''), isFalse);
    expect(vm.error, isNotNull);
    expect(
      await vm.analyze(resume: 'a' * 40, jobUrl: '', jobText: 'b' * 100),
      isTrue,
    );
    expect(vm.result!.score, 70);
    expect(vm.busy, isFalse);
    expect(
      await vm.analyze(
        resume: 'a' * 40,
        jobUrl: 'https://example.com',
        jobText: 'b' * 100,
      ),
      isFalse,
    );
    expect(vm.result, isNull);
    vm.dispose();
  });

  test('response parsing rejects invalid scores', () {
    expect(
      () => AnalysisResult.fromJson({
        'match_score': 101,
        'summary': 'summary',
        'matched_keywords': <String>[],
        'missing_keywords': <String>[],
        'tailored_bullets': <String>[],
        'cover_letter': 'letter',
        'cautions': <String>[],
      }),
      throwsFormatException,
    );
  });

  testWidgets('consent is required before submitting', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => BoosterViewModel(FakeRepository()),
        child: const MaterialApp(home: BoosterView()),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Analyze my match'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Analyze my match'),
    );
    expect(button.onPressed, isNull);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    final enabled = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Analyze my match'),
    );
    expect(enabled.onPressed, isNotNull);
  });
}
