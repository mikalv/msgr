/// Centralized app strings with Norwegian (default) and English support.
/// Usage: S.of(context).channels or S.channels (static, uses current locale)
class S {
  S._();

  static String _locale = 'en';

  static void setLocale(String locale) => _locale = locale;
  static String get locale => _locale;
  static bool get isNorwegian => _locale.startsWith('nb') || _locale.startsWith('no');

  // Sidebar
  static String get channels => isNorwegian ? 'Kanaler' : 'Channels';
  static String get directMessages => isNorwegian ? 'Direktemeldinger' : 'Direct messages';
  static String get addChannels => isNorwegian ? 'Legg til kanaler' : 'Add channels';
  static String get invitePeople => isNorwegian ? 'Inviter folk' : 'Invite people';
  static String get logout => isNorwegian ? 'Logg ut' : 'Log out';
  static String get settings => isNorwegian ? 'Innstillinger' : 'Settings';
  static String get newMessage => isNorwegian ? 'Ny melding' : 'New message';

  // Chat
  static String get noMessagesYet => isNorwegian ? 'Ingen meldinger ennå' : 'No messages yet';
  static String get selectChannelToStart => isNorwegian ? 'Velg en kanal for å starte' : 'Select a channel to start';
  static String get reconnecting => isNorwegian ? 'Kobler til igjen...' : 'Reconnecting...';
  static String get newMessages => isNorwegian ? 'Nye meldinger' : 'New messages';
  static String get editingMessage => isNorwegian ? 'Redigerer melding' : 'Editing message';
  static String get edited => isNorwegian ? '(redigert)' : '(edited)';
  static String typing(List<String> names) {
    final joined = names.join(', ');
    return isNorwegian ? '$joined skriver...' : '$joined is typing...';
  }

  // Composer
  static String get composerPlaceholder => isNorwegian
      ? 'Del en oppdatering eller skriv / for kommandoer'
      : 'Share an update or type / for commands';
  static String get composerPlaceholderShort => isNorwegian ? 'Melding' : 'Message';

  // Context menu
  static String get copyText => isNorwegian ? 'Kopier tekst' : 'Copy text';
  static String get replyInThread => isNorwegian ? 'Svar i tråd' : 'Reply in thread';
  static String get addReaction => isNorwegian ? 'Legg til reaksjon' : 'Add reaction';
  static String get pinMessage => isNorwegian ? 'Fest melding' : 'Pin message';
  static String get edit => isNorwegian ? 'Rediger' : 'Edit';
  static String get delete => isNorwegian ? 'Slett' : 'Delete';
  static String get copyLink => isNorwegian ? 'Kopier lenke' : 'Copy link';
  static String get textCopied => isNorwegian ? 'Tekst kopiert' : 'Text copied';
  static String get linkCopied => isNorwegian ? 'Lenke kopiert' : 'Link copied';
  static String get comingSoon => isNorwegian ? 'Kommer snart' : 'Coming soon';

  // Channel context menu
  static String get muteChannel => isNorwegian ? 'Demp kanal' : 'Mute channel';
  static String get leaveChannel => isNorwegian ? 'Forlat kanal' : 'Leave channel';
  static String get editChannel => isNorwegian ? 'Rediger kanal' : 'Edit channel';
  static String get channelLinkCopied => isNorwegian ? 'Kanal-lenke kopiert' : 'Channel link copied';

  // Threads
  static String replies(int count) => isNorwegian ? '$count svar' : '$count replies';

  // Search
  static String get searchMessages => isNorwegian ? 'Søk i meldinger...' : 'Search messages...';
  static String get minTwoChars => isNorwegian ? 'Skriv minst 2 tegn' : 'Type at least 2 characters';
  static String get noResults => isNorwegian ? 'Ingen resultater' : 'No results';

  // Errors
  static String get uploadFailed => isNorwegian ? 'Opplasting feilet' : 'Upload failed';
  static String get commandFailed => isNorwegian ? 'Kommando feilet' : 'Command failed';
  static String get couldNotDelete => isNorwegian ? 'Kunne ikke slette' : 'Could not delete';
  static String get couldNotEdit => isNorwegian ? 'Kunne ikke redigere melding' : 'Could not edit message';
  static String get couldNotLoadImage => isNorwegian ? 'Kunne ikke laste bilde' : 'Could not load image';
  static String get couldNotLoadMembers => isNorwegian ? 'Kunne ikke laste medlemmer' : 'Could not load members';
  static String get fileTooLarge => isNorwegian ? 'er for stor (maks 50 MB)' : 'is too large (max 50 MB)';
  static String get loadingError => isNorwegian ? 'Feil ved lasting av meldinger' : 'Error loading messages';
  static String get tryAgain => isNorwegian ? 'Prøv igjen' : 'Try again';

  // Avatar upload
  static String get changeProfilePicture => isNorwegian ? 'Endre profilbilde' : 'Change profile picture';
  static String get file => isNorwegian ? 'Fil' : 'File';
  static String get paste => isNorwegian ? 'Lim inn' : 'Paste';
  static String get pasteImageUrl => isNorwegian ? 'Lim inn bilde-URL...' : 'Paste image URL...';
  static String get fetch => isNorwegian ? 'Hent' : 'Fetch';
  static String get cancel => isNorwegian ? 'Avbryt' : 'Cancel';
  static String get save => isNorwegian ? 'Lagre' : 'Save';

  // Auth
  static String get enterEmail => isNorwegian ? 'Skriv inn e-postadresse' : 'Enter email address';
  static String get enterPhone => isNorwegian ? 'Skriv inn telefonnummer' : 'Enter phone number';
  static String get enterCode => isNorwegian ? 'Skriv inn kode' : 'Enter code';
}
