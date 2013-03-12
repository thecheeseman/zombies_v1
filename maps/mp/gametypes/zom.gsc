///////////////////////////////////////////////////////////////////////////////
//
/*
	Zombies!
	by Cheese
	Made for 1.1 and CoDaM
*/
//
///////////////////////////////////////////////////////////////////////////////

// TDM based
main()
{
	level.callbackStartGameType = ::Callback_StartGameType;
	level.callbackPlayerConnect = ::Callback_PlayerConnect;
	level.callbackPlayerDisconnect = ::Callback_PlayerDisconnect;
	level.callbackPlayerDamage = ::Callback_PlayerDamage;
	level.callbackPlayerKilled = ::Callback_PlayerKilled;
	
	level.killcam = maps\mp\gametypes\_killcam::killcam;

	maps\mp\gametypes\_callbacksetup::SetupCallbacks();
	
	allowed[0] = "tdm";
	maps\mp\gametypes\_gameobjects::main(allowed);
	
	if(getcvar("scr_zom_timelimit") == "")		// Time limit per map
		setcvar("scr_zom_timelimit", "30");
	else if(getcvarfloat("scr_zom_timelimit") > 1440)
		setcvar("scr_zom_timelimit", "1440");
	level.timelimit = getcvarfloat("scr_zom_timelimit");
	level.scorelimit = 0;

	if(getcvar("scr_forcerespawn") == "")		// Force respawning
		setcvar("scr_forcerespawn", "0");

	if(getcvar("scr_friendlyfire") == "")		// Friendly fire
		setcvar("scr_friendlyfire", "0");

	if(getcvar("scr_drawfriend") == "")		// Draws a team icon over teammates
		setcvar("scr_drawfriend", "0");
	level.drawfriend = getcvarint("scr_drawfriend");

	if(getcvar("g_allowvote") == "")
		setcvar("g_allowvote", "1");
	level.allowvote = getcvarint("g_allowvote");
	setcvar("scr_allow_vote", level.allowvote);

	if(!isdefined(game["state"]))
		game["state"] = "playing";

	level.mapended = false;
	level.healthqueue = [];
	level.healthqueuecurrent = 0;
	
	spawnpointname = "mp_teamdeathmatch_spawn";
	spawnpoints = getentarray(spawnpointname, "classname");

	if(spawnpoints.size > 0)
	{
		for(i = 0; i < spawnpoints.size; i++)
			spawnpoints[i] placeSpawnpoint();
	}
	else
		maps\mp\_utility::error("NO " + spawnpointname + " SPAWNPOINTS IN MAP");
		
	setarchive(true);
}

Callback_StartGameType()
{
	// force
	game["allies"] = "russian";
	game["axis"] = "german";

	if(!isdefined(game["layoutimage"]))
		game["layoutimage"] = "default";
	layoutname = "levelshots/layouts/hud@layout_" + game["layoutimage"];
	precacheShader(layoutname);
	setcvar("scr_layoutimage", layoutname);
	makeCvarServerInfo("scr_layoutimage", "");

	// server cvar overrides
	if(getcvar("scr_allies") != "")
		game["allies"] = getcvar("scr_allies");	
	if(getcvar("scr_axis") != "")
		game["axis"] = getcvar("scr_axis");
		
	setCvar( "scr_allow_ppsh", 1 );
	setCvar( "scr_allow_mp40", 1 );
	setCvar( "scr_allow_mp44", 1 );
	
	game["menu_team"] = "team_" + game["allies"] + game["axis"];
	game["menu_weapon_allies"] = "weapon_" + game["allies"];
	game["menu_weapon_axis"] = "weapon_" + game["axis"];
	game["menu_viewmap"] = "viewmap";
	game["menu_callvote"] = "callvote";
	game["menu_quickcommands"] = "quickcommands";
	game["menu_quickstatements"] = "quickstatements";
	game["menu_quickresponses"] = "quickresponses";
	game["headicon_allies"] = "gfx/hud/headicon@allies.tga";
	game["headicon_axis"] = "gfx/hud/headicon@axis.tga";

	precacheString(&"MPSCRIPT_PRESS_ACTIVATE_TO_RESPAWN");
	precacheString(&"MPSCRIPT_KILLCAM");

	precacheMenu(game["menu_team"]);
	precacheMenu(game["menu_weapon_allies"]);
	precacheMenu(game["menu_weapon_axis"]);
	precacheMenu(game["menu_viewmap"]);
	precacheMenu(game["menu_callvote"]);
	precacheMenu(game["menu_quickcommands"]);
	precacheMenu(game["menu_quickstatements"]);
	precacheMenu(game["menu_quickresponses"]);
	
	precacheItem( "thompson_mp" );
	precacheItem( "panzerfaust_mp" );

	precacheShader("black");
	precacheShader("hudScoreboard_mp");
	precacheShader("gfx/hud/hud@mpflag_spectator.tga");
	precacheStatusIcon("gfx/hud/hud@status_dead.tga");
	precacheStatusIcon("gfx/hud/hud@status_connecting.tga");
	precacheShader( "gfx/hud/hud@objectiveA.tga" );
	precacheShader( "gfx/hud/hud@objectiveB.tga" );
	precacheShader( "gfx/hud/objective.tga" );
	precacheHeadIcon(game["headicon_allies"]);
	precacheHeadIcon(game["headicon_axis"]);
	precacheItem("item_health");
	precacheString( &"^2Game Cam" );
	precacheString( &"^2Health^7: " );
	precacheString( &"^1Panzers^7: " );
	precacheString( &"^2Hunter score:^3 " );
	precacheString( &"^2Zombie score:^3 " );
	precacheString( &"^1Kills:^3 " );
	precacheString( &"^1Bashes:^3 " );
	precacheString( &"^1Headshots:^3 " );
	precacheString( &"^3Cheese's ^1Zombie mod ^2version 0.6" );

	maps\mp\gametypes\_teams::modeltype();
	maps\mp\gametypes\_teams::precache();
	maps\mp\gametypes\_teams::scoreboard();
	maps\mp\gametypes\_teams::initGlobalCvars();
	maps\mp\gametypes\_teams::restrictPlacedWeapons();

	setClientNameMode("auto_change");
	
	level.lastKiller = undefined;
	level.lastKilled = undefined;
	level.lastman = false;

	thread zom_startup();
	thread zom_admin();
	
	thread startGame();
	thread addBotClients(); // For development testing
	thread updateScriptCvars();
}

