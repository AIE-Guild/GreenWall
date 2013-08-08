
Guild Quickstart for GreenWall
==============================


Contents
--------

1. Definitions
2. Bridging Guild Chat
    - Required Configuration
    - Optional Configuration
    - Example
3. Bridging Officer Chat
    - Configuration
    - Example


Definitions
-----------

Bridging
> Replication of chat events within one guild into the guild, achievement, and officer chat of another guild.

Confederation
> A large WoW guild that is partitioned into smaller guilds to comply with Blizzard's guild size limit.

Container Guild or Co-Guild
> One of the component members of a guild confederation.

Officer
> A member of any of the co-guilds within a confederation who can view officer notes for members.


Bridging Guild Chat
-------------------

All configuration for general guild chat is stored in the "Guild Information" field in the "Guild" window (`J`).  The block of configuration text will be read by GreenWall on the member machines.  The benefit of this approach is that a member can join and use GreenWall without having to perform any special configuration.

All configuration directives use the following format.

    GWx:arglist

The *x* is substituted with a specific opcode and the *arglist* portion is a colon separated list of arguments.

### Required Configuration ###
 
#### Common Channel ####
    
    GWc:channel_name:password

This specifies the custom chat channel to use for all general confederation bridging.

        
#### Peer Co-Guild ####

    GWp:guild_name:tag

You must specify one of these directives for each co-guild in the confederation, **including the co-guild you are configuring**.

Additionally, the "guild_name" must be match the name of the guild exactly and the tag (a short nickname that will be shown if the member enables tagging) must be the same in all of the configurations across the co-guilds.


### Optional Configuration ###

#### Minimum Version ####

    GWv:x.y.z

This disables the GreenWall client if the member is running a version prior to version x.y.z.


### Example ###

    GWc:topSekritChan:pencil
    GWv:1.1.00
    GWp:Darkmoon Clan:DMC
    GWp:Baseball Dandies:BBD
    GWp:Nightlife:NL
        

Bridging Officer Chat
---------------------

### Configuration ###

There is only a single configuration directive for officer chat.  It is stored in the officer note of the guild leader.

    GWa:channel_name:password
        
This specifies the custom chat channel to use for bridging of the officer chat among co-guilds.

By default, officer chat bridging is disabled in the client.  To participate across co-guilds, an officer will need to issue the following command and make sure that officer chat is enabled in one of the chat windows.

    /greenwall ochat on


### Example ###

    GWa:secretSquirrels:rosebud

