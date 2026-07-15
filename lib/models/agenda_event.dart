/// Mirrors GET /api/agenda's event shape (App\Controller\Api\AgendaController).
class AgendaEvent {
  const AgendaEvent({
    required this.id,
    required this.title,
    required this.startAt,
    required this.audienceLabel,
    this.description,
    this.endAt,
    this.location,
    this.signupList,
  });

  factory AgendaEvent.fromJson(Map<String, dynamic> json) => AgendaEvent(
        id: json['id'] as int,
        title: json['title'] as String,
        description: json['description'] as String?,
        startAt: DateTime.parse(json['startAt'] as String),
        endAt: json['endAt'] != null ? DateTime.parse(json['endAt'] as String) : null,
        location: json['location'] as String?,
        audienceLabel: json['audienceLabel'] as String,
        signupList: json['signupList'] != null
            ? SignupListSummary.fromJson(json['signupList'] as Map<String, dynamic>)
            : null,
      );

  final int id;
  final String title;
  final String? description;
  final DateTime startAt;
  final DateTime? endAt;
  final String? location;
  final String audienceLabel;
  final SignupListSummary? signupList;
}

/// The attached sign-up list's live registration state, if any - see
/// App\Entity\AgendaEvent::$signupList's docblock. Also returned as-is by
/// POST /api/signup-lists/{id}/register|unregister (App\Controller\Api\SignupListController) so a
/// register/unregister action can update the widget in place without refetching the whole event.
class SignupListSummary {
  const SignupListSummary({
    required this.id,
    required this.registrationCount,
    required this.registrationOpen,
    required this.isRegistered,
    required this.canRegister,
    required this.canUnregister,
    this.title,
  });

  factory SignupListSummary.fromJson(Map<String, dynamic> json) => SignupListSummary(
        id: json['id'] as int,
        title: json['title'] as String?,
        registrationCount: json['registrationCount'] as int,
        registrationOpen: json['registrationOpen'] as bool,
        isRegistered: json['isRegistered'] as bool,
        canRegister: json['canRegister'] as bool,
        canUnregister: json['canUnregister'] as bool,
      );

  final int id;
  final String? title;
  final int registrationCount;
  final bool registrationOpen;
  final bool isRegistered;
  final bool canRegister;
  final bool canUnregister;

  SignupListSummary copyWith({
    int? registrationCount,
    bool? registrationOpen,
    bool? isRegistered,
    bool? canRegister,
    bool? canUnregister,
  }) =>
      SignupListSummary(
        id: id,
        title: title,
        registrationCount: registrationCount ?? this.registrationCount,
        registrationOpen: registrationOpen ?? this.registrationOpen,
        isRegistered: isRegistered ?? this.isRegistered,
        canRegister: canRegister ?? this.canRegister,
        canUnregister: canUnregister ?? this.canUnregister,
      );
}