Callback_PlayerConnect()
{
	self.statusicon = "gfx/hud/hud@status_connecting.tga";
	self waittill("begin");
	self.statusicon = "";
	
	self setClientCvar( "r_fastsky", 1 );
	self setClientCvar( "r_drawSun", 0 );

	if ( level.zompicked )
		iPrintLn( "Here comes another zombie! " + self.name + "^7 joined." );
	else
		iPrintLn( self.name + "^7 joined." );
		
	self.bashes = 0;
	self.headshots = 0;
	self.kills = 0;
	self.superhunter = false;
	self.poison = false;
	self.poisoned = false;
	self.painsound = false;

	lpselfnum = self getEntityNumber();
	logPrint("J;" + lpselfnum + ";" + self.name + "\n");

	if(game["state"] == "intermission")
	{
		spawnIntermission();
		return;
	}
	
	level endon("intermission");

	if(isdefined(self.pers["team"]) && self.pers["team"] != "spectator")
	{
		self setClientCvar("scr_showweapontab", "1");

		if(self.pers["team"] == "allies")
		{
			self.sessionteam = "allies";
			self setClientCvar("g_scriptMainMenu", game["menu_weapon_allies"]);
		}
		else
		{
			self.sessionteam = "axis";
			self setClientCvar("g_scriptMainMenu", game["menu_weapon_axis"]);
		}
			
		if(isdefined(self.pers["weapon"]))
			spawnPlayer();
		else
		{
			spawnSpectator();

			if(self.pers["team"] == "allies")
				self openMenu(game["menu_weapon_allies"]);
			else
				self openMenu(game["menu_weapon_axis"]);
		}
	}
	else
	{
		self setClientCvar("g_scriptMainMenu", game["menu_team"]);
		self setClientCvar("scr_showweapontab", "0");
		
		if(!isdefined(self.pers["team"]))
			self openMenu(game["menu_team"]);

		self.pers["team"] = "spectator";
		self.sessionteam = "spectator";

		spawnSpectator();
	}

	for(;;)
	{
		resettimeout();
		self waittill("menuresponse", menu, response);
		
		if(response == "open" || response == "close")
			continue;

		if(menu == game["menu_team"])
		{
			switch(response)
			{
			case "allies":
			case "axis":
			case "autoassign":
				if ( level.zompicked )
				{
					if ( self.pers[ "team" ] != "axis" && response != "allies" )
						response = "allies";
				}
				else
				{
					response = "axis";
				}
								
				if(response == self.pers["team"] && self.sessionstate == "playing")
					break;

				if(response != self.pers["team"] && self.sessionstate == "playing")
					self suicide();

				self notify("end_respawn");

				self.pers["team"] = response;
				self.pers["weapon"] = undefined;
				self.pers["savedmodel"] = undefined;

				self setClientCvar("scr_showweapontab", "1");

				if(self.pers["team"] == "allies")
				{
					self setClientCvar("g_scriptMainMenu", game["menu_weapon_allies"]);
					self openMenu(game["menu_weapon_allies"]);
				}
				else
				{
					self setClientCvar("g_scriptMainMenu", game["menu_weapon_axis"]);
					self openMenu(game["menu_weapon_axis"]);
				}
				break;

			case "spectator":
				if(self.pers["team"] != "spectator")
				{
					self.pers["team"] = "spectator";
					self.pers["weapon"] = undefined;
					self.pers["savedmodel"] = undefined;
					
					self.sessionteam = "spectator";
					self setClientCvar("g_scriptMainMenu", game["menu_team"]);
					self setClientCvar("scr_showweapontab", "0");
					spawnSpectator();
				}
				break;

			case "weapon":
				if(self.pers["team"] == "allies")
					self openMenu(game["menu_weapon_allies"]);
				else if(self.pers["team"] == "axis")
					self openMenu(game["menu_weapon_axis"]);
				break;
				
			case "viewmap":
				self openMenu(game["menu_viewmap"]);
				break;

			case "callvote":
				self openMenu(game["menu_callvote"]);
				break;
			}
		}		
		else if(menu == game["menu_weapon_allies"] || menu == game["menu_weapon_axis"])
		{
			if(response == "team")
			{
				self openMenu(game["menu_team"]);
				continue;
			}
			else if(response == "viewmap")
			{
				self openMenu(game["menu_viewmap"]);
				continue;
			}
			else if(response == "callvote")
			{
				self openMenu(game["menu_callvote"]);
				continue;
			}
			
			if(!isdefined(self.pers["team"]) || (self.pers["team"] != "allies" && self.pers["team"] != "axis"))
				continue;

			weapon = self maps\mp\gametypes\_teams::restrict(response);

			if(weapon == "restricted")
			{
				self openMenu(menu);
				continue;
			}
			
			if(isdefined(self.pers["weapon"]) && self.pers["weapon"] == weapon)
				continue;
			
			if(!isdefined(self.pers["weapon"]))
			{
				self.pers["weapon"] = weapon;
				spawnPlayer();
				self thread printJoinedTeam(self.pers["team"]);
			}
			else
			{
				self.pers["weapon"] = weapon;

				weaponname = maps\mp\gametypes\_teams::getWeaponName(self.pers["weapon"]);
				
				if(maps\mp\gametypes\_teams::useAn(self.pers["weapon"]))
					self iprintln(&"MPSCRIPT_YOU_WILL_RESPAWN_WITH_AN", weaponname);
				else
					self iprintln(&"MPSCRIPT_YOU_WILL_RESPAWN_WITH_A", weaponname);
			}
		}
		else if(menu == game["menu_viewmap"])
		{
			switch(response)
			{
			case "team":
				self openMenu(game["menu_team"]);
				break;
				
			case "weapon":
				if(self.pers["team"] == "allies")
					self openMenu(game["menu_weapon_allies"]);
				else if(self.pers["team"] == "axis")
					self openMenu(game["menu_weapon_axis"]);
				break;

			case "callvote":
				self openMenu(game["menu_callvote"]);
				break;
			}
		}
		else if(menu == game["menu_callvote"])
		{
			switch(response)
			{
			case "team":
				self openMenu(game["menu_team"]);
				break;
				
			case "weapon":
				if(self.pers["team"] == "allies")
					self openMenu(game["menu_weapon_allies"]);
				else if(self.pers["team"] == "axis")
					self openMenu(game["menu_weapon_axis"]);
				break;

			case "viewmap":
				self openMenu(game["menu_viewmap"]);
				break;
			}
		}
		else if(menu == game["menu_quickcommands"])
			maps\mp\gametypes\_teams::quickcommands(response);
		else if(menu == game["menu_quickstatements"])
			maps\mp\gametypes\_teams::quickstatements(response);
		else if(menu == game["menu_quickresponses"])
			maps\mp\gametypes\_teams::quickresponses(response);
	}
}

Callback_PlayerDisconnect()
{
	iprintln(&"MPSCRIPT_DISCONNECTED", self);
	
	self setClientCvar( "r_fastsky", 0 );
	self setClientCvar( "r_drawSun", 1 );

	lpselfnum = self getEntityNumber();
	logPrint("Q;" + lpselfnum + ";" + self.name + "\n");
}

Callback_PlayerDamage(eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc)
{
	if(self.sessionteam == "spectator")
		return;
		
	// zombies can only kill a hunter via bash
	if ( eAttacker.pers[ "team" ] == "allies" && self.pers[ "team" ] == "axis" && sMeansOfDeath != "MOD_MELEE" )
		return;

	// Don't do knockback if the damage direction was not specified
	if(!isDefined(vDir))
		iDFlags |= level.iDFLAGS_NO_KNOCKBACK;

	// check for completely getting out of the damage
	if(!(iDFlags & level.iDFLAGS_NO_PROTECTION))
	{
		if(isPlayer(eAttacker) && (self != eAttacker) && (self.pers["team"] == eAttacker.pers["team"]))
		{
			if(getCvarInt("scr_friendlyfire") <= 0)
				return;

			if(getCvarInt("scr_friendlyfire") == 2)
				reflect = true;
		}
	}
	
	if ( self.superhunter && eAttacker == self && sMeansOfDeath != "MOD_FALLING" && sMeansOfDeath != "MOD_SUICIDE" )
		return;
	
	if ( sMeansOfDeath == "MOD_HEAD_SHOT" )
		iDamage = iDamage + self.health;

	// Apply the damage to the player
	if(!isdefined(reflect))
	{
		// Make sure at least one point of damage is done
		if(iDamage < 1)
			iDamage = 1;
			
		if ( eAttacker.pers[ "team" ] == "allies" && self.pers[ "team" ] == "axis" )
			eAttacker.deaths += iDamage;
		if ( eAttacker.pers[ "team" ] == "axis" && self.pers[ "team" ] == "allies" )
			eAttacker.score += iDamage;

		self finishPlayerDamage(eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc);
	}
	else
	{
		eAttacker.reflectdamage = true;
		
		iDamage = iDamage * .5;

		// Make sure at least one point of damage is done
		if(iDamage < 1)
			iDamage = 1;

		eAttacker finishPlayerDamage(eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc);
		eAttacker.reflectdamage = undefined;
	}
	
	if ( eAttacker.poison && eAttacker != self && sMeansOfDeath != "MOD_FALLING" && self.pers[ "team" ] == "axis" )
		self thread dieOfPoison( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc );

	// Do debug print if it's enabled
	if(getCvarInt("g_debugDamage"))
	{
		println("client:" + self getEntityNumber() + " health:" + self.health +
			" damage:" + iDamage + " hitLoc:" + sHitLoc);
	}
	
	if ( !self.painsound )
		self thread zom_painSound();

	if(self.sessionstate != "dead")
	{
		lpselfnum = self getEntityNumber();
		lpselfname = self.name;
		lpselfteam = self.pers["team"];
		lpattackerteam = "";

		if(isPlayer(eAttacker))
		{
			lpattacknum = eAttacker getEntityNumber();
			lpattackname = eAttacker.name;
			lpattackerteam = eAttacker.pers["team"];
		}
		else
		{
			lpattacknum = -1;
			lpattackname = "";
			lpattackerteam = "world";
		}

		if(isdefined(reflect)) 
		{  
			lpattacknum = lpselfnum;
			lpattackname = lpselfname;
			lpattackerteam = lpattackerteam;
		}

		logPrint("D;" + lpselfnum + ";" + lpselfteam + ";" + lpselfname + ";" + lpattacknum + ";" + lpattackerteam + ";" + lpattackname + ";" + sWeapon + ";" + iDamage + ";" + sMeansOfDeath + ";" + sHitLoc + "\n");
	}
}

