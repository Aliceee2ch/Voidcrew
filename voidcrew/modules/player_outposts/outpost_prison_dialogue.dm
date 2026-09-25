/**
 * # Prisoner dialogue
 *
 * What prisoners say comes from strings/outpost_prisoners.json:
 *   personalities: the personalities a prisoner can get
 *   crimes: what they can be in for
 *   lines: context -> {"any": [...], "<personality>": [...]}
 *   conversations: [{"opener": "...", "replies": [...]}], two-person exchanges
 * Lines fill {name} (the speaker's first name), {other} (who they talk to), {crime} (the
 * speaker's crime) and {time_left} (the speaker's sentence left).
 *
 * Spontaneous lines wait out a per-prisoner cooldown (longer for quiet ones) and a short
 * cooldown shared by the whole wing, so a full wing never talks over itself. Replies, thanks,
 * arrivals and releases skip the prisoner's own cooldown.
 */

#define PRISONER_DIALOGUE_FILE "outpost_prisoners.json"
#define PRISONER_DIALOGUE_DIR "voidcrew/modules/player_outposts/strings"

/// One top-level entry of the dialogue file, or an empty list
/proc/outpost_prisoner_dialogue(key)
	var/list/entry = strings(PRISONER_DIALOGUE_FILE, key, PRISONER_DIALOGUE_DIR)
	return islist(entry) ? entry : list()

/// Scales a prisoner's pause between spontaneous lines
/mob/living/basic/outpost_prisoner/proc/speech_pace()
	switch(personality)
		if("chatty")
			return 0.6
		if("cheerful")
			return 0.8
		if("grumpy")
			return 1.1
		if("quiet")
			return 1.8
	return 1

/// Their sentence left in words, for {time_left}
/mob/living/basic/outpost_prisoner/proc/time_left_text()
	var/seconds = max(0, round(sentence_left))
	var/minutes = round(seconds / 60 + 0.5)
	if(minutes >= 2)
		return "[minutes] minutes"
	if(seconds >= 45)
		return "a minute"
	return "[max(seconds, 1)] seconds"

/// Fills a line's placeholders for this speaker, talking to `other`
/mob/living/basic/outpost_prisoner/proc/fill_line(line, mob/living/basic/outpost_prisoner/other)
	line = replacetext(line, "{name}", speech_name())
	line = replacetext(line, "{other}", other ? other.speech_name() : "pal")
	line = replacetext(line, "{crime}", crime)
	line = replacetext(line, "{time_left}", time_left_text())
	return line

/**
 * A line for `context`, filled in, or null when the file has none that fits. Personality lines
 * come up more often than the shared ones; lines naming {other} need someone to talk to.
 */
/mob/living/basic/outpost_prisoner/proc/pick_line(context, mob/living/basic/outpost_prisoner/other)
	var/list/lines = outpost_prisoner_dialogue("lines")
	var/list/by_personality = lines[context]
	if(!islist(by_personality))
		return null
	var/list/own = by_personality[personality]
	var/list/shared = by_personality["any"]
	var/list/first_pool = (length(own) && prob(60)) ? own : shared
	var/list/usable = usable_lines(first_pool, other)
	if(!length(usable))
		usable = usable_lines(first_pool == own ? shared : own, other)
	if(!length(usable))
		return null
	return fill_line(pick(usable), other)

/// The lines of `pool` they can say now: not the last thing they said, and naming nobody when alone
/mob/living/basic/outpost_prisoner/proc/usable_lines(list/pool, mob/living/basic/outpost_prisoner/other)
	var/list/usable = list()
	for(var/line in pool)
		if(!istext(line) || line == last_line || (!other && findtext(line, "{other}")))
			continue
		usable += line
	return usable

/// Says a line for `context`. Returns TRUE if they said something.
/mob/living/basic/outpost_prisoner/proc/say_context(context, mob/living/basic/outpost_prisoner/other)
	if(stat != CONSCIOUS || QDELETED(src))
		return FALSE
	var/line = pick_line(context, other)
	if(!line)
		return FALSE
	last_line = line
	say(line)
	return TRUE

/// Thanks whoever fed, clothed or treated them, no more than every 20 seconds
/mob/living/basic/outpost_prisoner/proc/thank(context)
	if(phase != PRISONER_PRESENT || !COOLDOWN_FINISHED(src, thanks_cooldown))
		return FALSE
	if(!say_context(context))
		return FALSE
	COOLDOWN_START(src, thanks_cooldown, 20 SECONDS)
	return TRUE

/**
 * Opens a two-person exchange with `partner`, who answers a few seconds later with one of the
 * opener's replies. Returns TRUE if it started.
 */
