/**
 * # Warden tools: the talk menu
 *
 * Owner: XC (extras-plan.md 4.8). A member's right click with an empty hand on a prisoner opens a
 * radial menu: "How are you doing?", "What are you in for?", "Back to your cell", plus whatever
 * talk_menu_extra_choices() adds from other packages (XF's pat-down, XG's questions), run through
 * talk_menu_extra_act().
 *
 * X0 stub: keeps the prison as it was until XC fills it in.
 */

/// Registers the talk menu on the prisoner; called from setup_extras()
/mob/living/basic/outpost_prisoner/proc/setup_warden_tools()
	return
