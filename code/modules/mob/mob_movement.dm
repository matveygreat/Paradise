/mob/CanPass(atom/movable/mover, turf/target, height=0)
	if(height==0)
		return 1
	if(istype(mover, /obj/item/projectile))
		return (!density || lying)
	if(mover.throwing)
		return (!density || lying || (mover.throwing.thrower == src))
	if(mover.checkpass(PASSMOB))
		return 1
	if(buckled == mover)
		return TRUE
	if(ismob(mover))
		var/mob/moving_mob = mover
		if((currently_grab_pulled && moving_mob.currently_grab_pulled))
			return FALSE
		if(mover in buckled_mobs)
			return TRUE
	return (!mover.density || !density || lying)


/client/verb/toggle_throw_mode()
	set hidden = 1
	if(iscarbon(mob))
		var/mob/living/carbon/C = mob
		C.toggle_throw_mode()
	else
		to_chat(usr, "<span class='danger'>Это существо не может бросать предметы.</span>")

/client/proc/Move_object(direct)
	if(mob && mob.control_object)
		if(mob.control_object.density)
			step(mob.control_object, direct)
			if(!mob.control_object)
				return
			mob.control_object.setDir(direct)
		else
			mob.control_object.forceMove(get_step(mob.control_object, direct))
	return

#define MOVEMENT_DELAY_BUFFER 0.75
#define MOVEMENT_DELAY_BUFFER_DELTA 1.25
/client/Move(n, direct)
	if(world.time < move_delay)
		return
	else
		input_data.desired_move_dir_add = NONE
		input_data.desired_move_dir_sub = NONE
	var/old_move_delay = move_delay
	move_delay = world.time + world.tick_lag //this is here because Move() can now be called multiple times per tick
	if(!mob || !mob.loc)
		return 0

	if(!n || !direct) // why did we never check this before?
		return FALSE

	if(mob.notransform)
		return 0 //This is sota the goto stop mobs from moving var

	if(mob.control_object)
		return Move_object(direct)

	if(!isliving(mob))
		return mob.Move(n, direct)

	if(mob.stat == DEAD)
		mob.ghostize()
		return 0

	if(moving)
		return 0

	if(isliving(mob))
		var/mob/living/L = mob
		if(L.incorporeal_move)//Move though walls
			move_delay = world.time + 0.5 // cap to 20fps
			L.glide_size = 8
			Process_Incorpmove(direct)
			return

	if(mob.remote_control) //we're controlling something, our movement is relayed to it
		return mob.remote_control.relaymove(mob, direct)

	if(isAI(mob))
		if(istype(mob.loc, /obj/item/aicard))
			var/obj/O = mob.loc
			return O.relaymove(mob, direct) // aicards have special relaymove stuff
		return AIMove(n, direct, mob)


	if(Process_Grab())
		return

	if(mob.buckled) //if we're buckled to something, tell it we moved.
		return mob.buckled.relaymove(mob, direct)

	if(!mob.canmove)
		return

	if(!mob.lastarea)
		mob.lastarea = get_area(mob.loc)

	if(isobj(mob.loc) || ismob(mob.loc)) //Inside an object, tell it we moved
		var/atom/O = mob.loc
		return O.relaymove(mob, direct)

	if(!mob.Process_Spacemove(direct))
		return 0

	if(mob.restrained()) // Why being pulled while cuffed prevents you from moving
		for(var/mob/M in orange(1, mob))
			if(M.pulling == mob)
				if(!M.incapacitated() && mob.Adjacent(M))
					to_chat(src, "<span class='warning'>Вы скованы и не можете пошевелиться!</span>")
					move_delay = world.time + 10
					return 0
				else
					M.stop_pulling()


	//We are now going to move
	moving = 1
	current_move_delay = mob.movement_delay()

	if(!istype(get_turf(mob), /turf/space) && mob.pulling)
		var/mob/living/M = mob
		var/mob/living/silicon/robot/R = mob
		if(!(STRONG in M.mutations) && !istype(M, /mob/living/simple_animal/hostile/construct) && !istype(M, /mob/living/simple_animal/hostile/clockwork) && !istype(M, /mob/living/simple_animal/hostile/guardian) && !(istype(R) && (/obj/item/borg/upgrade/vtec in R.upgrades))) //No slowdown for STRONG gene //Blood cult constructs //Clockwork constructs //Borgs with VTEC //Holopigs
			current_move_delay *= min(1.4, mob.pulling.get_pull_push_speed_modifier(current_move_delay))

	if(old_move_delay + (current_move_delay * MOVEMENT_DELAY_BUFFER_DELTA) + MOVEMENT_DELAY_BUFFER > world.time)
		move_delay = old_move_delay
	else
		move_delay = world.time
	mob.last_movement = world.time

	if(locate(/obj/item/grab, mob))
		current_move_delay += 7
	else if(mob.confused)
		var/newdir = NONE
		if(mob.confused > 40)
			newdir = pick(GLOB.alldirs)
		else if(prob(mob.confused * 1.5))
			newdir = angle2dir(dir2angle(direct) + pick(90, -90))
		else if(prob(mob.confused * 3))
			newdir = angle2dir(dir2angle(direct) + pick(45, -45))
		if(newdir)
			direct = newdir
			n = get_step(mob, direct)

	. = mob.SelfMove(n, direct, current_move_delay)
	mob.setDir(direct)

	if((direct & (direct - 1)) && mob.loc == n) //moved diagonally successfully
		current_move_delay *= 1.41 //Will prevent mob diagonal moves from smoothing accurately, sadly

	move_delay += current_move_delay

	if(mob.pulledby)
		mob.pulledby.stop_pulling()

	moving = 0
	if(mob && .)
		if(mob.throwing)
			mob.throwing.finalize(FALSE)

	for(var/obj/O in mob)
		O.on_mob_move(direct, mob)


