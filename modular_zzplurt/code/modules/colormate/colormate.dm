#define COLORMATE_TINT 1
#define COLORMATE_HSV 2
#define COLORMATE_MATRIX 3

/obj/machinery/gear_painter
	name = "\improper ColorMate"
	desc = "A machine to give your apparel a fresh new color!"
	icon = 'modular_zzplurt/icons/obj/machines/colormate.dmi'
	icon_state = "colormate"
	// light_mask = "colormate-light-mask"
	density = TRUE
	anchored = TRUE
	circuit = /obj/item/circuitboard/machine/colormate
	var/atom/movable/inserted
	var/activecolor = "#FFFFFF"
	var/list/color_matrix_last
	var/active_mode = COLORMATE_HSV

	var/build_hue = 0
	var/build_sat = 1
	var/build_val = 1
	/// Allow holder'd mobs
	var/allow_mobs = TRUE
	/// Minimum lightness for normal mode
	var/minimum_normal_lightness = 50
	/// Minimum lightness for matrix mode, tested using 4 test colors of full red, green, blue, white.
	var/minimum_matrix_lightness = 75
	/// Minimum matrix tests that must pass for something to be considered a valid color (see above)
	var/minimum_matrix_tests = 2
	var/list/allowed_types = list(
			/obj/item/clothing,
			/obj/item/storage/backpack,
			/obj/item/storage/belt
			)
	/// Temporary messages
	var/temp

/obj/machinery/gear_painter/Initialize(mapload)
	. = ..()
	color_matrix_last = list(
		1, 0, 0,
		0, 1, 0,
		0, 0, 1,
		0, 0, 0
	)

/obj/machinery/gear_painter/update_icon_state()
	if(panel_open)
		icon_state = "colormate_open"
	else if(!is_operational)
		icon_state = "colormate_off"
	else if(inserted)
		icon_state = "colormate_active"
	else
		icon_state = "colormate"

	return ..()

/obj/machinery/gear_painter/Destroy()
	if(inserted) //please i beg you do not drop nulls
		inserted.forceMove(drop_location())
	return ..()

/obj/machinery/gear_painter/attackby(obj/item/I, mob/living/user, list/modifiers, list/attack_modifiers)
	if(inserted)
		to_chat(user, "<span class='warning'>The machine is already loaded.</span>")
		return
	if(default_deconstruction_screwdriver(user, "colormate_open", "colormate", I))
		return
	if(default_deconstruction_crowbar(I))
		return
	if(default_unfasten_wrench(user, I, 40))
		return
	if(allow_mobs && istype(I, /obj/item/mob_holder))
		var/obj/item/mob_holder/H = I
		var/mob/victim = H.held_mob
		if(!user.transferItemToLoc(I, src))
			to_chat(user, "<span class='warning'>[I] is stuck to your hand!</span>")
			return
		if(!QDELETED(H))
			H.release()

		insert_mob(victim, user)
		SStgui.update_uis(src)

	if(is_type_in_list(I, allowed_types) && is_operational)
		if(!user.transferItemToLoc(I, src))
			to_chat(user, "<span class='warning'>[I] is stuck to your hand!</span>")
			return
		if(QDELETED(I))
			return
		user.visible_message("<span class='notice'>[user] inserts [I] into [src]'s receptable.</span>")

		inserted = I
		update_icon()
		SStgui.update_uis(src)

	else
		return ..()

/obj/machinery/gear_painter/proc/insert_mob(mob/victim, mob/user)
	if(inserted)
		return
	if(user)
		visible_message("<span class='warning'>[user] stuffs [victim] into [src]!</span>")
	inserted = victim
	inserted.forceMove(src)

/obj/machinery/gear_painter/AllowDrop()
	return FALSE

// /obj/machinery/gear_painter/handle_atom_del(atom/movable/AM)
// 	if(AM == inserted)
// 		inserted = null
// 	return ..()

/obj/machinery/gear_painter/click_alt(mob/user)
	. = ..()
	drop_item()