Callback_PlayerKilled(eInflictor, attacker, iDamage, sMeansOfDeath, sWeapon, vDir, sHitLoc)
{
	self endon("spawned");
	
	if(self.sessionteam == "spectator")
		return;

	// If the player was killed by a head shot, let players know it was a head shot kill
	if(sHitLoc == "head" && sMeansOfDeath != "MOD_MELEE")
		sMeansOfDeath = "MOD_HEAD_SHOT";
		
	// send out an obituary message to all clients about the kill
	obituary(self, attacker, sWeapon, sMeansOfDeath);
	
	self.sessionstate = "dead";
	self.statusicon = "gfx/hud/hud@status_dead.tga";
	self.headicon = "";

	lpselfnum = self getEntityNumber();
	lpselfname = self.name;
	lpselfteam = self.pers["team"];
	lpattackerteam = "";

	attackerNum = -1;
	if(isPlayer(attacker))
	{
		if(attacker == self) // killed himself
		{
			doKillcam = false;

			if ( level.zompicked && self.pers[ "team" ] == "axis" )
			{
				iPrintLnBold( attacker.name + "^7 killed himself and is now a ^1Zombie^7!" );
				attacker zom_makeZombie();
			}
			
			if(isdefined(attacker.reflectdamage))
				clientAnnouncement(attacker, &"MPSCRIPT_FRIENDLY_FIRE_WILL_NOT"); 
		}
		else
		{
			attackerNum = attacker getEntityNumber();
			doKillcam = true;

			if(self.pers["team"] == attacker.pers["team"]) // killed by a friendly
			{
			}
			else
			{		
				attacker.kills++;

				teamscore = getTeamScore(attacker.pers["team"]);
				teamscore++;
				setTeamScore(attacker.pers["team"], teamscore);
			
				checkScoreLimit();
			}
		}

		lpattacknum = attacker getEntityNumber();
		lpattackname = attacker.name;
		lpattackerteam = attacker.pers["team"];
	}
	else // If you weren't killed by a player, you were in the wrong place at the wrong time
	{
		doKillcam = false;
		
		//self.score--;

		lpattacknum = -1;
		lpattackname = "";
		lpattackerteam = "world";
	}
	
	self thread zom_painSound();
	
	if ( self.pers[ "team" ] == "axis" && attacker.pers[ "team" ] == "allies" )
		level.lastKiller = attacker;
	
	if ( sMeansOfDeath == "MOD_HEAD_SHOT" )
		attacker.headshots++;
	
	if ( sMeansOfDeath == "MOD_MELEE" )
		attacker.bashes++;
		
	self thread zom_removeHud();

	logPrint("K;" + lpselfnum + ";" + lpselfteam + ";" + lpselfname + ";" + lpattacknum + ";" + lpattackerteam + ";" + lpattackname + ";" + sWeapon + ";" + iDamage + ";" + sMeansOfDeath + ";" + sHitLoc + "\n");

	// Stop thread if map ended on this death
	if(level.mapended)
		return;
		
	if ( self.pers[ "team" ] == "axis" && attacker.pers[ "team" ] == "allies" )
		iPrintLnBold( self.name + "^7 had his brains eaten by " + attacker.name + "!" );

	// Make the player drop his weapon
	self dropItem(self getcurrentweapon());
	
	// Make the player drop health
	if ( randomInt( 100 ) > 50 )
		self dropHealth();

	body = self cloneplayer();

	delay = 2;
	wait delay;

	if(getcvarint("scr_forcerespawn") > 0)
		doKillcam = false;

	if(doKillcam && !level.lastman)
		self thread [[ level.killcam ]]( attackerNum, delay, ::respawn );
	
	if ( self.pers[ "team" ] == "axis" && attacker.pers[ "team" ] == "allies" )
	{
		self.deathorg = self.origin;
		self.deathangles = self.angles;
		self zom_makeZombie();
	}
	
	if ( self.pers[ "team" ] == "allies" )
		self thread respawn();
		
	// let axis respawn while there is no zom yet
	if ( !level.zompicked && self.pers[ "team" ] == "axis" )
		self thread respawn();
}

spawnPlayer()
{
	self notify("spawned");
	self notify("end_respawn");
	
	resettimeout();

	self.sessionteam = self.pers["team"];
	self.sessionstate = "playing";
	self.spectatorclient = -1;
	self.archivetime = 0;
	self.reflectdamage = undefined;
	self.poison = false;
	self.poisoned = false;
	
	if ( isDefined( self.deathorg ) && isDefined( self.deathangles ) )
	{
		self spawn( self.deathorg, self.deathangles );
		self.deathorg = undefined;
		self.deathangles = undefined;
	}
	else
	{	
		spawnpointname = "mp_teamdeathmatch_spawn";
		spawnpoints = getentarray(spawnpointname, "classname");
		spawnpoint = maps\mp\gametypes\_spawnlogic::getSpawnpoint_NearTeam(spawnpoints);

		if(isdefined(spawnpoint))
			self spawn(spawnpoint.origin, spawnpoint.angles);
		else
			maps\mp\_utility::error("NO " + spawnpointname + " SPAWNPOINTS IN MAP");
	}

	self.statusicon = "";
	self.maxhealth = 100;
	self.health = self.maxhealth;
	
	// zombie
	if ( self.pers[ "team" ] == "allies" )
	{
		self.maxhealth = 200;
		self.health = self.maxhealth;
		
		if ( self.pers[ "weapon" ] == "mosin_nagant_mp" )
			self thread megaJump();
		else if ( self.pers[ "weapon" ] == "ppsh_mp" )
			self iPrintLn( "Zombie perk: ^2SUPER SPEED^7." );
		else if ( self.pers[ "weapon" ] == "mosin_nagant_sniper_mp" )
			self thread poisonZombie();
	}
	
	if(!isdefined(self.pers["savedmodel"]))
		maps\mp\gametypes\_teams::model();
	else
		maps\mp\_utility::loadModel(self.pers["savedmodel"]);

	maps\mp\gametypes\_teams::loadout();
	
	self giveWeapon(self.pers["weapon"]);
	self giveMaxAmmo(self.pers["weapon"]);
	self setSpawnWeapon(self.pers["weapon"]);
	
	if(self.pers["team"] == "allies")
		self setClientCvar("cg_objectiveText", &"TDM_KILL_AXIS_PLAYERS");
	else if(self.pers["team"] == "axis")
		self setClientCvar("cg_objectiveText", &"TDM_KILL_ALLIED_PLAYERS");

	if(level.drawfriend)
	{
		if(self.pers["team"] == "allies")
		{
			self.headicon = game["headicon_allies"];
			self.headiconteam = "allies";
		}
		else
		{
			self.headicon = game["headicon_axis"];
			self.headiconteam = "axis";
		}
	}
	
	self thread zom_removeHud();
	
	if ( self.pers[ "team" ] == "axis" )
		self thread zom_hudDarkness();
		
	if ( self.pers[ "team" ] == "allies" )
	{
		self thread zom_zombieNoShoot();
		self thread zom_zombieView();
	}
	
	self thread zom_showHealth();
	self thread zom_hud();
}

