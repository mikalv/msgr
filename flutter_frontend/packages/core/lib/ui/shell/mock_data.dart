import 'shell_models.dart';

final mockTeams = <MockTeam>[
  const MockTeam(
    id: 'team-1',
    name: 'Eyr',
    slug: 'eyr',
    iconEmoji: '\u{1F3E5}', // 🏥
    unreadCount: 4,
  ),
  const MockTeam(
    id: 'team-2',
    name: 'MadAppGang',
    slug: 'madappgang',
    iconEmoji: '\u{1F680}', // 🚀
    unreadCount: 0,
  ),
  const MockTeam(
    id: 'team-3',
    name: 'Family',
    slug: 'family',
    iconEmoji: '\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}\u{200D}\u{1F466}', // 👨‍👩‍👧‍👦
    unreadCount: 2,
  ),
];

final mockChannels = <MockChannel>[
  MockChannel(
    id: 'ch-1',
    name: 'general',
    slug: 'general',
    iconEmoji: '\u{1F4AC}', // 💬
    kind: ChannelKind.public,
    unreadCount: 3,
    lastActivityAt: DateTime.now().subtract(const Duration(minutes: 5)),
  ),
  MockChannel(
    id: 'ch-2',
    name: 'dev',
    slug: 'dev',
    iconEmoji: '\u{1F6E0}', // 🛠
    kind: ChannelKind.public,
    unreadCount: 0,
    lastActivityAt: DateTime.now().subtract(const Duration(hours: 1)),
  ),
  MockChannel(
    id: 'ch-3',
    name: 'announcements',
    slug: 'announcements',
    iconEmoji: '\u{1F4E2}', // 📢
    kind: ChannelKind.announcement,
    unreadCount: 1,
    lastActivityAt: DateTime.now().subtract(const Duration(minutes: 30)),
  ),
  MockChannel(
    id: 'ch-4',
    name: 'random',
    slug: 'random',
    iconEmoji: '\u{1F3B2}', // 🎲
    kind: ChannelKind.public,
    unreadCount: 0,
    lastActivityAt: DateTime.now().subtract(const Duration(hours: 3)),
  ),
  MockChannel(
    id: 'ch-5',
    name: 'design',
    slug: 'design',
    iconEmoji: '\u{1F3A8}', // 🎨
    kind: ChannelKind.public,
    unreadCount: 0,
    hasDraft: true,
    lastActivityAt: DateTime.now().subtract(const Duration(hours: 2)),
  ),
];

final mockDmContacts = <MockDmContact>[
  MockDmContact(
    id: 'dm-1',
    name: 'Kari Nordmann',
    isOnline: true,
    unreadCount: 2,
    lastActivityAt: DateTime.now().subtract(const Duration(minutes: 3)),
  ),
  MockDmContact(
    id: 'dm-2',
    name: 'Ola Hansen',
    isOnline: false,
    unreadCount: 0,
    lastActivityAt: DateTime.now().subtract(const Duration(hours: 4)),
  ),
  MockDmContact(
    id: 'dm-3',
    name: 'Ingrid Berg',
    isOnline: true,
    unreadCount: 0,
    lastActivityAt: DateTime.now().subtract(const Duration(hours: 1)),
  ),
  MockDmContact(
    id: 'dm-4',
    name: 'Erik Solheim',
    isOnline: false,
    unreadCount: 5,
    lastActivityAt: DateTime.now().subtract(const Duration(minutes: 15)),
  ),
];
