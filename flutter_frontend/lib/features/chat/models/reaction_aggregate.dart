class ReactionAggregate {
  const ReactionAggregate({
    required this.emoji,
    required this.count,
    required this.profileIds,
  });

  final String emoji;
  final int count;
  final List<String> profileIds;

  ReactionAggregate copyWith({
    String? emoji,
    int? count,
    List<String>? profileIds,
  }) {
    return ReactionAggregate(
      emoji: emoji ?? this.emoji,
      count: count ?? this.count,
      profileIds: profileIds ?? List<String>.from(this.profileIds),
    );
  }

  Map<String, dynamic> toJson() => {
        'emoji': emoji,
        'count': count,
        'profile_ids': profileIds,
      };

  factory ReactionAggregate.fromJson(Map<String, dynamic> json) {
    return ReactionAggregate(
      emoji: json['emoji'] as String? ?? '',
      count: json['count'] as int? ?? 0,
      profileIds: [
        for (final entry in (json['profile_ids'] as List? ?? const []))
          if (entry is String) entry
      ],
    );
  }
}
