/// The « Nuage de mots » seen from the phone - the shapes Api\WordCloudController answers with.
///
/// Deliberately smaller than the live contest's models: a cloud has no participant, no phase and no
/// leaderboard. A student is asked a question, writes a word or three, and is done.
library;

/// What the home banner needs, and nothing more - the detail is fetched when it is opened.
class WordCloudBanner {
  const WordCloudBanner({
    required this.id,
    required this.name,
    required this.question,
    this.programShortName,
  });

  factory WordCloudBanner.fromJson(Map<String, dynamic> json) => WordCloudBanner(
        id: json['id'] as int,
        name: json['name'] as String,
        question: json['question'] as String,
        programShortName: json['programShortName'] as String?,
      );

  final int id;
  final String name;
  final String question;
  final String? programShortName;
}

/// One word this student has already sent.
///
/// A refused word is kept and shown struck through, exactly as on the web: it left the cloud, not
/// the record, and hiding it would leave somebody wondering where their word went.
class WordCloudOwnWord {
  const WordCloudOwnWord({
    required this.text,
    required this.rejected,
    required this.pending,
  });

  factory WordCloudOwnWord.fromJson(Map<String, dynamic> json) => WordCloudOwnWord(
        text: json['text'] as String,
        rejected: json['rejected'] as bool? ?? false,
        pending: json['pending'] as bool? ?? false,
      );

  final String text;
  final bool rejected;
  final bool pending;
}

/// One word of the cloud, already weighted by the server.
///
/// [size] and [step] come from App\Service\WordCloud\WordCloudWeighting: the phone never decides
/// how big a word is, so it cannot draw a cloud the board would have drawn differently. [step] is a
/// rung of the ladder (`top`/`strong`/`mid`/`faint`) rather than a colour, because the palette
/// belongs to whoever is drawing.
class WordCloudWord {
  const WordCloudWord({
    required this.word,
    required this.count,
    required this.size,
    required this.step,
  });

  factory WordCloudWord.fromJson(Map<String, dynamic> json) => WordCloudWord(
        word: json['word'] as String,
        count: json['count'] as int,
        size: (json['size'] as num).toDouble(),
        step: json['step'] as String,
      );

  final String word;
  final int count;
  final double size;
  final String step;
}

/// Everything the screen draws itself from, and everything it needs to know before letting somebody
/// type.
class WordCloudState {
  const WordCloudState({
    required this.id,
    required this.name,
    required this.question,
    required this.status,
    required this.canSubmit,
    required this.maxCharacters,
    this.programShortName,
    this.remainingWords,
    this.maxWordsPerAnswer,
    this.closesAt,
    this.ownWords = const [],
    this.cloud,
  });

  factory WordCloudState.fromJson(Map<String, dynamic> json) => WordCloudState(
        id: json['id'] as int,
        name: json['name'] as String,
        question: json['question'] as String,
        status: json['status'] as String,
        canSubmit: json['canSubmit'] as bool? ?? false,
        maxCharacters: json['maxCharacters'] as int? ?? 30,
        programShortName: json['programShortName'] as String?,
        // Null is « Illimités » throughout the tool, never a large number standing in for it.
        remainingWords: json['remainingWords'] as int?,
        maxWordsPerAnswer: json['maxWordsPerAnswer'] as int?,
        closesAt: json['closesAt'] != null ? DateTime.tryParse(json['closesAt'] as String) : null,
        ownWords: ((json['ownWords'] as List<dynamic>?) ?? const [])
            .map((entry) => WordCloudOwnWord.fromJson(entry as Map<String, dynamic>))
            .toList(),
        // Null unless « Les étudiants voient le nuage sur leur écran » is on - off by default,
        // because a cloud on every desk is a cloud nobody looks up from.
        cloud: json['cloud'] == null
            ? null
            : (json['cloud'] as List<dynamic>)
                .map((entry) => WordCloudWord.fromJson(entry as Map<String, dynamic>))
                .toList(),
      );

  final int id;
  final String name;
  final String question;

  /// `scheduled` | `open` | `closed`, as App\Service\WordCloud\WordCloudSchedule reads it.
  final String status;

  /// Whether a word may be written right now - the period and the quota folded into one answer.
  final bool canSubmit;

  final int maxCharacters;
  final String? programShortName;

  /// How many words are left to this student, or null when the cloud is unlimited.
  final int? remainingWords;

  /// How many words one box may hold, or null on « Expression libre ».
  final int? maxWordsPerAnswer;

  final DateTime? closesAt;
  final List<WordCloudOwnWord> ownWords;
  final List<WordCloudWord>? cloud;

  bool get isClosed => status == 'closed';
  bool get isScheduled => status == 'scheduled';

  /// How many empty boxes to draw. Unlimited means one at a time - a page of thirty boxes is not
  /// what « Illimités » is for.
  int get boxCount => remainingWords == null ? 1 : remainingWords!.clamp(0, 6);
}

/// A word the server would not take, and why - the reason code plus the sentence to show.
class WordCloudRefusal {
  const WordCloudRefusal({required this.word, required this.reason, required this.message});

  factory WordCloudRefusal.fromJson(Map<String, dynamic> json) => WordCloudRefusal(
        word: json['word'] as String,
        reason: json['reason'] as String,
        message: json['message'] as String,
      );

  final String word;
  final String reason;
  final String message;
}

/// What comes back from a submission: what was taken, what was not, and the new state.
///
/// One round trip on purpose - a refusal in the second box must not cost the screen a second call
/// to find out that the first was accepted.
class WordCloudSubmitResult {
  const WordCloudSubmitResult({
    required this.accepted,
    required this.refusals,
    required this.state,
  });

  factory WordCloudSubmitResult.fromJson(Map<String, dynamic> json) => WordCloudSubmitResult(
        accepted: ((json['accepted'] as List<dynamic>?) ?? const []).cast<String>(),
        refusals: ((json['refusals'] as List<dynamic>?) ?? const [])
            .map((entry) => WordCloudRefusal.fromJson(entry as Map<String, dynamic>))
            .toList(),
        state: WordCloudState.fromJson(json['state'] as Map<String, dynamic>),
      );

  final List<String> accepted;
  final List<WordCloudRefusal> refusals;
  final WordCloudState state;
}
