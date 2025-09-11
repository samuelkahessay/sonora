import Foundation

/// Static in-memory catalog of recording prompts.
/// Stores taxonomy/metadata only; localized strings supplied elsewhere.
final class PromptCatalogStatic: PromptCatalog, @unchecked Sendable {
    private let promptsSeed: [RecordingPrompt] = [
        // MARK: - Growth (8)
        RecordingPrompt(
            id: "growth_micro_win_today",
            localizationKey: "prompt.growth.micro-win-today",
            category: .growth,
            emotionalDepth: .light,
            allowedDayParts: [.morning],
            allowedWeekParts: [.startOfWeek],
            weight: 2
        ),
        RecordingPrompt(
            id: "growth_stretch_one_percent",
            localizationKey: "prompt.growth.stretch-one-percent",
            category: .growth,
            emotionalDepth: .medium,
            allowedDayParts: DayPart.any,
            allowedWeekParts: WeekPart.any
        ),
        RecordingPrompt(
            id: "growth_lesson_from_setback",
            localizationKey: "prompt.growth.lesson-from-setback",
            category: .growth,
            emotionalDepth: .deep,
            allowedDayParts: [.evening],
            allowedWeekParts: WeekPart.any
        ),
        RecordingPrompt(
            id: "growth_new_perspective",
            localizationKey: "prompt.growth.new-perspective",
            category: .growth,
            emotionalDepth: .light,
            allowedDayParts: [.morning, .afternoon],
            allowedWeekParts: WeekPart.any
        ),
        RecordingPrompt(
            id: "growth_three_highlights",
            localizationKey: "prompt.growth.three-highlights",
            category: .growth,
            emotionalDepth: .light,
            allowedDayParts: DayPart.any,
            allowedWeekParts: [.midWeek]
        ),
        RecordingPrompt(
            id: "growth_next_tiny_step",
            localizationKey: "prompt.growth.next-tiny-step",
            category: .growth,
            emotionalDepth: .light,
            allowedDayParts: DayPart.any,
            allowedWeekParts: WeekPart.any
        ),
        RecordingPrompt(
            id: "growth_gratitude_for_progress",
            localizationKey: "prompt.growth.gratitude-for-progress",
            category: .growth,
            emotionalDepth: .medium,
            allowedDayParts: [.evening],
            allowedWeekParts: [.endOfWeek]
        ),
        RecordingPrompt(
            id: "growth_teach_someone",
            localizationKey: "prompt.growth.teach-someone",
            category: .growth,
            emotionalDepth: .medium,
            allowedDayParts: [.afternoon],
            allowedWeekParts: [.midWeek]
        ),

        // MARK: - Work (8)
        RecordingPrompt(
            id: "work_unblock_one_task",
            localizationKey: "prompt.work.unblock-one-task",
            category: .work,
            emotionalDepth: .light,
            allowedDayParts: [.afternoon],
            allowedWeekParts: [.midWeek]
        ),
        RecordingPrompt(
            id: "work_define_top_three",
            localizationKey: "prompt.work.define-top-3",
            category: .work,
            emotionalDepth: .medium,
            allowedDayParts: [.morning],
            allowedWeekParts: [.startOfWeek]
        ),
        RecordingPrompt(
            id: "work_midweek_checkpoint",
            localizationKey: "prompt.work.midweek-checkpoint",
            category: .work,
            emotionalDepth: .medium,
            allowedDayParts: [.afternoon],
            allowedWeekParts: [.midWeek],
            weight: 2
        ),
        RecordingPrompt(
            id: "work_delegate_or_drop",
            localizationKey: "prompt.work.delegate-or-drop",
            category: .work,
            emotionalDepth: .medium,
            allowedDayParts: DayPart.any,
            allowedWeekParts: WeekPart.any
        ),
        RecordingPrompt(
            id: "work_reduce_scope",
            localizationKey: "prompt.work.reduce-scope",
            category: .work,
            emotionalDepth: .light,
            allowedDayParts: [.morning],
            allowedWeekParts: WeekPart.any
        ),
        RecordingPrompt(
            id: "work_meeting_prep",
            localizationKey: "prompt.work.meeting-prep",
            category: .work,
            emotionalDepth: .light,
            allowedDayParts: [.morning],
            allowedWeekParts: [.midWeek]
        ),
        RecordingPrompt(
            id: "work_after_action_review",
            localizationKey: "prompt.work.after-action-review",
            category: .work,
            emotionalDepth: .deep,
            allowedDayParts: [.evening],
            allowedWeekParts: [.endOfWeek]
        ),
        RecordingPrompt(
            id: "work_flow_session_plan",
            localizationKey: "prompt.work.flow-session-plan",
            category: .work,
            emotionalDepth: .medium,
            allowedDayParts: [.morning],
            allowedWeekParts: [.startOfWeek, .midWeek]
        ),

        // MARK: - Relationships (8)
        RecordingPrompt(
            id: "relationships_share_a_thank_you",
            localizationKey: "prompt.relationships.share-a-thank-you",
            category: .relationships,
            emotionalDepth: .light,
            allowedDayParts: [.evening],
            allowedWeekParts: [.endOfWeek]
        ),
        RecordingPrompt(
            id: "relationships_check_in_one_person",
            localizationKey: "prompt.relationships.check-in-one-person",
            category: .relationships,
            emotionalDepth: .light,
            allowedDayParts: [.afternoon],
            allowedWeekParts: WeekPart.any
        ),
        RecordingPrompt(
            id: "relationships_repair_micro_moment",
            localizationKey: "prompt.relationships.repair-micro-moment",
            category: .relationships,
            emotionalDepth: .deep,
            allowedDayParts: [.evening],
            allowedWeekParts: WeekPart.any
        ),
        RecordingPrompt(
            id: "relationships_celebrate_small_win",
            localizationKey: "prompt.relationships.celebrate-small-win",
            category: .relationships,
            emotionalDepth: .light,
            allowedDayParts: [.night],
            allowedWeekParts: [.endOfWeek]
        ),
        RecordingPrompt(
            id: "relationships_plan_connection",
            localizationKey: "prompt.relationships.plan-connection",
            category: .relationships,
            emotionalDepth: .medium,
            allowedDayParts: [.morning],
            allowedWeekParts: [.startOfWeek, .midWeek]
        ),
        RecordingPrompt(
            id: "relationships_express_boundary_kindly",
            localizationKey: "prompt.relationships.express-boundary-kindly",
            category: .relationships,
            emotionalDepth: .deep,
            allowedDayParts: [.afternoon],
            allowedWeekParts: [.midWeek]
        ),
        RecordingPrompt(
            id: "relationships_ask_for_help",
            localizationKey: "prompt.relationships.ask-for-help",
            category: .relationships,
            emotionalDepth: .medium,
            allowedDayParts: DayPart.any,
            allowedWeekParts: WeekPart.any
        ),
        RecordingPrompt(
            id: "relationships_reach_out_old_friend",
            localizationKey: "prompt.relationships.reach-out-old-friend",
            category: .relationships,
            emotionalDepth: .medium,
            allowedDayParts: [.evening],
            allowedWeekParts: WeekPart.any
        ),

        // MARK: - Creative (8)
        RecordingPrompt(
            id: "creative_new_angle_on_old_idea",
            localizationKey: "prompt.creative.new-angle-on-old-idea",
            category: .creative,
            emotionalDepth: .light,
            allowedDayParts: [.morning, .afternoon],
            allowedWeekParts: WeekPart.any
        ),
        RecordingPrompt(
            id: "creative_constraints_challenge",
            localizationKey: "prompt.creative.constraints-challenge",
            category: .creative,
            emotionalDepth: .medium,
            allowedDayParts: DayPart.any,
            allowedWeekParts: WeekPart.any
        ),
        RecordingPrompt(
            id: "creative_mashup_two_things",
            localizationKey: "prompt.creative.mashup-two-things",
            category: .creative,
            emotionalDepth: .light,
            allowedDayParts: [.afternoon],
            allowedWeekParts: WeekPart.any
        ),
        RecordingPrompt(
            id: "creative_remove_one_element",
            localizationKey: "prompt.creative.remove-one-element",
            category: .creative,
            emotionalDepth: .light,
            allowedDayParts: DayPart.any,
            allowedWeekParts: WeekPart.any
        ),
        RecordingPrompt(
            id: "creative_switch_medium",
            localizationKey: "prompt.creative.switch-medium",
            category: .creative,
            emotionalDepth: .medium,
            allowedDayParts: [.evening],
            allowedWeekParts: WeekPart.any
        ),
        RecordingPrompt(
            id: "creative_divergent_ideas",
            localizationKey: "prompt.creative.divergent-ideas",
            category: .creative,
            emotionalDepth: .deep,
            allowedDayParts: [.morning],
            allowedWeekParts: WeekPart.any
        ),
        RecordingPrompt(
            id: "creative_capture_random_detail",
            localizationKey: "prompt.creative.capture-random-detail",
            category: .creative,
            emotionalDepth: .light,
            allowedDayParts: [.night],
            allowedWeekParts: WeekPart.any
        ),
        RecordingPrompt(
            id: "creative_storyboard_next_step",
            localizationKey: "prompt.creative.storyboard-next-step",
            category: .creative,
            emotionalDepth: .medium,
            allowedDayParts: [.morning],
            allowedWeekParts: [.startOfWeek, .midWeek]
        ),

        // MARK: - Goals (8)
        RecordingPrompt(
            id: "goals_weekly_review",
            localizationKey: "prompt.goals.weekly-review",
            category: .goals,
            emotionalDepth: .deep,
            allowedDayParts: [.evening],
            allowedWeekParts: [.endOfWeek],
            weight: 2
        ),
        RecordingPrompt(
            id: "goals_next_milestone",
            localizationKey: "prompt.goals.next-milestone",
            category: .goals,
            emotionalDepth: .medium,
            allowedDayParts: [.morning],
            allowedWeekParts: [.startOfWeek]
        ),
        RecordingPrompt(
            id: "goals_success_definition",
            localizationKey: "prompt.goals.success-definition",
            category: .goals,
            emotionalDepth: .medium,
            allowedDayParts: DayPart.any,
            allowedWeekParts: WeekPart.any
        ),
        RecordingPrompt(
            id: "goals_risk_one_thing",
            localizationKey: "prompt.goals.risk-one-thing",
            category: .goals,
            emotionalDepth: .deep,
            allowedDayParts: [.afternoon],
            allowedWeekParts: [.midWeek]
        ),
        RecordingPrompt(
            id: "goals_today_top_one",
            localizationKey: "prompt.goals.today-top-one",
            category: .goals,
            emotionalDepth: .light,
            allowedDayParts: [.morning],
            allowedWeekParts: WeekPart.any
        ),
        RecordingPrompt(
            id: "goals_remove_nonessential",
            localizationKey: "prompt.goals.remove-nonessential",
            category: .goals,
            emotionalDepth: .light,
            allowedDayParts: DayPart.any,
            allowedWeekParts: WeekPart.any
        ),
        RecordingPrompt(
            id: "goals_habit_streak",
            localizationKey: "prompt.goals.habit-streak",
            category: .goals,
            emotionalDepth: .medium,
            allowedDayParts: [.night],
            allowedWeekParts: WeekPart.any
        ),
        RecordingPrompt(
            id: "goals_reflect_quarter",
            localizationKey: "prompt.goals.reflect-quarter",
            category: .goals,
            emotionalDepth: .deep,
            allowedDayParts: [.evening],
            allowedWeekParts: [.midWeek, .endOfWeek]
        ),

        // MARK: - Mindfulness (8)
        RecordingPrompt(
            id: "mindfulness_name_three_calm_things",
            localizationKey: "prompt.mindfulness.name-three-calm-things",
            category: .mindfulness,
            emotionalDepth: .light,
            allowedDayParts: [.night],
            allowedWeekParts: WeekPart.any
        ),
        RecordingPrompt(
            id: "mindfulness_breathing_box",
            localizationKey: "prompt.mindfulness.breathing-box",
            category: .mindfulness,
            emotionalDepth: .light,
            allowedDayParts: DayPart.any,
            allowedWeekParts: WeekPart.any
        ),
        RecordingPrompt(
            id: "mindfulness_body_scan",
            localizationKey: "prompt.mindfulness.body-scan",
            category: .mindfulness,
            emotionalDepth: .medium,
            allowedDayParts: [.evening],
            allowedWeekParts: WeekPart.any
        ),
        RecordingPrompt(
            id: "mindfulness_let_go_thought",
            localizationKey: "prompt.mindfulness.let-go-thought",
            category: .mindfulness,
            emotionalDepth: .medium,
            allowedDayParts: [.night],
            allowedWeekParts: WeekPart.any
        ),
        RecordingPrompt(
            id: "mindfulness_gratitude_three",
            localizationKey: "prompt.mindfulness.gratitude-three",
            category: .mindfulness,
            emotionalDepth: .light,
            allowedDayParts: [.evening],
            allowedWeekParts: [.endOfWeek]
        ),
        RecordingPrompt(
            id: "mindfulness_mindful_walk",
            localizationKey: "prompt.mindfulness.mindful-walk",
            category: .mindfulness,
            emotionalDepth: .light,
            allowedDayParts: [.morning, .afternoon],
            allowedWeekParts: WeekPart.any
        ),
        RecordingPrompt(
            id: "mindfulness_emotion_labeling",
            localizationKey: "prompt.mindfulness.emotion-labeling",
            category: .mindfulness,
            emotionalDepth: .deep,
            allowedDayParts: [.afternoon],
            allowedWeekParts: WeekPart.any
        ),
        RecordingPrompt(
            id: "mindfulness_intention_for_day",
            localizationKey: "prompt.mindfulness.intention-for-day",
            category: .mindfulness,
            emotionalDepth: .light,
            allowedDayParts: [.morning],
            allowedWeekParts: [.startOfWeek]
        )
    ]

    func allPrompts() -> [RecordingPrompt] { promptsSeed }
}