/mob/living/basic/outpost_prisoner/proc/start_conversation(mob/living/basic/outpost_prisoner/partner)
	if(stat != CONSCIOUS || QDELETED(partner) || partner.stat != CONSCIOUS)
		return FALSE
	var/list/conversations = outpost_prisoner_dialogue("conversations")
	if(!length(conversations))
		return FALSE
	var/list/conversation = pick(conversations)
	var/opener = conversation["opener"]
	var/list/replies = conversation["replies"]
	if(!istext(opener) || !length(replies))
		return FALSE
	last_line = opener
	say(fill_line(opener, partner))
	addtimer(CALLBACK(partner, PROC_REF(reply_in_conversation), pick(replies), WEAKREF(src)), rand(3, 5) SECONDS)
	prison?.note_speech()
	return TRUE

/// The second half of a conversation
/mob/living/basic/outpost_prisoner/proc/reply_in_conversation(line, datum/weakref/opener_ref)
	var/mob/living/basic/outpost_prisoner/opener = opener_ref?.resolve()
	if(stat != CONSCIOUS || phase != PRISONER_PRESENT || QDELETED(opener) || get_dist(src, opener) > 5)
		return FALSE
	face_atom(opener)
	last_line = line
	say(fill_line(line, opener))
	return TRUE

/// Whether a member of staff (anyone awake who isn't a prisoner) is in sight
/mob/living/basic/outpost_prisoner/proc/staff_in_view()
	for(var/mob/living/carbon/human/person in view(5, src))
		if(person.stat == CONSCIOUS)
			return TRUE
	return FALSE

/// Another prisoner close by, to talk at
/mob/living/basic/outpost_prisoner/proc/nearby_prisoner()
	for(var/mob/living/basic/outpost_prisoner/other in view(3, src))
		if(other != src && other.stat == CONSCIOUS && other.phase == PRISONER_PRESENT)
			return other
	return null

/**
 * What to talk about now, as list(context, other), most pressing first: being locked in, needs,
 * the state of the wing, staff in sight, what they are doing, then small talk.
 */
/mob/living/basic/outpost_prisoner/proc/pick_speech()
	if(activity?.sleeping)
		return prob(25) ? list("sleeping", null) : null
	// Trouble has its own lines, said as it happens (outpost_prison_trouble.dm).
	if(trouble == PRISONER_TROUBLE_LOOSE)
		return prob(50) ? list("breakout", null) : null
	if(is_rioting())
		return list("riot", null)
	if(trouble || beaten_left > 0 || threat_ref || climb_ref)
		return null
	if(locked_in_seconds >= OUTPOST_PRISON_LOCKED_IN_COMPLAINT && prob(60))
		return list("locked_in", null)
	// The wing's mood shows before it turns: complaints, then shouting at staff.
	switch(prison?.stage)
		if(PRISON_STAGE_RESTLESS)
			if(prob(staff_in_view() ? 60 : 40))
				return list("restless", null)
		if(PRISON_STAGE_GRUMBLING)
			if(prob(35))
				return list("grumbling", null)
	if(hunger < PRISONER_HUNGER_STARVING && prob(70))
		return list("starving", null)
	if(hunger < PRISONER_HUNGER_HUNGRY && prob(50))
		return list("hungry", null)
	if(uniform_grime >= PRISONER_GRIME_FILTHY && prob(50))
		return list("filthy", null)
	if(health_factor() < PRISONER_BLEED_BELOW && prob(50))
		return list("hurt", null)
	if(prison)
		if(!prison.powered_score && prob(40))
			return list("no_power", null)
		if(prison.lit_score < 50 && prob(40))
			return list("dark", null)
		if(prison.clean_score < 60 && prob(30))
			return list("dirty_prison", null)
	if(prob(30) && staff_in_view())
		return list("staff_near", null)
	var/mob/living/basic/outpost_prisoner/partner = activity?.chat_partner()
	if(activity?.context && prob(60))
		return list(activity.context, partner)
	return list("idle", partner || nearby_prisoner())

/**
 * Called about once a second by the prison. Most seconds they say nothing; once their own and
 * the wing's cooldowns are up there is a small chance each second.
 */
/mob/living/basic/outpost_prisoner/proc/speech_tick()
	if(stat != CONSCIOUS || phase != PRISONER_PRESENT || !prison)
		return FALSE
	if(!said_release_soon && sentence_left <= 90)
		said_release_soon = TRUE
		return say_context("release_soon")
	if(!COOLDOWN_FINISHED(src, speech_cooldown) || !prison.wing_can_speak() || !prob(10))
		return FALSE
	var/list/choice = pick_speech()
	if(!choice)
		return FALSE
	if(!say_context(choice[1], choice[2]))
		return FALSE
	COOLDOWN_START(src, speech_cooldown, rand(35, 80) SECONDS * speech_pace())
	prison.note_speech()
	return TRUE

#undef PRISONER_DIALOGUE_FILE
#undef PRISONER_DIALOGUE_DIR
