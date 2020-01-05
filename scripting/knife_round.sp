// thanks for SafeRemoveWeapon stock https://forums.alliedmods.net/archive/index.php/t-288614.html

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <entity>

#pragma semicolon				1
#pragma newdecls				required

public Plugin myinfo =
{
	name = "Knife Round",
	author = "Maciej Wrzesinski",
	description = "Plugin sets up an additional knife round after warmup ends",
	version = "1.3",
	url = "https://github.com/maciej-wrzesinski/"
};

int g_iRoundNumber = 0;

int g_iTeamVotes[4];

ConVar cvInfo;
ConVar cvTime;
ConVar cvVote;
ConVar cvAllowAllTalk;
ConVar cvUnload;
ConVar cvBuyTimeNormal;
ConVar cvBuyTimeImmunity;
ConVar cvTalkDead;
ConVar cvTalkLiving;

int g_iCvarInfo;
float g_fCvarRoundTime;
float g_fCvarVoteTime;
int g_iCvarAllowAllTalk;
char g_cCvarUnloadPlugins[256];
float g_fCvarBuyTimeNormal;
float g_fCvarBuyTimeImmunity;
int g_iCvarTalkDead;
int g_iCvarTalkLiving;

Handle g_hHUD;

public void OnPluginStart()
{
	HookEvent("round_start", RoundStart);
	HookEvent("round_end", RoundEnd);
	HookEvent("player_spawn", PlayerSpawn);
	
	cvInfo = CreateConVar("knifer_info", "2", "How should messages be displayed? (0 - none, 1 - chat, 2 - HUD)", _, true, 0.0, true, 2.0);
	cvTime = CreateConVar("knifer_roundtime", "60.0", "How much time should knife round take? (0.5 to 60.0 minutes)", _, true, 0.5, true, 60.0);
	cvVote = CreateConVar("knifer_votetime", "10.0", "How much time should vote take? (5 to 20 seconds)", _, true, 5.0, true, 20.0);
	cvAllowAllTalk = CreateConVar("knifer_alltalk", "1", "Should there be alltalk enabled while knife round? (1 - enabled, 0 - disabled)", _, true, 0.0, true, 1.0);
	cvUnload = CreateConVar("knifer_unload", "kento_rankme,temporary_plugin1,temporary_plugin2", "Unload these plugins while knife round is being played (separate plugins with commas)", _, false, _, false, _);
	
	cvBuyTimeNormal = FindConVar("mp_buytime");
	cvBuyTimeImmunity = FindConVar("mp_buy_during_immunity");
	cvTalkDead = FindConVar("sv_talk_enemy_dead");
	cvTalkLiving = FindConVar("sv_talk_enemy_living");
	
	ResetGlobalVariables();
	
	g_hHUD = CreateHudSynchronizer();
	
	AutoExecConfig(true, "knife_round");
	LoadTranslations("knife_round.phrases");
}

public void OnConfigsExecuted()
{
	g_iCvarInfo = GetConVarInt(cvInfo);
	g_fCvarRoundTime = GetConVarFloat(cvTime);
	g_fCvarVoteTime = GetConVarFloat(cvVote);
	g_iCvarAllowAllTalk = GetConVarInt(cvAllowAllTalk);
	GetConVarString(cvUnload, g_cCvarUnloadPlugins, sizeof(g_cCvarUnloadPlugins));
	
	
	g_fCvarBuyTimeNormal = GetConVarFloat(cvBuyTimeNormal);
	g_fCvarBuyTimeImmunity = GetConVarFloat(cvBuyTimeImmunity);
	g_iCvarTalkDead = GetConVarInt(cvTalkDead);
	g_iCvarTalkLiving = GetConVarInt(cvTalkLiving);
}

public void OnMapStart()
{
	ResetGlobalVariables();
}

public void OnMapEnd()
{
	ResetGlobalVariables();
}

public Action PlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	if (InKnifeRound())
		StripPlayerWeapons(GetClientOfUserId(GetEventInt(event, "userid")));
}

public Action RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	if (KnifeRoundPlayedAlready())
	{
		return;
	}
	
	if (InvalidConditionsForKnifeRound()) 
	{
		ResetGlobalVariables();
		return;
	}
	
	if (ShouldKnifeRoundStart())
	{
		PrepareCvarsForKnifeRound();
		return;
	}
	
	if(InKnifeRound())
	{
		PluginsOnKnifeRound("unload");
		
		
		CreateTimer(0.5, StripAllPlayersWeapons);
		
		
		SendMessageToAll("Knife_Start");
	}
}

