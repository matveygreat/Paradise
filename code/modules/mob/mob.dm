/mob/Destroy()//This makes sure that mobs with clients/keys are not just deleted from the game.
	GLOB.mob_list -= src
	GLOB.dead_mob_list -= src
	GLOB.alive_mob_list -= src
	input_focus = null
	QDEL_NULL(hud_used)
	if(mind && mind.current == src)
		spellremove(src)
	mobspellremove(src)
	QDEL_LIST(viruses)
	for(var/alert in alerts)
		clear_alert(alert)
	ghostize()
	QDEL_LIST_ASSOC_VAL(tkgrabbed_objects)
	for(var/I in tkgrabbed_objects)
		qdel(tkgrabbed_objects[I])
	tkgrabbed_objects = null
	if(buckled)
		buckled.unbuckle_mob(src, force = TRUE)
	if(viewing_alternate_appearances)
		for(var/datum/alternate_appearance/AA in viewing_alternate_appearances)
			AA.viewers -= src
		viewing_alternate_appearances = null
	LAssailant = null
	return ..()

/mob/Initialize(mapload)
	GLOB.mob_list += src
	if(stat == DEAD)
		GLOB.dead_mob_list += src
	else
		GLOB.alive_mob_list += src
	input_focus = src
	reset_perspective(src)
	prepare_huds()
	. = ..()

/atom/proc/prepare_huds()
	hud_list = list()
	for(var/hud in hud_possible)
		var/hint = hud_possible[hud]
		switch(hint)
			if(HUD_LIST_LIST)
				hud_list[hud] = list()
			else
				var/image/I = image('icons/mob/hud.dmi', src, "")
				I.appearance_flags = RESET_COLOR | RESET_TRANSFORM
				hud_list[hud] = I

/mob/proc/generate_name()
	return name

/mob/proc/GetAltName()
	return ""

/mob/proc/Cell()
	set category = "Admin"
	set hidden = 1

	if(!loc) return 0

	var/datum/gas_mixture/environment = loc.return_air()

	var/t = "<span class='notice'>Coordinates: [x],[y] \n</span>"
	t+= "<span class='warning'>Temperature: [environment.temperature] \n</span>"
	t+= "<span class='notice'>Nitrogen: [environment.nitrogen] \n</span>"
	t+= "<span class='notice'>Oxygen: [environment.oxygen] \n</span>"
	t+= "<span class='notice'>Plasma : [environment.toxins] \n</span>"
	t+= "<span class='notice'>Carbon Dioxide: [environment.carbon_dioxide] \n</span>"
	t+= "<span class='notice'>N2O: [environment.sleeping_agent] \n</span>"
	t+= "<span class='notice'>Agent B: [environment.agent_b] \n</span>"

	usr.show_message(t, 1)

/mob/proc/show_message(msg, type, alt, alt_type)//Message, type of message (1 or 2), alternative message, alt message type (1 or 2)

	if(!client)	return

	if(type)
		if(type & 1 && !has_vision(information_only=TRUE))//Vision related
			if(!( alt ))
				return
			else
				msg = alt
				type = alt_type
		if(type & 2 && !can_hear())//Hearing related
			if(!( alt ))
				return
			else
				msg = alt
				type = alt_type
				if(type & 1 && !has_vision(information_only=TRUE))
					return
	// Added voice muffling for Issue 41.
	if(stat == UNCONSCIOUS || (sleeping > 0 && stat != DEAD))
		to_chat(src, "<I>…Вам почти удаётся расслышать чьи-то слова…</I>")
	else
		to_chat(src, msg)
	return

// Show a message to all mobs in sight of this one
// This would be for visible actions by the src mob
// message is the message output to anyone who can see e.g. "[src] does something!"
// self_message (optional) is what the src mob sees  e.g. "You do something!"
// blind_message (optional) is what blind people will hear e.g. "You hear something!"

/mob/visible_message(var/message, var/self_message, var/blind_message)
	for(var/mob/M in get_mobs_in_view(7, src))
		if(M.see_invisible < invisibility)
			continue //can't view the invisible
		var/msg = message
		if(self_message && M == src)
			msg = self_message
		M.show_message(msg, 1, blind_message, 2)

// Show a message to all mobs in sight of this atom
// Use for objects performing visible actions
// message is output to anyone who can see, e.g. "The [src] does something!"
// blind_message (optional) is what blind people will hear e.g. "You hear something!"
/atom/proc/visible_message(var/message, var/blind_message)
	for(var/mob/M in get_mobs_in_view(7, src))
		if(!M.client)
			continue
		M.show_message(message, 1, blind_message, 2)

// Show a message to all mobs in earshot of this one
// This would be for audible actions by the src mob
// message is the message output to anyone who can hear.
// self_message (optional) is what the src mob hears.
// deaf_message (optional) is what deaf people will see.
// hearing_distance (optional) is the range, how many tiles away the message can be heard.
/mob/audible_message(message, deaf_message, hearing_distance)
	var/range = 7
	if(hearing_distance)
		range = hearing_distance
	var/msg = message
	for(var/mob/M in get_mobs_in_view(range, src))
		M.show_message(msg, 2, deaf_message, 1)

	// based on say code
	var/omsg = replacetext(message, "<B>[src]</B> ", "")
	var/list/listening_obj = new
	for(var/atom/movable/A in view(range, src))
		if(istype(A, /mob))
			var/mob/M = A
			for(var/obj/O in M.contents)
				listening_obj |= O
		else if(istype(A, /obj))
			var/obj/O = A
			listening_obj |= O
	for(var/obj/O in listening_obj)
		O.hear_message(src, omsg)

// Show a message to all mobs in earshot of this atom
// Use for objects performing audible actions
// message is the message output to anyone who can hear.
// deaf_message (optional) is what deaf people will see.
// hearing_distance (optional) is the range, how many tiles away the message can be heard.
/atom/proc/audible_message(message, deaf_message, hearing_distance)
	var/range = 7
	if(hearing_distance)
		range = hearing_distance
	for(var/mob/M in get_mobs_in_view(range, src))
		M.show_message(message, 2, deaf_message, 1)

/mob/proc/findname(msg)
	for(var/mob/M in GLOB.mob_list)
		if(M.real_name == text("[]", msg))
			return M
	return 0

/mob/proc/movement_delay()
	return 0

//This proc is called whenever someone clicks an inventory ui slot.
/mob/proc/attack_ui(slot)
	var/obj/item/W = get_active_hand()

	if(istype(W))
		advanced_equip_to_slot_if_possible(W, slot)
	else if(!restrained())
		W = get_item_by_slot(slot)
		if(W)
			W.attack_hand(src)

	if(ishuman(src) && W == src:head)
		src:update_hair()
		src:update_fhair()

