import { z } from 'zod';

// Normalize date-like strings to ISO 8601 to reduce schema mismatch errors from LLM output.
function normalizeDateInput(value: unknown, allowNull: boolean): unknown {
  if (value === null || value === undefined) {
    return allowNull ? null : value;
  }

  if (typeof value !== 'string') {
    return value;
  }

  const trimmed = value.trim();
  if (!trimmed) {
    return allowNull ? null : value;
  }

  // If model returns date only (YYYY-MM-DD), assume start-of-day UTC for consistency.
  if (/^\d{4}-\d{2}-\d{2}$/.test(trimmed)) {
    return `${trimmed}T00:00:00Z`;
  }

  // Accept time strings without timezone; Date will normalise to ISO.
  const parsed = new Date(trimmed);
  if (!Number.isNaN(parsed.getTime())) {
    return parsed.toISOString();
  }

  return value;
}

const IsoDateTime = z.preprocess((val) => normalizeDateInput(val, false), z.string().datetime());
const IsoDateTimeNullable = z.preprocess((val) => normalizeDateInput(val, true), z.string().datetime().nullable());

// GPT-5 Model Settings Configuration - Optimized per complexity
export const ModelSettings = {
  distill:             { verbosity: 'medium', reasoningEffort: 'medium' }, // Complex analysis with coaching questions
  'distill-summary':   { verbosity: 'low', reasoningEffort: 'low' },       // Just the overview
  'distill-actions':   { verbosity: 'low', reasoningEffort: 'low' },       // Just action items extraction
  'distill-themes':    { verbosity: 'low', reasoningEffort: 'low' },       // Just themes identification
  'distill-reflection':{ verbosity: 'low', reasoningEffort: 'medium' },    // Just coaching questions
  analysis:            { verbosity: 'low', reasoningEffort: 'medium' },    // Standard analysis with key points extraction
  themes:              { verbosity: 'low', reasoningEffort: 'medium' },    // Pattern recognition for thematic analysis
  todos:               { verbosity: 'low', reasoningEffort: 'low' },       // Simple extraction of actionable items
  events:              { verbosity: 'low', reasoningEffort: 'medium' },    // Calendar event extraction
  reminders:           { verbosity: 'low', reasoningEffort: 'low' },       // Reminder extraction
  summarize:           { verbosity: 'low', reasoningEffort: 'low' },       // Basic summarization task
  tldr:                { verbosity: 'low', reasoningEffort: 'low' }        // Minimal processing for quick summaries
} as const;

export type AnalysisMode = keyof typeof ModelSettings;
export type VerbosityLevel = "low" | "medium" | "high";
export type ReasoningEffort = "low" | "medium" | "high";

export const RequestSchema = z.object({
  mode: z.enum(['analysis', 'themes', 'todos', 'events', 'reminders', 'distill', 'distill-summary', 'distill-actions', 'distill-themes', 'distill-reflection']),
  transcript: z.string().min(10).max(10000)
});

export const AnalysisDataSchema = z.object({
  summary: z.string(),
  key_points: z.array(z.string())
});

export const DistillDataSchema = z.object({
  summary: z.string(),
  action_items: z.array(z.object({
    text: z.string(),
    priority: z.enum(['high', 'medium', 'low'])
  })),
  reflection_questions: z.array(z.string())
});

export const ThemesDataSchema = z.object({
  themes: z.array(z.object({
    name: z.string(),
    evidence: z.array(z.string())
  })),
  sentiment: z.enum(['positive', 'neutral', 'mixed', 'negative'])
});

export const TodosDataSchema = z.object({
  todos: z.array(z.object({
    text: z.string(),
    due: z.string().nullable()
  }))
});

// Events & Reminders Schemas
export const EventsDataSchema = z.object({
  events: z.array(z.object({
    id: z.string(),
    title: z.string(),
    startDate: IsoDateTimeNullable,
    endDate: IsoDateTimeNullable,
    location: z.string().nullable().optional(),
    participants: z.array(z.string()).optional(),
    confidence: z.number().min(0).max(1),
    sourceText: z.string(),
    memoId: z.string().uuid().optional().nullable(),
    recurrence: z
      .object({
        frequency: z.enum(['daily', 'weekly', 'monthly', 'yearly']),
        interval: z.number().int().positive().optional(),
        byWeekday: z.array(z.enum(['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'])).optional(),
        end: z
          .object({
            until: z.string().datetime().optional(),
            count: z.number().int().positive().optional()
          })
          .optional()
      })
      .optional()
  }))
});

export const RemindersDataSchema = z.object({
  reminders: z.array(z.object({
    id: z.string(),
    title: z.string(),
    dueDate: IsoDateTimeNullable,
    priority: z.enum(['High', 'Medium', 'Low']),
    confidence: z.number().min(0).max(1),
    sourceText: z.string(),
    memoId: z.string().uuid().optional().nullable()
  }))
});

