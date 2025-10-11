import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

@immutable
abstract class BaseModel {
  final String id;

  String get getId => id;

  BaseModel({id}) : id = id ?? Uuid().v4();

  @override
  String toString() => 'BaseModel{id: $id}';
}
