import Foundation

/// Static in-memory catalog of recording prompts.
/// Stores taxonomy/metadata alongside default English templates used for localization generation.
final class PromptCatalogStatic: PromptCatalog, @unchecked Sendable {
    struct PromptDefinition {
        let prompt: RecordingPrompt
        let defaultTemplate: String
    }

    private static let definitions: [PromptDefinition] = {
        var defs: [PromptDefinition] = []

        func add(
            id: String,
            key: String,
            category: PromptCategory,
            depth: EmotionalDepth,
            dayParts: Set<DayPart> = DayPart.any,
            weekParts: Set<WeekPart> = WeekPart.any,
            weight: Int = 1,
            template: String
        ) {
            let prompt = RecordingPrompt(
                id: id,
                localizationKey: key,
                category: category,
                emotionalDepth: depth,
                allowedDayParts: dayParts,
                allowedWeekParts: weekParts,
                weight: weight
            )
            defs.append(PromptDefinition(prompt: prompt, defaultTemplate: template))
        }

        // MARK: - Growth (8)
        add(id: "growth_micro_win_today", key: "prompt.growth.micro-win-today", category: .growth, depth: .light, dayParts: [.morning], weekParts: [.startOfWeek], weight: 2, template: "What's one small win this [DayPart], [Name]?")
        add(id: "growth_stretch_one_percent", key: "prompt.growth.stretch-one-percent", category: .growth, depth: .medium, template: "Where can you improve 1% this [WeekPart]?")
        add(id: "growth_lesson_from_setback", key: "prompt.growth.lesson-from-setback", category: .growth, depth: .deep, dayParts: [.evening], template: "Name a recent setback and the lesson you learned.")
        add(id: "growth_new_perspective", key: "prompt.growth.new-perspective", category: .growth, depth: .light, dayParts: [.morning, .afternoon], template: "What fresh angle could you try today, [Name]?")
        add(id: "growth_three_highlights", key: "prompt.growth.three-highlights", category: .growth, depth: .light, weekParts: [.midWeek], template: "Capture three [WeekPart] highlights so far.")
        add(id: "growth_next_tiny_step", key: "prompt.growth.next-tiny-step", category: .growth, depth: .light, template: "What's the next tiny step right now, [Name]?")
        add(id: "growth_gratitude_for_progress", key: "prompt.growth.gratitude-for-progress", category: .growth, depth: .medium, dayParts: [.evening], weekParts: [.endOfWeek], template: "What progress are you grateful for this [WeekPart]?")
        add(id: "growth_teach_someone", key: "prompt.growth.teach-someone", category: .growth, depth: .medium, dayParts: [.afternoon], weekParts: [.midWeek], template: "What could you teach someone today to reinforce your learning?")

        // MARK: - Work (8)
        add(id: "work_unblock_one_task", key: "prompt.work.unblock-one-task", category: .work, depth: .light, dayParts: [.afternoon], weekParts: [.midWeek], template: "Which single task can you unblock this [DayPart]?")
        add(id: "work_define_top_three", key: "prompt.work.define-top-3", category: .work, depth: .medium, dayParts: [.morning], weekParts: [.startOfWeek], template: "Define your top three priorities for the [WeekPart].")
        add(id: "work_midweek_checkpoint", key: "prompt.work.midweek-checkpoint", category: .work, depth: .medium, dayParts: [.afternoon], weekParts: [.midWeek], weight: 2, template: "Mid-week checkpoint: what's on track, what's not?")
        add(id: "work_delegate_or_drop", key: "prompt.work.delegate-or-drop", category: .work, depth: .medium, template: "What can you delegate or drop to move faster?")
        add(id: "work_reduce_scope", key: "prompt.work.reduce-scope", category: .work, depth: .light, dayParts: [.morning], template: "How can you reduce scope to ship sooner, [Name]?")
        add(id: "work_meeting_prep", key: "prompt.work.meeting-prep", category: .work, depth: .light, dayParts: [.morning], weekParts: [.midWeek], template: "What's your desired outcome for the next meeting?")
        add(id: "work_after_action_review", key: "prompt.work.after-action-review", category: .work, depth: .deep, dayParts: [.evening], weekParts: [.endOfWeek], template: "After-action review: what went well, what to improve?")
        add(id: "work_flow_session_plan", key: "prompt.work.flow-session-plan", category: .work, depth: .medium, dayParts: [.morning], weekParts: [.startOfWeek, .midWeek], template: "Plan a focused flow session: when and on what?")

        // MARK: - Relationships (8)
        add(id: "relationships_share_a_thank_you", key: "prompt.relationships.share-a-thank-you", category: .relationships, depth: .light, dayParts: [.evening], weekParts: [.endOfWeek], template: "Who deserves a genuine thank you this [WeekPart], [Name]?")
        add(id: "relationships_check_in_one_person", key: "prompt.relationships.check-in-one-person", category: .relationships, depth: .light, dayParts: [.afternoon], template: "Who could use a quick check-in from you today?")
        add(id: "relationships_repair_micro_moment", key: "prompt.relationships.repair-micro-moment", category: .relationships, depth: .deep, dayParts: [.evening], template: "Name a small moment you'd like to repair or revisit.")
        add(id: "relationships_celebrate_small_win", key: "prompt.relationships.celebrate-small-win", category: .relationships, depth: .light, dayParts: [.night], weekParts: [.endOfWeek], template: "Celebrate a small win with someone you care about.")
        add(id: "relationships_plan_connection", key: "prompt.relationships.plan-connection", category: .relationships, depth: .medium, dayParts: [.morning], weekParts: [.startOfWeek, .midWeek], template: "Plan one meaningful connection for the [WeekPart].")
        add(id: "relationships_express_boundary_kindly", key: "prompt.relationships.express-boundary-kindly", category: .relationships, depth: .deep, dayParts: [.afternoon], weekParts: [.midWeek], template: "What boundary can you express kindly and clearly?")
        add(id: "relationships_ask_for_help", key: "prompt.relationships.ask-for-help", category: .relationships, depth: .medium, template: "Where could you ask for help this [DayPart]?")
        add(id: "relationships_reach_out_old_friend", key: "prompt.relationships.reach-out-old-friend", category: .relationships, depth: .medium, dayParts: [.evening], template: "Reach out to an old friend—what's the first thing you'd say?")

        // MARK: - Creative (8)
        add(id: "creative_new_angle_on_old_idea", key: "prompt.creative.new-angle-on-old-idea", category: .creative, depth: .light, dayParts: [.morning, .afternoon], template: "Try a new angle on an old idea this [DayPart].")
        add(id: "creative_constraints_challenge", key: "prompt.creative.constraints-challenge", category: .creative, depth: .medium, template: "Set one constraint and create within it, [Name].")
        add(id: "creative_mashup_two_things", key: "prompt.creative.mashup-two-things", category: .creative, depth: .light, dayParts: [.afternoon], template: "Mash up two unrelated things from today—what do you get?")
        add(id: "creative_remove_one_element", key: "prompt.creative.remove-one-element", category: .creative, depth: .light, template: "Remove one element from your idea—what changes?")
        add(id: "creative_switch_medium", key: "prompt.creative.switch-medium", category: .creative, depth: .medium, dayParts: [.evening], template: "Switch mediums—how would your idea look in another format?")
        add(id: "creative_divergent_ideas", key: "prompt.creative.divergent-ideas", category: .creative, depth: .deep, dayParts: [.morning], template: "Spin up three divergent versions of your idea.")
        add(id: "creative_capture_random_detail", key: "prompt.creative.capture-random-detail", category: .creative, depth: .light, dayParts: [.night], template: "Capture a random detail from today as a spark.")
        add(id: "creative_storyboard_next_step", key: "prompt.creative.storyboard-next-step", category: .creative, depth: .medium, dayParts: [.morning], weekParts: [.startOfWeek, .midWeek], template: "Storyboard the very next step for your idea.")

        // MARK: - Goals (8)
        add(id: "goals_weekly_review", key: "prompt.goals.weekly-review", category: .goals, depth: .deep, dayParts: [.evening], weekParts: [.endOfWeek], weight: 2, template: "Weekly review: what mattered most this [WeekPart]?")
        add(id: "goals_next_milestone", key: "prompt.goals.next-milestone", category: .goals, depth: .medium, dayParts: [.morning], weekParts: [.startOfWeek], template: "What's the next milestone, and why does it matter?")
        add(id: "goals_success_definition", key: "prompt.goals.success-definition", category: .goals, depth: .medium, template: "Define success for the next [WeekPart] in one sentence.")
        add(id: "goals_risk_one_thing", key: "prompt.goals.risk-one-thing", category: .goals, depth: .deep, dayParts: [.afternoon], weekParts: [.midWeek], template: "What's one risk worth taking this [WeekPart]?")
        add(id: "goals_today_top_one", key: "prompt.goals.today-top-one", category: .goals, depth: .light, dayParts: [.morning], template: "If you did only one thing today, what would it be?")
        add(id: "goals_remove_nonessential", key: "prompt.goals.remove-nonessential", category: .goals, depth: .light, template: "Remove one nonessential commitment to create space.")
        add(id: "goals_habit_streak", key: "prompt.goals.habit-streak", category: .goals, depth: .medium, dayParts: [.night], template: "How's your habit streak? What's the next link?")
        add(id: "goals_reflect_quarter", key: "prompt.goals.reflect-quarter", category: .goals, depth: .deep, dayParts: [.evening], weekParts: [.midWeek, .endOfWeek], template: "Reflect on this quarter: one win, one lesson.")

        // MARK: - Mindfulness (8)
        add(id: "mindfulness_name_three_calm_things", key: "prompt.mindfulness.name-three-calm-things", category: .mindfulness, depth: .light, dayParts: [.night], template: "Name three calm things around you right now.")
        add(id: "mindfulness_breathing_box", key: "prompt.mindfulness.breathing-box", category: .mindfulness, depth: .light, template: "Try box breathing—four in, four hold, four out, four hold.")
        add(id: "mindfulness_body_scan", key: "prompt.mindfulness.body-scan", category: .mindfulness, depth: .medium, dayParts: [.evening], template: "Do a quick body scan—what sensations do you notice?")
        add(id: "mindfulness_let_go_thought", key: "prompt.mindfulness.let-go-thought", category: .mindfulness, depth: .medium, dayParts: [.night], template: "Notice a sticky thought and let it pass.")
        add(id: "mindfulness_gratitude_three", key: "prompt.mindfulness.gratitude-three", category: .mindfulness, depth: .light, dayParts: [.evening], weekParts: [.endOfWeek], template: "Name three things you're grateful for this [WeekPart].")
        add(id: "mindfulness_mindful_walk", key: "prompt.mindfulness.mindful-walk", category: .mindfulness, depth: .light, dayParts: [.morning, .afternoon], template: "Take a mindful walk; describe what you observe.")
        add(id: "mindfulness_emotion_labeling", key: "prompt.mindfulness.emotion-labeling", category: .mindfulness, depth: .deep, dayParts: [.afternoon], template: "Take 30 seconds to describe how you're feeling and why.")
        add(id: "mindfulness_intention_for_day", key: "prompt.mindfulness.intention-for-day", category: .mindfulness, depth: .light, dayParts: [.morning], weekParts: [.startOfWeek], template: "Set an intention for this [DayPart], [Name].")

        // MARK: - Lindy / Stoic (Full Set)
        // Helper to add numbered Lindy prompts
        func addLindy(_ n: Int, _ template: String, _ category: PromptCategory, _ depth: EmotionalDepth, dayParts: Set<DayPart> = DayPart.any, weekParts: Set<WeekPart> = WeekPart.any) {
            let id = String(format: "lindy_%03d", n)
            let key = String(format: "prompt.lindy.%03d", n)
            add(id: id, key: key, category: category, depth: depth, dayParts: dayParts, weekParts: weekParts, template: template)
        }

        // I. Self‑Knowledge & Character (1–10)
        addLindy(1,  "What virtue did you practice this [DayPart], and where did you fall short of your ideals?", .mindfulness, .medium, dayParts: [.morning, .evening])
        addLindy(2,  "Which of your actions today reflected your true character, and which reflected mere impulse or habit?", .mindfulness, .medium)
        addLindy(3,  "What would you do differently this [DayPart] if you knew today would define how you are remembered?", .growth, .medium, dayParts: [.afternoon, .evening])
        addLindy(4,  "In what ways are you still the same person you were five years ago, and in what ways have you grown?", .growth, .deep)
        addLindy(5,  "What fear or desire currently has the strongest hold over your decisions, [Name]?", .mindfulness, .deep)
        addLindy(6,  "If you could observe your thoughts and actions from outside yourself, what patterns would you notice?", .mindfulness, .medium)
        addLindy(7,  "What talents or abilities do you possess that you are not fully developing or using in service of others?", .growth, .medium)
        addLindy(8,  "How do your private thoughts and actions align with the person you present to the world?", .mindfulness, .medium)
        addLindy(9,  "What would those who know you best say is your greatest strength and your greatest weakness?", .mindfulness, .light)
        addLindy(10, "If you had to choose only three values to guide your decisions this [WeekPart], [Name], what would they be and why?", .goals, .medium, weekParts: [.startOfWeek, .midWeek])

        // II. Control & Acceptance (11–20)
        addLindy(11, "What are you trying to control this [DayPart] that is ultimately beyond your influence?", .mindfulness, .medium)
        addLindy(12, "How can you find peace with circumstances that you cannot change?", .mindfulness, .medium)
        addLindy(13, "What would you accept about your current situation if you truly believed it was exactly what you needed for your growth?", .mindfulness, .deep)
        addLindy(14, "Where are you wasting energy on outcomes rather than focusing on your efforts and intentions?", .mindfulness, .medium)
        addLindy(15, "What opinion of others are you allowing to disturb your inner tranquility?", .mindfulness, .light)
        addLindy(16, "How would your perspective on challenges this [WeekPart] change if you viewed them as exactly what you needed to practice virtue?", .mindfulness, .medium)
        addLindy(17, "What external circumstances are you blaming for your internal state of mind?", .mindfulness, .light)
        addLindy(18, "If you surrendered your need for a specific outcome, how would your actions change?", .mindfulness, .medium)
        addLindy(19, "What are you resisting that, if accepted, might actually bring you peace?", .mindfulness, .medium)
        addLindy(20, "How can you love your fate today, even the difficult parts?", .mindfulness, .light)

        // III. Death & Impermanence (21–28)
        addLindy(21, "If you knew you had one year to live, what would you start doing this [WeekPart], [Name]?", .growth, .deep)
        addLindy(22, "What would you want written on your tombstone, and how are your daily actions moving you toward or away from that legacy?", .growth, .deep)
        addLindy(23, "How does remembering your mortality change the importance you place on today's worries?", .mindfulness, .medium)
        addLindy(24, "What wisdom would you want to pass on if you could only share one piece of advice?", .growth, .medium)
        addLindy(25, "How would you spend this [DayPart] if it were your last with the people you love most?", .relationships, .deep, dayParts: [.evening])
        addLindy(26, "What are you postponing that you would regret never experiencing or expressing?", .growth, .medium)
        addLindy(27, "How does contemplating the impermanence of all things affect your attachment to material possessions?", .mindfulness, .medium)
        addLindy(28, "What legacy are you creating through your daily choices and interactions?", .goals, .medium)

        // IV. Relationships & Community (29–36)
        addLindy(29, "How did you serve others today without expecting anything in return?", .relationships, .light)
        addLindy(30, "What assumptions are you making about someone that might be preventing you from understanding them better?", .relationships, .medium)
        addLindy(31, "Who in your life deserves gratitude this [WeekPart], [Name], that you haven't expressed recently?", .relationships, .light, weekParts: [.endOfWeek])
        addLindy(32, "How can you be more present and attentive in your relationships?", .relationships, .light)
        addLindy(33, "What judgment or resentment are you holding that only harms your own peace of mind?", .relationships, .medium)
        addLindy(34, "How can you better honor the trust that others place in you?", .relationships, .medium)
        addLindy(35, "What conflict in your life could be resolved if you focused on understanding rather than being understood?", .relationships, .medium)
        addLindy(36, "How do your actions and words contribute to the well-being of your community?", .relationships, .light)

        // V. Action & Purpose (37–43)
        addLindy(37, "What meaningful work did you accomplish this [DayPart] that aligns with your deeper purpose?", .goals, .medium)
        addLindy(38, "How are you using your unique position and abilities to make a positive difference?", .goals, .medium)
        addLindy(39, "What small action could you take tomorrow that would move you closer to who you want to become?", .goals, .light)
        addLindy(40, "Where are you choosing comfort over growth, and what is the cost of that choice?", .growth, .medium)
        addLindy(41, "How do your daily habits either support or undermine your highest aspirations?", .goals, .medium)
        addLindy(42, "What would you attempt if you knew failure was impossible, and what does that reveal about your true desires?", .growth, .medium)
        addLindy(43, "How can you bring more intention and mindfulness to routine activities?", .mindfulness, .light)

        // VI. Adversity & Resilience (44–50)
        addLindy(44, "What is this current challenge teaching you about your own strength and character?", .growth, .medium)
        addLindy(45, "How can you reframe obstacles this [WeekPart] as opportunities for growth and practice?", .growth, .medium)
        addLindy(46, "What would you tell a dear friend facing the same difficulties, [Name]?", .mindfulness, .light)
        addLindy(47, "How have past struggles prepared you for current challenges?", .growth, .medium)
        addLindy(48, "What good might come from this difficult situation that you cannot yet see?", .mindfulness, .medium)
        addLindy(49, "How can you maintain your values and character even when faced with setbacks?", .growth, .medium)
        addLindy(50, "What story will you tell about this period of your life when you look back years from now?", .creative, .light)

        // VII. Cognitive Clarity & Distortions (51–60)
        addLindy(51, "What belief are you treating as absolute fact that might just be one interpretation among many?", .mindfulness, .medium)
        addLindy(52, "Where are you catastrophizing today, and what's the realistic probability of your worst-case scenario?", .mindfulness, .medium)
        addLindy(53, "What thinking trap are you falling into: all-or-nothing, mind reading, fortune telling, or personalization?", .mindfulness, .medium)
        addLindy(54, "What evidence contradicts the negative story you're telling yourself about this situation?", .mindfulness, .medium)
        addLindy(55, "How would you advise a close friend who was having the exact same thoughts you're having?", .mindfulness, .light)
        addLindy(56, "What would you need to believe about yourself or the world for this worry to make complete sense?", .mindfulness, .medium)
        addLindy(57, "Are you confusing your feelings about something with the facts of the situation?", .mindfulness, .medium)
        addLindy(58, "What automatic thought keeps recurring this [WeekPart], and what more balanced alternative could you practice?", .mindfulness, .medium, weekParts: [.midWeek, .endOfWeek])
        addLindy(59, "Where are you filtering out positive information and focusing only on what went wrong?", .mindfulness, .medium)
        addLindy(60, "What rational statement could you record now to counter your current irrational fear?", .mindfulness, .medium)

        // VIII. Socratic Self‑Inquiry (61–68)
        addLindy(61, "What exactly do you mean when you say you \"should\" do something — who determined this rule?", .mindfulness, .medium)
        addLindy(62, "What assumption are you making that you haven't examined or questioned?", .mindfulness, .medium)
        addLindy(63, "If you're wrong about this conclusion, what would that mean for your next steps?", .mindfulness, .medium)
        addLindy(64, "What evidence would you need to see to change your mind about this belief?", .mindfulness, .medium)
        addLindy(65, "Why do you believe what you believe about this situation — is it based on your direct experience or hearsay?", .mindfulness, .medium)
        addLindy(66, "What question are you avoiding that might lead to greater clarity?", .mindfulness, .medium)
        addLindy(67, "How might someone who disagrees with you make a reasonable case for their position?", .mindfulness, .medium)
        addLindy(68, "What would you discover if you approached this problem with genuine curiosity instead of predetermined answers?", .mindfulness, .medium)

        // IX. Non‑Striving & Acceptance (69–76)
        addLindy(69, "What are you trying to force that might unfold naturally if you step back and allow it?", .mindfulness, .medium)
        addLindy(70, "Where are you creating unnecessary suffering by resisting what's already happening?", .mindfulness, .medium)
        addLindy(71, "How can you be fully engaged in this task without being attached to a specific outcome?", .mindfulness, .medium)
        addLindy(72, "What would change if you trusted that you're exactly where you need to be right now, [Name]?", .mindfulness, .medium)
        addLindy(73, "How can you act skillfully while simultaneously letting go of needing to control results?", .mindfulness, .medium)
        addLindy(74, "What would flow more easily if you stopped pushing so hard against it?", .mindfulness, .light)
        addLindy(75, "Where are you swimming against the current when you could work with natural forces instead, [Name]?", .mindfulness, .medium)
        addLindy(76, "How can you find peace within uncertainty rather than demanding guarantees?", .mindfulness, .medium)

        // X. Narrative & Life Story (77–84)
        addLindy(77, "What story are you telling yourself about who you are, and is this narrative empowering or limiting you?", .creative, .medium)
        addLindy(78, "How would you narrate today's events to your future self as part of a meaningful journey?", .creative, .light)
        addLindy(79, "What chapter of your life are you in now, and how does today's experience fit into your larger plot?", .creative, .medium)
        addLindy(80, "If you could edit the story you tell about your past, what would you emphasize differently?", .creative, .medium)
        addLindy(81, "What recurring themes appear across different periods of your life?", .creative, .light)
        addLindy(82, "How do you want the protagonist of your life story to respond to current challenges?", .creative, .medium)
        addLindy(83, "What wisdom have you gained from previous chapters that applies to your current situation?", .creative, .medium)
        addLindy(84, "If someone were to write your biography, what would you want this current period to demonstrate about your character?", .creative, .medium)

        // XI. Daily Review & Progress (85–92)
        addLindy(85, "What went well this [DayPart], what went poorly, and what can you improve tomorrow, [Name]?", .goals, .light, dayParts: [.evening])
        addLindy(86, "Which of your core principles did you honor today, and which did you compromise?", .goals, .medium)
        addLindy(87, "What progress did you make toward your most important goals, however small?", .goals, .light)
        addLindy(88, "How did you grow today, and what lesson will you carry forward?", .goals, .light)
        addLindy(89, "What moment today are you most grateful for, and why?", .mindfulness, .light)
        addLindy(90, "Where did you act from habit versus conscious choice, and what does this reveal?", .mindfulness, .medium)
        addLindy(91, "What would you do differently if you could replay today with the wisdom you have now?", .goals, .medium)
        addLindy(92, "How did your actions today align with the person you're becoming?", .goals, .medium)

        // XII. Stream to Structure (93–100)
        addLindy(93, "What recurring thought patterns have you noticed this [WeekPart], and what might they be telling you?", .creative, .medium, weekParts: [.midWeek, .endOfWeek])
        addLindy(94, "What's the underlying emotion or need beneath your scattered thoughts right now?", .mindfulness, .medium)
        addLindy(95, "If you had to summarize your mental state in one word, what would it be and why?", .mindfulness, .light)
        addLindy(96, "What theme keeps emerging when you let your mind wander freely?", .creative, .light)
        addLindy(97, "What clarity is trying to emerge from the chaos of your current thinking?", .creative, .medium)
        addLindy(98, "If your stream of consciousness had a soundtrack, what would it sound like today?", .creative, .light)
        addLindy(99, "What insight is hidden in the pattern of what you've been avoiding thinking about?", .creative, .medium)
        addLindy(100,"What would happen if you trusted that your meandering thoughts are leading somewhere meaningful?", .creative, .medium)

        return defs
    }()

    private static let promptsSeed: [RecordingPrompt] = definitions.map(\.prompt)
    private static let templateLookup: [String: String] = Dictionary(uniqueKeysWithValues: definitions.map { ($0.prompt.localizationKey, $0.defaultTemplate) })

    init() {}

    func allPrompts() -> [RecordingPrompt] { Self.promptsSeed }

    static func defaultPromptTemplates() -> [String: String] { templateLookup }
    static func promptDefinitions() -> [PromptDefinition] { definitions }
}
