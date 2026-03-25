/// Realistic mock data for all providers so the UI can be tested without a
/// running backend.

import 'models.dart';

// ---------------------------------------------------------------------------
// Teams
// ---------------------------------------------------------------------------
final mockMsgrTeams = <MsgrTeam>[
  const MsgrTeam(
    id: 'team-1',
    name: 'Eyr',
    slug: 'eyr',
    iconEmoji: '\u{1F3E5}',
    domain: 'eyr.dev.msgr.no',
  ),
  const MsgrTeam(
    id: 'team-2',
    name: 'MadAppGang',
    slug: 'madappgang',
    iconEmoji: '\u{1F680}',
    domain: 'madappgang.dev.msgr.no',
  ),
  const MsgrTeam(
    id: 'team-3',
    name: 'Family',
    slug: 'family',
    iconEmoji: '\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}\u{200D}\u{1F466}',
    domain: 'family.dev.msgr.no',
  ),
];

// ---------------------------------------------------------------------------
// Channels (per team slug)
// ---------------------------------------------------------------------------
final mockMsgrChannels = <String, List<MsgrChannel>>{
  'eyr': [
    const MsgrChannel(
      id: 'ch-eyr-1',
      name: 'general',
      slug: 'general',
      icon: '\u{1F4AC}',
      kind: ChannelKind.channel,
      teamSlug: 'eyr',
      topic: 'Alt som angaar Eyr',
    ),
    const MsgrChannel(
      id: 'ch-eyr-2',
      name: 'dev',
      slug: 'dev',
      icon: '\u{1F6E0}',
      kind: ChannelKind.channel,
      teamSlug: 'eyr',
      topic: 'Development',
    ),
    const MsgrChannel(
      id: 'ch-eyr-3',
      name: 'announcements',
      slug: 'announcements',
      icon: '\u{1F4E2}',
      kind: ChannelKind.channel,
      visibility: ChannelVisibility.public,
      teamSlug: 'eyr',
    ),
    const MsgrChannel(
      id: 'ch-eyr-4',
      name: 'random',
      slug: 'random',
      icon: '\u{1F3B2}',
      kind: ChannelKind.channel,
      teamSlug: 'eyr',
    ),
    const MsgrChannel(
      id: 'ch-eyr-5',
      name: 'design',
      slug: 'design',
      icon: '\u{1F3A8}',
      kind: ChannelKind.channel,
      teamSlug: 'eyr',
    ),
    const MsgrChannel(
      id: 'dm-eyr-1',
      name: 'Kari Nordmann',
      slug: 'kari-nordmann',
      kind: ChannelKind.dm,
      teamSlug: 'eyr',
    ),
    const MsgrChannel(
      id: 'dm-eyr-2',
      name: 'Ola Hansen',
      slug: 'ola-hansen',
      kind: ChannelKind.dm,
      teamSlug: 'eyr',
    ),
  ],
  'madappgang': [
    const MsgrChannel(
      id: 'ch-mag-1',
      name: 'general',
      slug: 'general',
      icon: '\u{1F4AC}',
      kind: ChannelKind.channel,
      teamSlug: 'madappgang',
    ),
    const MsgrChannel(
      id: 'ch-mag-2',
      name: 'flutter',
      slug: 'flutter',
      icon: '\u{1F426}',
      kind: ChannelKind.channel,
      teamSlug: 'madappgang',
    ),
    const MsgrChannel(
      id: 'ch-mag-3',
      name: 'rust',
      slug: 'rust',
      icon: '\u{2699}',
      kind: ChannelKind.channel,
      teamSlug: 'madappgang',
    ),
  ],
  'family': [
    const MsgrChannel(
      id: 'ch-fam-1',
      name: 'general',
      slug: 'general',
      icon: '\u{1F3E0}',
      kind: ChannelKind.channel,
      teamSlug: 'family',
    ),
    const MsgrChannel(
      id: 'ch-fam-2',
      name: 'photos',
      slug: 'photos',
      icon: '\u{1F4F7}',
      kind: ChannelKind.channel,
      teamSlug: 'family',
    ),
  ],
};

// ---------------------------------------------------------------------------
// Messages (per channel ID)
// ---------------------------------------------------------------------------
MsgrMessage _msg(
  String id,
  String channelId,
  String senderId,
  String senderName,
  String content,
  int minutesAgo, {
  String? threadParentId,
}) {
  return MsgrMessage(
    id: id,
    channelId: channelId,
    senderProfileId: senderId,
    senderName: senderName,
    content: content,
    insertedAt: DateTime.now().subtract(Duration(minutes: minutesAgo)),
    threadParentId: threadParentId,
    status: MessageStatus.sent,
  );
}

