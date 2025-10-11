// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:libmsgr/src/models/base.dart';
import 'package:meta/meta.dart';

@immutable
class User extends BaseModel {
  final String identifier;
  final String accessToken;
  final String refreshToken;

  String get uid => id;

  User(
      {super.id,
      required this.identifier,
      required this.accessToken,
      required this.refreshToken});

  @override
  bool operator ==(other) =>
      identical(this, other) ||
      other is User &&
          uid == other.uid &&
          identifier == other.identifier &&
          accessToken == other.accessToken &&
          accessToken == other.accessToken &&
          refreshToken == other.refreshToken;

  @override
  int get hashCode =>
      super.hashCode ^
      uid.hashCode ^
      identifier.hashCode ^
      accessToken.hashCode ^
      refreshToken.hashCode;

  factory User.fromJson(dynamic json) {
    return switch (json) {
      {
        'uid': String uid,
        'identifier': String identifier,
        'accessToken': String token,
        'refreshToken': String refreshToken
      } =>
        User(
            id: uid,
            identifier: identifier,
            accessToken: token,
            refreshToken: refreshToken),
      _ => throw const FormatException('Failed to load user.'),
    };
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'identifier': identifier,
        'accessToken': accessToken,
        'refreshToken': refreshToken
      };

  @override
  String toString() {
    return 'User{uid: $uid, identifier: $identifier, '
        'accessToken: <<SECRET>>, refreshToken: <<SECRET>>}';
  }

  User copyWith({
    String? uid,
    String? identifier,
    String? accessToken,
    String? refreshToken,
  }) {
    return User(
      id: uid ?? this.uid,
      identifier: identifier ?? this.identifier,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
    );
  }
}