/mob/proc/SelfMove(turf/n, direct, movetime)
	return Move(n, direct, movetime)

///Process_Grab()
///Called by client/Move()
///Checks to see if you are being grabbed and if so attemps to break it
/client/proc/Process_Grab()
	if(mob.grabbed_by.len)
		if(mob.incapacitated(FALSE, TRUE, TRUE)) // Can't break out of grabs if you're incapacitated
			return TRUE
		var/list/grabbing = list()

		if(istype(mob.l_hand, /obj/item/grab))
			var/obj/item/grab/G = mob.l_hand
			grabbing += G.affecting

		if(istype(mob.r_hand, /obj/item/grab))
			var/obj/item/grab/G = mob.r_hand
			grabbing += G.affecting

		for(var/X in mob.grabbed_by)
			var/obj/item/grab/G = X
			switch(G.state)

				if(GRAB_PASSIVE)
					if(!grabbing.Find(G.assailant)) //moving always breaks a passive grab unless we are also grabbing our grabber.
						qdel(G)

				if(GRAB_AGGRESSIVE)
					move_delay = world.time + 10
					if(!prob(25))
						return TRUE
					mob.visible_message("<span class='danger'>[mob] вырыва[pluralize_ru(mob.gender,"ется","ются")] из хватки [G.assailant]!</span>")
					qdel(G)

				if(GRAB_NECK)
					move_delay = world.time + 10
					if(!prob(5))
						return TRUE
					mob.visible_message("<span class='danger'>[mob] вырыва[pluralize_ru(mob.gender,"ется","ются")] из захвата головы [G.assailant]!</span>")
					qdel(G)
	return FALSE


