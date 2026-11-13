class AnalysisResult {
  const AnalysisResult({
    required this.score,
    required this.summary,
    required this.matched,
    required this.missing,
    required this.bullets,
    required this.coverLetter,
    required this.cautions,
  });
  final int score;
  final String summary;
  final List<String> matched;
  final List<String> missing;
  final List<String> bullets;
  final String coverLetter;
  final List<String> cautions;

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    List<String> strings(String key) => (json[key] as List<dynamic>)
        .map((item) => item as String)
        .toList(growable: false);
    final score = json['match_score'] as int;
    if (score < 0 || score > 100) throw const FormatException('Invalid score');
    return AnalysisResult(
      score: score,
      summary: json['summary'] as String,
      matched: strings('matched_keywords'),
      missing: strings('missing_keywords'),
      bullets: strings('tailored_bullets'),
      coverLetter: json['cover_letter'] as String,
      cautions: strings('cautions'),
    );
  }
}