/mob/proc/put_in_any_hand_if_possible(obj/item/W as obj, del_on_fail = 0, disable_warning = 1)
	if(equip_to_slot_if_possible(W, slot_l_hand, del_on_fail, disable_warning))
		return 1
	else if(equip_to_slot_if_possible(W, slot_r_hand, del_on_fail, disable_warning))
		return 1
	return 0


/mob/proc/advanced_equip_to_slot_if_possible(obj/item/W, slot, del_on_fail = 0, disable_warning = 0)
	return equip_to_slot_if_possible(W, slot, del_on_fail, disable_warning)

//This is a SAFE proc. Use this instead of equip_to_slot()!
//set del_on_fail to have it delete W if it fails to equip
//set disable_warning to disable the 'you are unable to equip that' warning.
/mob/proc/equip_to_slot_if_possible(obj/item/W, slot, del_on_fail = 0, disable_warning = 0)
	if(!istype(W)) return 0

	if(!W.mob_can_equip(src, slot, disable_warning))
		if(del_on_fail)
			qdel(W)
		else
			if(!disable_warning)
				to_chat(src, "<span class='warning'>Вы не можете это надеть.</span>")//Only print if del_on_fail is false

		return 0

	equip_to_slot(W, slot) //This proc should not ever fail.
	return 1

//This is an UNSAFE proc. It merely handles the actual job of equipping. All the checks on whether you can or can't eqip need to be done before! Use mob_can_equip() for that task.
//In most cases you will want to use equip_to_slot_if_possible()
/mob/proc/equip_to_slot(obj/item/W, slot)
	return

//This is just a commonly used configuration for the equip_to_slot_if_possible() proc, used to equip people when the rounds tarts and when events happen and such.
/mob/proc/equip_to_slot_or_del(obj/item/W as obj, slot)
	return equip_to_slot_if_possible(W, slot, TRUE, TRUE)

// Convinience proc.  Collects crap that fails to equip either onto the mob's back, or drops it.
// Used in job equipping so shit doesn't pile up at the start loc.
/mob/living/carbon/human/proc/equip_or_collect(var/obj/item/W, var/slot)
	if(W.mob_can_equip(src, slot, 1))
		//Mob can equip.  Equip it.
		equip_to_slot_or_del(W, slot)
	else
		//Mob can't equip it.  Put it their backpack or toss it on the floor
		if(istype(back, /obj/item/storage))
			var/obj/item/storage/S = back
			//Now, B represents a container we can insert W into.
			S.handle_item_insertion(W,1)
			return S

		var/turf/T = get_turf(src)
		if(istype(T))
			W.forceMove(T)
			return T


//The list of slots by priority. equip_to_appropriate_slot() uses this list. Doesn't matter if a mob type doesn't have a slot.
GLOBAL_LIST_INIT(slot_equipment_priority, list( \
		slot_back,\
		slot_wear_pda,\
		slot_wear_id,\
		slot_w_uniform,\
		slot_wear_suit,\
		slot_wear_mask,\
		slot_neck,\
		slot_head,\
		slot_shoes,\
		slot_gloves,\
		slot_l_ear,\
		slot_r_ear,\
		slot_glasses,\
		slot_belt,\
		slot_s_store,\
		slot_tie,\
		slot_l_store,\
		slot_r_store\
	))

//puts the item "W" into an appropriate slot in a human's inventory
//returns 0 if it cannot, 1 if successful
/mob/proc/equip_to_appropriate_slot(obj/item/W, var/ignore_obscured = TRUE)
	if(!istype(W)) return 0

	for(var/slot in GLOB.slot_equipment_priority)
		if(istype(W,/obj/item/storage/) && slot == slot_head) // Storage items should be put on the belt before the head
			continue
		if(ignore_obscured)
			if(equip_to_slot_if_possible(W, slot, del_on_fail = FALSE, disable_warning = TRUE))
				return 1
		else
			if(advanced_equip_to_slot_if_possible(W, slot, del_on_fail = FALSE, disable_warning = TRUE))
				return 1


	return 0

/mob/proc/check_for_open_slot(obj/item/W)
	if(!istype(W)) return 0
	var/openslot = 0
	for(var/slot in GLOB.slot_equipment_priority)
		if(W.mob_check_equip(src, slot, 1) == 1)
			openslot = 1
			break
	return openslot

