import { z } from 'zod';

// GPT-5 Model Settings Configuration - Optimized per complexity
export const ModelSettings = {
  distill:   { verbosity: 'medium', reasoningEffort: 'medium' }, // Complex analysis with coaching questions
  analysis:  { verbosity: 'low', reasoningEffort: 'medium' },    // Standard analysis with key points extraction
  themes:    { verbosity: 'low', reasoningEffort: 'medium' },    // Pattern recognition for thematic analysis
  todos:     { verbosity: 'low', reasoningEffort: 'low' },       // Simple extraction of actionable items
  summarize: { verbosity: 'low', reasoningEffort: 'low' },       // Basic summarization task
  tldr:      { verbosity: 'low', reasoningEffort: 'low' }        // Minimal processing for quick summaries
} as const;

export type AnalysisMode = keyof typeof ModelSettings;
export type VerbosityLevel = "low" | "medium" | "high";
export type ReasoningEffort = "low" | "medium" | "high";

export const RequestSchema = z.object({
  mode: z.enum(['analysis', 'themes', 'todos', 'distill']),
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
  key_themes: z.array(z.string()),
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
      key_themes: {
        type: "array",
        description: "2-4 main themes/topics extracted from the memo",
        items: { type: "string" },
        minItems: 2,
        maxItems: 4
      },
      reflection_questions: {
        type: "array",
        description: "2-3 coaching questions to help the user think deeper",
        items: { type: "string" },
        minItems: 2,
        maxItems: 3
      }
    },
    required: ["summary", "action_items", "key_themes", "reflection_questions"],
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

// Mapping analysis types to their JSON schemas
export const AnalysisJsonSchemas = {
  distill: DistillJsonSchema,
  analysis: AnalysisJsonSchema,
  themes: ThemesJsonSchema,
  todos: TodosJsonSchema
} as const;

// Supported GPT models
export const ModelSchema = z.enum(['gpt-5-mini', 'gpt-5-nano', 'gpt-4o', 'gpt-4o-mini']);

export const ResponseSchema = z.object({
  mode: z.enum(['analysis', 'themes', 'todos', 'distill']),
  data: z.union([AnalysisDataSchema, ThemesDataSchema, TodosDataSchema, DistillDataSchema]),
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
export type ThemesData = z.infer<typeof ThemesDataSchema>;
export type TodosData = z.infer<typeof TodosDataSchema>;
export type DataOut = AnalysisData | ThemesData | TodosData | DistillData;
export type ResponseData = z.infer<typeof ResponseSchema>;
