/// Support for doing something awesome.
///
/// More dartdocs go here.
library;

export 'src/utils/extensions.dart';
export 'src/abstracts.dart';
export 'src/libmsgr_base.dart';

// Repositories
export 'src/repositories/auth_repository.dart';
export 'src/repositories/message_repository.dart';
export 'src/repositories/profile_repository.dart';
export 'src/repositories/room_repository.dart';
export 'src/repositories/conversation_repository.dart';

// Data models
export 'src/models/user.dart';
export 'src/models/device.dart';
export 'src/models/profile.dart';
export 'src/models/team.dart';
export 'src/models/room.dart';
export 'src/models/conversation.dart';
export 'src/models/message.dart';
export 'src/models/auth_challenge.dart';

export 'src/registration_service.dart';
export 'src/services/contact_api.dart';

export 'src/lib_constants.dart';

export 'package:libmsgr_core/libmsgr_core.dart'
    show UserSession, RefreshSessionResponse, TeamCreationResult, ProfileResult;

export 'src/repositories/repository_factory.dart';

export 'src/redux.dart';

export 'src/platform_support/none.dart'
    if (dart.library.io) 'src/platform_support/io_platform.dart'
    if (dart.library.js_interop) 'src/platform_support/web_platform.dart';

const String libmsgrVersion = '0.1.2';

/*
Here's what that code does:

In an app that can use dart:io (for example, a command-line app), export src/hw_io.dart.
In an app that can use dart:js_interop (a web app), export src/hw_web.dart.
Otherwise, export src/hw_none.dart.

*/
/*

export 'src/hw_none.dart' // Stub implementation
    if (dart.library.io) 'src/hw_io.dart' // dart:io implementation
    if (dart.library.js_interop) 'src/hw_web.dart'; // package:web implementation
*/