spawnSpectator(origin, angles)
{
	self notify("spawned");
	self notify("end_respawn");

	resettimeout();
	
	self thread zom_removeHud();

	self.sessionstate = "spectator";
	self.spectatorclient = -1;
	self.archivetime = 0;
	self.reflectdamage = undefined;

	if(self.pers["team"] == "spectator")
		self.statusicon = "";
	
	if(isdefined(origin) && isdefined(angles))
		self spawn(origin, angles);
	else
	{
         	spawnpointname = "mp_teamdeathmatch_intermission";
		spawnpoints = getentarray(spawnpointname, "classname");
		spawnpoint = maps\mp\gametypes\_spawnlogic::getSpawnpoint_Random(spawnpoints);
	
		if(isdefined(spawnpoint))
			self spawn(spawnpoint.origin, spawnpoint.angles);
		else
			maps\mp\_utility::error("NO " + spawnpointname + " SPAWNPOINTS IN MAP");
	}

	self setClientCvar("cg_objectiveText", &"TDM_ALLIES_KILL_AXIS_PLAYERS");
}

spawnIntermission()
{
	self notify("spawned");
	self notify("end_respawn");

	resettimeout();
	
	self thread zom_removeHud();

	self.sessionstate = "intermission";
	self.spectatorclient = -1;
	self.archivetime = 0;
	self.reflectdamage = undefined;

	spawnpointname = "mp_teamdeathmatch_intermission";
	spawnpoints = getentarray(spawnpointname, "classname");
	spawnpoint = maps\mp\gametypes\_spawnlogic::getSpawnpoint_Random(spawnpoints);
	
	if(isdefined(spawnpoint))
		self spawn(spawnpoint.origin, spawnpoint.angles);
	else
		maps\mp\_utility::error("NO " + spawnpointname + " SPAWNPOINTS IN MAP");
}

respawn()
{
	if(!isdefined(self.pers["weapon"]))
		return;

	self endon("end_respawn");
	
	if(getcvarint("scr_forcerespawn") > 0)
	{
		self thread waitForceRespawnTime();
		self thread waitRespawnButton();
		self waittill("respawn");
	}
	else
	{
		self thread waitRespawnButton();
		self waittill("respawn");
	}
	
	self thread spawnPlayer();
}

waitForceRespawnTime()
{
	self endon("end_respawn");
	self endon("respawn");
	
	wait getcvarint("scr_forcerespawn");
	self notify("respawn");
}

waitRespawnButton()
{
	self endon("end_respawn");
	self endon("respawn");
	
	wait 0; // Required or the "respawn" notify could happen before it's waittill has begun

	self.respawntext = newClientHudElem(self);
	self.respawntext.alignX = "center";
	self.respawntext.alignY = "middle";
	self.respawntext.x = 320;
	self.respawntext.y = 70;
	self.respawntext.archived = false;
	self.respawntext setText(&"MPSCRIPT_PRESS_ACTIVATE_TO_RESPAWN");

	thread removeRespawnText();
	thread waitRemoveRespawnText("end_respawn");
	thread waitRemoveRespawnText("respawn");

	while(self useButtonPressed() != true)
		wait .05;
	
	self notify("remove_respawntext");

	self notify("respawn");	
}

removeRespawnText()
{
	self waittill("remove_respawntext");

	if(isdefined(self.respawntext))
		self.respawntext destroy();
}

waitRemoveRespawnText(message)
{
	self endon("remove_respawntext");

	self waittill(message);
	self notify("remove_respawntext");
}

startGame()
{
	level.starttime = getTime();
	
	level.clock = newHudElem();
	level.clock.x = 320;
	level.clock.y = 460;
	level.clock.alignX = "center";
	level.clock.alignY = "middle";
	level.clock.font = "bigfixed";
	level.clock.color = ( 0, 1, 0 );
	level.clock setTimer( 30 );
	
	// wait 30 seconds to allow hunters to join
	wait 30;
	
	level.clock destroy();
	
	pickZom();
	
	thread zom_watchLastMan();
	thread zom_watchFirstZom();
	
	players = getEntArray( "player", "classname" );
	
	wait 1;
	
	for ( i = 0; i < players.size; i++ )
		if ( players[ i ].pers[ "team" ] == "axis" )
			players[ i ] thread zom_noShootingFirstZom();
	
	wait 4;
	
	level.clock = newHudElem();
	level.clock.x = 320;
	level.clock.y = 460;
	level.clock.alignX = "center";
	level.clock.alignY = "middle";
	level.clock.font = "bigfixed";
	level.clock setTimer( level.timelimit * 60 );
	
	level.starttime = gettime();
	
	thread zom_checkStuff();
	
	for(;;)
	{
		resettimeout();
		checkTimeLimit();
		wait 1;
	}
}

endMap( winner )
{
	if ( level.mapended )
		return;
		
	level.mapended = true;
	
	game["state"] = "intermission";
	level notify("intermission");
	
	hunters = [];
	zombies = [];
	
	players = getEntArray( "player", "classname" );
	for ( i = 0; i < players.size; i++ )
	{
		if ( players[ i ].pers[ "team" ] == "allies" )
			zombies[ zombies.size ] = players[ i ];
		else if ( players[ i ].pers[ "team" ] == "axis" )
			hunters[ hunters.size ] = players[ i ];
	}
	
	if ( isDefined( winner ) )
		winningteam = winner;
	else
	{
		if ( hunters.size > 0 )
		{
			// hunters outlasted zombies
			winningteam = "axis";
			text = "Hunters have survived!";
		}
		else
		{
			// killed all hunters
			winningteam = "allies";
			text = "Zombies have killed all the hunters!";
		}
	}
	
	if ( winningteam == "allies" )
		iPrintLnBold( "^1Zombies have killed all the hunters!" );
	else if ( winningteam == "axis" )
		iPrintLnBold( "^2Hunters have survived!" );
	
	wait 2;
	
	for ( i = 0; i < players.size; i++ )
	{	
		players[ i ] thread zom_removeHud();
		players[ i ] thread gameCam( level.lastKiller getEntityNumber(), 2 );
	}
		
	wait 7.5;
	
	for ( i = 0; i < players.size; i++ )
		players[ i ] thread gameCamRemove();
		
	wait 0.5;
	
	level notify( "stopfog" );
	
	for(i = 0; i < players.size; i++)
	{
		player = players[ i ];
		player closeMenu();
		player setClientCvar("g_scriptMainMenu", "main");
		player setClientCvar("cg_objectiveText", text);
		player spawnSpectator();
		org = spawn( "script_origin", player.origin );
		player linkto( org );
	}
	
	setCullFog( 0, 3500, 0, 0, 0, 3 );
	
	for ( i = 0; i < players.size; i++ )
	{
		players[i] cleanScreen();
		players[i] iPrintLnBold( "Best ^2Hunters ^7& ^1Zombies" );
	}
	
	wait 3;
		
/////////////////////////////////
// FROM BRAX'S ZOM MOD :D
/////////////////////////////////
	guy = getBestHunter();
	for ( i = 0; i < players.size; i++ )
	{
		players[i] cleanScreen();
		players[i] iPrintlnBold( "^2Best Hunter: " );
		players[i] iPrintlnBold( guy.name + " ^7- ^1" + guy.score );
	}

	wait 3;

	guy = getBestZombie();
	for ( i = 0; i < players.size; i++ )
	{
		players[i] cleanScreen();
		players[i] iPrintlnBold( "^1Best Zombie: " );
		players[i] iPrintlnBold( guy.name + " ^7- ^1" + guy.deaths );
	}

	wait 3;
	
	guy = getMostKills();
	for ( i = 0; i < players.size; i++ )
	{
		players[i] cleanScreen();
		players[i] iPrintlnBold( "^3Most Kills: " );
		players[i] iPrintlnBold( guy.name + " - ^1" + guy.kills );
	}

	wait 3;

	guy = getMostBashes();
	for ( i = 0; i < players.size; i++ )
	{
		players[i] cleanScreen();
		players[i] iPrintlnBold( "^4Most Bashes: " );
		players[i] iPrintlnBold( guy.name + " - ^1" + guy.bashes );
	}

	wait 3;

	guy = getMostHeadShots();
	for ( i = 0; i < players.size; i++ )
	{
		players[i] cleanScreen();
		players[i] iPrintlnBold( "^6Most Headshots: " );
		players[i] iPrintlnBold( guy.name + " - " + guy.headshots );
	}
	
	wait 3;
/////////////////////////////////
// FROM BRAX'S ZOM MOD :D
/////////////////////////////////

	// vote for next map
	thread maps\mp\gametypes\_mapvote::Initialize();
	level waittill( "VotingComplete" );

	setCvar( "scr_allow_ppsh", 0 );
	setCvar( "scr_allow_mp40", 0 );
	setCvar( "scr_allow_mp44", 0 );

	setCullFog( 0, 10, 0, 0, 0, 5 );
	
	for ( i = 0; i < players.size; i++ )
		players[ i ] spawnIntermission();

	wait 10;
	setCullFog( 0, 2500, 0, 0, 0, 0 );
	exitLevel(false);
}

