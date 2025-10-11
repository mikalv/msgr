# Changes that seems logical after developing for a while


## Shortly upcoming

* Rooms and Conversations will merge to CChannel model
  * Type field will distinct between them
  * Better for Message object to only have one relation


## Long Term

* A GenServer per channel to handle
  * Caching in ETS
  * Writing to Database
    * Cache when/if database is unavailable
  * Keeps a time bucket of messages
  * Talks with Phoenix Channels and REST/GraphQL

* A own OTP app for outgoing stuff
  * Will handle push notifications for iOS / Android
  * Will send SMSes
  * Will send Emails
  * Will trigger and execute webhooks
