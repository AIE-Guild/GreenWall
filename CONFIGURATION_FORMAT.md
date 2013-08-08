
Guild Configuration Format
==========================


This page documents the ugly details of GreenWall's configuration.  Unless you have a large confederation and need to minimize the size of your configuration or you are trying to do something fancy, you probably want to read the Guild Quickstart guide (GUILD_QUICKSTART.md) instead.

All configuration for general guild chat is stored in the "Guild Information" field in the "Guild" window (`J`).  The block of configuration text will be read by GreenWall on the member machines.  The benefit of this approach is that a member can join and use GreenWall without having to perform any special configuration.


Directive Format
----------------

All configuration directives use the following format.

    GWx:arglist

Versions older than 1.3 use the following format.  The older format is still supported after 1.3 for backwards compatibility.

    GW:x:arglist

The `x` is substituted with a specific opcode and the `arglist` portion is a 
colon separated list of arguments.


Required Directives
-------------------

### Common Channel ###
  
This specifies the custom chat channel to use for all general confederation bridging. 

Op Code: c

Arguments: 
- Channel Name
- Channel Password

Example:

    GWc:topSekrit:E88l2S8qXq5m


### Peer Co-Guild ###

You must specify one of these directives for each co-guild in the confederation, **including the co-guild you are configuring**.

Op Code: p

Arguments:
- Guild Name: The full name of the co-guild.  This must match the name of the guild exactly, with the exception of *substitution variables*.
- Guild Tag (optional): A terse, unique identifier that will be shown if the member enables tagging.  If this argument is not given the full co-guild name will be used.

**The peer co-guild directives must be identical between all co-guild configurations after all variable substitution has been applied.**

Example:

    GWp:Alea Iacta Est Fortuna:fortuna


Optional Directives
-------------------

### Officer Channel ###
  
This specifies the custom chat channel to use for officer chat confederation bridging. 

Op Code: a

Arguments:
- Channel Name
- Channel Password

Example:

    GWa:secretSquirrels:y7Gl5058j68f


### Substitution Variable ###

This specifies a variable that will can be used in the *peer co-guild* directives to reduce the size of the configuration.

Op Code: s

Arguments:
- Value: A string that occurrences of the variable will be substituted with.
- Name: A single-character, case-sensitive name for the variable.

If specified, any occurrence of a `$` character followed by the variable name will be substituted with the configured value.  Since the `$` character is not allowed in the name of a guild, there is no escape sequence for the character.

**The parser is single-pass, so the variable definition must precede the use of the variable in the configuration.**

Example:

    GWs:Alea Iacta Est:n
    GWp:$n Verendus:verendus
    GWp:$n Salus:salus


### Minimum Version ###

The minimum version of GreenWall that the guild management wishes to allow members to use.

Op Code: *v*

Arguments:
- Version: The minimum version allowed.

Example:

    GWv:1.3.0


### Channel Defense ###

This option specifies the type of channel defense hat should be employed.  

**This feature is currently unimplemented.**

Op Code: d

Arguments:
- Mechanism:
    - k = Kick unauthorized participants.
    - kb = Kick and ban unauthorized participants.

If left unspecified, no channel defense will be employed.

Example:

    GWd:k


Deprecated Directives
---------------------

### Option ###

This is the old format for specifying configuration options.

Op Code: o

Arguments:
- Key/Value Pair: A key and value in the format `key=value`.  

The value associated with the key  `mv` will be interpreted as the *minimum version* and value associated with the key `cd` will be interpreted as the *channel defense* setting.