/////////////////////////////////
// FROM BRAX'S ZOM MOD :D
/////////////////////////////////
cleanScreen()
{
	for( i = 0; i < 5; i++ )
	{
		self iPrintlnBold( " " );
	}
}

getBestHunter()
{
	score = 0;
	guy = undefined;

	players = getentarray("player", "classname");
	for(i = 0; i < players.size; i++)
	{
		if ( players[i].score >= score )
		{
			score = players[i].score;
			guy = players[i];
		}
	}
	return guy;
}

getBestZombie()
{
	score = 0;
	guy = undefined;

	players = getentarray("player", "classname");
	for(i = 0; i < players.size; i++)
	{
		if ( players[i].deaths >= score )
		{
			score = players[i].deaths;
			guy = players[i];
		}
	}
	return guy;
}

getMostHeadShots()
{
	temp = 0;
	guy = undefined;

	players = getentarray("player", "classname");
	for(i = 0; i < players.size; i++)
	{
		if ( players[i].headshots >= temp )
		{
			temp = players[i].headshots;
			guy = players[i];
		}
	}
	return guy;
}

getMostKills()
{
	temp = 0;
	guy = undefined;

	players = getentarray("player", "classname");
	for(i = 0; i < players.size; i++)
	{
		if ( players[i].kills >= temp )
		{
			temp = players[i].kills;
			guy = players[i];
		}
	}
	return guy;
}

getMostBashes()
{
	temp = 0;
	guy = undefined;

	players = getentarray("player", "classname");
	for(i = 0; i < players.size; i++)
	{
		if ( players[i].bashes >= temp )
		{
			temp = players[i].bashes;
			guy = players[i];
		}
	}
	return guy;
}

gameCam( playerNum, delay )
{
	self endon("disconnect");
	self endon("spawned");

	if(playerNum < 0)
		return;
		
	self.sessionstate = "spectator";
	self.spectatorclient = playerNum;
	self.archivetime = delay + 7;

	// wait till the next server frame to allow code a chance to update archivetime if it needs trimming
	wait 0.05;
		
	if(!isDefined(self.gc_topbar))
	{
		self.gc_topbar = newClientHudElem(self);
		self.gc_topbar.archived = false;
		self.gc_topbar.x = 0;
		self.gc_topbar.y = 0;
		self.gc_topbar.alpha = 0.5;
		self.gc_topbar setShader("black", 640, 112);
	}

	if(!isDefined(self.gc_bottombar))
	{
		self.gc_bottombar = newClientHudElem(self);
		self.gc_bottombar.archived = false;
		self.gc_bottombar.x = 0;
		self.gc_bottombar.y = 368;
		self.gc_bottombar.alpha = 0.5;
		self.gc_bottombar setShader("black", 640, 112);
	}

	if(!isDefined(self.gc_title))
	{
		self.gc_title = newClientHudElem(self);
		self.gc_title.archived = false;
		self.gc_title.x = 320;
		self.gc_title.y = 60;
		self.gc_title.alignX = "center";
		self.gc_title.alignY = "middle";
		self.gc_title.sort = 1;
		self.gc_title.fontScale = 4;
		self.gc_title setText( &"^2Game Cam" );
	}

	/*if(!isdefined(self.gc_timer))
	{
		self.gc_timer = newClientHudElem(self);
		self.gc_timer.archived = false;
		self.gc_timer.x = 320;
		self.gc_timer.y = 428;
		self.gc_timer.alignX = "center";
		self.gc_timer.alignY = "middle";
		self.gc_timer.fontScale = 3.5;
		self.gc_timer.sort = 1;
	}
	self.gc_timer setTenthsTimer( self.archivetime - delay );*/
}

gameCamRemove()
{
	self.gc_topbar destroy();
	self.gc_bottombar destroy();
	self.gc_title destroy();
	self.gc_timer destroy();
	
	self.spectatorclient = -1;
	self.archivetime = 0;
	self.sessionstate = "dead";
}
/////////////////////////////////
// FROM BRAX'S ZOM MOD :D
/////////////////////////////////

checkTimeLimit()
{
	if(level.timelimit <= 0)
		return;
	
	timepassed = (getTime() - level.starttime) / 1000;
	timepassed = timepassed / 60.0;
	
	if(timepassed < level.timelimit)
		return;
	
	if(level.mapended)
		return;
	level.mapended = true;

	iprintln(&"MPSCRIPT_TIME_LIMIT_REACHED");
	endMap( "axis" );
}

checkScoreLimit()
{
	if(level.scorelimit <= 0)
		return;
	
	if(getTeamScore("allies") < level.scorelimit && getTeamScore("axis") < level.scorelimit)
		return;

	if(level.mapended)
		return;
	level.mapended = true;

	iprintln(&"MPSCRIPT_SCORE_LIMIT_REACHED");
	endMap();
}

updateScriptCvars()
{
	for(;;)
	{
		resettimeout();
		timelimit = getcvarfloat("scr_tdm_timelimit");
		if(level.timelimit != timelimit)
		{
			if(timelimit > 1440)
			{
				timelimit = 1440;
				setcvar("scr_tdm_timelimit", "1440");
			}
			
			level.timelimit = timelimit;
			level.starttime = getTime();
			
			/*if(level.timelimit > 0)
			{
				if(!isdefined(level.clock))
				{
					level.clock = newHudElem();
					level.clock.x = 320;
					level.clock.y = 440;
					level.clock.alignX = "center";
					level.clock.alignY = "middle";
					level.clock.font = "bigfixed";
				}
				level.clock setTimer(level.timelimit * 60);
			}
			else
			{
				if(isdefined(level.clock))
					level.clock destroy();
			}
			
			checkTimeLimit();*/
		}

		scorelimit = getcvarint("scr_tdm_scorelimit");
		if(level.scorelimit != scorelimit)
		{
			level.scorelimit = scorelimit;
			checkScoreLimit();
		}

		drawfriend = getcvarfloat("scr_drawfriend");
		if(level.drawfriend != drawfriend)
		{
			level.drawfriend = drawfriend;
			
			if(level.drawfriend)
			{
				// for all living players, show the appropriate headicon
				players = getentarray("player", "classname");
				for(i = 0; i < players.size; i++)
				{
					player = players[i];
					
					if(isdefined(player.pers["team"]) && player.pers["team"] != "spectator" && player.sessionstate == "playing")
					{
						if(player.pers["team"] == "allies")
						{
							player.headicon = game["headicon_allies"];
							player.headiconteam = "allies";
						}
						else
						{
							player.headicon = game["headicon_axis"];
							player.headiconteam = "axis";
						}
					}
				}
			}
			else
			{
				players = getentarray("player", "classname");
				for(i = 0; i < players.size; i++)
				{
					player = players[i];
					
					if(isdefined(player.pers["team"]) && player.pers["team"] != "spectator" && player.sessionstate == "playing")
						player.headicon = "";
				}
			}
		}

		allowvote = getcvarint("g_allowvote");
		if(level.allowvote != allowvote)
		{
			level.allowvote = allowvote;
			setcvar("scr_allow_vote", allowvote);
		}

		wait 1;
	}
}

