// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:libmsgr/src/models/base.dart';
import 'package:meta/meta.dart';

@immutable
class Profile extends BaseModel {
  final String uid;
  final String username;
  final String? firstName;
  final String? lastName;
  final String? status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? avatarUrl;
  final Map<String, dynamic>? settings;
  final List<dynamic> roles;

  Profile(
      {super.id,
      required this.username,
      required this.uid,
      required this.createdAt,
      required this.updatedAt,
      required this.roles,
      this.firstName,
      this.lastName,
      this.status,
      this.settings,
      this.avatarUrl});

  @override
  bool operator ==(other) =>
      identical(this, other) ||
      other is Profile &&
          id == other.id &&
          username == other.username &&
          uid == other.uid &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          roles == other.roles &&
          firstName == other.firstName &&
          lastName == other.lastName &&
          status == other.status &&
          settings == other.settings &&
          avatarUrl == other.avatarUrl;

  @override
  int get hashCode =>
      super.hashCode ^
      id.hashCode ^
      username.hashCode ^
      uid.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode ^
      roles.hashCode ^
      firstName.hashCode ^
      lastName.hashCode ^
      status.hashCode ^
      settings.hashCode ^
      avatarUrl.hashCode;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'uid': uid,
      'inserted_at': createdAt,
      'updated_at': updatedAt,
      'roles': roles,
      'first_name': firstName,
      'last_name': lastName,
      'status': status,
      'settings': settings,
      'avatar_url': avatarUrl
    };
  }

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'],
      username: map['username'],
      uid: map['uid'],
      createdAt: map['inserted_at'],
      updatedAt: map['updated_at'],
      roles: map['roles'],
      firstName: map['first_name'],
      lastName: map['last_name'],
      status: map['status'],
      settings: map['settings'],
      avatarUrl: map['avatar_url'],
    );
  }

  factory Profile.fromJson(dynamic json) {
    //final bJson = json as Map<String, dynamic>;
    /*return switch (json) {
      {
        'id': String id,
        'username': String username,
        'first_name': String firstName,
        'last_name': String lastName,
        'uid': String uid,
        'status': String status,
        'avatar_url': String avatarUrl,
        'inserted_at': String insertedAt,
      } =>
        Profile(
            id: id,
            username: username,
            firstName: firstName,
            lastName: lastName,
            uid: uid,
            status: status,
            avatarUrl: avatarUrl,
            insertedAt: insertedAt),
      _ => throw const FormatException('Failed to load profile.'),
    };*/
    return Profile(
        id: json['id'],
        uid: json['uid'],
        username: json['username'],
        firstName: json['first_name'],
        lastName: json['last_name'],
        avatarUrl: json['avatar_url'],
        createdAt: DateTime.parse(json['inserted_at']),
        updatedAt: DateTime.parse(json['updated_at']),
        roles: json['roles'] as List<dynamic>,
        settings: json['settings']);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'uid': uid,
        'username': username,
        'first_name': firstName,
        'last_name': lastName,
        'avatar_url': avatarUrl,
        'inserted_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'roles': roles,
        'settings': settings
      };

  @override
  String toString() {
    return (firstName != null && lastName != null)
        ? '@$username ($firstName $lastName)'
        : '@$username';
  }

  Profile copyWith({
    String? id,
    String? uid,
    String? username,
    String? firstName,
    String? lastName,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? avatarUrl,
    Map<String, dynamic>? settings,
    List<dynamic>? roles,
  }) {
    return Profile(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      username: username ?? this.username,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      settings: settings ?? this.settings,
      roles: roles ?? this.roles,
    );
  }
}
