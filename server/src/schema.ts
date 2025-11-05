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
  'thinking-patterns':    { verbosity: 'medium', reasoningEffort: 'high' },   // Pro: Linguistic speech patterns
  'philosophical-echoes': { verbosity: 'medium', reasoningEffort: 'high' },   // Pro: Ancient wisdom connections
  'values-recognition':   { verbosity: 'medium', reasoningEffort: 'high' },   // Pro: Core values + tensions
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
    'distill-reflection',
    'thinking-patterns',
    'philosophical-echoes',
    'values-recognition'
  ]),
  transcript: z.string().min(10).max(10000),
  historicalContext: z.array(HistoricalMemoContextSchema).max(10).optional(),
  isPro: z.boolean().default(false), // Pro subscription flag - server includes pro modes when true (defaults to false if not provided)
  stream: z.boolean().default(false) // SSE streaming flag - server sends progressive updates via Server-Sent Events when true
});

export const DistillDataSchema = z.object({
  summary: z.string(),
  action_items: z.array(z.object({
    text: z.string(),
    priority: z.enum(['high', 'medium', 'low'])
  })),
  reflection_questions: z.array(z.string()),
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
  })).optional(),
  // Pro-tier fields (populated when isPro=true in request)
  thinkingPatterns: z.array(z.object({
    id: z.string().optional(),
    type: z.enum([
      'black-and-white-thinking',
      'worst-case-thinking',
      'assumption-making',
      'overbroad-generalizing',
      'pressure-language',
      'feelings-as-facts-thinking'
    ]),
    observation: z.string(),
    reframe: z.string().optional()
  })).optional(),
  philosophicalEchoes: z.array(z.object({
    id: z.string().optional(),
    tradition: z.enum(['stoicism', 'buddhism', 'existentialism', 'socratic']),
    connection: z.string(),
    quote: z.string().optional(),
    source: z.string().optional()
  })).optional(),
  valuesInsights: z.object({
    coreValues: z.array(z.object({
      id: z.string().optional(),
      name: z.string(),
      evidence: z.string(),
      confidence: z.number().min(0).max(1)
    })),
    tensions: z.array(z.object({
      id: z.string().optional(),
      value1: z.string(),
      value2: z.string(),
      observation: z.string()
    })).optional()
  }).optional()
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

// Pro Tier Analysis Schemas

// Thinking Patterns - Observational language pattern recognition
export const ThinkingPatternsDataSchema = z.object({
  thinkingPatterns: z.array(z.object({
    id: z.string().optional(),
    type: z.enum([
      'black-and-white-thinking',
      'worst-case-thinking',
      'assumption-making',
      'overbroad-generalizing',
      'pressure-language',
      'feelings-as-facts-thinking'
    ]),
    observation: z.string(),
    reframe: z.string().optional()
  }))
});

// Philosophical Echoes - Connections to ancient wisdom traditions
export const PhilosophicalEchoesDataSchema = z.object({
  philosophicalEchoes: z.array(z.object({
    id: z.string().optional(),
    tradition: z.enum(['stoicism', 'buddhism', 'existentialism', 'socratic']),
    connection: z.string(),
    quote: z.string().optional(),
    source: z.string().optional()
  }))
});