///Process_Incorpmove
///Called by client/Move()
///Allows mobs to run though walls
/client/proc/Process_Incorpmove(direct)
	var/turf/mobloc = get_turf(mob)
	if(!isliving(mob))
		return
	var/mob/living/L = mob
	switch(L.incorporeal_move)
		if(INCORPOREAL_NORMAL)
			L.forceMove(get_step(L, direct))
			L.dir = direct
		if(INCORPOREAL_NINJA)
			if(prob(50))
				var/locx
				var/locy
				switch(direct)
					if(NORTH)
						locx = mobloc.x
						locy = (mobloc.y+2)
						if(locy>world.maxy)
							return
					if(SOUTH)
						locx = mobloc.x
						locy = (mobloc.y-2)
						if(locy<1)
							return
					if(EAST)
						locy = mobloc.y
						locx = (mobloc.x+2)
						if(locx>world.maxx)
							return
					if(WEST)
						locy = mobloc.y
						locx = (mobloc.x-2)
						if(locx<1)
							return
					else
						return
				L.glide_size = L.glide_size * 2
				L.forceMove(locate(locx,locy,mobloc.z))
				spawn(0)
					var/limit = 2//For only two trailing shadows.
					for(var/turf/T in getline(mobloc, L.loc))
						new /obj/effect/temp_visual/dir_setting/ninja/shadow(T, L.dir)
						limit--
						if(limit<=0)
							break
			else
				new /obj/effect/temp_visual/dir_setting/ninja/shadow(mobloc, L.dir)
				L.forceMove(get_step(L, direct))
			L.dir = direct
		if(INCORPOREAL_REVENANT) //Incorporeal move, but blocked by holy-watered tiles
			var/turf/simulated/floor/stepTurf = get_step(L, direct)
			if(stepTurf.flags & NOJAUNT)
				to_chat(L, "<span class='warning'>Святые силы блокируют ваш путь.</span>")
				L.notransform = 1
				spawn(2)
					L.notransform = 0
			else
				L.forceMove(get_step(L, direct))
				L.dir = direct
	return 1


///Process_Spacemove
///Called by /client/Move()
///For moving in space
///Return 1 for movement 0 for none
/mob/Process_Spacemove(movement_dir = 0)
	if(..())
		return 1
	var/atom/movable/backup = get_spacemove_backup()
	if(backup)
		if(istype(backup) && movement_dir && !backup.anchored)
			var/opposite_dir = turn(movement_dir, 180)
			if(backup.newtonian_move(opposite_dir)) //You're pushing off something movable, so it moves
				to_chat(src, "<span class='notice'>Вы отталкиваетесь от [backup] для продолжения движения.</span>")
		return 1
	return 0

/mob/get_spacemove_backup()
	for(var/A in orange(1, get_turf(src)))
		if(isarea(A))
			continue
		else if(isturf(A))
			var/turf/turf = A
			if(istype(turf, /turf/space))
				continue
			if(!turf.density && !mob_negates_gravity())
				continue
			return A
		else
			var/atom/movable/AM = A
			if(AM == buckled) //Kind of unnecessary but let's just be sure
				continue
			if(!AM.CanPass(src) || AM.density)
				if(AM.anchored)
					return AM
				if(pulling == AM)
					continue
				. = AM


/mob/proc/mob_has_gravity(turf/T)
	return has_gravity(src, T)

/mob/proc/mob_negates_gravity()
	return 0

/mob/proc/Move_Pulled(atom/A)
	if(!canmove || restrained() || !pulling)
		return
	if(pulling.anchored || pulling.move_resist > move_force || !pulling.Adjacent(src))
		stop_pulling()
		return
	if(isliving(pulling))
		var/mob/living/L = pulling
		if(L.buckled && L.buckled.buckle_prevents_pull) //if they're buckled to something that disallows pulling, prevent it
			stop_pulling()
			return
	if(A == loc && pulling.density)
		return
	if(!Process_Spacemove(get_dir(pulling.loc, A)))
		return
	if(ismob(pulling))
		var/mob/M = pulling
		var/atom/movable/t = M.pulling
		M.stop_pulling()
		step(pulling, get_dir(pulling.loc, A))
		if(M)
			M.start_pulling(t)
	else
		step(pulling, get_dir(pulling.loc, A))
	return

/mob/proc/update_gravity(has_gravity)
	return

/client/proc/check_has_body_select()
	return mob && mob.hud_used && mob.hud_used.zone_select && istype(mob.hud_used.zone_select, /obj/screen/zone_sel)

/client/verb/body_toggle_head()
	set name = "body-toggle-head"
	set hidden = 1

	if(!check_has_body_select())
		return

	var/next_in_line
	switch(mob.zone_selected)
		if(BODY_ZONE_HEAD)
			next_in_line = BODY_ZONE_PRECISE_EYES
		if(BODY_ZONE_PRECISE_EYES)
			next_in_line = BODY_ZONE_PRECISE_MOUTH
		else
			next_in_line = BODY_ZONE_HEAD

	var/obj/screen/zone_sel/selector = mob.hud_used.zone_select
	selector.set_selected_zone(next_in_line, mob)

