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
  distill:                { verbosity: 'medium', reasoningEffort: 'medium' }, // Complex analysis with coaching questions
  'lite-distill':         { verbosity: 'low', reasoningEffort: 'medium' },    // Free tier: focused clarity with ONE insight
  'distill-summary':      { verbosity: 'low', reasoningEffort: 'low' },       // Just the overview
  'distill-actions':      { verbosity: 'low', reasoningEffort: 'low' },       // Just action items extraction
  'distill-themes':       { verbosity: 'low', reasoningEffort: 'low' },       // Just themes identification
  'distill-reflection':   { verbosity: 'low', reasoningEffort: 'medium' },    // Just coaching questions
  events:                 { verbosity: 'low', reasoningEffort: 'medium' },    // Calendar event extraction
  reminders:              { verbosity: 'low', reasoningEffort: 'low' }        // Reminder extraction
} as const;

export type AnalysisMode = keyof typeof ModelSettings;
export type VerbosityLevel = "low" | "medium" | "high";
export type ReasoningEffort = "low" | "medium" | "high";

// Historical Memo Context for pattern detection
export const HistoricalMemoContextSchema = z.object({
  memoId: z.string(),
  title: z.string(),
  daysAgo: z.number(),
  summary: z.string().optional(),
  themes: z.array(z.string()).optional()
});

export const RequestSchema = z.object({
  mode: z.enum([
    'events',
    'reminders',
    'distill',
    'lite-distill',
    'distill-summary',
    'distill-actions',
    'distill-themes',
    'distill-reflection'
  ]),
  transcript: z.string().min(10).max(10000),
  historicalContext: z.array(HistoricalMemoContextSchema).max(10).optional()
});