/obj/item/proc/mob_check_equip(M as mob, slot, disable_warning = 0)
	if(!M) return 0
	if(!slot) return 0
	if(ishuman(M))
		//START HUMAN
		var/mob/living/carbon/human/H = M

		switch(slot)
			if(slot_l_hand)
				if(H.l_hand)
					return 0
				return 1
			if(slot_r_hand)
				if(H.r_hand)
					return 0
				return 1
			if(slot_wear_mask)
				if( !(slot_flags & SLOT_MASK) )
					return 0
				if(H.wear_mask)
					return 0
				return 1
			if(slot_back)
				if( !(slot_flags & SLOT_BACK) )
					return 0
				if(H.back)
					if(!(H.back.flags & NODROP))
						return 2
					else
						return 0
				return 1
			if(slot_wear_suit)
				if( !(slot_flags & SLOT_OCLOTHING) )
					return 0
				if(H.wear_suit)
					if(!(H.wear_suit.flags & NODROP))
						return 2
					else
						return 0
				return 1
			if(slot_gloves)
				if( !(slot_flags & SLOT_GLOVES) )
					return 0
				if(H.gloves)
					if(!(H.gloves.flags & NODROP))
						return 2
					else
						return 0
				return 1
			if(slot_neck)
				if(!(slot_flags & SLOT_NECK))
					return 0
				if(H.neck)
					if(!(H.neck.flags & NODROP))
						return 2
					else
						return 0
				return 1
			if(slot_shoes)
				if( !(slot_flags & SLOT_FEET) )
					return 0
				if(H.shoes)
					if(!(H.shoes.flags & NODROP))
						return 2
					else
						return 0
				return 1
			if(slot_belt)
				if(!H.w_uniform)
					if(!disable_warning)
						to_chat(H, "<span class='warning'>Наденьте комбинезон, чтобы навесить [name] на него.</span>")
					return 0
				if( !(slot_flags & SLOT_BELT) )
					return 0
				if(H.belt)
					if(!(H.belt.flags & NODROP))
						return 2
					else
						return 0
				return 1
			if(slot_glasses)
				if( !(slot_flags & SLOT_EYES) )
					return 0
				if(H.glasses)
					if(!(H.glasses.flags & NODROP))
						return 2
					else
						return 0
				return 1
			if(slot_head)
				if( !(slot_flags & SLOT_HEAD) )
					return 0
				if(H.head)
					if(!(H.head.flags & NODROP))
						return 2
					else
						return 0
				return 1
			if(slot_l_ear)
				if( !(slot_flags & slot_l_ear) )
					return 0
				if(H.l_ear)
					if(!(H.l_ear.flags & NODROP))
						return 2
					else
						return 0
				return 1
			if(slot_r_ear)
				if( !(slot_flags & slot_r_ear) )
					return 0
				if(H.r_ear)
					if(!(H.r_ear.flags & NODROP))
						return 2
					else
						return 0
				return 1
			if(slot_w_uniform)
				if( !(slot_flags & SLOT_ICLOTHING) )
					return 0
				if(H.w_uniform)
					if(!(H.w_uniform.flags & NODROP))
						return 2
					else
						return 0
				return 1
			if(slot_wear_id)
				if(!H.w_uniform)
					if(!disable_warning)
						to_chat(H, "<span class='warning'>Наденьте комбинезон, чтобы прикрепить к нему [name].</span>")
					return 0
				if( !(slot_flags & SLOT_ID) )
					return 0
				if(H.wear_id)
					if(!(H.wear_id.flags & NODROP))
						return 2
					else
						return 0
				return 1
			if(slot_l_store)
				if(H.l_store)
					return 0
				if(!H.w_uniform)
					if(!disable_warning)
						to_chat(H, "<span class='warning'>Наденьте комбинезон, чтобы положить [name] в карман.</span>")
					return 0
				if(slot_flags & SLOT_DENYPOCKET)
					return
				if( w_class <= WEIGHT_CLASS_SMALL || (slot_flags & SLOT_POCKET) )
					return 1
			if(slot_r_store)
				if(H.r_store)
					return 0
				if(!H.w_uniform)
					if(!disable_warning)
						to_chat(H, "<span class='warning'>Наденьте комбинезон, чтобы положить [name] в карман.</span>")
					return 0
				if(slot_flags & SLOT_DENYPOCKET)
					return 0
				if( w_class <= WEIGHT_CLASS_SMALL || (slot_flags & SLOT_POCKET) )
					return 1
				return 0
			if(slot_s_store)
				if(!H.wear_suit)
					if(!disable_warning)
						to_chat(H, "<span class='warning'>Наденьте верхнюю одежду, чтобы положить [name] в карман.</span>")
					return 0
				if(!H.wear_suit.allowed)
					if(!disable_warning)
						to_chat(usr, "Вы как-то достали костюм без хранения разрешенных предметов. Прекратите это.")
					return 0
				if(src.w_class > WEIGHT_CLASS_BULKY)
					if(!disable_warning)
						to_chat(usr, "[name] слишком большого размера и не влезает в карман верхней одежды.")
					return 0
				if( istype(src, /obj/item/pda) || istype(src, /obj/item/pen) || is_type_in_list(src, H.wear_suit.allowed) )
					if(H.s_store)
						if(!(H.s_store.flags & NODROP))
							return 2
						else
							return 0
					else
						return 1
				return 0
			if(slot_handcuffed)
				if(H.handcuffed)
					return 0
				if(!istype(src, /obj/item/restraints/handcuffs))
					return 0
				return 1
			if(slot_legcuffed)
				if(H.legcuffed)
					return 0
				if(!istype(src, /obj/item/restraints/legcuffs))
					return 0
				return 1
			if(slot_in_backpack)
				if(H.back && istype(H.back, /obj/item/storage/backpack))
					var/obj/item/storage/backpack/B = H.back
					if(B.contents.len < B.storage_slots && w_class <= B.max_w_class)
						return 1
				return 0
		return 0 //Unsupported slot
		//END HUMAN

/mob/proc/get_visible_mobs()
	var/list/seen_mobs = list()
	for(var/mob/M in view(src))
		seen_mobs += M

	return seen_mobs

/**
  * Called by using Activate Held Object with an empty hand/limb
  *
  * Does nothing by default. The intended use is to allow limbs to call their
  * own attack_self procs. It is up to the individual mob to override this
  * parent and actually use it.
  */
/mob/proc/limb_attack_self()
	return

/**
 * Returns an assoc list which contains the mobs in range and their "visible" name.
 * Mobs out of view but in range will be listed as unknown. Else they will have their visible name
*/
/mob/proc/get_telepathic_targets()
	var/list/validtargets = new /list()
	var/turf/T = get_turf(src)
	var/list/mobs_in_view = get_visible_mobs()

	for(var/mob/living/M in range(14, T))
		if(M && M.mind)
			if(M == src)
				continue
			var/mob_name
			if(M in mobs_in_view)
				mob_name = M.name
			else
				mob_name = "Unknown entity"
			var/i = 0
			var/result_name
			do
				result_name = mob_name
				if(i++)
					result_name += " ([i])" // Avoid dupes
			while(validtargets[result_name])
			validtargets[result_name] = M
	return validtargets

// If you're looking for `reset_perspective`, that's a synonym for this proc.
/mob/proc/reset_perspective(atom/A)
	if(client)
		if(istype(A, /atom/movable))
			client.perspective = EYE_PERSPECTIVE
			client.eye = A
		else
			if(isturf(loc))
				client.eye = client.mob
				client.perspective = MOB_PERSPECTIVE
			else
				client.perspective = EYE_PERSPECTIVE
				client.eye = loc
		return 1

/mob/living/reset_perspective(atom/A)
	. = ..()
	if(.)
		// Above check means the mob has a client
		update_sight()
		if(client.eye != src)
			var/atom/AT = client.eye
			AT.get_remote_view_fullscreens(src)
		else
			clear_fullscreen("remote_view", 0)
		update_pipe_vision()

/mob/dead/reset_perspective(atom/A)
	. = ..()
	if(.)
		// Allows sharing HUDs with ghosts
		if(hud_used)
			client.screen = list()
			hud_used.show_hud(hud_used.hud_version)

/mob/setDir(new_dir)
	if(forced_look)
		if(isnum(forced_look))
			dir = forced_look
		else
			var/atom/A = locateUID(forced_look)
			if(istype(A))
				dir = get_cardinal_dir(src, A)
		return
	. = ..()