/client/verb/body_r_arm()
	set name = "body-r-arm"
	set hidden = 1
	if(!check_has_body_select())
		return

	var/next_in_line
	if(mob.zone_selected == BODY_ZONE_R_ARM)
		next_in_line = BODY_ZONE_PRECISE_R_HAND
	else
		next_in_line = BODY_ZONE_R_ARM

	var/obj/screen/zone_sel/selector = mob.hud_used.zone_select
	selector.set_selected_zone(next_in_line, mob)

/client/verb/body_chest()
	set name = "body-chest"
	set hidden = 1

	if(!check_has_body_select())
		return
	var/next_in_line
	if(mob.zone_selected == BODY_ZONE_CHEST)
		next_in_line = BODY_ZONE_WING
	else
		next_in_line = BODY_ZONE_CHEST
	var/obj/screen/zone_sel/selector = mob.hud_used.zone_select
	selector.set_selected_zone(next_in_line, mob)

/client/verb/body_l_arm()
	set name = "body-l-arm"
	set hidden = 1

	if(!check_has_body_select())
		return

	var/next_in_line
	if(mob.zone_selected == BODY_ZONE_L_ARM)
		next_in_line = BODY_ZONE_PRECISE_L_HAND
	else
		next_in_line = BODY_ZONE_L_ARM

	var/obj/screen/zone_sel/selector = mob.hud_used.zone_select
	selector.set_selected_zone(next_in_line, mob)

/client/verb/body_r_leg()
	set name = "body-r-leg"
	set hidden = 1

	if(!check_has_body_select())
		return

	var/next_in_line
	if(mob.zone_selected == BODY_ZONE_R_LEG)
		next_in_line = BODY_ZONE_PRECISE_R_FOOT
	else
		next_in_line = BODY_ZONE_R_LEG

	var/obj/screen/zone_sel/selector = mob.hud_used.zone_select
	selector.set_selected_zone(next_in_line, mob)

/client/verb/body_groin()
	set name = "body-groin"
	set hidden = 1

	if(!check_has_body_select())
		return

	var/obj/screen/zone_sel/selector = mob.hud_used.zone_select
	selector.set_selected_zone(BODY_ZONE_PRECISE_GROIN, mob)

/client/verb/body_tail()
	set name = "body-tail"
	set hidden = 1

	if(!check_has_body_select())
		return

	var/obj/screen/zone_sel/selector = mob.hud_used.zone_select
	selector.set_selected_zone(BODY_ZONE_TAIL, mob)

/client/verb/body_l_leg()
	set name = "body-l-leg"
	set hidden = 1

	if(!check_has_body_select())
		return

	var/next_in_line
	if(mob.zone_selected == BODY_ZONE_L_LEG)
		next_in_line = BODY_ZONE_PRECISE_L_FOOT
	else
		next_in_line = BODY_ZONE_L_LEG

	var/obj/screen/zone_sel/selector = mob.hud_used.zone_select
	selector.set_selected_zone(next_in_line, mob)

/client/verb/toggle_walk_run()
	set name = "toggle-walk-run"
	set hidden = TRUE
	set instant = TRUE
	if(mob)
		mob.toggle_move_intent()

/mob/proc/toggle_move_intent()
	if(iscarbon(src))
		var/mob/living/carbon/C = src
		if(C.legcuffed)
			to_chat(C, "<span class='notice'>Ваши ноги скованы! Вы не можете бежать, пока не снимете [C.legcuffed]!</span>")
			C.m_intent = MOVE_INTENT_WALK	//Just incase
			C.hud_used.move_intent.icon_state = "walking"
			return

	var/icon_toggle
	if(m_intent == MOVE_INTENT_RUN)
		m_intent = MOVE_INTENT_WALK
		icon_toggle = "walking"
	else
		m_intent = MOVE_INTENT_RUN
		icon_toggle = "running"

	if(hud_used && hud_used.move_intent && hud_used.static_inventory)
		hud_used.move_intent.icon_state = icon_toggle
		for(var/obj/screen/mov_intent/selector in hud_used.static_inventory)
			selector.update_icon(src)
