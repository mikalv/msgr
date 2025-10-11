import 'dart:convert';
import 'dart:io';

import 'package:cli_menu/cli_menu.dart';
import 'package:cli_menu/src/result.dart';
import 'package:cli_util/cli_logging.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:libmsgr/libmsgr.dart';
import 'package:yaml_writer/yaml_writer.dart';

final envVarMap = Platform.environment;

class AppStateTon {
  static final AppStateTon _singleton = AppStateTon._internal();
  bool shouldRunCli = true;
  String? token;

  factory AppStateTon() {
    return _singleton;
  }

  AppStateTon._internal();
}

String? readInput(String prompt) {
  print(prompt);
  var line = stdin.readLineSync(encoding: utf8);
  return line?.trim();
}

paintMenu(List<String> listen) {
  final menu = Menu(listen);
  final result = menu.choose();
  return result;
}

Future<String?> writeYamlConfig() async {
  var path = envVarMap['HOME'];
  if (await FileSystemEntity.isDirectory(path!)) {
    final config = {
      'cli': {'token': AppStateTon().token!}
    };
    final yamlWriter = YAMLWriter();
    var yamlDoc = yamlWriter.write(config);
    final configFile = File('$path/.msgr-cli.yaml');
    await configFile.writeAsString(yamlDoc, mode: FileMode.append);
    return yamlDoc;
  }
}

Future<void> whatToDo(logger) async {
  const newUserStr = 'Create new user';
  const updateTokenStr = 'Update token';
  const quitStr = 'Quit';
  const selectTeamStr = 'Select team';
  const listRoomsStr = 'List rooms';
  const writeMessageStr = 'Write message';
  const saveConfigStr = 'Save Config to file';
  logger.stdout("What do you wanna do?");
  final MenuResult<String> what = paintMenu([
    newUserStr,
    updateTokenStr,
    selectTeamStr,
    listRoomsStr,
    writeMessageStr,
    saveConfigStr,
    quitStr,
  ]);
  switch (what.toString()) {
    case newUserStr:
      logger.stdout('Whats your email or msisdn?');
      break;
    case updateTokenStr:
      break;
    case selectTeamStr:
      break;
    case listRoomsStr:
      break;
    case writeMessageStr:
      break;
    case saveConfigStr:
      final data = await writeYamlConfig();
      logger.stdout(data);
      break;
    case quitStr:
      logger.stdout('Bye!');
      AppStateTon().shouldRunCli = false;
      break;
  }
}

void mainLoop(logger) async {
  do {
    logger.stdout('AppStateTon().shouldRunCli: ${AppStateTon().shouldRunCli}');
    await whatToDo(logger);
  } while (AppStateTon().shouldRunCli);
}

void main(List<String> args) {
  print(Platform.version);
  print('LOGNAME = ${envVarMap['LOGNAME']}');

  var verbose = args.contains('-v');
  var logger = verbose ? Logger.verbose() : Logger.standard();

  //print('PATH = ${envVarMap['PATH']}');
  var token = readInput("What's your token?");
  logger.trace("Token was: $token");
  AppStateTon().token = token;
  Map<String, dynamic> decodedToken = JwtDecoder.decode(token!);
  logger.stdout('Decoded: $decodedToken');
  DateTime expirationDate = JwtDecoder.getExpirationDate(token);
  Duration tokenTime = JwtDecoder.getTokenTime(token);
  logger.stdout(
      'Token will expire at: $expirationDate (token is ${tokenTime.inDays} days old)');
  mainLoop(logger);
}