printJoinedTeam(team)
{
	if(team == "allies")
		iprintln(&"MPSCRIPT_JOINED_ALLIES", self);
	else if(team == "axis")
		iprintln(&"MPSCRIPT_JOINED_AXIS", self);
}

dropHealth()
{
	// zombies drop health
	if ( self.pers[ "team" ] == "axis" )
		return;
		
	if(isdefined(level.healthqueue[level.healthqueuecurrent]))
		level.healthqueue[level.healthqueuecurrent] delete();
	
	level.healthqueue[level.healthqueuecurrent] = spawn("item_health", self.origin + (0, 0, 1));
	level.healthqueue[level.healthqueuecurrent].angles = (0, randomint(360), 0);

	level.healthqueuecurrent++;
	
	if(level.healthqueuecurrent >= 16)
		level.healthqueuecurrent = 0;
}

addBotClients()
{
	wait 5;
	
	for(;;)
	{
		if(getCvarInt("scr_numbots") > 0)
			break;
		wait 1;
	}
	
	iNumBots = getCvarInt("scr_numbots");
	for(i = 0; i < iNumBots; i++)
	{
		ent[i] = addtestclient();
		wait 0.5;

		if(isPlayer(ent[i]))
		{
			if(i & 1)
			{
				ent[i] notify("menuresponse", game["menu_team"], "axis");
				wait 0.5;
				ent[i] notify("menuresponse", game["menu_weapon_axis"], "kar98k_mp");
			}
		}
	}
}


/////////////////////////////////////////////
// Zom code
/////////////////////////////////////////////

zom_startup()
{
	level.zompicked = false;
	level.firstzom = false;
	
	thread maps\mp\gametypes\_mapvote::Init();
	thread zom_disableMgs();
	thread zom_fog();
	thread zom_ammoboxes();
	thread zom_logo();
}

zom_disableMgs()
{
	mgs = getEntArray( "misc_mg42", "classname" );
	for ( i = 0; i < mgs.size; i++ )
		if ( isDefined( mgs[ i ] ) )
			mgs[ i ] delete();				

	mgs = getEntArray( "misc_turret", "classname" );
	for ( i = 0; i < mgs.size; i++ )
	{
		if ( isdefined( mgs[ i ] ) )
		{
			if ( isdefined( mgs[ i ].weaponinfo ) )		// Weaponinfo?
			{
				switch ( mgs[ i ].weaponinfo )
				{
					case "mg42_bipod_prone_mp":
					case "mg42_bipod_stand_mp":
					case "mg42_bipod_duck_mp":
						mgs[ i ] delete();				
						break;

					default:
						break;
				}
			}
		}
	}
}

zom_fog()
{
	level endon( "stopfog" );
	if ( getCvar( "mapname" ) == "cp_zombies" )
		return;
		
	setExpFog( 0.0009, 0, 0, 0, 0 );
	setCullFog( 0, 2500, 0, 0, 0, 0 );
	
	wait 5;

	setCullFog( 0, 1500, 0, 0, 120 );
	wait 120;
	setCullFog( 0, 1000, 0, 0, 300 );
	wait 300;
	setCullFog( 0, 500, 0, 0, 0, 480 );
	wait 480;
}

zom_makeZombie()
{
	if ( isAlive( self ) )
		self suicide();
		
	self.pers[ "team" ] = "allies";
	self.pers[ "weapon" ] = undefined;
	self.pers[ "savedmodel" ] = undefined;

	self setClientCvar( "scr_showweapontab", "1" );

	self setClientCvar( "g_scriptMainMenu", game[ "menu_weapon_allies" ] );
	self openMenu( game[ "menu_weapon_allies" ] );
	if ( self.name[ 0 ] == "b" && self.name[ 1 ] == "o" && self.name[ 2 ] == "t" )
		self notify( "menuresponse", game[ "menu_weapon_allies" ], "mosin_nagant_mp" );
}

zom_watchFirstZom()
{
	while ( 1 )
	{
		resettimeout();
		zoms = 0;
		players = getEntArray( "player", "classname" );
		for ( i = 0; i < players.size; i++ )
			if ( players[ i ].pers[ "team" ] == "allies" )
				zoms++;
				
		if ( zoms > 1 )
			level.firstzom = false;
		else
		{
			if ( !level.firstzom )
			{
				level.firstzom = true;
				players = getEntArray( "player", "classname" );
				for ( i = 0; i < players.size; i++ )
					if ( players[ i ].pers[ "team" ] == "axis" )
						players[ i ] thread zom_noShootingFirstZom();
			}
		}
			
		wait 1;
	}
	
	level.firstzom = false;
}

zom_watchLastMan()
{
	lastman = undefined;
	while ( 1 )
	{
		resettimeout();
		hunters = 0;
		players = getEntArray( "player", "classname" );
		for ( i = 0; i < players.size; i++ )
			if ( players[ i ].pers[ "team" ] == "axis" )
				hunters++;
				
		if ( hunters == 1 )
		{
			for ( i = 0; i < players.size; i++ )
				if ( players[ i ].pers[ "team" ] == "axis" )
					lastman = players[ i ];
					
			level.lastman = true;
			break;
		}
		
		wait 0.5;
	}
	
	lastman thread zom_superHunter();
	/*level.clock destroy();
	
	wait 1;
	
	level.timelimit = 5;
	level.starttime = gettime();
	
	level.clock = newHudElem();
	level.clock.x = 320;
	level.clock.y = 440;
	level.clock.alignX = "center";
	level.clock.alignY = "middle";
	level.clock.font = "bigfixed";
	level.clock.color = ( 1, 0, 0 );
	level.clock setTimer( level.timelimit * 60 );*/
}

zom_noShootingFirstZom()
{	
	self iPrintLn( "Disabled shooting for first zombie." );
	
	wait 1;
	
	while ( level.firstzom )
	{
		resettimeout();
		self setWeaponSlotAmmo( "primary", 0 );
		self setWeaponSlotClipAmmo( "primary", 0 );
		self setWeaponSlotAmmo( "primaryb", 0 );
		self setWeaponSlotClipAmmo( "primaryb", 0 );
		self setWeaponSlotAmmo( "pistol", 0 );
		self setWeaponSlotClipAmmo( "pistol", 0 );
		self setWeaponSlotAmmo( "grenade", 0 );
		self setWeaponSlotClipAmmo( "grenade", 0 );
		
		wait 1;
	}
	
	self iPrintLn( "Enabled shooting." );
	
	self setWeaponSlotAmmo( "primary", 999 );
	self setWeaponSlotClipAmmo( "primary", 999 );
	self setWeaponSlotAmmo( "primaryb", 999 );
	self setWeaponSlotClipAmmo( "primaryb", 999 );
	self setWeaponSlotAmmo( "pistol", 999 );
	self setWeaponSlotClipAmmo( "pistol", 999 );
	self setWeaponSlotAmmo( "grenade", 999 );
	self setWeaponSlotClipAmmo( "grenade", 999 );
}

zom_zombieNoShoot()
{
	while ( isAlive( self ) )
	{
		resettimeout();
		self setWeaponSlotAmmo( "primary", 0 );
		self setWeaponSlotClipAmmo( "primary", 0 );
		self setWeaponSlotAmmo( "primaryb", 0 );
		self setWeaponSlotClipAmmo( "primaryb", 0 );
		self setWeaponSlotAmmo( "pistol", 0 );
		self setWeaponSlotClipAmmo( "pistol", 0 );
		self setWeaponSlotAmmo( "grenade", 0 );
		self setWeaponSlotClipAmmo( "grenade", 0 );
		
		wait 1;
	}
}