public Action RoundEnd(Handle event, const char[] name, bool dontBroadcast)
{
	//debug, to be deleted
	LogError("--- debug ---");
	LogError("winner %i", GetEventInt(event, "winner"));
	LogError("teamid %i", GetEventInt(event, "teamid"));
	LogError("winnerid %i", GetEventInt(event, "winnerid"));
	
	if (KnifeRoundPlayedAlready())
	{
		return;
	}
	
	if (InvalidConditionsForKnifeRound())
	{
		ResetGlobalVariables();
		return;
	}
	
	if (InKnifeRound())
	{
		PluginsOnKnifeRound("load");
		
		
		g_iRoundNumber++;
		RestoreCvarsAfterKnifeRound();
		
		
		int iWinningTeam = GetEventInt(event, "winner");
		
		
		if (iWinningTeam != CS_TEAM_T && iWinningTeam != CS_TEAM_CT)
		{
			SendMessageToAll("Win_None");
			
			RestartLastTime();
		}
		else
			PrepareVoteMenu(iWinningTeam);
	}
}

public int ShowVotingMenuHandle(Handle hMenu, MenuAction action, int client, int selected_team)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			g_iTeamVotes[GetTeamID(selected_team)]++;
		}
		case MenuAction_End:
		{
			CloseHandle(hMenu);
		}
	}
}

public Action EndVoteMenu(Handle hTimer, Handle hData)
{
	ResetPack(hData);
	int iWinningTeam = ReadPackCell(hData);
	
	
	int iWantedTeam = GetMostVotedTeam();
	
	
	if (iWinningTeam != iWantedTeam)
	{
		SendMessageToAll("Winning_Swap");
		
		RestartLastTime(.swap = true);
	}
	else
	{
		SendMessageToAll("Winning_Stay");
		
		RestartLastTime();
	}
}

public Action StripAllPlayersWeapons(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++)
		StripPlayerWeapons(i);
}

public Action DisplayDelayedHUD(Handle hTimer, Handle hData)
{
	ResetPack(hData);
	
	char cTempText[256];
	ReadPackString(hData, cTempText, sizeof(cTempText));
	
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientValid(i))
		{
			SetHudTextParams(-1.0, -1.0, 4.0, 255, 255, 255, 200, 0, 0.0, 0.0, 0.0);
			ShowSyncHudText(i, g_hHUD, cTempText);
		}
}

stock void PrepareVoteMenu(int iWinningTeam)
{
	SendMessageToAll("Voting_Start");
	
	
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientValid(i) && GetClientTeam(i) == iWinningTeam)
			DisplayVoteMenu(i);
	
	
	Handle hData = CreateDataPack();
	WritePackCell(hData, iWinningTeam);
	CreateTimer(g_fCvarVoteTime, EndVoteMenu, hData);
}