// Individual Distill Component Schemas
export const DistillSummaryDataSchema = z.object({
  summary: z.string()
});

export const DistillActionsDataSchema = z.object({
  action_items: z.array(z.object({
    text: z.string(),
    priority: z.enum(['high', 'medium', 'low'])
  }))
});

export const DistillThemesDataSchema = z.object({
  key_themes: z.array(z.string())
});

export const DistillReflectionDataSchema = z.object({
  reflection_questions: z.array(z.string())
});

// JSON Schemas for GPT-5 Responses API validation
export const DistillJsonSchema = {
  name: "distill_response",
  schema: {
    type: "object",
    properties: {
      summary: {
        type: "string",
        description: "Brief 2-3 sentence overview of the memo"
      },
      action_items: {
        type: "array",
        description: "Array of actionable tasks explicitly mentioned in the memo. Return empty array if none.",
        items: {
          type: "object",
          properties: {
            text: { type: "string" },
            priority: { type: "string", enum: ["high", "medium", "low"] }
          },
          required: ["text", "priority"],
          additionalProperties: false
        }
      },
      reflection_questions: {
        type: "array",
        description: "2-3 coaching questions to help the user think deeper",
        items: { type: "string" },
        minItems: 2,
        maxItems: 3
      }
    },
    required: ["summary", "action_items", "reflection_questions"],
    additionalProperties: false
  }
};

export const AnalysisJsonSchema = {
  name: "analysis_response",
  schema: {
    type: "object",
    properties: {
      summary: { type: "string" },
      key_points: {
        type: "array",
        items: { type: "string" }
      }
    },
    required: ["summary", "key_points"],
    additionalProperties: false
  }
};

export const ThemesJsonSchema = {
  name: "themes_response",
  schema: {
    type: "object",
    properties: {
      themes: {
        type: "array",
        items: {
          type: "object",
          properties: {
            name: { type: "string" },
            evidence: {
              type: "array",
              items: { type: "string" }
            }
          },
          required: ["name", "evidence"],
          additionalProperties: false
        }
      },
      sentiment: {
        type: "string",
        enum: ["positive", "neutral", "mixed", "negative"]
      }
    },
    required: ["themes", "sentiment"],
    additionalProperties: false
  }
};

export const TodosJsonSchema = {
  name: "todos_response",
  schema: {
    type: "object",
    properties: {
      todos: {
        type: "array",
        items: {
          type: "object",
          properties: {
            text: { type: "string" },
            due: { type: "string", nullable: true }
          },
          required: ["text", "due"],
          additionalProperties: false
        }
      }
    },
    required: ["todos"],
    additionalProperties: false
  }
};