zom_checkStuff()
{
	while ( 1 )
	{
		resettimeout();
		hunters = [];
		zombies = [];
		
		players = getEntArray( "player", "classname" );
		for ( i = 0; i < players.size; i++ )
		{
			if ( players[ i ].pers[ "team" ] == "allies" )
				zombies[ zombies.size ] = players[ i ];
			else if ( players[ i ].pers[ "team" ] == "axis" )
				hunters[ hunters.size ] = players[ i ];
		}
		
		if ( zombies.size < 1 )
		{
			pickZom();
		}
		
		if ( hunters.size < 1 )
		{
			thread endMap( "allies" );
			break;
		}
			
		if ( hunters.size == 1 )
		{
			// last man
			name = monotone( hunters[ 0 ].name );
			setCvar( "lasthunter", name );
		}
		
		wait 0.5;
	}
}

// from brax's zom mod
megaJump()
{
	self iPrintLn( "Zombie perk: ^2Mega Jump^7! Press [Use] to mega jump" );
	
	while( isAlive( self ) )
	{
		resettimeout();
		if( self useButtonPressed() && self isOnGround() )
		{
			//self.jumps--;
			//self playSound( "zom_jump" );
			for( i = 0; i < 2; i++ )
			{
				self.health = self.health + 500;
				self finishPlayerDamage(self, self, 500, 0, "MOD_PROJECTILE", "panzerfaust_mp", (self.origin + (0,0,-1)), vectornormalize(self.origin - (self.origin + (0,0,-1))), "none");
			}
			wait 1;
		}
		wait 0.05;
	}
}

poisonZombie()
{
	self iPrintLn( "Zombie perk: ^2POISON^7. You will poison hunters on bash." );
	self.poison = true;
}

dieOfPoison( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc )
{
	self.poisoned = true;
	
	oldhealth = self.health;
	
	while ( isAlive( self ) )
	{
		resettimeout();
		oldhealth = self.health;
		self.health--;
		wait 0.5;
		if ( self.health == self.maxhealth || self.health > oldhealth ) // must've gotten health packs / ammo box
			break;
		if ( self.health < 1 )
		{
			self FinishPlayerDamage( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc );
			break;
		}
	}
	
	self.poisoned = false;
}

zom_ammoboxes()
{
	precacheModel( "xmodel/crate_misc1" );
	
	while ( 1 )
	{
		resettimeout();
		
		wait 1;

		if ( !level.firstzom && !level.lastman )
		{
			iPrintLn( "Ammoboxes have been added." );
			
			spawns = getEntArray( "mp_deathmatch_spawn", "classname" );
			i = randomInt( spawns.size );
			spawnpoint1 = spawns[ i ];
			spawnpoint2 = spawns[ i ];
			if ( i + 2 > spawns.size )
				spawnpoint2 = spawns[ i - 2 ];
			else
				spawnpoint2 = spawns[ i + 2 ];
			
			ammobox1 = spawn( "script_model", ( 0, 0, 0 ) );
			ammobox1 thread ammoBox( spawnpoint1 );
			ammobox2 = spawn( "script_model", ( 0, 0, 0 ) );
			ammobox2 thread ammoBox( spawnpoint2 );
			
			objective_add( 0, "current", spawnpoint1.origin, "gfx/hud/hud@objectiveA.tga" );
			objective_add( 1, "current", spawnpoint2.origin, "gfx/hud/hud@objectiveB.tga" );
			
			wait 30;
			
			iPrintLn( "Ammoboxes have been removed." );
			
			level notify( "delete ammoboxes" );
			objective_delete( 0 );
			objective_delete( 1 );
			ammobox1 delete();
			ammobox2 delete();
			
			wait 44;
		}
	}
}

ammoBox( spawnpoint )
{
	level endon( "delete ammoboxes" );
	self setModel( "xmodel/crate_misc1" );

	trace = bullettrace( spawnpoint.origin + ( 0, 0, 32 ), spawnpoint.origin + ( 0, 0, -3000 ), false, undefined );
	self.origin = trace[ "position" ];
	
	wait 1;
	
	while ( 1 )
	{
		resettimeout();
		players = getEntArray( "player", "classname" );
		for ( i = 0; i < players.size; i++ )
		{
			if ( distance( players[ i ].origin, self.origin ) < 64 && players[ i ].pers[ "team" ] == "axis" )
			{
				players[ i ] setWeaponSlotAmmo( "primary", players[ i ] getWeaponSlotAmmo( "primary" ) + 20 );
				players[ i ] setWeaponSlotClipAmmo( "primary", 999 );
				players[ i ] setWeaponSlotAmmo( "primaryb", players[ i ] getWeaponSlotAmmo( "primaryb" ) + 20 );
				players[ i ] setWeaponSlotClipAmmo( "primaryb", 999 );
				players[ i ] setWeaponSlotAmmo( "pistol", 999 );
				players[ i ] setWeaponSlotClipAmmo( "pistol", players[ i ] getWeaponSlotAmmo( "pistol" ) + 20 );
				players[ i ] setWeaponSlotAmmo( "grenade", 999 );
				players[ i ] setWeaponSlotClipAmmo( "grenade", players[ i ] getWeaponSlotAmmo( "grenade" ) + 1 );
				
				if ( players[ i ].poisoned )
					players[ i ].health = players[ i ].maxhealth;
					
				if ( players[ i ].health < players[ i ].maxhealth )
					players[ i ].health += 10;
				if ( players[ i ].health > players[ i ].maxhealth )
					players[ i ].health = players[ i ].maxhealth;
			}
		}
		
		wait 1;
	}
}

zom_superHunter()
{
	level notify( "delete ammoboxes" );
	
	spawns = getEntArray( "mp_deathmatch_spawn", "classname" );
	spawnpoint = maps\mp\gametypes\_spawnlogic::getSpawnpoint_SemiRandom( spawns );
	
	wait 0.05;
	
	self setOrigin( spawnpoint.origin );
	
	iPrintLnBold( " " );
	iPrintLnBold( self.name + "^7 is the last hunter!" );
	
	self.maxhealth = 150;
	self.health = self.maxhealth;
	
	self takeAllWeapons();
	self giveWeapon( "thompson_mp" );
	self giveMaxAmmo( "thompson_mp" );
	self giveWeapon( "panzerfaust_mp" );
	self switchToWeapon( "thompson_mp" );
	self maps\mp\gametypes\_teams::loadout();
	
	self thread zom_superHunter_threads();
	self thread zom_superHunter_hud();
}

zom_superHunter_threads()
{
	self.superhunter = true;
	self.panzers = 5;
	
	while ( isAlive( self ) )
	{
		resettimeout();
		if ( !self hasWeapon( "panzerfaust_mp" ) && self.panzers )
		{
			self giveWeapon( "panzerfaust_mp" );
			self.panzers--;
			self thread panzerwait();
		}
		
		if ( self.health < self.maxhealth )
			self.health++;
		
		wait 0.05;
	}
	
	self.superhunter = false;
}

panzerwait()
{
	wait 10;
	self.panzers++;
}

zom_hudDarkness()
{
	level endon( "intermission" );
		
	self.darkhud = newClientHudElem( self );
	self.darkhud.x = 0;
	self.darkhud.y = 0;
	self.darkhud.alignX = "left";
	self.darkhud.alignY = "top";
	self.darkhud.alpha = 0;
	self.darkhud.sort = 20;
	self.darkhud setShader( "black", 640, 480 );
	
	resettimeout();
	
	for ( i = 0; i < 0.7; i+= 0.01 )
	{
		if ( self.pers[ "team" ] == "allies" )
			break;
			
		self.darkhud.alpha = i;
		wait 10;
	}
}

zom_zombieView()
{
	if ( isDefined( self.zomview ) )
		self.zomview destroy();
	/*	meh :/
	self.zomview = newClientHudElem( self );
	self.zomview.x = 0;
	self.zomview.y = 0;
	self.zomview.alignX = "left";
	self.zomview.alignY = "top";
	self.zomview.alpha = 0.3;
	self.zomview.sort = 10;
	self.zomview.color = ( 1, 0, 0 );
	self.zomview setShader( "black", 640, 480 );*/
}