final mockMsgrMessages = <String, List<MsgrMessage>>{
  'ch-eyr-1': [
    _msg('m1', 'ch-eyr-1', 'p1', 'Kari Nordmann', 'God morgen alle sammen!', 60),
    _msg('m2', 'ch-eyr-1', 'p2', 'Ola Hansen', 'Morgen! Noen som har sett den nye PRen?', 55),
    _msg('m3', 'ch-eyr-1', 'p3', 'Ingrid Berg', 'Ja, ser bra ut. Godkjent fra min side.', 50),
    _msg('m4', 'ch-eyr-1', 'p1', 'Kari Nordmann', 'Fint. Merger den naa.', 45),
    _msg('m5', 'ch-eyr-1', 'p4', 'Erik Solheim', 'Standup om 10 minutter!', 10),
    _msg('m6', 'ch-eyr-1', 'p2', 'Ola Hansen', 'Takk for paaminnelsen.', 8),
  ],
  'ch-eyr-2': [
    _msg('m7', 'ch-eyr-2', 'p2', 'Ola Hansen', 'Pushet ny Rust gateway versjon til staging.', 120),
    _msg('m8', 'ch-eyr-2', 'p3', 'Ingrid Berg', 'Ser ut til at NOISE-handshake er 2x raskere naa.', 100),
    _msg('m9', 'ch-eyr-2', 'p1', 'Kari Nordmann', 'Noen som kan reviewe PR #142?', 30),
  ],
  'ch-mag-1': [
    _msg('m10', 'ch-mag-1', 'p5', 'Jack R', 'Ny release av frontend-pluginen er ute.', 200),
    _msg('m11', 'ch-mag-1', 'p6', 'Anna K', 'Oppdatert til v3.13.0. Alt ser bra ut.', 180),
  ],
  'ch-fam-1': [
    _msg('m12', 'ch-fam-1', 'p7', 'Mamma', 'Husk middag paa sondag!', 300),
    _msg('m13', 'ch-fam-1', 'p8', 'Pappa', 'Kommer klokka 15.', 280),
  ],
};

// Thread replies keyed by parent message ID
final mockThreadReplies = <String, List<MsgrMessage>>{
  'm2': [
    _msg('t1', 'ch-eyr-1', 'p3', 'Ingrid Berg', 'Hvilken PR? #140?', 53, threadParentId: 'm2'),
    _msg('t2', 'ch-eyr-1', 'p2', 'Ola Hansen', 'Ja, den med NOISE-handshake fix.', 52, threadParentId: 'm2'),
    _msg('t3', 'ch-eyr-1', 'p1', 'Kari Nordmann', 'LGTM!', 51, threadParentId: 'm2'),
  ],
  'm9': [
    _msg('t4', 'ch-eyr-2', 'p2', 'Ola Hansen', 'Jeg tar den.', 28, threadParentId: 'm9'),
  ],
};

// ---------------------------------------------------------------------------
// Presence (per team slug)
// ---------------------------------------------------------------------------
final mockPresenceData = <String, Map<String, PresenceInfo>>{
  'eyr': {
    'p1': const PresenceInfo(profileId: 'p1', status: PresenceStatus.online),
    'p2': const PresenceInfo(profileId: 'p2', status: PresenceStatus.online),
    'p3': const PresenceInfo(profileId: 'p3', status: PresenceStatus.away),
    'p4': const PresenceInfo(profileId: 'p4', status: PresenceStatus.offline),
  },
  'madappgang': {
    'p5': const PresenceInfo(profileId: 'p5', status: PresenceStatus.online),
    'p6': const PresenceInfo(profileId: 'p6', status: PresenceStatus.offline),
  },
  'family': {
    'p7': const PresenceInfo(profileId: 'p7', status: PresenceStatus.offline),
    'p8': const PresenceInfo(profileId: 'p8', status: PresenceStatus.offline),
  },
};

// ---------------------------------------------------------------------------
// Profiles (per team slug)
// ---------------------------------------------------------------------------
final mockProfiles = <String, List<MsgrProfile>>{
  'eyr': const [
    MsgrProfile(id: 'p1', displayName: 'Kari Nordmann', email: 'kari@eyr.no', role: 'admin'),
    MsgrProfile(id: 'p2', displayName: 'Ola Hansen', email: 'ola@eyr.no', role: 'member'),
    MsgrProfile(id: 'p3', displayName: 'Ingrid Berg', email: 'ingrid@eyr.no', role: 'member'),
    MsgrProfile(id: 'p4', displayName: 'Erik Solheim', email: 'erik@eyr.no', role: 'member'),
  ],
  'madappgang': const [
    MsgrProfile(id: 'p5', displayName: 'Jack R', email: 'jack@mag.com', role: 'owner'),
    MsgrProfile(id: 'p6', displayName: 'Anna K', email: 'anna@mag.com', role: 'member'),
  ],
  'family': const [
    MsgrProfile(id: 'p7', displayName: 'Mamma', role: 'admin'),
    MsgrProfile(id: 'p8', displayName: 'Pappa', role: 'member'),
  ],
};

// ---------------------------------------------------------------------------
// Unread counts (per channel ID)
// ---------------------------------------------------------------------------
final mockUnreadCounts = <String, int>{
  'ch-eyr-1': 3,
  'ch-eyr-3': 1,
  'dm-eyr-1': 2,
  'ch-fam-1': 2,
};
