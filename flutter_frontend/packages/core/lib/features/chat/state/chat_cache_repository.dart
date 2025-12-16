import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:messngr/features/chat/models/chat_message.dart';
import 'package:messngr/features/chat/models/chat_thread.dart';
import 'package:messngr/features/chat/widgets/chat_composer.dart';
import 'package:path/path.dart' as p;
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';
import 'package:sembast/sembast_memory.dart';

abstract class ChatCacheStore {
  Future<void> initialise({String? basePath});
  Future<void> saveThreads(List<ChatThread> threads);
  Future<List<ChatThread>> readThreads();
  Future<void> saveMessages(String threadId, List<ChatMessage> messages);
  Future<List<ChatMessage>> readMessages(String threadId);
  Future<void> saveDraft(String threadId, ChatDraftSnapshot snapshot);
  Future<ChatDraftSnapshot?> readDraft(String threadId);
}

class HiveChatCacheStore implements ChatCacheStore {
  HiveChatCacheStore({
    HiveInterface? hive,
    DatabaseFactory? databaseFactory,
  })  : _hive = hive ?? Hive,
        _databaseFactory = databaseFactory;

  final HiveInterface _hive;
  final DatabaseFactory? _databaseFactory;

  static const _threadBoxName = 'chat_threads';
  static const _draftBoxName = 'chat_drafts';
  static const _dbFile = 'chat_messages.db';
  static const _messageKey = 'messages';

  final StoreRef<String, Map<String, dynamic>> _messageStore =
      stringMapStoreFactory.store('thread_messages');

  Box<dynamic>? _threadBox;
  Box<dynamic>? _draftBox;
  Database? _db;
  bool _isInitialised = false;

  @override
  Future<void> initialise({String? basePath}) async {
    if (_isInitialised) return;

    if (!_hive.isAdapterRegistered(0)) {
      // noop: ensures Hive is initialised. No adapters required as we store maps.
    }

    if (!_hive.isBoxOpen(_threadBoxName)) {
      if (basePath != null) {
        _hive.init(basePath);
      } else {
        await Hive.initFlutter();
      }
      _threadBox = await _hive.openBox<dynamic>(_threadBoxName);
      _draftBox = await _hive.openBox<dynamic>(_draftBoxName);
    } else {
      _threadBox = _hive.box<dynamic>(_threadBoxName);
      _draftBox = _hive.box<dynamic>(_draftBoxName);
    }

    final factory = _databaseFactory ??
        (kIsWeb ? databaseFactoryMemory : databaseFactoryIo);
    final dbPath = basePath != null ? p.join(basePath, _dbFile) : _dbFile;
    _db = await factory.openDatabase(dbPath);

    _isInitialised = true;
  }

  @override
  Future<List<ChatThread>> readThreads() async {
    await _ensureReady();
    final values = _threadBox!.values;
    return [
      for (final value in values)
        if (value is Map) ChatThread.fromJson(value.cast<String, dynamic>()),
    ];
  }

  @override
  Future<void> saveThreads(List<ChatThread> threads) async {
    await _ensureReady();
    await Future.wait(
      threads.map((thread) => _threadBox!.put(thread.id, thread.toJson())),
    );
  }

  @override
  Future<void> saveMessages(String threadId, List<ChatMessage> messages) async {
    await _ensureReady();
    await _messageStore.record(threadId).put(
      _db!,
      {_messageKey: messages.map((message) => message.toJson()).toList()},
    );
  }

  @override
  Future<List<ChatMessage>> readMessages(String threadId) async {
    await _ensureReady();
    final record = await _messageStore.record(threadId).get(_db!);
    if (record == null) return const [];
    final raw = record[_messageKey];
    if (raw is! List) return const [];
    return [
      for (final entry in raw)
        if (entry is Map) ChatMessage.fromJson(entry.cast<String, dynamic>()),
    ];
  }

  @override
  Future<void> saveDraft(String threadId, ChatDraftSnapshot snapshot) async {
    await _ensureReady();
    if (snapshot.isEmpty) {
      await _draftBox!.delete(threadId);
    } else {
      await _draftBox!.put(threadId, snapshot.toJson());
    }
  }

  @override
  Future<ChatDraftSnapshot?> readDraft(String threadId) async {
    await _ensureReady();
    final value = await _draftBox!.get(threadId);
    if (value is Map) {
      return ChatDraftSnapshot.fromJson(value.cast<String, dynamic>());
    }
    return null;
  }

  Future<void> _ensureReady() async {
    if (!_isInitialised) {
      await initialise();
    }
  }
}

class InMemoryChatCacheStore implements ChatCacheStore {
  final Map<String, ChatThread> _threads = {};
  final Map<String, List<ChatMessage>> _messages = {};
  final Map<String, ChatDraftSnapshot> _drafts = {};

  @override
  Future<void> initialise({String? basePath}) async {}

  @override
  Future<List<ChatThread>> readThreads() async => _threads.values.toList();

  @override
  Future<List<ChatMessage>> readMessages(String threadId) async =>
      _messages[threadId] ?? const [];

  @override
  Future<ChatDraftSnapshot?> readDraft(String threadId) async =>
      _drafts[threadId];

  @override
  Future<void> saveMessages(String threadId, List<ChatMessage> messages) async {
    _messages[threadId] = List.of(messages);
  }

  @override
  Future<void> saveThreads(List<ChatThread> threads) async {
    for (final thread in threads) {
      _threads[thread.id] = thread;
    }
  }

  @override
  Future<void> saveDraft(String threadId, ChatDraftSnapshot snapshot) async {
    if (snapshot.isEmpty) {
      _drafts.remove(threadId);
    } else {
      _drafts[threadId] = snapshot;
    }
  }
}