// Values Recognition - Core values and competing priorities
export const ValuesRecognitionDataSchema = z.object({
  coreValues: z.array(z.object({
    id: z.string().optional(),
    name: z.string(),
    evidence: z.string(),
    confidence: z.number().min(0).max(1)
  })),
  tensions: z.array(z.object({
    id: z.string().optional(),
    value1: z.string(),
    value2: z.string(),
    observation: z.string()
  })).optional()
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

// Pro Tier JSON Schemas for GPT-5 Responses API

export const ThinkingPatternsJsonSchema = {
  name: "thinking_patterns_response",
  schema: {
    type: "object",
    properties: {
      thinkingPatterns: {
        type: "array",
        description: "Linguistic speech patterns observed. Return empty array if none found.",
        items: {
          type: "object",
          properties: {
            type: {
              type: "string",
              enum: ["black-and-white-thinking", "worst-case-thinking", "assumption-making", "overbroad-generalizing", "pressure-language", "feelings-as-facts-thinking"],
              description: "Type of speech pattern observed"
            },
            observation: {
              type: "string",
              description: "Specific observation from the transcript with evidence"
            },
            reframe: {
              type: "string",
              description: "Optional: An alternative way to express this"
            }
          },
          required: ["type", "observation"]
        }
      }
    },
    required: ["thinkingPatterns"],
    additionalProperties: false
  }
};

export const PhilosophicalEchoesJsonSchema = {
  name: "philosophical_echoes_response",
  schema: {
    type: "object",
    properties: {
      philosophicalEchoes: {
        type: "array",
        description: "Connections to ancient wisdom traditions. Return empty array if no clear connections.",
        items: {
          type: "object",
          properties: {
            tradition: {
              type: "string",
              enum: ["stoicism", "buddhism", "existentialism", "socratic"],
              description: "Wisdom tradition this insight connects to"
            },
            connection: {
              type: "string",
              description: "2-3 sentences explaining how their insight echoes this tradition"
            },
            quote: {
              type: "string",
              description: "Optional: Relevant quote from the tradition"
            },
            source: {
              type: "string",
              description: "Optional: Attribution (e.g., 'Marcus Aurelius, Meditations')"
            }
          },
          required: ["tradition", "connection"]
        }
      }
    },
    required: ["philosophicalEchoes"],
    additionalProperties: false
  }
};

export const ValuesRecognitionJsonSchema = {
  name: "values_recognition_response",
  schema: {
    type: "object",
    properties: {
      coreValues: {
        type: "array",
        description: "2-4 core values revealed in this memo based on energy, emphasis, emotion",
        items: {
          type: "object",
          properties: {
            name: {
              type: "string",
              description: "The value name (e.g., 'Authenticity', 'Family', 'Achievement')"
            },
            evidence: {
              type: "string",
              description: "Specific moment from the memo that reveals this value"
            },
            confidence: {
              type: "number",
              description: "Confidence score: 0.9-1.0 = explicit, 0.7-0.89 = strong implicit, <0.7 = omit"
            }
          },
          required: ["name", "evidence", "confidence"]
        },
        minItems: 2,
        maxItems: 4
      },
      tensions: {
        type: "array",
        description: "Optional: Value tensions (competing priorities). Return empty array if no clear tensions.",
        items: {
          type: "object",
          properties: {
            value1: { type: "string", description: "First value in tension" },
            value2: { type: "string", description: "Second value in tension" },
            observation: {
              type: "string",
              description: "How this tension manifests in their life"
            }
          },
          required: ["value1", "value2", "observation"]
        }
      }
    },
    required: ["coreValues", "tensions"],
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
  'thinking-patterns': ThinkingPatternsJsonSchema,
  'philosophical-echoes': PhilosophicalEchoesJsonSchema,
  'values-recognition': ValuesRecognitionJsonSchema,
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
    'distill-reflection',
    'thinking-patterns',
    'philosophical-echoes',
    'values-recognition'
  ]),
  data: z.union([
    EventsDataSchema,
    RemindersDataSchema,
    DistillDataSchema,
    LiteDistillDataSchema,
    DistillSummaryDataSchema,
    DistillActionsDataSchema,
    DistillThemesDataSchema,
    DistillReflectionDataSchema,
    ThinkingPatternsDataSchema,
    PhilosophicalEchoesDataSchema,
    ValuesRecognitionDataSchema
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
export type ThinkingPatternsData = z.infer<typeof ThinkingPatternsDataSchema>;
export type PhilosophicalEchoesData = z.infer<typeof PhilosophicalEchoesDataSchema>;
export type ValuesRecognitionData = z.infer<typeof ValuesRecognitionDataSchema>;
export type EventsData = z.infer<typeof EventsDataSchema>;
export type RemindersData = z.infer<typeof RemindersDataSchema>;
export type DataOut = DistillData | LiteDistillData | DistillSummaryData | DistillActionsData | DistillThemesData | DistillReflectionData | ThinkingPatternsData | PhilosophicalEchoesData | ValuesRecognitionData | EventsData | RemindersData;
export type ResponseData = z.infer<typeof ResponseSchema>;