export const DistillDataSchema = z.object({
  summary: z.string(),
  keyThemes: z.array(z.string()).min(2).max(4).optional(),
  personalInsight: z.object({
    type: z.enum(['emotionalTone', 'wordPattern', 'valueGlimpse', 'energyShift', 'stoicMoment', 'recurringPhrase']),
    observation: z.string(),
    invitation: z.string().optional()
  }).optional(),
  action_items: z.array(z.object({
    text: z.string(),
    priority: z.enum(['high', 'medium', 'low'])
  })).optional(),
  reflection_questions: z.array(z.string()),
  closingNote: z.string().optional(),
  patterns: z.array(z.object({
    id: z.string().optional(),
    theme: z.string(),
    description: z.string(),
    relatedMemos: z.array(z.object({
      memoId: z.string().optional(),
      title: z.string(),
      daysAgo: z.number().optional(),
      snippet: z.string().optional()
    })).optional(),
    confidence: z.number().min(0).max(1).default(0.8)
  })).optional()
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
      .nullable()
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

// Free Tier Lite Distill Schema
export const LiteDistillDataSchema = z.object({
  summary: z.string(),
  keyThemes: z.array(z.string()).min(2).max(3),
  personalInsight: z.object({
    id: z.string().optional(),
    type: z.enum(['emotionalTone', 'wordPattern', 'valueGlimpse', 'energyShift', 'stoicMoment', 'recurringPhrase']),
    observation: z.string(),
    invitation: z.string().optional()
  }),
  simpleTodos: z.array(z.object({
    id: z.string().optional(),
    text: z.string(),
    priority: z.enum(['high', 'medium', 'low'])
  })),
  reflectionQuestion: z.string(),
  closingNote: z.string()
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
      keyThemes: {
        type: "array",
        description: "3-4 short topic labels (2-4 words each)",
        items: { type: "string" },
        minItems: 2,
        maxItems: 4
      },
      personalInsight: {
        type: "object",
        description: "ONE meaningful observation about patterns or themes",
        properties: {
          type: {
            type: "string",
            enum: ["emotionalTone", "wordPattern", "valueGlimpse", "energyShift", "stoicMoment", "recurringPhrase"]
          },
          observation: { type: "string", description: "Brief noticing in warm, curious tone (1-2 sentences)" },
          invitation: { type: "string", description: "Optional reflection prompt (1 sentence)" }
        },
        required: ["type", "observation"],
        additionalProperties: false
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
      },
      closingNote: {
        type: "string",
        description: "Brief encouraging observation about their self-awareness (1 sentence)"
      },
      patterns: {
        type: "array",
        description: "Pro feature: Recurring themes detected across historical memos. Return empty array if no historical context or no strong patterns.",
        items: {
          type: "object",
          properties: {
            id: { type: "string" },
            theme: { type: "string" },
            description: { type: "string" },
            relatedMemos: {
              type: "array",
              items: {
                type: "object",
                properties: {
                  memoId: { type: "string" },
                  title: { type: "string" },
                  daysAgo: { type: "number" },
                  snippet: { type: "string" }
                },
                required: ["title"],
                additionalProperties: false
              }
            },
            confidence: { type: "number", minimum: 0, maximum: 1 }
          },
          required: ["theme", "description", "confidence"],
          additionalProperties: false
        }
      }
    },
    required: ["summary", "reflection_questions"],
    additionalProperties: false
  }
};

export const LiteDistillJsonSchema = {
  name: "lite_distill_response",
  schema: {
    type: "object",
    properties: {
      summary: {
        type: "string",
        description: "Brief 2-3 sentence overview of the memo"
      },
      keyThemes: {
        type: "array",
        description: "2-3 topics discussed in the memo",
        items: { type: "string" },
        minItems: 2,
        maxItems: 3
      },
      personalInsight: {
        type: "object",
        description: "ONE meaningful observation to create an 'aha moment'",
        properties: {
          type: {
            type: "string",
            enum: ["emotionalTone", "wordPattern", "valueGlimpse", "energyShift", "stoicMoment", "recurringPhrase"],
            description: "Type of insight detected"
          },
          observation: {
            type: "string",
            description: "Gentle noticing using 'I notice...' language"
          },
          invitation: {
            type: ["string", "null"],
            description: "Optional: A question to invite deeper reflection"
          }
        },
        required: ["type", "observation", "invitation"],
        additionalProperties: false
      },
      simpleTodos: {
        type: "array",
        description: "Explicit action items mentioned. Return empty array if none.",
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
      reflectionQuestion: {
        type: "string",
        description: "ONE deep Socratic question to extend thinking"
      },
      closingNote: {
        type: "string",
        description: "Brief encouraging note about their practice (e.g., 'You're developing awareness...')"
      }
    },
    required: ["summary", "keyThemes", "personalInsight", "simpleTodos", "reflectionQuestion", "closingNote"],
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
              type: ['object', 'null'],
              properties: {
                frequency: { type: 'string', enum: ['daily', 'weekly', 'monthly', 'yearly'] },
                interval: { type: ['integer', 'null'], minimum: 1 },
                byWeekday: { type: 'array', items: { type: 'string', enum: ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'] } },
                end: {
                  type: ['object', 'null'],
                  properties: {
                    until: { type: ['string', 'null'], description: 'ISO 8601 datetime' },
                    count: { type: ['integer', 'null'], minimum: 1 }
                  },
                  required: ['until', 'count'],
                  additionalProperties: false
                }
              },
              required: ['frequency', 'interval', 'byWeekday', 'end'],
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
  'lite-distill': LiteDistillJsonSchema,
  'distill-summary': DistillSummaryJsonSchema,
  'distill-actions': DistillActionsJsonSchema,
  'distill-themes': DistillThemesJsonSchema,
  'distill-reflection': DistillReflectionJsonSchema,
  events: EventsJsonSchema,
  reminders: RemindersJsonSchema
} as const;

// Supported GPT models
export const ModelSchema = z.enum(['gpt-5-mini', 'gpt-5-nano', 'gpt-4o', 'gpt-4o-mini']);

export const ResponseSchema = z.object({
  mode: z.enum([
    'events',
    'reminders',
    'distill',
    'lite-distill',
    'distill-summary',
    'distill-actions',
    'distill-themes',
    'distill-reflection'
  ]),
  data: z.union([
    EventsDataSchema,
    RemindersDataSchema,
    DistillDataSchema,
    LiteDistillDataSchema,
    DistillSummaryDataSchema,
    DistillActionsDataSchema,
    DistillThemesDataSchema,
    DistillReflectionDataSchema
  ]),
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
export type DistillData = z.infer<typeof DistillDataSchema>;
export type LiteDistillData = z.infer<typeof LiteDistillDataSchema>;
export type DistillSummaryData = z.infer<typeof DistillSummaryDataSchema>;
export type DistillActionsData = z.infer<typeof DistillActionsDataSchema>;
export type DistillThemesData = z.infer<typeof DistillThemesDataSchema>;
export type DistillReflectionData = z.infer<typeof DistillReflectionDataSchema>;
export type EventsData = z.infer<typeof EventsDataSchema>;
export type RemindersData = z.infer<typeof RemindersDataSchema>;
export type DataOut = DistillData | LiteDistillData | DistillSummaryData | DistillActionsData | DistillThemesData | DistillReflectionData | EventsData | RemindersData;
export type ResponseData = z.infer<typeof ResponseSchema>;
