# User Documentation for GreenWall #


## Frequently Asked Questions ##

- What does GreenWall do?

This add-on replicates guild chat and achievement spam between multiple guilds.
 
The add-on's functionality is very close to LemonKing's Cross Guild Chat, but the management interface (or lack of one in GreenWall's case) is very different.
 
- Do I need to be a member of Alea Iacta Est to use it?

No, it was written to be guild-agnostic.  While it addresses a specific need that we had, it was designed to work for any guild that's larger than the limit.


- If I'm a member of Alea Iacta Est, do I need to run it?

No, you don't. But guild chat will be very, very frustrating for you if you don't since you will only see about 1% of the complete conversations.


- How do I get it?

The latest version is available at the following locations.

- [GitHub](https://github.com/AIE-Guild/GreenWall/releases)
- [Curse](http://www.curse.com/addons/wow/greenwall)

It is also mirrored in WoWMatrix, but we make no guarantees about how frequently WoWMatrix updates or the integrity of the files that it provides.

 - [WoWMatrix](http://www.wowmatrix.com/)

You can also check out the latest version from the GitHub repository, if you are technically inclined and foolhardy enough to run pre-release code.

[GitHub](https://github.com/AIE-Guild/GreenWall)


## Prerequisites ##


- You must have fewer than 10 custom channels configured in-game.  You can see a listing of the custom channels by opening the "Social" window (bound to the "O" key) and selecting the "Chat" tab.
- You must be able to edit the Guild Information tab to configure GreenWall for the co-guild members.


## Installation ##


1. Exit "World of Warcraft" completely

2. Download the mod you want to install
 -   Make a folder on your desktop called "My Mods"
 -   Save the .zip file to this folder.
 -   If, when you try to download the file, it automatically "opens" it... you need to RIGHT click on the link and "save as..." or "Save Target As". 

3. Extract the file - commonly known as 'unzipping'
  	- Windows
        - Windows XP has a built in ZIP extractor. Double click on the file to open it, inside should be the file or folders needed. Copy these outside to the "My Mods" folder.
        - WinZip: You MUST make sure the option to "Use Folder Names" is CHECKED or it will just extract the files and not make the proper folders how the Authors designed 
    - Mac OS X
        - StuffitExpander: Double click the archive to extract it to a folder in the current directory. 
    
4. Verify your WoW Installation Path. That is where you are running WoW from and THAT is where you need to install your mods.
    
5. Move to the Addon folder
    - Open your World of Warcraft folder. The default is `C:\Program Files (x86)\World of Warcraft\`.
    - Go into the "Interface" folder.
    - Go into the "AddOns" folder.
    - In a new window, open the "My Mods" folder.
    - The "My Mods" folder should have the "GreenWall" folder in it.
    - Move the "GreenWall" folder into the "AddOns" folder. 

6. Start World of Warcraft.

7. Make sure AddOns are installed.
    - Log in.
    - At the Character Select screen, look in lower left corner for the "addons" button.
        - If button is there: make sure all the mods you installed are listed and make sure "load out of date addons" is checked.
        - If the button is NOT there: means you did not install the addons properly. 


## Configuration ##

GreenWall was designed to minimize the amount of configuration necessary by most members.  If your officers have set up the guild configuration correctly, you don't need to do anything to particiapte in the conversation between co-guilds.

However, there are a few options you may want to consider.  

To access the user configuration screen:

1. Open the **Game Menu** by hitting the `Esc` key.
2. Click on the **Interface** button.
3. Select the **AddOns** tab.
4. Click on **GreenWall** in the sidebar.

You will be able to enable or disable the following options.

**Show Co-Guild Tags**
> Show co-guild identifier in messages. 
> Default: on

**Show Co-Guild Achievement Announcements**
> Show achievements from other co-guilds. 
> Default: off

**Show Co-Guild Roster Announcements**
> Show guild join and leave messages from other co-guilds. 
> Default: on 

**Show Co-Guild Rank Announcements**
> Show promotion and demotion messages from other co-guilds. 
> Default: off 

**Bridge Officer Chat**
> Show bridge officer chat between the co-guilds. This only works for members who have privileges to view officer notes.
> Default: off 

## Command Line Interface ##

All commands must be prefixed with `/greenwall` or `/gw`.

As an example, the configuration option for co-guild tagging is `tag`. To turn it on, you would enter one of the following commands. In the command descriptions, optional arguments are in square brackets and alternatives are separated by the pipe character.

    /greenwall tag on
    /gw tag on

To view the current configuration, you would enter one of the following.

    /greenwall tag
    /gw tag

### Output Options ###

tag [ on | off ]
> Show co-guild identifier in messages. 
> Default: on

achievements [ on | off ]
> Show achievements from other co-guilds. 
> Default: off

roster [ on | off ]
> Show guild join and leave messages from other co-guilds. 
> Default: on 

rank [ on | off ]
> Show promotion and demotion messages from other co-guilds. 
> Default: off 


### Officer Options ###

ochat [ on | off ]
> Show bridge officer chat between the co-guilds. This only works for members who have privileges to view officer notes.
> Default: off 


### Debugging Options ###

debug level
> Enable debugging at the specified level. The level argument is an integer from 0 to 5. Setting the level to 0 disables debugging. 
> Default: 0 

log [ on | off ]
> Capture debugging output in the `SavedVariables` file. 
> Default: off 

logsize length
> Keep length number log entries in the `SavedVariables` file. 
> Default: 2048 

verbose [ on | off ]
> Display the debugging output in your chat window. Only do this if you are masochistic. 
> Default: off 


### Operation ###

help
> Print a summary of available commands. 

stats
> Prints a summary of the connection statistics for the common communication channel(s). 

status
> Prints a summary of the GreenWall communication parameters and state variables. 

reload
> Issues a request to all members of the confederated guilds to reload the configuration. 

refresh
> Checks and corrects the communications status for the common channel(s). 

version
> Print the installed version of GreenWall. 

