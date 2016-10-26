# Change Log

This project uses [Semantic Versioning](http://semver.org/).

## [1.8.1] -- 2016-10-25
### Fixed
- Corrected configuration whitespace grooming.

### Changed
- Updated TOC for WoW 7.1.

## [1.8.0] -- 2016-09-20
### Fixed
- Added whitespace trimming to configuration parser.

### Changed
- Compatibility messages are now raised as debugging output.

## [1.7.3] -- 2016-08-03
### Fixed
- Corrected global name parsing to account for UTF-8.
- Updated API documentation.

## [1.7.2] -- 2016-07-20
### Fixed
- Workaround for delayed bridge channel join caused by missing 
  CHAT_MSG_CHANNEL_NOTICE events.

## [1.7.1] -- 2016-07-20
### Changed
- Updated TOC for WoW 7.0.3.

## [1.7.0] -- 2016-01-01
### Fixed
- Improved message validation during adaptation layer decoding.
- Fixed message handling logic.

### Changed
- Updated color of addon messages in chat.

### Added
- Confederation bridging API for third-party add-ons.
- Automatic Prat-3.0 compatibility mode.

### Removed
- Removed version number from options screen title.

## [1.6.6] -- 2015-12-16
### Fixed
- A check is now done for officer status before sending a gratuitous officer
  announcement.
- Added officer note data validation before parsing.

### Added
- Automatic ElvUI compatibility mode. Thank you, Blazeflack.
- Added Markdown change log.
- Added channel-specific hold downs for join failures.

## [1.6.5] -- 2015-06-24
### Changed
- Updated TOC for WoW 6.2.

## [1.6.4] -- 2015-03-07
### Changed
- Refactored the user option validation.
- Modified the GwHoldDown object.  Renamed `GwHoldDown:set()` to
 `GwHoldDown:start()` and created a new 'GwHoldDown:set()' mutator to
  change the interval.
- Moved the Semantic Versioning parser to a LibStub library.

### Added
- Added a user option (joindelay) to control the channel join hold-down.

## [1.6.3] -- 2015-03-04
### Changed
- Restored original channel hold-down timer value of 30 seconds.

## [1.6.2] -- 2015-03-01
### Changed
- Removed lazy sweeper case in the event loop and replaced it with a callback
for handling hold-down expiry.
- Reduced channel hold-down to 10 seconds.

## [1.6.1] -- 2015-02-28
### Fixed
- Added conditional to check achievements flag on receipt of achievement spam.

### Added
- Added guild ID to debugging output on message receipt.

## [1.6.0] -- 2015-02-24
### Changed
- Comprehensive refactor to allow new features in 2.0.
- Refactored configuration parser.
- Split GreenWall_Core.lua into multiple files.
- Removed excess semicolons ... Lua is not Perl.

### Added
- Added GwConfig object to contain configuration.
- Added GwChannel objects for channel management, implementing transport and 
  adaptation layers for communication.
- Added GwHoldDown and GwHoldDownCache objects.
- Added LibStub libraries for SHA256, Salsa20, CRC16-CCITT, and Base64.

## [1.5.4] -- 2014-12-12
### Fixed
- Corrected comparisons of character names to account for capitalization
  normalization in the API.

### Changed
- Updated luadoc.

## [1.5.3] -- 2014-11-11
### Fixed
- Added comember cache updates for channel join/leave events. This stops
flapping roster announcements for characters in peer co-guilds.

## [1.5.2] -- 2014-10-31
### Fixed
- Fixed the General chat delay lockout.
- Improved the tests for officer status.

## [1.5.1] -- 2014-10-15
### Fixed
- Fixed regular expression for realm name in GwGlobalName.

## [1.5.0] -- 2015-10-14
### Fixed
- Updated for fully qualified names.

### Changed
- Switched to MIT license.
- Minor changes to debug messages.

### Added
- Added support for guilds on connected realms.

## [1.4.1] -- 2014-08-10
### Fixed
- Corrected the processing of the reload request.

## [1.4.0] -- 2014-03-22
### Changed
- Update documentation for Interface Options.
- Cleaned up debugging levels.

### Added
- Added Interface Options panel for GreenWall options.

## [1.3.6] -- 2014-02-18
### Fixed
- Fixed sender identification under WoW 5.4.7.

### Added
- Added realm name to gwPlayerName.

## [1.3.5] -- 2014-0120
### Added
- Added missing roster notification functionality.

## [1.3.4] -- 2013-11-17
### Changed
- Changed officer note format and updated parsing.

## [1.3.3] -- 2013-09-10
### Changed
- Updated TOC for WoW 5.4.0.

## [1.3.2] -- 2013-08-07
### Fixed
- Fixed message integrity checking for duplicated messages.
- Fixed messages generated on guild join, leave, or kick.
- Corrected formatting of documentation.

## [1.3.1] -- 2013-08-06
### Changed
- Project moved to [GitHub](https://github.com/AIE-Guild/GreenWall).
- All text documentation has been converted to Markdown and HTML.
- All URLs have been updated in the TOC.

### Added
- Guild configuration format documentation has been added.

## [1.3.0] -- 2013-06-09
### Fixed
- Fixed handling of a kick from a guild.
- Fixed variable names for input validation in GwStringHash().

### Changed
- Simplified the unpacking of inter-guild messages.

### Added
- Added support for a newer, compact configuration format.

## [1.2.7] -- 2013-02-27
### Changed
- Updated TOC for WoW 5.2.0.

## [1.2.6] -- 2012-12-04
### Changed
- Updated TOC for WoW 5.1.0.

## [1.2.5] -- 2012-09-01
### Fixed
- Localized _ to avoid the taint issues with glyphs in 5.0.4.

## [1.2.4] -- 2012-08-29
### Changed
- Updated TOC for WoW 5.0.4.

## [1.2.3] -- 2012-08-25
### Changed
- Replaced the 32-bit string hash used to obfuscate channel names in the
  debugging output with a standard CRC-16-CCITT implementation to avoid
  overflow issues with `string.format()` in MoP.
- Made some changes to the debugging code to improve visibility into message
  passing and replication.

### Added
- Added extra debugging information for current guild information.
- Added value checking for missing coguild ID in GwSendConfederationMsg().

## [1.2.2] -- 2012-11-12
### Fixed
- Fixed officer chat bridging for the guild leader.

## [1.2.1] -- 2011-11-29
### Changed
- Updated TOC for WoW version 4.3.

### Added
- Added link to LemonKing's add-on in the documentation.
- Documented prequisites.

## [1.2.0] -- 2011-11-26
### Fixed
- Fixed unnecessary channel resets due to configuration reload.
- Fixed behavior during UI reload.
- Corrected join/leave handling.
- Corrected case statement for handling chat events.

### Changed
- Switched to [Semantic Versioning](http://semver.org/).
- Separated guild info parsing from the `GwRefreshComms()` function.
- Factored out some ugly flags.
- Cleaned up CLI configuration.
- Cleaned up debugging output.
- Cleaned up guild info handling.
- Parameterized all channel control functions.
- Masked all channel names and passwords in debugging output.

### Added
- Added officer chat support.
- Added message queuing.
- Added a GwIsOfficer() check to the officer chat configuration phase to
  avoid pointless work.
- Added broadcast message type.
- Added broadcasts of guild join and leave events.
- Added broadcasts of promote and demote messages.
- Added hold-down for reconfiguration.
- Added broadcast receiver code.
- Added string hash to determine changes in text fields.
- Added error checking for officer note parsing failure.
- Added README.txt and GUILD_QUICKSTART.txt.

### Removed
- Removed channel protection code.
- Removed SHA1 library.

## [1.1.07] -- 2011-06-28
### Changed
- Updated TOC for WoW version 4.2.

## [1.1.06] -- 2011-03-21
### Changed
- Babel now disabled by default.

## [1.1.05] -- 2011-03-21
### Changed
- Moved scan of chat windows to chat message event handlers.
- Sorted clauses in the main event switch for legibility.

### Added
- Added `GwReplicateMessage()` function.
- Added RegisterAddonMessagePrefix call for 4.1 changes.
- Added Babel.

## [1.1.04] -- 2011-01-15
### Changed
- Minor updates for Curse packager.
- Cleaned up status display code.

### Added
- Added BSD-derived license.

## [1.1.03] -- 2011-01-14
### Changed
- Moved `GuildRoster` call to PLAYER_LOGIN handler.
- Limited conditions under which reinitialization occurred on
  PLAYER_GUILD_UPDATE.
- Renamed `gwPlayerGuild` to `gwGuildName`.
- Cleaned up prep/refresh/join flow for connecting to the common channel.

### Added
- Added a delay mechanism to prevent hijacking of general channel.
- Added connection statistics gathering.
- Added LuaDoc data for functions and procedures.

## [1.1.02] -- 2010-12-11
### Fixed
- Fixed missing assignment of channel number on join.

### Changed
- Redacted sensitive data in the status output.

### Added
- Added hold-downs for join and configuration messages.
- Added a configuration flag to enable replication of achievement messages.
- Added frame identifier to Tx debug messages.
- Added help text with command listing.

### Removed
- Removed tabs from the source code!
- Removed event registration for channel leave events.
- Removed squelch message on reload flood.

## [1.1.01] -- 2010-12-06
### Fixed
- Fixed status output when no channel has been configured.

### Added
- Added co-guild tagging.

## [1.1.00] -- 2010-12-05
### Added
- Added announcement flag check for logout announcements.

### Removed
- Removed unused moderation release code.

## [1.0.18] -- 2010-12-04
### Added
- Added options line to configuration.

## [1.0.17] -- 2010-12-04
### Fixed
- Fixed SavedVariables processing.

## [1.0.16] -- 2010-12-04
### Fixed
- Removed moderator handling and switched to better handling of owner status.

## [1.0.15] -- 2010-12-03
### Fixed
- Removed faulty `tContains()` for `gwPeerTable` checks to stop
  prolific kicking.

## [1.0.14] -- 2010-12-03
### Fixed
- Fixed missing argument to `GetGuildInfo()`.

## [1.0.13] -- 2010-12-03
### Changed
- Updated guild change/update handling.

## [1.0.12] -- 2010-12-03
### Fixed
- Fixed /who and channel join event processing.

## [1.0.11] -- 2010-12-03
### Fixed
- Limited handling of channel owner/moderator changes to the common channel.

### Changed
- Simplified and improved `GwIsConnected()`.

### Added
- Added a nil result check for the system message regex.
- Added gratuitous container officer response on channel join.
- Suspend confederation messages until container ID is known.
- Limit scope of the channel debugging.

### Removed
- Removed proactive channel leave before a join.

## [1.0.10] -- 2010-11-22
### Changed
- Rewrote guild lookups.

### Added
- Added extra slash commands.

## [1.0.09] -- 2010-11-21
### Fixed
- Missing negation in channel defense code.

## [1.0.08] -- 2010-11-21
### Fixed
- Corrected guild join handling.

### Added
- Added more debugging code.

### Removed
- Removed channel bans.

## [1.0.07] -- 2010-11-17
### Fixed
- Typos in variable names.

## [1.0.06] -- 2010-11-13
### Added
- Added online/offline notices.

## [1.0.05] -- 2010-11-13
### Fixed
- Fixed the placement and use of `GwLeaveChannel()`.

### Changed
- Changed container messaging system to generalize the request message type.

## [1.0.04] -- 2010-11-13
### Fixed
- Fixed container recognition in configuration processing.

### Added
- Added debugging output to slash command handling.

## [1.0.03] -- 2010-11-12
### Changed
- Changed configuration to support common configurations across co-guilds.
- Refactored configuration parsing.
- Cleaned up slash command handling.

### Added
- Added variable field to the saved variables.

## [1.0.02] -- 2010-11-12
### Added
- Added container IDs to channel messages to avoid duplicates within the
  same co-guild.

## [1.0.01] -- 2010-11-12
### Added
- Brought back GUILD_ROSTER_UPDATE to get around the guild info loading delay.

## [1.0.00] -- 2010-11-11
### Changed
- Cleaned up debugging statements.

### Added
- Added moderator/owner status handling.
- Added kick/ban handling for interlopers.
- Added channel leave if player leaves the guild.
- Finished defensive ownership/moderation handling.
- Added handling for guild achievements.
- Added forced reload.

### Removed
-Removed GUILD_ROSTER_UPDATE event handling.

## [0.9.02] -- 2010-11-06
### Fixed
- Fixed parsing of peer entries in configuration.

### Changed
- Expanded debugging code.

### Removed
- Removed slash command code, left stub.

## [0.9.01] -- 2010-11-06
### Changed
- Abstracted several functions.

### Added
- Added peer configuration entries.

## 0.9.00 -- 2010-11-01
Initial commit.

[1.8.0]: https://github.com/AIE-Guild/GreenWall/compare/v1.7.3...v1.8.0
[1.7.3]: https://github.com/AIE-Guild/GreenWall/compare/v1.7.2...v1.7.3
[1.7.2]: https://github.com/AIE-Guild/GreenWall/compare/v1.7.1...v1.7.2
[1.7.1]: https://github.com/AIE-Guild/GreenWall/compare/v1.7.0...v1.7.1
[1.7.0]: https://github.com/AIE-Guild/GreenWall/compare/v1.6.6...v1.7.0
[1.6.6]: https://github.com/AIE-Guild/GreenWall/compare/v1.6.5...v1.6.6
[1.6.5]: https://github.com/AIE-Guild/GreenWall/compare/v1.6.4...v1.6.5
[1.6.4]: https://github.com/AIE-Guild/GreenWall/compare/v1.6.3...v1.6.4
[1.6.3]: https://github.com/AIE-Guild/GreenWall/compare/v1.6.2...v1.6.3
[1.6.2]: https://github.com/AIE-Guild/GreenWall/compare/v1.6.1...v1.6.2
[1.6.1]: https://github.com/AIE-Guild/GreenWall/compare/v1.6.0...v1.6.1
[1.6.0]: https://github.com/AIE-Guild/GreenWall/compare/v1.5.4...v1.6.0
[1.5.4]: https://github.com/AIE-Guild/GreenWall/compare/v1.5.3...v1.5.4
[1.5.3]: https://github.com/AIE-Guild/GreenWall/compare/v1.5.2...v1.5.3
[1.5.2]: https://github.com/AIE-Guild/GreenWall/compare/v1.5.1...v1.5.2
[1.5.1]: https://github.com/AIE-Guild/GreenWall/compare/v1.5.0...v1.5.1
[1.5.0]: https://github.com/AIE-Guild/GreenWall/compare/v1.4.1...v1.5.0
[1.4.1]: https://github.com/AIE-Guild/GreenWall/compare/v1.4.0...v1.4.1
[1.4.0]: https://github.com/AIE-Guild/GreenWall/compare/v1.3.6...v1.4.0
[1.3.6]: https://github.com/AIE-Guild/GreenWall/compare/v1.3.5...v1.3.6
[1.3.5]: https://github.com/AIE-Guild/GreenWall/compare/v1.3.4...v1.3.5
[1.3.4]: https://github.com/AIE-Guild/GreenWall/compare/v1.3.3...v1.3.4
[1.3.3]: https://github.com/AIE-Guild/GreenWall/compare/v1.3.2...v1.3.3
[1.3.2]: https://github.com/AIE-Guild/GreenWall/compare/v1.3.1...v1.3.2
[1.3.1]: https://github.com/AIE-Guild/GreenWall/compare/release-1.3.0...v1.3.1
[1.3.0]: https://github.com/AIE-Guild/GreenWall/compare/release-1.2.7...release-1.3.0
[1.2.7]: https://github.com/AIE-Guild/GreenWall/compare/release-1.2.6...release-1.2.7
[1.2.6]: https://github.com/AIE-Guild/GreenWall/compare/release-1.2.5...release-1.2.6
[1.2.5]: https://github.com/AIE-Guild/GreenWall/compare/release-1.2.4...release-1.2.5
[1.2.4]: https://github.com/AIE-Guild/GreenWall/compare/release-1.2.3...release-1.2.4
[1.2.3]: https://github.com/AIE-Guild/GreenWall/compare/release-1.2.2...release-1.2.3
[1.2.2]: https://github.com/AIE-Guild/GreenWall/compare/release-1.2.1...release-1.2.2
[1.2.1]: https://github.com/AIE-Guild/GreenWall/compare/release-1.2.0...release-1.2.1
[1.2.0]: https://github.com/AIE-Guild/GreenWall/compare/v1.1.07...release-1.2.0
[1.1.07]: https://github.com/AIE-Guild/GreenWall/compare/v1.1.06...v1.1.07
[1.1.06]: https://github.com/AIE-Guild/GreenWall/compare/v1.1.05...v1.1.06
[1.1.05]: https://github.com/AIE-Guild/GreenWall/compare/v1.1.04...v1.1.05
[1.1.04]: https://github.com/AIE-Guild/GreenWall/compare/v1.1.03...v1.1.04
[1.1.03]: https://github.com/AIE-Guild/GreenWall/compare/v1.1.02...v1.1.03
[1.1.02]: https://github.com/AIE-Guild/GreenWall/compare/v1.1.01...v1.1.02
[1.1.01]: https://github.com/AIE-Guild/GreenWall/compare/v1.1.00...v1.1.01
[1.1.00]: https://github.com/AIE-Guild/GreenWall/compare/v1.0.18...v1.1.00
[1.0.18]: https://github.com/AIE-Guild/GreenWall/compare/v1.0.17...v1.0.18
[1.0.17]: https://github.com/AIE-Guild/GreenWall/compare/v1.0.16...v1.0.17
[1.0.16]: https://github.com/AIE-Guild/GreenWall/compare/v1.0.15...v1.0.16
[1.0.15]: https://github.com/AIE-Guild/GreenWall/compare/v1.0.14...v1.0.15
[1.0.14]: https://github.com/AIE-Guild/GreenWall/compare/v1.0.13...v1.0.14
[1.0.13]: https://github.com/AIE-Guild/GreenWall/compare/v1.0.12...v1.0.13
[1.0.12]: https://github.com/AIE-Guild/GreenWall/compare/v1.0.11...v1.0.12
[1.0.11]: https://github.com/AIE-Guild/GreenWall/compare/v1.0.10...v1.0.11
[1.0.10]: https://github.com/AIE-Guild/GreenWall/compare/v1.0.09...v1.0.10
[1.0.09]: https://github.com/AIE-Guild/GreenWall/compare/v1.0.08...v1.0.09
[1.0.08]: https://github.com/AIE-Guild/GreenWall/compare/v1.0.07...v1.0.08
[1.0.07]: https://github.com/AIE-Guild/GreenWall/compare/v1.0.06...v1.0.07
[1.0.06]: https://github.com/AIE-Guild/GreenWall/compare/v1.0.05...v1.0.06
[1.0.05]: https://github.com/AIE-Guild/GreenWall/compare/v1.0.04...v1.0.05
[1.0.04]: https://github.com/AIE-Guild/GreenWall/compare/v1.0.03...v1.0.04
[1.0.03]: https://github.com/AIE-Guild/GreenWall/compare/v1.0.02...v1.0.03
[1.0.02]: https://github.com/AIE-Guild/GreenWall/compare/v1.0.01...v1.0.02
[1.0.01]: https://github.com/AIE-Guild/GreenWall/compare/v1.0.00...v1.0.01
[1.0.00]: https://github.com/AIE-Guild/GreenWall/compare/v0.9.02...v1.0.00
[0.9.02]: https://github.com/AIE-Guild/GreenWall/compare/v0.9.01...v0.9.02
[0.9.01]: https://github.com/AIE-Guild/GreenWall/compare/v0.9.00...v0.9.01
