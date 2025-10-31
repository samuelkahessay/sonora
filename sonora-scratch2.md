Now let me create a comprehensive analysis of what remains to be implemented.

  ★ Insight ─────────────────────────────────────
  Based on my analysis of the codebase, the Free vs Pro redesign is well underway but still needs several key Pro-tier features. The free tier (Lite Distill) is fully implemented
  with all components in place, but the Pro enrichment phase needs work.
  ─────────────────────────────────────────────────

  Analysis Summary

  ---
  ❌ Missing Pro-Tier Features (Phase 2)

  According to the design document, Pro tier should have 5 additional components:

  1. Cognitive Clarity (NEW - Beck/Ellis patterns)

  Status: ❌ Not implemented

  What's needed:
  // iOS Model (add to AnalysisModels.swift)
  public struct CognitivePattern: Codable, Sendable, Identifiable {
      public let id: String
      public let type: CognitiveDistortion
      public let observation: String
      public let reframe: String?

      public enum CognitiveDistortion: String, Codable {
          case allOrNothing      // "I always mess up"
          case catastrophizing   // "This is a disaster"
          case mindReading       // "They think I'm incompetent"
          case overgeneralization // "Nothing ever works"
          case shouldStatements  // "I should be better"
          case emotionalReasoning // "I feel it, so it must be true"
      }
  }

  Server prompt needed (add to prompts.ts):
  case 'cognitive-clarity':
    user = `Transcript: <<<${safe}>>>\n` +
      `Identify cognitive distortions (Beck/Ellis framework).\n` +
      `Types: all-or-nothing, catastrophizing, mind-reading, overgeneralization, should-statements, emotional-reasoning\n` +
      `Return JSON: {"cognitivePatterns":[{"type":"...","observation":"...","reframe":"..."}]}`;

  ---
  2. Philosophical Echoes (Wisdom connections)

  Status: ❌ Not implemented

  What's needed:
  // iOS Model
  public struct PhilosophicalEcho: Codable, Sendable, Identifiable {
      public let id: String
      public let tradition: PhilosophicalTradition
      public let connection: String
      public let quote: String?
      public let source: String?

      public enum PhilosophicalTradition: String, Codable {
          case stoicism          // Epictetus, Marcus Aurelius
          case buddhism          // Non-attachment, mindfulness
          case existentialism    // Frankl, Camus
          case socratic          // Questioning, examined life
      }
  }

  Server prompt needed:
  case 'philosophical-echoes':
    user = `Transcript: <<<${safe}>>>\n` +
      `Connect user insights to ancient wisdom (Stoicism, Buddhism, Existentialism, Socratic thought).\n` +
      `Return JSON: {"philosophicalEchoes":[{"tradition":"...","connection":"...","quote":"...","source":"..."}]}`;

  ---
  3. Values Recognition (What matters)

  Status: ❌ Not implemented

  What's needed:
  // iOS Model
  public struct ValuesInsight: Codable, Sendable {
      public let coreValues: [DetectedValue]
      public let tensions: [ValueTension]?

      public struct DetectedValue: Codable, Sendable, Identifiable {
          public let id: String
          public let name: String          // "Authenticity"
          public let evidence: String      // "You lit up discussing 'being real'"
          public let confidence: Float
      }

      public struct ValueTension: Codable, Sendable, Identifiable {
          public let id: String
          public let value1: String        // "Achievement"
          public let value2: String        // "Rest"
          public let observation: String   // "Pull between productivity and self-care"
      }
  }

  Server prompt needed:
  case 'values-recognition':
    user = `Transcript: <<<${safe}>>>\n` +
      `Identify core values (what matters to this person based on energy, emphasis, emotion).\n` +
      `Detect value tensions (competing priorities).\n` +
      `Return JSON: {"coreValues":[...],"tensions":[...]}`;

  ---
  4. Enhanced DistillData (Update existing model)

  Status: ⚠️ Partially implemented

  Current DistillData has:
  - ✅ summary
  - ✅ action_items
  - ✅ reflection_questions
  - ✅ patterns (historical patterns with cross-memo themes)

  What's missing: Add Pro fields to existing model (AnalysisModels.swift:81-143):
  public struct DistillData: Codable, Sendable {
      // Existing fields...

      // PRO ADDITIONS
      public let cognitivePatterns: [CognitivePattern]?
      public let philosophicalEchoes: [PhilosophicalEcho]?
      public let valuesInsights: ValuesInsight?
  }

  ---
  5. Pro UI Organization (Collapsible sections)

  Status: ❌ Not implemented

  Current UI (DistillResultView.swift): Shows flat list of sections
  Needed: Reorganize into collapsible "Wisdom View" with:
  - 🧠 Cognitive Clarity (expandable)
  - 🔗 Patterns & Connections (expandable)
  - 📚 Philosophical Echoes (expandable)
  - 💎 Values & What Matters (expandable)
  - ✅ Action Intelligence (tabs: Tasks | Events | Reminders)

  New component needed:
  // CollapsibleWisdomSection.swift
  struct CollapsibleWisdomSection<Content: View>: View {
      let title: String
      let icon: String
      let content: Content
      @State private var isExpanded: Bool = false

      var body: some View {
          VStack {
              // Header with chevron
              // Expandable content
          }
      }
  }

  ---
  ⚠️ Tier Gating Implementation

  Current State:
  - ✅ StoreKitService tracks isPro status
  - ✅ AnalysisMode.freeTierCases and .proTierCases defined (AnalysisModels.swift:21-28)
  - ⚠️ Missing: Enforcement in UI and service layer

  What's needed:
  // In MemoDetailViewModel or AnalysisSectionView
  func performAnalysis(mode: AnalysisMode, transcript: String) {
      let isPro = storeKitService.isPro

      if mode.isProTier && !isPro {
          // Show paywall
          showPaywall = true
          return
      }

      // Proceed with analysis
      if isPro {
          analyzeDistillParallelUseCase.execute(...)  // Pro: 5-7 API calls
      } else {
          analyzeLiteDistillUseCase.execute(...)      // Free: 1 API call
      }
  }

  ---
  📋 Implementation Roadmap

  Based on the design document's 3-phase plan:

  Phase 1: Foundation ✅ COMPLETE

  - ✅ LiteDistillData model
  - ✅ lite-distill server prompt
  - ✅ LiteDistillResultView UI
  - ✅ PersonalInsight delight factor

  Phase 2: Pro Enrichment ❌ INCOMPLETE (Estimate: 3-4 weeks)

  1. Add Pro data models (~2 days)
    - CognitivePattern
    - PhilosophicalEcho
    - ValuesInsight
    - Update DistillData
  2. Server prompts for Pro features (~3 days)
    - cognitive-clarity mode
    - philosophical-echoes mode
    - values-recognition mode
    - Update parallel execution to include new modes
  3. Pro UI components (~5 days)
    - CognitiveClaritySectionView
    - PhilosophicalEchosSectionView
    - ValuesInsightSectionView
    - CollapsibleWisdomSection wrapper
  4. Reorganize DistillResultView (~3 days)
    - Implement collapsible sections
    - Add progressive disclosure
    - Update layout for "Wisdom View"
  5. Tier gating enforcement (~2 days)
    - Add isPro checks in ViewModel
    - Show paywall for Pro features
    - Analytics tracking for upgrade prompts

  Phase 3: Polish & Optimize ❌ NOT STARTED (Estimate: 2 weeks)

  - A/B test Personal Insight types
  - Optimize prompt costs
  - UI transitions/animations
  - Progressive disclosure refinements

  ---
  🎯 Next Steps (Recommended Priority)

  1. Define Pro data models (CognitivePattern, PhilosophicalEcho, ValuesInsight)
  2. Create server prompts for 3 new Pro modes
  3. Update parallel execution to include cognitive-clarity, philosophical-echoes, values-recognition
  4. Build Pro UI sections with collapsible layout
  5. Add tier gating to enforce Free vs Pro access
  6. Update DistillData schema to include Pro fields

  ---
  ★ Insight ─────────────────────────────────────
  Key Architectural Decision: The free tier is a complete experience (not crippled), while Pro adds genuine depth. This aligns with the design doc's philosophy: "Delight over
  withholding." The single PersonalInsight in free tier creates an "aha moment," making users want more without feeling cheated.



  Before we create the pro UI components, can we enable streaming for the AI analysis (we already have streaming for auto title generation) - just to enable faster user feedback to
  see that analysis is actually happening. Let's make a thorough plan


    4. Build Pro UI sections with collapsible layout

  5. Pro UI Organization (Collapsible sections)

  Status: ❌ Not implemented

  Current UI (DistillResultView.swift): Shows flat list of sections
  Needed: Reorganize into collapsible "Wisdom View" with:
  - 🧠 Cognitive Clarity (expandable)
  - 🔗 Patterns & Connections (expandable)
  - 📚 Philosophical Echoes (expandable)
  - 💎 Values & What Matters (expandable)
  - ✅ Action Intelligence (tabs: Tasks | Events | Reminders)

  New component needed:
  // CollapsibleWisdomSection.swift
  struct CollapsibleWisdomSection<Content: View>: View {
      let title: String
      let icon: String
      let content: Content
      @State private var isExpanded: Bool = false

      var body: some View {
          VStack {
              // Header with chevron
              // Expandable content
          }
      }
  }