/mob/proc/show_inv(mob/user)
	user.set_machine(src)
	var/dat = {"<meta charset="UTF-8"><table>
	<tr><td><B>Left Hand:</B></td><td><A href='?src=[UID()];item=[slot_l_hand]'>[(l_hand && !(l_hand.flags&ABSTRACT)) ? l_hand : "<font color=grey>Empty</font>"]</A></td></tr>
	<tr><td><B>Right Hand:</B></td><td><A href='?src=[UID()];item=[slot_r_hand]'>[(r_hand && !(r_hand.flags&ABSTRACT)) ? r_hand : "<font color=grey>Empty</font>"]</A></td></tr>
	<tr><td>&nbsp;</td></tr>"}
	dat += {"</table>
	<A href='?src=[user.UID()];mach_close=mob\ref[src]'>Close</A>
	"}

	var/datum/browser/popup = new(user, "mob\ref[src]", "[src]", 440, 250)
	popup.set_content(dat)
	popup.open()

//mob verbs are faster than object verbs. See http://www.byond.com/forum/?post=1326139&page=2#comment8198716 for why this isn't atom/verb/examine()
/mob/verb/examinate(atom/A as mob|obj|turf in view())
	set name = "Examine"
	set category = "IC"

	DEFAULT_QUEUE_OR_CALL_VERB(VERB_CALLBACK(src, PROC_REF(run_examinate), A))

/mob/proc/run_examinate(atom/A)
	if(!has_vision(information_only = TRUE) && !isobserver(src))
		to_chat(src, "<span class='notice'>Здесь что-то есть, но вы не видите — что именно.</span>")
		return 1

	face_atom(A)
	var/list/result = A.examine(src)
	to_chat(src, "<div class='examine'>[result.Join("\n")]</div>")

//same as above
//note: ghosts can point, this is intended
//visible_message will handle invisibility properly
//overriden here and in /mob/dead/observer for different point span classes and sanity checks
/mob/verb/pointed(atom/A as mob|obj|turf)
	set name = "Point To"
	set category = "Object"

	if(next_move >= world.time)
		return
	if(!isturf(loc) || istype(A, /obj/effect/temp_visual/point))
		return FALSE

	DEFAULT_QUEUE_OR_CALL_VERB(VERB_CALLBACK(src, PROC_REF(run_pointed), A))

/// possibly delayed verb that finishes the pointing process starting in [/mob/verb/pointed()].
/// either called immediately or in the tick after pointed() was called, as per the [DEFAULT_QUEUE_OR_CALL_VERB()] macro
/mob/proc/run_pointed(atom/A)
	if(client && !(A in view(client.view, src)))
		return FALSE

	changeNext_move(CLICK_CD_POINT)

	var/tile = get_turf(A)
	if(!tile)
		return FALSE
	var/obj/P = new /obj/effect/temp_visual/point(tile)
	P.invisibility = invisibility
	if(get_turf(src) != tile)
		// Start off from the pointer and make it slide to the pointee
		P.pixel_x = (x - A.x) * 32
		P.pixel_y = (y - A.y) * 32
		animate(P, 0.5 SECONDS, pixel_x = A.pixel_x, pixel_y = A.pixel_y, easing = QUAD_EASING)
	return TRUE

/mob/proc/ret_grab(obj/effect/list_container/mobl/L as obj, flag)
	if((!( istype(l_hand, /obj/item/grab) ) && !( istype(r_hand, /obj/item/grab) )))
		if(!( L ))
			return null
		else
			return L.container
	else
		if(!( L ))
			L = new /obj/effect/list_container/mobl( null )
			L.container += src
			L.master = src
		if(istype(l_hand, /obj/item/grab))
			var/obj/item/grab/G = l_hand
			if(!( L.container.Find(G.affecting) ))
				L.container += G.affecting
				if(G.affecting)
					G.affecting.ret_grab(L, 1)
		if(istype(r_hand, /obj/item/grab))
			var/obj/item/grab/G = r_hand
			if(!( L.container.Find(G.affecting) ))
				L.container += G.affecting
				if(G.affecting)
					G.affecting.ret_grab(L, 1)
		if(!( flag ))
			if(L.master == src)
				var/list/temp = list(  )
				temp += L.container
				//L = null
				qdel(L)
				return temp
			else
				return L.container
	return


/mob/verb/mode()
	set name = "Activate Held Object"
	set category = null
	set src = usr

	if(istype(loc,/obj/mecha)) return

	var/obj/item/I = get_active_hand()
	if(I)
		I.attack_self(src)
		update_inv_l_hand()
		update_inv_r_hand()
		return

	limb_attack_self()

/*
/mob/verb/dump_source()

	var/master = "<PRE>"
	for(var/t in typesof(/area))
		master += text("[]\n", t)
		//Foreach goto(26)
	src << browse(master)
	return
*/


/mob/verb/memory()
	set name = "Notes"
	set category = "IC"
	if(mind)
		mind.show_memory(src)
	else
		to_chat(src, "The game appears to have misplaced your mind datum, so we can't show you your notes.")

/mob/verb/add_memory(msg as message)
	set name = "Add Note"
	set category = "IC"

	msg = copytext(msg, 1, MAX_MESSAGE_LEN)
	msg = sanitize_simple(html_encode(msg), list("\n" = "<BR>"))
	msg = sanitize_censored_patterns(msg)

	var/combined = length(memory + msg)
	if(mind && (combined < MAX_PAPER_MESSAGE_LEN))
		mind.store_memory(msg)
	else if(combined >= MAX_PAPER_MESSAGE_LEN)
		to_chat(src, "Your brain can't hold that much information!")
		return
	else
		to_chat(src, "The game appears to have misplaced your mind datum, so we can't show you your notes.")

/mob/proc/store_memory(msg as message, popup, sane = 1)
	msg = copytext(msg, 1, MAX_MESSAGE_LEN)

	if(sane)
		msg = sanitize(msg)

	if(length(memory) == 0)
		memory += msg
	else
		memory += "<BR>[msg]"

	if(popup)
		memory()

/mob/proc/update_flavor_text()
	set src in usr
	if(usr != src)
		to_chat(usr, "No.")
	var/msg = input(usr,"Set the flavor text in your 'examine' verb. The flavor text should be a physical descriptor of your character at a glance.","Flavor Text",html_decode(flavor_text)) as message|null

	if(msg != null)
		msg = copytext_char(msg, 1, MAX_PAPER_MESSAGE_LEN)
		msg = html_encode(msg)

		flavor_text = msg

/mob/proc/print_flavor_text(var/shrink = TRUE)
	if(flavor_text && flavor_text != "")
		var/msg = replacetext(flavor_text, "\n", " ")
		if(length(msg) <= 60 || !shrink)
			return "<span class='notice'>[html_encode(msg)]</span>" //Repeat after me, "I will not give players access to decoded HTML."
		else
			return "<span class='notice'>[copytext_preserve_html(msg, 1, 57)]... <a href='byond://?src=[UID()];flavor_more=1'>More...</a></span>"

/mob/proc/is_dead()
	return stat == DEAD

/mob
	var/newPlayerType = /mob/new_player

/mob/verb/abandon_mob()
	set name = "Respawn"
	set category = "OOC"

	if(!GLOB.abandon_allowed)
		to_chat(usr, "<span class='warning'>Respawning is disabled.</span>")
		return

	if(stat != DEAD || !SSticker)
		to_chat(usr, "<span class='boldnotice'>You must be dead to use this!</span>")
		return

	if(!(usr in GLOB.respawnable_list))
		to_chat(usr, "You are not dead or you have given up your right to be respawned!")
		return

	var/deathtime = world.time - src.timeofdeath
	if(istype(src,/mob/dead/observer))
		var/mob/dead/observer/G = src
		if(cannotPossess(G))
			to_chat(usr, "<span class='warning'>Upon using the antagHUD you forfeited the ability to join the round.</span>")
			return

	var/deathtimeminutes = round(deathtime / 600)
	var/pluralcheck = "minute"
	if(deathtimeminutes == 0)
		pluralcheck = ""
	else if(deathtimeminutes == 1)
		pluralcheck = " [deathtimeminutes] minute and"
	else if(deathtimeminutes > 1)
		pluralcheck = " [deathtimeminutes] minutes and"
	var/deathtimeseconds = round((deathtime - deathtimeminutes * 600) / 10,1)

	if(deathtimeminutes < config.respawn_delay)
		to_chat(usr, "You have been dead for[pluralcheck] [deathtimeseconds] seconds.")
		to_chat(usr, "<span class='warning'>You must wait [config.respawn_delay] minutes to respawn!</span>")
		return

	if(alert("Are you sure you want to respawn?", "Are you sure?", "Yes", "No") != "Yes")
		return

	add_game_logs("has respawned.", usr)

	to_chat(usr, "<span class='boldnotice'>Make sure to play a different character, and please roleplay correctly!</span>")

	if(!client)
		add_game_logs("respawn failed due to disconnect.", usr)
		return
	client.screen.Cut()
	client.screen += client.void

	if(!client)
		add_game_logs("respawn failed due to disconnect.", usr)
		return

	GLOB.respawnable_list -= usr
	var/mob/new_player/M = new /mob/new_player()
	if(!client)
		add_game_logs("respawn failed due to disconnect.", usr)
		qdel(M)
		return

	M.key = key
	GLOB.respawnable_list += usr
	return

/mob/verb/observe()
	set name = "Observe"
	set category = "OOC"
	var/is_admin = 0

	if(client.holder && (client.holder.rights & R_ADMIN))
		is_admin = 1
	else if(stat != DEAD || isnewplayer(src))
		to_chat(usr, "<span class='notice'>You must be observing to use this!</span>")
		return

	if(is_admin && stat == DEAD)
		is_admin = 0

	var/list/names = list()
	var/list/namecounts = list()
	var/list/creatures = list()

	for(var/obj/O in GLOB.poi_list)
		if(!O.loc)
			continue
		if(istype(O, /obj/item/disk/nuclear))
			var/name = "Nuclear Disk"
			if(names.Find(name))
				namecounts[name]++
				name = "[name] ([namecounts[name]])"
			else
				names.Add(name)
				namecounts[name] = 1
			creatures[name] = O

		if(istype(O, /obj/singularity))
			var/name = "Singularity"
			if(names.Find(name))
				namecounts[name]++
				name = "[name] ([namecounts[name]])"
			else
				names.Add(name)
				namecounts[name] = 1
			creatures[name] = O


	for(var/mob/M in sortAtom(GLOB.mob_list))
		var/name = M.name
		if(names.Find(name))
			namecounts[name]++
			name = "[name] ([namecounts[name]])"
		else
			names.Add(name)
			namecounts[name] = 1

		creatures[name] = M


	client.perspective = EYE_PERSPECTIVE

	var/eye_name = null

	var/ok = "[is_admin ? "Admin Observe" : "Observe"]"
	eye_name = input("Please, select a player!", ok, null, null) as null|anything in creatures

	if(!eye_name)
		return

	var/mob/mob_eye = creatures[eye_name]

	if(client && mob_eye)
		client.eye = mob_eye

/mob/verb/cancel_camera()
	set name = "Cancel Camera View"
	set category = "OOC"
	reset_perspective(null)
	unset_machine()
	if(istype(src, /mob/living))
		if(src:cameraFollow)
			src:cameraFollow = null

/mob/Topic(href, href_list)
	. = ..()
	if(href_list["mach_close"])
		var/t1 = text("window=[href_list["mach_close"]]")
		unset_machine()
		src << browse(null, t1)

	if(href_list["refresh"])
		if(machine && in_range(src, usr))
			show_inv(machine)

	if(!usr.incapacitated() && in_range(src, usr))
		if(href_list["item"])
			var/slot = text2num(href_list["item"])
			var/obj/item/what = get_item_by_slot(slot)

			if(what)
				usr.stripPanelUnequip(what,src,slot)
			else
				usr.stripPanelEquip(what,src,slot)

	if(usr.machine == src)
		if(Adjacent(usr))
			show_inv(usr)
		else
			usr << browse(null,"window=mob\ref[src]")

	if(href_list["flavor_more"])
		usr << browse(text({"<HTML><meta charset="UTF-8"><HEAD><TITLE>[]</TITLE></HEAD><BODY><TT>[]</TT></BODY></HTML>"}, name, replacetext(flavor_text, "\n", "<BR>")), text("window=[];size=500x200", name))
		onclose(usr, "[name]")
	if(href_list["flavor_change"])
		update_flavor_text()

// The src mob is trying to strip an item from someone
// Defined in living.dm
/mob/proc/stripPanelUnequip(obj/item/what, mob/who)
	return

// The src mob is trying to place an item on someone
// Defined in living.dm
/mob/proc/stripPanelEquip(obj/item/what, mob/who)
	return

/mob/MouseDrop(mob/M as mob)
	..()
	if(M != usr) return
	if(isliving(M))
		var/mob/living/L = M
		if(L.mob_size <= MOB_SIZE_SMALL)
			return // Stops pAI drones and small mobs (borers, parrots, crabs) from stripping people. --DZD
	if(!M.can_strip)
		return
	if(usr == src)
		return
	if(!Adjacent(usr))
		return
	if(IsFrozen(src) && !is_admin(usr))
		to_chat(usr, "<span class='boldannounce'>Interacting with admin-frozen players is not permitted.</span>")
		return
	if(isLivingSSD(src) && M.client && M.client.send_ssd_warning(src))
		return
	show_inv(usr)

/mob/proc/can_use_hands()
	return

/mob/proc/is_mechanical()
	return mind && (mind.assigned_role == "Cyborg" || mind.assigned_role == "AI")

/mob/proc/is_ready()
	return client && !!mind

/mob/proc/is_in_brig()
	if(!loc || !loc.loc)
		return 0

	// They should be in a cell or the Brig portion of the shuttle.
	var/area/A = loc.loc
	if(!istype(A, /area/security/prison))
		if(!istype(A, /area/shuttle/escape) || loc.name != "Brig floor")
			return 0

	// If they still have their ID they're not brigged.
	for(var/obj/item/card/id/card in src)
		return 0
	for(var/obj/item/pda/P in src)
		if(P.id)
			return 0

	return 1

/mob/proc/get_gender()
	return gender

/mob/proc/is_muzzled()
	return 0

/mob/Stat()
	..()

	show_stat_turf_contents()

	statpanel("Status") // We only want alt-clicked turfs to come before Status
	stat(null, "Round ID: [GLOB.round_id ? GLOB.round_id : "NULL"]")

	if(mob_spell_list && mob_spell_list.len)
		for(var/obj/effect/proc_holder/spell/S in mob_spell_list)
			add_spell_to_statpanel(S)
	if(mind && istype(src, /mob/living) && mind.spell_list && mind.spell_list.len)
		for(var/obj/effect/proc_holder/spell/S in mind.spell_list)
			add_spell_to_statpanel(S)

	// Allow admins + PR reviewers to VIEW the panel. Doesnt mean they can click things.
	if(is_admin(src) || check_rights(R_VIEWRUNTIMES, FALSE))
		if(statpanel("MC")) //looking at that panel
			var/turf/T = get_turf(client.eye)
			stat("Location:", COORD(T))
			stat("CPU:", "[Master.formatcpu()]")
			stat("Map CPU:", "[Master.format_mapcpu()]")
			stat("Instances:", "[num2text(world.contents.len, 10)]")
			GLOB.stat_entry()
			stat("Server Time:", time_stamp())
			stat(null)
			if(Master)
				Master.stat_entry()
			else
				stat("Master Controller:", "ERROR")
			if(Failsafe)
				Failsafe.stat_entry()
			else
				stat("Failsafe Controller:", "ERROR")
			if(Master)
				stat(null)
				for(var/datum/controller/subsystem/SS in Master.subsystems)
					SS.stat_entry()

	statpanel("Status") // Switch to the Status panel again, for the sake of the lazy Stat procs

	if(client && client.statpanel == "Status" && SSticker)
		show_stat_station_time()

// this function displays the station time in the status panel
/mob/proc/show_stat_station_time()
	stat(null, "Current Map: [SSmapping.map_datum.name]")
	if(SSmapping.next_map)
		stat(null, "Next Map: [SSmapping.next_map.name]")
	stat(null, "Round Time: [worldtime2text()]")
	stat(null, "Station Time: [station_time_timestamp()]")
	stat(null, "Server TPS: [world.fps]")
	stat(null, "Desired Client FPS: [client?.prefs?.clientfps]")
	stat(null, "Time Dilation: [round(SStime_track.time_dilation_current,1)]% " + \
				"AVG:([round(SStime_track.time_dilation_avg_fast,1)]%, " + \
				"[round(SStime_track.time_dilation_avg,1)]%, " + \
				"[round(SStime_track.time_dilation_avg_slow,1)]%)")
	stat(null, "Ping: [round(client.lastping, 1)]ms (Average: [round(client.avgping, 1)]ms)")

// this function displays the shuttles ETA in the status panel if the shuttle has been called
/mob/proc/show_stat_emergency_shuttle_eta()
	var/ETA = SSshuttle.emergency.getModeStr()
	if(ETA)
		stat(null, "[ETA] [SSshuttle.emergency.getTimerStr()]")

/mob/proc/show_stat_turf_contents()
	if(listed_turf && client)
		if(!TurfAdjacent(listed_turf))
			listed_turf = null
		else
			statpanel(listed_turf.name, null, listed_turf)
			var/list/statpanel_things = list()
			for(var/foo in listed_turf)
				var/atom/A = foo
				if(A.invisibility > see_invisible)
					continue
				if(is_type_in_list(A, shouldnt_see) || !A.simulated)
					continue
				statpanel_things += A
			statpanel(listed_turf.name, null, statpanel_things)

/mob/proc/add_spell_to_statpanel(var/obj/effect/proc_holder/spell/S)
	switch(S.charge_type)
		if("recharge")
			statpanel(S.panel,"[S.charge_counter/10.0]/[S.charge_max/10]",S)
		if("charges")
			statpanel(S.panel,"[S.charge_counter]/[S.charge_max]",S)
		if("holdervar")
			statpanel(S.panel,"[S.holder_var_type] [S.holder_var_amount]",S)

// facing verbs
/mob/proc/canface()
	if(!canmove)						return 0
	if(client.moving)					return 0
	if(stat==2)							return 0
	if(anchored)						return 0
	if(notransform)						return 0
	if(restrained())					return 0
	return 1

/mob/proc/fall(var/forced)
	drop_l_hand()
	drop_r_hand()

/mob/proc/facedir(ndir)
	if(!canface())
		return FALSE
	setDir(ndir)
	client.move_delay += movement_delay()
	return TRUE


/mob/verb/eastface()
	set hidden = 1
	return facedir(EAST)


/mob/verb/westface()
	set hidden = 1
	return facedir(WEST)


/mob/verb/northface()
	set hidden = 1
	return facedir(NORTH)


/mob/verb/southface()
	set hidden = 1
	return facedir(SOUTH)


/mob/proc/IsAdvancedToolUser()//This might need a rename but it should replace the can this mob use things check
	return FALSE

/mob/proc/swap_hand()
	return

/mob/proc/activate_hand(selhand)
	return

/mob/dead/observer/verb/respawn()
	set name = "Respawn as NPC"
	set category = "Ghost"

	if(jobban_isbanned(usr, ROLE_SENTIENT))
		to_chat(usr, "<span class='warning'>You are banned from playing as sentient animals.</span>")
		return

	if(!SSticker || SSticker.current_state < 3)
		to_chat(src, "<span class='warning'>You can't respawn as an NPC before the game starts!</span>")
		return

	if(stat==2 || istype(usr,/mob/dead/observer)) // Always can respawn as NPC
		var/list/creatures = list("Mouse")
		for(var/mob/living/L in GLOB.alive_mob_list)
			if(safe_respawn(L.type) && L.stat!=2)
				if(!L.key)
					creatures += L
		var/picked = input("Please select an NPC to respawn as", "Respawn as NPC")  as null|anything in creatures
		switch(picked)
			if("Mouse")
				GLOB.respawnable_list -= usr
				become_mouse()
//				spawn(5)
//					GLOB.respawnable_list += usr
			else
				var/mob/living/NPC = picked
				if(istype(NPC) && !NPC.key)
					GLOB.respawnable_list -= usr
					NPC.key = key
//					spawn(5)
//						GLOB.respawnable_list += usr
	else
		to_chat(usr, "You are not dead or you have given up your right to be respawned!")
		return


/mob/proc/become_mouse()
	var/timedifference = world.time - client.time_joined_as_mouse
	if(client.time_joined_as_mouse && timedifference <= GLOB.mouse_respawn_time * 600)
		var/timedifference_text = time2text(GLOB.mouse_respawn_time * 600 - timedifference,"mm:ss")
		to_chat(src, "<span class='warning'>You may only spawn again as a mouse more than [GLOB.mouse_respawn_time] minutes after last spawn. You have [timedifference_text] left.</span>")
		return

	//find a viable mouse candidate
	var/list/found_vents = get_valid_vent_spawns(min_network_size = 0, station_levels_only = FALSE, z_level = z)
	if(length(found_vents))
		client.time_joined_as_mouse = world.time
		var/obj/vent_found = pick(found_vents)
		var/choosen_type = prob(90) ? /mob/living/simple_animal/mouse : /mob/living/simple_animal/mouse/rat
		var/mob/living/simple_animal/mouse/host = new choosen_type(vent_found.loc)
		host.ckey = src.ckey
		if(istype(get_area(vent_found), /area/syndicate/unpowered/syndicate_space_base))
			host.faction += "syndicate"
		to_chat(host, "<span class='info'>You are now a mouse. Try to avoid interaction with players, and do not give hints away that you are more than a simple rodent.</span>")
	else
		to_chat(src, "<span class='warning'>Unable to find any unwelded vents to spawn mice at.</span>")

/mob/proc/assess_threat() //For sec bot threat assessment
	return 5

/mob/proc/get_ghost(even_if_they_cant_reenter = 0)
	if(mind)
		return mind.get_ghost(even_if_they_cant_reenter)

/mob/proc/grab_ghost(force)
	if(mind)
		return mind.grab_ghost(force = force)

/mob/proc/notify_ghost_cloning(message = "Someone is trying to revive you. Re-enter your corpse if you want to be revived!", sound = 'sound/effects/genetics.ogg', atom/source = null, flashwindow = TRUE)
	var/mob/dead/observer/ghost = get_ghost()
	if(ghost)
		if(flashwindow)
			window_flash(ghost.client)
		ghost.notify_cloning(message, sound, source)
		return ghost

/mob/proc/fakevomit(green = 0, no_text = 0) //for aesthetic vomits that need to be instant and do not stun. -Fox
	if(stat==DEAD)
		return
	var/turf/location = loc
	if(istype(location, /turf/simulated))
		if(green)
			if(!no_text)
				visible_message("<span class='warning'>[src.name] вырвало зелёной липкой массой!</span>","<span class='warning'>Вас вырвало зелёной липкой массой!</span>")
			location.add_vomit_floor(FALSE, TRUE)
		else
			if(!no_text)
				visible_message("<span class='warning'>[src.name] наблевал[genderize_ru(src.gender,"","а","о","и")] на себя!</span>","<span class='warning'>Вы наблевали на себя!</span>")
			location.add_vomit_floor(TRUE)

/mob/proc/AddSpell(obj/effect/proc_holder/spell/S)
	mob_spell_list += S
	S.action.Grant(src)

/mob/proc/RemoveSpell(obj/effect/proc_holder/spell/spell) //To remove a specific spell from a mind
	if(!spell)
		return
	for(var/obj/effect/proc_holder/spell/S in mob_spell_list)
		if(istype(S, spell))
			qdel(S)
			mob_spell_list -= S

//override to avoid rotating pixel_xy on mobs
/mob/shuttleRotate(rotation)
	dir = angle2dir(rotation+dir2angle(dir))

/mob/proc/handle_ventcrawl()
	return // Only living mobs can ventcrawl

/**
  * Buckle to another mob
  *
  * You can buckle on mobs if you're next to them since most are dense
  *
  * Turns you to face the other mob too
  */
/mob/buckle_mob(mob/living/M, force = FALSE, check_loc = TRUE)
	if(M.buckled)
		return 0
	var/turf/T = get_turf(src)
	if(M.loc != T)
		var/old_density = density
		density = FALSE
		var/can_step = step_towards(M, T)
		density = old_density
		if(!can_step)
			return 0
	return ..()

///Call back post buckle to a mob to offset your visual height
/mob/post_buckle_mob(mob/living/M)
	var/height = M.get_mob_buckling_height(src)
	M.pixel_y = initial(M.pixel_y) + height
	if(M.layer < layer)
		M.layer = layer + 0.1

///Call back post unbuckle from a mob, (reset your visual height here)
/mob/post_unbuckle_mob(mob/living/M)
	M.layer = initial(M.layer)
	M.pixel_y = initial(M.pixel_y)

///returns the height in pixel the mob should have when buckled to another mob.
/mob/proc/get_mob_buckling_height(mob/seat)
	if(isliving(seat))
		var/mob/living/L = seat
		if(L.mob_size <= MOB_SIZE_SMALL) //being on top of a small mob doesn't put you very high.
			return 0
	return 9

///can the mob be buckled to something by default?
/mob/proc/can_buckle()
	return 1

///can the mob be unbuckled from something by default?
/mob/proc/can_unbuckle()
	return 1


//Can the mob see reagents inside of containers?
/mob/proc/can_see_reagents()
	return 0

//Can this mob leave its location without breaking things terrifically?
/mob/proc/can_safely_leave_loc()
	return 1 // Yes, you can

/mob/proc/IsVocal()
	return 1

/mob/proc/get_access_locations()
	return list()

//Must return list or IGNORE_ACCESS
/mob/proc/get_access()
	. = list()
	for(var/obj/item/access_location in get_access_locations())
		. |= access_location.GetAccess()

/*
 * * Creates Log Record for Log Viewer
 * log_type - look __DEFINES/logs.dm (example: ATTACK_LOG, SAY_LOG, MISC_LOGS)
 * what - happened that got logged a mob. Someone screamed or planted an explosion
 * target - who targeted
 * where(optional) - at what placed
 */
/mob/proc/create_log(log_type, what, target = null, turf/where = get_turf(src))
	if(!ckey)
		return
	var/real_ckey = ckey
	if(ckey[1] == "@") // Admin aghosting will do this
		real_ckey = copytext(ckey, 2)
	var/datum/log_record/record = new(log_type, src, what, target, where, world.time)
	GLOB.logging.add_log(real_ckey, record)

/mob/vv_get_dropdown()
	. = ..()
	.["Show player panel"] = "?_src_=vars;mob_player_panel=[UID()]"

	.["Give Spell"] = "?_src_=vars;give_spell=[UID()]"
	.["Give Martial Art"] = "?_src_=vars;givemartialart=[UID()]"
	.["Give Disease"] = "?_src_=vars;give_disease=[UID()]"
	.["Give Taipan Hud"] = "?_src_=vars;give_taipan_hud=[UID()]"
	.["Toggle Godmode"] = "?_src_=vars;godmode=[UID()]"
	.["Toggle Build Mode"] = "?_src_=vars;build_mode=[UID()]"

	.["Make 2spooky"] = "?_src_=vars;make_skeleton=[UID()]"

	.["Assume Direct Control"] = "?_src_=vars;direct_control=[UID()]"
	.["Offer Control to Ghosts"] = "?_src_=vars;offer_control=[UID()]"
	.["Drop Everything"] = "?_src_=vars;drop_everything=[UID()]"

	.["Regenerate Icons"] = "?_src_=vars;regenerateicons=[UID()]"
	.["Add Language"] = "?_src_=vars;addlanguage=[UID()]"
	.["Remove Language"] = "?_src_=vars;remlanguage=[UID()]"
	.["Grant All Language"] = "?_src_=vars;grantalllanguage=[UID()]"
	.["Change Voice"] = "?_src_=vars;changevoice=[UID()]"
	.["Add Organ"] = "?_src_=vars;addorgan=[UID()]"
	.["Remove Organ"] = "?_src_=vars;remorgan=[UID()]"

	.["Add Verb"] = "?_src_=vars;addverb=[UID()]"
	.["Remove Verb"] = "?_src_=vars;remverb=[UID()]"

	.["Gib"] = "?_src_=vars;gib=[UID()]"

///Can this mob resist (default FALSE)
/mob/proc/can_resist()
	return FALSE		//overridden in living.dm

/mob/proc/spin(spintime, speed)
	set waitfor = FALSE
	var/D = dir
	if(spintime < world.tick_lag || speed < world.tick_lag || !spintime || !speed)
		return
	while(spintime >= speed)
		sleep(speed)
		switch(D)
			if(NORTH)
				D = EAST
			if(SOUTH)
				D = WEST
			if(EAST)
				D = SOUTH
			if(WEST)
				D = NORTH
		setDir(D)
		spintime -= speed

/mob/proc/is_literate()
	return FALSE

/mob/proc/faction_check_mob(mob/target, exact_match)
	if(exact_match) //if we need an exact match, we need to do some bullfuckery.
		var/list/faction_src = faction.Copy()
		var/list/faction_target = target.faction.Copy()
		if(!("\ref[src]" in faction_target)) //if they don't have our ref faction, remove it from our factions list.
			faction_src -= "\ref[src]" //if we don't do this, we'll never have an exact match.
		if(!("\ref[target]" in faction_src))
			faction_target -= "\ref[target]" //same thing here.
		return faction_check(faction_src, faction_target, TRUE)
	return faction_check(faction, target.faction, FALSE)

/proc/faction_check(list/faction_A, list/faction_B, exact_match)
	var/list/match_list
	if(exact_match)
		match_list = faction_A & faction_B //only items in both lists
		var/length = LAZYLEN(match_list)
		if(length)
			return (length == LAZYLEN(faction_A)) //if they're not the same len(gth) or we don't have a len, then this isn't an exact match.
	else
		match_list = faction_A & faction_B
		return LAZYLEN(match_list)
	return FALSE

/mob/proc/update_sight()
	SEND_SIGNAL(src, COMSIG_MOB_UPDATE_SIGHT)
	sync_lighting_plane_alpha()

/mob/proc/set_sight(datum/vision_override/O)
	QDEL_NULL(vision_type)
	if(O) //in case of null
		vision_type = new O
	update_sight()

/mob/proc/sync_lighting_plane_alpha()
	if(hud_used)
		var/obj/screen/plane_master/lighting/L = hud_used.plane_masters["[LIGHTING_PLANE]"]
		if(L)
			L.alpha = lighting_alpha

	sync_nightvision_screen() //Sync up the overlay used for nightvision to the amount of see_in_dark a mob has. This needs to be called everywhere sync_lighting_plane_alpha() is.

/mob/proc/sync_nightvision_screen()
	var/obj/screen/fullscreen/see_through_darkness/S = screens["see_through_darkness"]
	if(S)
		var/suffix = ""
		switch(see_in_dark)
			if(3 to 8)
				suffix = "_[see_in_dark]"
			if(8 to INFINITY)
				suffix = "_8"

		S.icon_state = "[initial(S.icon_state)][suffix]"

///Adjust the nutrition of a mob
/mob/proc/adjust_nutrition(change)
	nutrition = max(0, nutrition + change)

///Force set the mob nutrition
/mob/proc/set_nutrition(change)
	nutrition = max(0, change)

/mob/clean_blood(clean_hands = TRUE, clean_mask = TRUE, clean_feet = TRUE)
	. = ..()
	if(bloody_hands && clean_hands)
		bloody_hands = 0
		update_inv_gloves()
	if(l_hand)
		if(l_hand.clean_blood())
			update_inv_l_hand()
	if(r_hand)
		if(r_hand.clean_blood())
			update_inv_r_hand()
	if(back)
		if(back.clean_blood())
			update_inv_back()
	if(wear_mask && clean_mask)
		if(wear_mask.clean_blood())
			update_inv_wear_mask()
	if(clean_feet)
		feet_blood_color = null
		qdel(feet_blood_DNA)
		bloody_feet = list(BLOOD_STATE_HUMAN = 0, BLOOD_STATE_XENO = 0,  BLOOD_STATE_NOT_BLOODY = 0)
		blood_state = BLOOD_STATE_NOT_BLOODY
		update_inv_shoes()
	update_icons()	//apply the now updated overlays to the mob

///Makes a call in the context of a different usr. Use sparingly
/world/proc/invoke_callback_with_usr(mob/user_mob, datum/callback/invoked_callback, ...)
	var/temp = usr
	usr = user_mob
	if (length(args) > 2)
		. = invoked_callback.Invoke(arglist(args.Copy(3)))
	else
		. = invoked_callback.Invoke()
	usr = temp