/obj/machinery/gear_painter/proc/drop_item()
	if(!usr.CanReach(src))
		return
	if(!inserted)
		return
	to_chat(usr, "<span class='notice'>You remove [inserted] from [src]")
	inserted.forceMove(drop_location())
	var/mob/living/user = usr
	if(istype(user))
		user.put_in_hands(inserted)
	inserted = null
	update_icon()
	SStgui.update_uis(src)

/obj/machinery/gear_painter/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "Colormate", src.name)
		ui.set_autoupdate(FALSE) //This might be a bit intensive, better to not update it every few ticks
		ui.open()

/obj/machinery/gear_painter/ui_data(mob/user)
	. = list()
	.["activemode"] = active_mode
	.["matrixcolors"] = list(
			"rr" = color_matrix_last[1],
			"rg" = color_matrix_last[2],
			"rb" = color_matrix_last[3],
			"gr" = color_matrix_last[4],
			"gg" = color_matrix_last[5],
			"gb" = color_matrix_last[6],
			"br" = color_matrix_last[7],
			"bg" = color_matrix_last[8],
			"bb" = color_matrix_last[9],
			"cr" = color_matrix_last[10],
			"cg" = color_matrix_last[11],
			"cb" = color_matrix_last[12]
			)
	.["buildhue"] = build_hue
	.["buildsat"] = build_sat
	.["buildval"] = build_val
	if(temp)
		.["temp"] = temp
	if(inserted)
		.["item"] = list()
		.["item"]["name"] = inserted.name
		.["item"]["sprite"] = icon2base64(getFlatIcon(inserted,defdir=SOUTH,no_anim=TRUE))
		.["item"]["preview"] = icon2base64(build_preview())
	else
		.["item"] = null

/obj/machinery/gear_painter/ui_act(action, params)
	. = ..()
	if(.)
		return
	if(inserted)
		switch(action)
			if("switch_modes")
				active_mode = text2num(params["mode"])
				return TRUE
			if("choose_color")
				var/chosen_color = tgui_color_picker(usr, "Choose a color: ", "Colormate color picking", activecolor)
				if(chosen_color)
					activecolor = chosen_color
				return TRUE
			if("paint")
				do_paint(usr)
				temp = "Painted Successfully!"
				return TRUE
			if("drop")
				temp = ""
				drop_item()
				return TRUE
			if("clear")
				inserted.remove_atom_colour(FIXED_COLOUR_PRIORITY)
				playsound(src, 'sound/effects/spray3.ogg', 50, 1)
				temp = "Cleared Successfully!"
				return TRUE
			if("set_matrix_color")
				color_matrix_last[params["color"]] = params["value"]
				return TRUE
			if("set_hue")
				build_hue = clamp(text2num(params["buildhue"]), 0, 360)
				return TRUE
			if("set_sat")
				build_sat = clamp(text2num(params["buildsat"]), -10, 10)
				return TRUE
			if("set_val")
				build_val = clamp(text2num(params["buildval"]), -10, 10)
				return TRUE


/obj/machinery/gear_painter/proc/do_paint(mob/user)
	var/color_to_use
	switch(active_mode)
		if(COLORMATE_TINT)
			color_to_use = activecolor
		if(COLORMATE_MATRIX)
			color_to_use = rgb_construct_color_matrix(
							text2num(color_matrix_last[1]),
							text2num(color_matrix_last[2]),
							text2num(color_matrix_last[3]),
							text2num(color_matrix_last[4]),
							text2num(color_matrix_last[5]),
							text2num(color_matrix_last[6]),
							text2num(color_matrix_last[7]),
							text2num(color_matrix_last[8]),
							text2num(color_matrix_last[9]),
							text2num(color_matrix_last[10]),
							text2num(color_matrix_last[11]),
							text2num(color_matrix_last[12])
							)
		if(COLORMATE_HSV)
			color_to_use = color_matrix_hsv(build_hue, build_sat, build_val)
			color_matrix_last = color_to_use
	if(!color_to_use || !check_valid_color(color_to_use, user))
		to_chat(user, "<span class='notice'>Invalid color.</span>")
		return FALSE
	inserted.add_atom_colour(color_to_use, FIXED_COLOUR_PRIORITY)
	playsound(src, 'sound/effects/spray3.ogg', 50, 1)
	return TRUE


