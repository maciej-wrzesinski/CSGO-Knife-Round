# Knife Round
Simple SourceMod plugin that allows you to play an additional round before a match with knifes only. The round is being played after "Warmup" or at the start of the match if there is none. Winning team will choose starting side on this match via a menu.


# Changelog
```
1.3
- Code cleanup
- Comments cleanup
- Added delay on weapon strip so the VIPs can't have additional weapons
- Added #define for kento_rankme blockade

1.2.2
- An attempt to fix crashes #2

1.2.1
- An attempt to fix crashes

1.2
- Cvar knifer_alltalk added
- Fixed a bug when player could actually buy something on knife round

1.1
- Cvar knifer_info added
- Cvar knifer_roundtime added
- Cvar knifer_votetime added

1.0
- Plugin release
```

# Cvars
```
knifer_info 0-2 - Sets the messages display type (0 - no messages, 1 - chat, 2 - HUD)
knifer_roundtime 0.5-60.0 - Sets how long the knife round will last
knifer_votetime 5.0-20.0 - Sets how long the vote for team change will last
knifer_alltalk 0-1 - Sets if there will be alltalk enabled on knife round
```