export const EventsJsonSchema = {
  name: 'events_response',
  schema: {
    type: 'object',
    properties: {
      events: {
        type: 'array',
        items: {
          type: 'object',
          properties: {
            id: { type: 'string', description: 'Stable UUID for this detection' },
            title: { type: 'string' },
            startDate: { type: ['string', 'null'], description: 'ISO 8601 datetime' },
            endDate: { type: ['string', 'null'], description: 'ISO 8601 datetime' },
            location: { type: ['string', 'null'] },
            participants: { type: 'array', items: { type: 'string' } },
            confidence: { type: 'number', minimum: 0, maximum: 1 },
            sourceText: { type: 'string' },
            memoId: { type: ['string', 'null'] },
            recurrence: {
              type: 'object',
              nullable: true,
              properties: {
                frequency: { type: 'string', enum: ['daily', 'weekly', 'monthly', 'yearly'] },
                interval: { type: 'integer', minimum: 1 },
                byWeekday: { type: 'array', items: { type: 'string', enum: ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'] } },
                end: {
                  type: 'object',
                  properties: {
                    until: { type: 'string', description: 'ISO 8601 datetime' },
                    count: { type: 'integer', minimum: 1 }
                  },
                  additionalProperties: false
                }
              },
              additionalProperties: false
            }
          },
          // Responses API requires required[] to include every key in properties.
          required: ['id', 'title', 'startDate', 'endDate', 'location', 'participants', 'confidence', 'sourceText', 'memoId', 'recurrence'],
          additionalProperties: false
        }
      }
    },
    required: ['events'],
    additionalProperties: false
  }
};

export const RemindersJsonSchema = {
  name: 'reminders_response',
  schema: {
    type: 'object',
    properties: {
      reminders: {
        type: 'array',
        items: {
          type: 'object',
          properties: {
            id: { type: 'string', description: 'Stable UUID for this detection' },
            title: { type: 'string' },
            dueDate: { type: ['string', 'null'], description: 'ISO 8601 datetime' },
            priority: { type: 'string', enum: ['High', 'Medium', 'Low'] },
            confidence: { type: 'number', minimum: 0, maximum: 1 },
            sourceText: { type: 'string' },
            memoId: { type: ['string', 'null'] }
          },
          // Responses API requires required[] to include every key in properties.
          required: ['id', 'title', 'dueDate', 'priority', 'confidence', 'sourceText', 'memoId'],
          additionalProperties: false
        }
      }
    },
    required: ['reminders'],
    additionalProperties: false
  }
};

// Individual Distill Component JSON Schemas
export const DistillSummaryJsonSchema = {
  name: "distill_summary_response",
  schema: {
    type: "object",
    properties: {
      summary: { type: "string", description: "Brief 2-3 sentence overview of the memo" }
    },
    required: ["summary"],
    additionalProperties: false
  }
};

export const DistillActionsJsonSchema = {
  name: "distill_actions_response", 
  schema: {
    type: "object",
    properties: {
      action_items: {
        type: "array",
        description: "Array of actionable tasks. Return empty array if none mentioned.",
        items: {
          type: "object",
          properties: {
            text: { type: "string" },
            priority: { type: "string", enum: ["high", "medium", "low"] }
          },
          required: ["text", "priority"],
          additionalProperties: false
        }
      }
    },
    required: ["action_items"],
    additionalProperties: false
  }
};

export const DistillThemesJsonSchema = {
  name: "distill_themes_response",
  schema: {
    type: "object", 
    properties: {
      key_themes: {
        type: "array",
        description: "2-4 main themes/topics extracted from the memo",
        items: { type: "string" },
        minItems: 2,
        maxItems: 4
      }
    },
    required: ["key_themes"],
    additionalProperties: false
  }
};

export const DistillReflectionJsonSchema = {
  name: "distill_reflection_response",
  schema: {
    type: "object",
    properties: {
      reflection_questions: {
        type: "array",
        description: "2-3 coaching questions to help the user think deeper",
        items: { type: "string" },
        minItems: 2,
        maxItems: 3
      }
    },
    required: ["reflection_questions"],
    additionalProperties: false
  }
};

// Mapping analysis types to their JSON schemas
export const AnalysisJsonSchemas = {
  distill: DistillJsonSchema,
  'distill-summary': DistillSummaryJsonSchema,
  'distill-actions': DistillActionsJsonSchema,
  'distill-themes': DistillThemesJsonSchema,
  'distill-reflection': DistillReflectionJsonSchema,
  analysis: AnalysisJsonSchema,
  themes: ThemesJsonSchema,
  todos: TodosJsonSchema,
  events: EventsJsonSchema,
  reminders: RemindersJsonSchema
} as const;

// Supported GPT models
export const ModelSchema = z.enum(['gpt-5-mini', 'gpt-5-nano', 'gpt-4o', 'gpt-4o-mini']);

export const ResponseSchema = z.object({
  mode: z.enum(['analysis', 'themes', 'todos', 'events', 'reminders', 'distill', 'distill-summary', 'distill-actions', 'distill-themes', 'distill-reflection']),
  data: z.union([AnalysisDataSchema, ThemesDataSchema, TodosDataSchema, EventsDataSchema, RemindersDataSchema, DistillDataSchema, DistillSummaryDataSchema, DistillActionsDataSchema, DistillThemesDataSchema, DistillReflectionDataSchema]),
  model: ModelSchema,
  tokens: z.object({
    input: z.number(),
    output: z.number()
  }),
  latency_ms: z.number(),
  moderation: z
    .object({
      flagged: z.boolean(),
      categories: z.record(z.boolean()).optional(),
      category_scores: z.record(z.number()).optional(),
    })
    .optional()
});

export type RequestData = z.infer<typeof RequestSchema>;
export type AnalysisData = z.infer<typeof AnalysisDataSchema>;
export type DistillData = z.infer<typeof DistillDataSchema>;
export type DistillSummaryData = z.infer<typeof DistillSummaryDataSchema>;
export type DistillActionsData = z.infer<typeof DistillActionsDataSchema>;
export type DistillThemesData = z.infer<typeof DistillThemesDataSchema>;
export type DistillReflectionData = z.infer<typeof DistillReflectionDataSchema>;
export type ThemesData = z.infer<typeof ThemesDataSchema>;
export type TodosData = z.infer<typeof TodosDataSchema>;
export type DataOut = AnalysisData | ThemesData | TodosData | DistillData | DistillSummaryData | DistillActionsData | DistillThemesData | DistillReflectionData;
export type ResponseData = z.infer<typeof ResponseSchema>;
