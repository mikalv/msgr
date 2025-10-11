# Introduction

## Main application

Everything related to UI and Frontend is located here. For communication with server, local storage etc
you'll have to lookup Libmsgr.

lib/
  config/                 - Configuration, routing, navigation, constants
  desktop/                - Code spesific to the desktop client
  models/                 - Look at Libmsgr instead, this isn't used now
  redux/
    authentication/       - Redux classes, functions etc for authentication/team and connectivity
    message/              - Redux classes, functions for messages/conversations/rooms
    navigation/           - For navigation
    profile/              - For profile handling, own and others.
    push/                 - Will be for notifications both local and via push
    ui/                   - UI Events, will for example be for desktop when resizing window
  services/
  ui/
    pages/                - Pages are usually for the authenticated user
    screens/              - Has fullscreen pages, like login, registration, create team, select team
    widgets/              - Single widgets
    

## Libmsgr

