import { z } from 'zod';

export const RequestSchema = z.object({
  mode: z.enum(['tldr', 'analysis', 'themes', 'todos']),
  transcript: z.string().min(10).max(10000)
});

export const AnalysisDataSchema = z.object({
  summary: z.string(),
  key_points: z.array(z.string())
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

export const ResponseSchema = z.object({
  mode: z.enum(['tldr', 'analysis', 'themes', 'todos']),
  data: z.union([AnalysisDataSchema, ThemesDataSchema, TodosDataSchema]),
  model: z.string(),
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
export type ThemesData = z.infer<typeof ThemesDataSchema>;
export type TodosData = z.infer<typeof TodosDataSchema>;
export type DataOut = AnalysisData | ThemesData | TodosData;
export type ResponseData = z.infer<typeof ResponseSchema>;
