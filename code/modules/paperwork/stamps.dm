/obj/item/stamp
	name = "\improper rubber stamp"
	desc = "A rubber stamp for stamping important documents."
	icon = 'icons/obj/bureaucracy.dmi'
	icon_state = "stamp-ok"
	item_state = "stamp"
	throwforce = 0
	w_class = WEIGHT_CLASS_TINY
	throw_speed = 3
	throw_range = 7
	materials = list(MAT_METAL=60)
	item_color = "cargo" //Если у кого-то как у меня возникнет непонимание зачем вообще нужен этот параметр, то он нужен для окрашивания вещей в стиральной машине...
	pressure_resistance = 2
	attack_verb = list("stamped")
	var/list/stamp_sounds = list('sound/effects/stamp1.ogg','sound/effects/stamp2.ogg','sound/effects/stamp3.ogg')

/obj/item/stamp/attack(mob/living/M, mob/living/user)
	. = ..()
	playsound(M, pick(stamp_sounds), 35, 1, -1)

/obj/item/stamp/suicide_act(mob/user)
	user.visible_message("<span class='suicide'>[user] stamps 'VOID' on [user.p_their()] forehead, then promptly falls over, dead.</span>")
	return OXYLOSS

/obj/item/stamp/qm
	name = "Quartermaster's rubber stamp"
	icon_state = "stamp-qm"
	item_color = "qm"

/obj/item/stamp/law
	name = "Law office's rubber stamp"
	icon_state = "stamp-law"
	item_color = "cargo"

/obj/item/stamp/captain
	name = "captain's rubber stamp"
	icon_state = "stamp-cap"
	item_color = "captain"

/obj/item/stamp/hop
	name = "head of personnel's rubber stamp"
	icon_state = "stamp-hop"
	item_color = "hop"

/obj/item/stamp/hos
	name = "head of security's rubber stamp"
	icon_state = "stamp-hos"
	item_color = "hosred"

/obj/item/stamp/warden
	name = "warden's rubber stamp"
	icon_state = "stamp-ward"
	item_color = "hosred"

/obj/item/stamp/ce
	name = "chief engineer's rubber stamp"
	icon_state = "stamp-ce"
	item_color = "chief"

/obj/item/stamp/rd
	name = "research director's rubber stamp"
	icon_state = "stamp-rd"
	item_color = "director"

/obj/item/stamp/cmo
	name = "chief medical officer's rubber stamp"
	icon_state = "stamp-cmo"
	item_color = "medical"

/obj/item/stamp/granted
	name = "\improper GRANTED rubber stamp"
	icon_state = "stamp-ok"
	item_color = "qm"

/obj/item/stamp/denied
	name = "\improper DENIED rubber stamp"
	icon_state = "stamp-deny"
	item_color = "redcoat"

/obj/item/stamp/clown
	name = "clown's rubber stamp"
	icon_state = "stamp-clown"
	item_color = "clown"

/obj/item/stamp/rep
	name = "Nanotrasen Representative's rubber stamp"
	icon_state = "stamp-rep"
	item_color = "rep"

/obj/item/stamp/magistrate
	name = "Magistrate's rubber stamp"
	icon_state = "stamp-magistrate"
	item_color = "rep"

/obj/item/stamp/centcom
	name = "Central Command rubber stamp"
	icon_state = "stamp-cent"
	item_color = "centcom"

/obj/item/stamp/ploho
	name = "'Very Bad, Redo' rubber stamp"
	icon_state = "stamp-ploho"
	item_color = "hop"

/obj/item/stamp/BIGdeny
	name = "BIG DENY rubber stamp"
	icon_state = "stamp-BIGdeny"
	item_color = "redcoat"
	
/obj/item/stamp/navcom
	name = "Nanotrasen Naval Command rubber stamp"
	icon_state = "stamp-navcom"
	item_color = "captain"

/obj/item/stamp/syndicate
	name = "suspicious rubber stamp"
	icon_state = "stamp-syndicate"
	item_color = "syndicate"

/obj/item/stamp/syndicate/taipan
	name = "taipan rubber stamp"
	icon_state = "stamp-taipan"
	item_color = "syndicate"

/obj/item/stamp/mime
	name = "mime's rubber stamp"
	icon_state = "stamp-mime"
	item_color = "mime"
