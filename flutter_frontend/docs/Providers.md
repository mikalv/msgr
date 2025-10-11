# Providers

## Short intro

Read https://docs.flutter.dev/data-and-backend/state-mgmt/simple

## Our usage of providers

For now we use a MultiProvider in the top of the application which handles for example if the user
is logged in or not. Later I would like to imagine that we would use more specialized providers for
some sub-screens, like the usage of a MessageProvider when the user is in a ConversationScreen, or
a ConversationProvider when listing all his/her conversations.
