import 'package:flutter_test/flutter_test.dart';

import 'package:core/providers/models.dart';

void main() {
  group('SlackTeam', () {
    test('construction with required fields', () {
      const team = SlackTeam(id: 't1', name: 'Acme', slug: 'acme');
      expect(team.id, 't1');
      expect(team.name, 'Acme');
      expect(team.slug, 'acme');
      expect(team.iconEmoji, isNull);
      expect(team.domain, isNull);
    });

    test('equality based on id', () {
      const a = SlackTeam(id: 't1', name: 'Acme', slug: 'acme');
      const b = SlackTeam(id: 't1', name: 'Acme Corp', slug: 'acme-corp');
      expect(a, equals(b));
    });

    test('inequality for different ids', () {
      const a = SlackTeam(id: 't1', name: 'Acme', slug: 'acme');
      const b = SlackTeam(id: 't2', name: 'Acme', slug: 'acme');
      expect(a, isNot(equals(b)));
    });

    test('copyWith', () {
      const team = SlackTeam(id: 't1', name: 'Old', slug: 'old');
      final updated = team.copyWith(name: 'New', domain: 'new.com');
      expect(updated.name, 'New');
      expect(updated.domain, 'new.com');
      expect(updated.id, 't1');
      expect(updated.slug, 'old');
    });

    test('toString includes slug', () {
      const team = SlackTeam(id: 't1', name: 'Acme', slug: 'acme');
      expect(team.toString(), contains('acme'));
    });
  });

  group('SlackChannel', () {
    test('construction with defaults', () {
      const ch = SlackChannel(id: 'c1', name: 'general', slug: 'general');
      expect(ch.id, 'c1');
      expect(ch.name, 'general');
      expect(ch.kind, ChannelKind.channel);
      expect(ch.visibility, ChannelVisibility.public);
      expect(ch.icon, isNull);
      expect(ch.topic, isNull);
      expect(ch.teamSlug, isNull);
    });

    test('construction as DM', () {
      const ch = SlackChannel(
        id: 'dm1',
        name: 'Alice',
        slug: 'alice-dm',
        kind: ChannelKind.dm,
        visibility: ChannelVisibility.private,
      );
      expect(ch.kind, ChannelKind.dm);
      expect(ch.visibility, ChannelVisibility.private);
    });

    test('equality based on id', () {
      const a = SlackChannel(id: 'c1', name: 'general', slug: 'general');
      const b = SlackChannel(id: 'c1', name: 'random', slug: 'random');
      expect(a, equals(b));
    });
  });

  group('ChannelKind', () {
    test('has expected values', () {
      expect(ChannelKind.values, containsAll([
        ChannelKind.channel,
        ChannelKind.dm,
        ChannelKind.groupDm,
      ]));
    });
  });

  group('SlackMessage', () {
    test('construction with required fields', () {
      final msg = SlackMessage(
        id: 'm1',
        channelId: 'ch-1',
        senderProfileId: 'p1',
        senderName: 'Alice',
        content: 'Hello',
        insertedAt: DateTime(2024, 6, 1),
      );
      expect(msg.id, 'm1');
      expect(msg.channelId, 'ch-1');
      expect(msg.content, 'Hello');
      expect(msg.status, MessageStatus.sent);
      expect(msg.reactions, isEmpty);
      expect(msg.mentions, isEmpty);
      expect(msg.mediaRefs, isEmpty);
      expect(msg.threadParentId, isNull);
      expect(msg.threadReplyCount, 0);
      expect(msg.isSystem, false);
    });

    test('computed properties', () {
      final threadReply = SlackMessage(
        id: 'm2',
        channelId: 'ch-1',
        senderProfileId: 'p1',
        senderName: 'Alice',
        content: 'Reply',
        insertedAt: DateTime(2024, 6, 1),
        threadParentId: 'm1',
      );
      expect(threadReply.isThreadReply, true);
      expect(threadReply.hasThreadReplies, false);

      final parent = SlackMessage(
        id: 'm1',
        channelId: 'ch-1',
        senderProfileId: 'p1',
        senderName: 'Alice',
        content: 'Parent',
        insertedAt: DateTime(2024, 6, 1),
        threadReplyCount: 5,
      );
      expect(parent.isThreadReply, false);
      expect(parent.hasThreadReplies, true);
    });

    test('hasMentions', () {
      final msg = SlackMessage(
        id: 'm3',
        channelId: 'ch-1',
        senderProfileId: 'p1',
        senderName: 'Alice',
        content: 'Hey @Bob',
        insertedAt: DateTime(2024, 6, 1),
        mentions: const [
          MentionData(
            profileId: 'bob-1',
            displayName: 'Bob',
            offset: 4,
            length: 4,
          ),
        ],
      );
      expect(msg.hasMentions, true);
    });

    test('copyWith preserves and overrides', () {
      final msg = SlackMessage(
        id: 'm1',
        channelId: 'ch-1',
        senderProfileId: 'p1',
        senderName: 'Alice',
        content: 'Original',
        insertedAt: DateTime(2024, 6, 1),
        status: MessageStatus.sending,
      );

      final updated = msg.copyWith(
        content: 'Edited',
        status: MessageStatus.sent,
      );
      expect(updated.id, 'm1');
      expect(updated.content, 'Edited');
      expect(updated.status, MessageStatus.sent);
      expect(updated.senderName, 'Alice');
    });

    test('status transitions', () {
      var msg = SlackMessage(
        id: 'm1',
        channelId: 'ch-1',
        senderProfileId: 'p1',
        senderName: 'Alice',
        content: 'Hello',
        insertedAt: DateTime(2024, 6, 1),
        status: MessageStatus.sending,
      );
      expect(msg.status, MessageStatus.sending);

      msg = msg.copyWith(status: MessageStatus.sent);
      expect(msg.status, MessageStatus.sent);

      msg = msg.copyWith(status: MessageStatus.delivered);
      expect(msg.status, MessageStatus.delivered);

      msg = msg.copyWith(status: MessageStatus.read);
      expect(msg.status, MessageStatus.read);

      msg = msg.copyWith(status: MessageStatus.failed);
      expect(msg.status, MessageStatus.failed);
    });

    test('equality based on id', () {
      final a = SlackMessage(
        id: 'm1',
        channelId: 'ch-1',
        senderProfileId: 'p1',
        senderName: 'Alice',
        content: 'V1',
        insertedAt: DateTime(2024, 6, 1),
      );
      final b = SlackMessage(
        id: 'm1',
        channelId: 'ch-1',
        senderProfileId: 'p1',
        senderName: 'Alice',
        content: 'V2',
        insertedAt: DateTime(2024, 6, 2),
      );
      expect(a, equals(b));
    });
  });

  group('MessageStatus', () {
    test('has all expected values', () {
      expect(MessageStatus.values, containsAll([
        MessageStatus.sending,
        MessageStatus.sent,
        MessageStatus.delivered,
        MessageStatus.read,
        MessageStatus.failed,
      ]));
    });
  });

  group('MessageReaction', () {
    test('construction', () {
      const reaction = MessageReaction(
        emoji: 'thumbsup',
        count: 3,
        profileIds: ['p1', 'p2', 'p3'],
        includesMe: true,
      );
      expect(reaction.emoji, 'thumbsup');
      expect(reaction.count, 3);
      expect(reaction.profileIds.length, 3);
      expect(reaction.includesMe, true);
    });

    test('fromJson', () {
      final reaction = MessageReaction.fromJson({
        'emoji': 'heart',
        'count': 2,
        'profile_ids': ['p1', 'p2'],
      });
      expect(reaction.emoji, 'heart');
      expect(reaction.count, 2);
      expect(reaction.profileIds, ['p1', 'p2']);
      expect(reaction.includesMe, false);
    });

    test('fromJson with currentProfileId sets includesMe', () {
      final reaction = MessageReaction.fromJson({
        'emoji': 'wave',
        'count': 1,
        'profile_ids': ['my-profile'],
      }, currentProfileId: 'my-profile');
      expect(reaction.includesMe, true);
    });

    test('fromJson includesMe false when not in list', () {
      final reaction = MessageReaction.fromJson({
        'emoji': 'wave',
        'count': 1,
        'profile_ids': ['other-profile'],
      }, currentProfileId: 'my-profile');
      expect(reaction.includesMe, false);
    });

    test('fromJson handles missing profile_ids', () {
      final reaction = MessageReaction.fromJson({
        'emoji': 'fire',
        'count': 5,
      });
      expect(reaction.profileIds, isEmpty);
      // count falls back to ids.length when count is null,
      // but here count is explicitly 5
      expect(reaction.count, 5);
    });

    test('fromJson uses ids.length when count is null', () {
      final reaction = MessageReaction.fromJson({
        'emoji': 'star',
        'profile_ids': ['p1', 'p2'],
      });
      expect(reaction.count, 2); // falls back to ids.length
    });

    test('copyWith', () {
      const reaction = MessageReaction(
        emoji: 'thumbsup',
        count: 1,
        profileIds: ['p1'],
        includesMe: false,
      );
      final updated = reaction.copyWith(
        count: 2,
        profileIds: ['p1', 'p2'],
        includesMe: true,
      );
      expect(updated.emoji, 'thumbsup');
      expect(updated.count, 2);
      expect(updated.profileIds, ['p1', 'p2']);
      expect(updated.includesMe, true);
    });
  });

  group('MentionData', () {
    test('construction', () {
      const mention = MentionData(
        profileId: 'p1',
        displayName: 'Alice',
        offset: 5,
        length: 6,
      );
      expect(mention.profileId, 'p1');
      expect(mention.displayName, 'Alice');
      expect(mention.offset, 5);
      expect(mention.length, 6);
    });

    test('fromJson', () {
      final mention = MentionData.fromJson({
        'profile_id': 'bob-123',
        'display_name': 'Bob',
        'offset': 10,
        'length': 4,
      });
      expect(mention.profileId, 'bob-123');
      expect(mention.displayName, 'Bob');
      expect(mention.offset, 10);
      expect(mention.length, 4);
    });

    test('fromJson handles missing fields gracefully', () {
      final mention = MentionData.fromJson({});
      expect(mention.profileId, '');
      expect(mention.displayName, '');
      expect(mention.offset, 0);
      expect(mention.length, 0);
    });

    test('toJson', () {
      const mention = MentionData(
        profileId: 'p1',
        displayName: 'Alice',
        offset: 0,
        length: 6,
      );
      final json = mention.toJson();
      expect(json['profile_id'], 'p1');
      expect(json['display_name'], 'Alice');
      expect(json['offset'], 0);
      expect(json['length'], 6);
    });

    test('fromJson/toJson round-trip', () {
      const original = MentionData(
        profileId: 'p1',
        displayName: 'Charlie',
        offset: 15,
        length: 8,
      );
      final json = original.toJson();
      final restored = MentionData.fromJson(json);
      expect(restored.profileId, original.profileId);
      expect(restored.displayName, original.displayName);
      expect(restored.offset, original.offset);
      expect(restored.length, original.length);
    });
  });
}