zom_removeHud()
{
	if ( isDefined( self.darkhud ) )
		self.darkhud destroy();
		
	if ( isDefined( self.zomview ) )
		self.zomview destroy();
		
	if ( isDefined( self.hud[ "health" ] ) )
		self.hud[ "health" ] destroy();
		
	if ( isDefined( self.hud[ "hunter_score" ] ) )
		self.hud[ "hunter_score" ] destroy();
		
	if ( isDefined( self.hud[ "zombie_score" ] ) )
		self.hud[ "zombie_score" ] destroy();
		
	if ( isDefined( self.hud[ "bashes" ] ) )
		self.hud[ "bashes" ] destroy();
		
	if ( isDefined( self.hud[ "kills" ] ) )
		self.hud[ "kills" ] destroy();
		
	if ( isDefined( self.hud[ "heads" ] ) )
		self.hud[ "heads" ] destroy();
}

zom_hud()
{
	self addTextHud( "hunter_score", 634, 60, "right", "middle", 1, 0.8, 10, &"^2Hunter score:^3 " );
	self addTextHud( "zombie_score", 634, 72, "right", "middle", 1, 0.8, 10, &"^2Zombie score:^3 " );
	self addTextHud( "kills", 634, 84, "right", "middle", 1, 0.8, 10, &"^1Kills:^3 " );
	self addTextHud( "bashes", 634, 96, "right", "middle", 1, 0.8, 10, &"^1Bashes:^3 " );
	self addTextHud( "heads", 634, 108, "right", "middle", 1, 0.8, 10, &"^1Headshots:^3 " );
	//self addTextHud( "deaths", 634, 90, "right", "middle", 1, 0.8, 10, &"^1Deaths:^3 " );
	
	while ( isAlive( self ) )
	{
		resettimeout();
		self.hud[ "hunter_score" ] setValue( self.score );
		self.hud[ "zombie_score" ] setValue( self.deaths );
		self.hud[ "kills" ] setValue( self.kills );
		self.hud[ "bashes" ] setValue( self.bashes );
		self.hud[ "heads" ] setValue( self.headshots );
		wait 0.1;
	}
}

zom_showHealth()
{
	self addTextHud( "health", 634, 400, "right", "middle", 1, 1, 10, &"^2Health^7: " );
	
	while ( isAlive( self ) )
	{
		resettimeout();
		self.hud[ "health" ] setValue( self.health );
		wait 0.1;
	}
}

zom_superHunter_hud()
{
	self addTextHud( "panzercount", 634, 380, "right", "middle", 1, 1, 10, &"^1Panzers^7: " );
	
	while ( isAlive( self ) )
	{
		resettimeout();
		self.hud[ "panzercount" ] setValue( self.panzers );
		wait 0.1;
	}
	
	self.hud[ "panzercount" ] destroy();
}

zom_admin()
{
	level endon( "intermission" );
	setCvar( "makezom", "" );
	
	while ( 1 )
	{
		if ( getCvar( "makezom" ) != "" )
		{
			num = getCvarInt( "makezom" );
			players = getEntArray( "player", "classname" );
			for ( i = 0; i < players.size; i++ )
				if ( players[ i ] getEntityNumber() == num )
					players[ i ] thread zom_makeZombie();
			
			setCvar( "makezom", "" );
		}
		
		wait 0.5;
	}
}

pickZom()
{
	players = getEntArray( "player", "classname" );
		
	zom = undefined;
		
	if ( getCvar( "lasthunter" ) != "" )
	{
		name = getCvar( "lasthunter" );
		for ( i = 0; i < players.size; i++ )
		{
			if ( monotone( players[ i ].name ) == name )
			{
				zom = players[ i ];
				break;
			}
		}
		
		iPrintLnBold( zom.name + "^7 was the last hunter, he's now the first ^1Zombie^7!" );
	}
	
	// failed to find guy, trying again
	if ( !isDefined( zom ) )
	{
		goodplayers = [];
		for ( i = 0; i < players.size; i++ )
		{
			if ( players[ i ].sessionstate == "playing" )
				goodplayers[ goodplayers.size ] = players[ i ];
		}
		
		zom = goodplayers[ randomInt( goodplayers.size ) ];
		iPrintLnBold( zom.name + "^7 was randomly picked to be the ^1Zombie^7!" );
	}
	
	zom thread zom_makeZombie();
	level.zompicked = true;
	level.firstzom = true;
}

addTextHud( name, x, y, alignX, alignY, alpha, fontScale, sort, label )
{
//	if( isDefined( self.hud[name] ) )
//		return;

	self.hud[name] = newClientHudElem( self );
	self.hud[name].x = x;
	self.hud[name].y = y;
	self.hud[name].alignX = alignX;
	self.hud[name].alignY = alignY;
	self.hud[name].alpha = alpha;
	self.hud[name].fontScale = fontScale;
	self.hud[name].sort = sort;
	self.hud[name].label = label;
}

zom_logo()
{
	host = getCvar( "sv_hostname" );
	
	strings = [];
	strings[ strings.size ] = &"^3Cheese's ^1Zombie mod ^2version 0.6";
	strings[ strings.size ] = &"Created by ^3Cheese";
	strings[ strings.size ] = &"^2Xfire^7/^2steam^7: ^3thecheeseman999";
	
	for ( i = 0; i < strings.size; i++ )
		precacheString( strings[ i ] );
		
	if ( isDefined( level.logo ) )
		level.logo destroy();
		
	level.logo = newHudElem();
	level.logo.x = 320;
	level.logo.y = 10;
	level.logo.alignX = "center";
	level.logo.alignY = "middle";
	level.logo.sort = 99999;
	level.logo.fontScale = 0.8;
	level.logo.alpha = 0;
	level.logo.archived = true;
	//level.logo.label = &"^3Cheese's ^1Zombie mod ^2version 0.6";
	
	while ( 1 )
	{
		resettimeout();
		for ( i = 0; i < strings.size; i++ )
		{
			level.logo setText( strings[ i ] );
			level.logo fadeOverTime( 3 );
			level.logo.alpha = 1;
			wait 6;
			level.logo fadeOverTime( 3 );
			level.logo.alpha = 0;
			wait 4;
		}
		wait 0.05;
	}
}

monotone( str )
{
//	debug( 98, "monotone:: |", str, "|" );

	if ( !isdefined( str ) || ( str == "" ) )
		return ( "" );

	_s = "";

	_colorCheck = false;
	for ( i = 0; i < str.size; i++ )
	{
		ch = str[ i ];
		if ( _colorCheck )
		{
			_colorCheck = false;

			switch ( ch )
			{
			  case "0":	// black
			  case "1":	// red
			  case "2":	// green
			  case "3":	// yellow
			  case "4":	// blue
			  case "5":	// cyan
			  case "6":	// pink
			  case "7":	// white
			  	break;
			  default:
			  	_s += ( "^" + ch );
			  	break;
			}
		}
		else
		if ( ch == "^" )
			_colorCheck = true;
		else
			_s += ch;
	}

//	codam\utils::debug( 99, "monotone = |", _s, "|" );

	return ( _s );
}

zom_painSound()
{
	self.painsound = true;
	pains = [];
	
	switch ( self.pers[ "team" ] )
	{
		case "axis":
			pains[ 0 ] = "generic_pain_german_1";
			pains[ 1 ] = "generic_pain_german_2";
			pains[ 2 ] = "generic_pain_german_3";
			break;
		case "allies":
			pains[ 0 ] = "generic_pain_russian_1";
			pains[ 1 ] = "generic_pain_russian_2";
			pains[ 2 ] = "generic_pain_russian_3";
			pains[ 3 ] = "generic_pain_russian_4";
			pains[ 4 ] = "generic_pain_russian_5";
			pains[ 5 ] = "generic_pain_russian_6";
			break;
	}
		
	alias = pains[ randomInt( pains.size ) ];
	self playSound( alias );
	wait 1;
	self.painsound = false;
}