stock void DisplayVoteMenu(int client)
{
	Handle hMenu = CreateMenu(ShowVotingMenuHandle);
	char cTitle[128];
	Format(cTitle, sizeof(cTitle), "%t", "Menu_Title");
	SetMenuTitle(hMenu, cTitle);

	AddMenuItem(hMenu, "TT", "TT");
	AddMenuItem(hMenu, "CT", "CT");

	SetMenuExitButton(hMenu, false);
	SetMenuExitBackButton(hMenu, false);

	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

stock void PrepareCvarsForKnifeRound()
{
	if (g_iCvarAllowAllTalk)
	{
		ServerCommand("sv_talk_enemy_dead 1");
		ServerCommand("sv_talk_enemy_living 1");
	}
	ServerCommand("mp_roundtime %f", g_fCvarRoundTime);
	ServerCommand("mp_roundtime_defuse %f", g_fCvarRoundTime);
	ServerCommand("mp_buytime 0");
	ServerCommand("mp_buy_during_immunity 0");
	ServerCommand("mp_startmoney 0");
	ServerCommand("mp_restartgame 1");
}

stock void RestoreCvarsAfterKnifeRound()
{
	if (g_iCvarAllowAllTalk)
	{
		ServerCommand("sv_talk_enemy_dead %i", g_iCvarTalkDead);
		ServerCommand("sv_talk_enemy_living %i", g_iCvarTalkLiving);
	}
	ServerCommand("mp_roundtime 1.92");
	ServerCommand("mp_roundtime_defuse 1.92");
	ServerCommand("mp_pause_match");
}

stock void RestartLastTime(bool swap = false)
{
	ServerCommand("mp_buytime %f", g_fCvarBuyTimeNormal);
	ServerCommand("mp_buy_during_immunity %f", g_fCvarBuyTimeImmunity);
	ServerCommand("mp_startmoney 800");
	ServerCommand("mp_unpause_match");
	
	if (swap)
		ServerCommand("mp_swapteams");
	else
		ServerCommand("mp_restartgame 1");
}

stock void StripPlayerWeapons(int client)
{
	if (IsClientValid(client) && IsPlayerAlive(client))
	{
		int weapon = -1;
		for (int i = 0; i < 5; i++)
			if ((weapon = GetPlayerWeaponSlot(client, i)) != -1)
				if (IsValidEntity(weapon))
				{
					--i;
					SafeRemoveWeapon(client, weapon);
				}
		
		GivePlayerItem(client, "weapon_knife");
		ClientCommand(client, "slot3");
	}
}

stock bool SafeRemoveWeapon(int client, int weapon)
{
	if (!IsValidEntity(weapon) || !IsValidEdict(weapon))
		return false;
	
	if (!HasEntProp(weapon, Prop_Send, "m_hOwnerEntity"))
		return false;
	
	int owner_entity = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
	
	if (owner_entity != client)
		SetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity", client);
	
	CS_DropWeapon(client, weapon, false);
	
	if (HasEntProp(weapon, Prop_Send, "m_hWeaponWorldModel"))
	{
		int world_entity = GetEntPropEnt(weapon, Prop_Send, "m_hWeaponWorldModel");
		
		if (IsValidEdict(world_entity) && IsValidEntity(world_entity) && !AcceptEntityInput(world_entity, "Kill"))
			return false;
	}
	
	if (!AcceptEntityInput(weapon, "Kill"))
		return false;
	
	return true;
}

stock bool IsClientValid(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && !IsClientSourceTV(client));
}

stock int GetClientCountInTeams()
{
	int sum = 0;
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientValid(i) && IsClientAuthorized(i) && (GetClientTeam(i) == CS_TEAM_T || GetClientTeam(i) == CS_TEAM_CT))
			++sum;
	
	return sum;
}

stock void SendMessageToAll(char[] phrase)
{
	char text[256];
	Format(text, sizeof(text), "%t", phrase);
	
	switch (g_iCvarInfo)
	{
		case 1:
		{
			PrintToChatAll(text);
		}
		case 2:
		{
			Handle hData = CreateDataPack();
			WritePackString(hData, text);
			CreateTimer(2.0, DisplayDelayedHUD, hData);
		}
	}
}

stock void ResetGlobalVariables()
{
	g_iRoundNumber = 0;
}

stock bool InKnifeRound()
{
	return g_iRoundNumber == 2;
}

stock bool KnifeRoundPlayedAlready()
{
	return g_iRoundNumber > 2;
}

stock bool ShouldKnifeRoundStart()
{
	return (++g_iRoundNumber == 1);
}

stock bool InvalidConditionsForKnifeRound()
{
	return GetClientCountInTeams() < 1 || GameRules_GetProp("m_bWarmupPeriod");
}

stock int GetTeamID(int selected_team)
{
	return selected_team + 2;
}

stock int GetMostVotedTeam()
{
	return g_iTeamVotes[CS_TEAM_T] >= g_iTeamVotes[CS_TEAM_CT] ? CS_TEAM_T : CS_TEAM_CT;
}

stock void PluginsOnKnifeRound(char[] command)
{
	char plugins[256];
	Format(plugins, sizeof(plugins), g_cCvarUnloadPlugins);
	TrimString(plugins);
	StripQuotes(plugins);
	StrCat(plugins, sizeof(plugins), ",");
	
	while (StrContains(plugins, ",")) 
	{
		char found_plugin[128];
		SplitString(plugins, ",", found_plugin, sizeof(found_plugin));
		
		ServerCommand("sm plugins %s %s", command, found_plugin);
		
		ReplaceStringEx(plugins, sizeof(plugins), found_plugin, "");
		ReplaceStringEx(plugins, sizeof(plugins), ",", "");
		
		//debug, to be deleted
		LogError("--- debug ---");
		LogError("sm plugins %s %s", command, found_plugin);
		LogError("plugins string after %s", plugins);
	}
}