/// Produces the preview image of the item, used in the UI, the way the color is not stacking is a sin.
/obj/machinery/gear_painter/proc/build_preview()
	if(inserted) //sanity
		var/list/cm
		switch(active_mode)
			if(COLORMATE_MATRIX)
				cm = rgb_construct_color_matrix(
							text2num(color_matrix_last[1]),
							text2num(color_matrix_last[2]),
							text2num(color_matrix_last[3]),
							text2num(color_matrix_last[4]),
							text2num(color_matrix_last[5]),
							text2num(color_matrix_last[6]),
							text2num(color_matrix_last[7]),
							text2num(color_matrix_last[8]),
							text2num(color_matrix_last[9]),
							text2num(color_matrix_last[10]),
							text2num(color_matrix_last[11]),
							text2num(color_matrix_last[12])
							)
				if(!check_valid_color(cm, usr))
					return getFlatIcon(inserted, defdir=SOUTH, no_anim=TRUE)

			if(COLORMATE_TINT)
				if(!check_valid_color(activecolor, usr))
					return getFlatIcon(inserted, defdir=SOUTH, no_anim=TRUE)

			if(COLORMATE_HSV)
				cm = color_matrix_hsv(build_hue, build_sat, build_val)
				color_matrix_last = cm
				if(!check_valid_color(cm, usr))
					return getFlatIcon(inserted, defdir=SOUTH, no_anim=TRUE)

		var/cur_color = inserted.color
		inserted.color = null
		inserted.color = (active_mode == COLORMATE_TINT ? activecolor : cm)
		var/icon/preview = getFlatIcon(inserted, defdir=SOUTH, no_anim=TRUE)
		inserted.color = cur_color
		temp = ""

		. = preview

/obj/machinery/gear_painter/proc/check_valid_color(list/cm, mob/user)
	// if(!islist(cm))		// normal
		// var/list/HSV = rgb2hsv(cm)
		// if(HSV[3] < minimum_normal_lightness)
		// 	temp = "[cm] is too dark (Minimum lightness: [minimum_normal_lightness])"
		// 	return FALSE
		// return TRUE
	// else	// matrix
		// We test using full red, green, blue, and white
		// A predefined number of them must pass to be considered valid
		// var/passed = 0
// #define COLORTEST(thestring, thematrix) passed += (rgb2hsv(RGBMatrixTransform(thestring, thematrix))[3] >= minimum_matrix_lightness) // Вызывает рантаймы, мб потом починю. В любом случае проверка нужна только чтоб слишком темное не делать и т.п.
// 		COLORTEST("FF0000", cm)
// 		COLORTEST("00FF00", cm)
// 		COLORTEST("0000FF", cm)
// 		COLORTEST("FFFFFF", cm)
// #undef COLORTEST
		// if(passed < minimum_matrix_tests)
		// 	temp = "Matrix is too dark. (passed [passed] out of [minimum_matrix_tests] required tests. Minimum lightness: [minimum_matrix_lightness])."
		// 	return FALSE
	return TRUE


///////////

/obj/item/circuitboard/machine/colormate
	name = "Colormate (Machine Board)"
	icon = 'icons/obj/devices/circuitry_n_data.dmi'
	icon_state = "circuit_map"
	build_path = /obj/machinery/gear_painter
	req_components = list()

/datum/design/board/colormate
	name = "ColorMate"
	desc = "This machine lets you paint your gear."
	id = "colormate"
	build_path = /obj/item/circuitboard/machine/colormate
	category = list(
		RND_CATEGORY_MACHINE + RND_SUBCATEGORY_MACHINE_CARGO
	)
	//departmental_flags = DEPARTMENT_BITFLAG_CARGO | DEPARTMENT_BITFLAG_ENGINEERING

/datum/techweb_node/construction/New()
	design_ids += list(
		"colormate",
	)
	return ..()

