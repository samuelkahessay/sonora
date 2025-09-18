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

        return defs
    }()

    private static let promptsSeed: [RecordingPrompt] = definitions.map(\.prompt)
    private static let templateLookup: [String: String] = Dictionary(uniqueKeysWithValues: definitions.map { ($0.prompt.localizationKey, $0.defaultTemplate) })

    init() {}

    func allPrompts() -> [RecordingPrompt] { Self.promptsSeed }

    static func defaultPromptTemplates() -> [String: String] { templateLookup }
    static func promptDefinitions() -> [PromptDefinition] { definitions }
}
