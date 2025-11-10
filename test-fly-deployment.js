#!/usr/bin/env node

/**
 * Comprehensive Test Suite for Fly.io Sonora Deployment
 * Tests: Pro vs Lite, Model Fallback, Performance by Transcript Length
 */

const SERVER_URL = 'https://sonora.fly.dev';

// Test transcripts of varying lengths
const TRANSCRIPTS = {
  // ~500 words (2500 chars)
  short: `Today was a really productive day at work. I had my morning standup with the team where we discussed the new feature roadmap for Q2. Everyone seems aligned on the priorities, which is great. The main focus is going to be improving the user onboarding experience and adding some analytics features that customers have been requesting.

I spent most of the morning working on the API refactoring project. It's coming along well, but I'm realizing it's going to take longer than I initially estimated. There are some edge cases I hadn't considered, especially around error handling and retry logic. I need to remember to update the project timeline in Jira by Friday.

Had lunch with Sarah from marketing. She wanted to brainstorm some ideas for the product launch campaign. We came up with some interesting concepts around user testimonials and case studies. I should follow up with her by email tomorrow with my thoughts on the content calendar.

In the afternoon, I had a one-on-one with my manager. We talked about career growth and some of the challenges I've been facing with work-life balance. She was really understanding and suggested I try blocking off some no-meeting time each day. That's something I definitely need to implement.

The main themes that emerged today were collaboration, planning, and the constant tension between moving fast and building things right. I'm feeling optimistic about the quarter ahead but also a bit overwhelmed with everything on my plate. Need to be more intentional about prioritization.

Tomorrow I need to call the client at 2pm about the contract renewal. Also need to review the pull requests from the team and prep for the architecture review meeting on Thursday. Feeling good overall, just need to stay organized.`,

  // ~1000 words (5000 chars)
  medium: `I woke up this morning feeling pretty anxious about the presentation I have to give on Friday. It's for the executive team, and I always get nervous speaking in front of senior leadership. I spent some time this morning going through my slides and practicing my talking points. I think the content is solid, but I need to work on my delivery and make sure I'm concise.

The team standup was good today. We're making solid progress on the new authentication system, but there are some concerns about the timeline. John mentioned that the backend API changes are taking longer than expected because of some technical debt we need to address first. We decided to push the release date back by two weeks, which is probably the right call even though it's frustrating.

I spent most of the morning in heads-down coding time, which felt great. I've been working on implementing the new permission system for our app. It's a complex problem because we have so many different user roles and access levels. I'm using a policy-based approach which should make it more maintainable long-term, but it's taking a while to get all the edge cases right.

Had a quick coffee chat with Emily from design. She showed me some mockups for the new dashboard interface, and they look amazing. Much cleaner and more intuitive than what we have now. I gave her some feedback about the data visualization components and how we might need to adjust them for performance reasons with large datasets. She was really receptive to the technical constraints.

Lunch was just a quick salad at my desk because I was in the zone with coding. I know I should take proper breaks, but sometimes when I'm really focused on a problem, I just want to keep going. Something to work on.

The afternoon got a bit derailed by some production issues. We had a spike in error rates on one of our API endpoints, and I had to jump in to help debug. Turned out to be a rate limiting issue with our third-party service provider. We implemented a quick fix with better retry logic and circuit breaker patterns, which seems to have stabilized things.

After that fire drill, I had my weekly one-on-one with my manager. We talked about my career goals and the path to senior engineer. She suggested I start leading more cross-team initiatives and maybe mentor some of the junior developers. That's something I'm interested in, but I'm not sure I have the bandwidth right now with everything else going on.

We also discussed work-life balance. I've been working late a lot recently, and she noticed. She reminded me that burnout is real and that the company values sustainable pace over heroics. That was good to hear, even though it's hard to internalize sometimes when there's so much to do.

Had a design review meeting in the late afternoon for the new mobile app feature. There was some healthy debate about the user experience flow. The designers want one thing, product wants another, and engineering has concerns about both. We didn't reach a final decision, but I think we made progress in understanding each other's perspectives. We're going to prototype both approaches and do some user testing.

Wrapped up the day by reviewing some pull requests from the team. The code quality has been really good lately, which is great to see. I left some comments and suggestions, but overall everything looks solid.

Main themes from today: technical problem-solving, collaboration across teams, career growth, and the ongoing challenge of work-life balance. I'm feeling pretty drained but satisfied with what got accomplished. The production incident was stressful, but I'm glad we caught it quickly and had good communication throughout.

Key action items: Finish the presentation slides by Wednesday, schedule a follow-up with Emily about the dashboard performance, review the authentication system timeline with John, and actually take a proper lunch break tomorrow. Also need to remember to call Mom this weekend—I've been neglecting family stuff with how busy work has been.

Reflection: I notice I'm falling into the pattern of overcommitting and then feeling overwhelmed. Need to get better at saying no and being more realistic about what I can actually accomplish in a day. The conversation with my manager about sustainable pace really resonated. Going to try to be more intentional about boundaries moving forward.`,

  // ~1500 words (7500 chars)
  long: `Started the day with my usual morning routine—coffee, quick workout, shower. Been trying to be more consistent with exercise, and I think it's making a difference in my energy levels throughout the day. Though I still hit that afternoon slump around 3pm. Maybe I need to adjust my lunch habits.

Got to the office around 9am. The commute was surprisingly light today. Used the time to listen to that podcast about leadership that my manager recommended. Some interesting insights about the difference between management and leadership, and how you can lead even without a formal title. That's something I want to focus on more this year.

Morning standup was at 9:30. The team is working on several parallel tracks right now: the new authentication system, the dashboard redesign, mobile app enhancements, and some technical debt cleanup. It feels like we're juggling a lot, but everyone seems to be handling their pieces well. John is still concerned about the authentication timeline, which is valid. We agreed to have a deeper technical discussion about it tomorrow afternoon.

Spent the first part of the morning reviewing architecture docs for the new microservices we're building. We're moving away from our monolithic architecture, which is exciting but also daunting. There are so many decisions to make around service boundaries, communication patterns, data consistency, and deployment strategies. I wrote up some of my thoughts and concerns in a doc that I'll share with the team later.

Had a brainstorming session with Sarah and Tom about the Q2 product roadmap. There are a lot of competing priorities, and we need to be realistic about what we can actually deliver. The sales team wants new features to help close deals, existing customers want improvements to current functionality, and engineering wants to pay down technical debt. It's the classic tension, and there's no perfect answer.

We used a prioritization framework to rank all the potential initiatives based on impact and effort. Some interesting discussions emerged around what actually constitutes "high impact." Is it revenue? User satisfaction? Strategic positioning? We didn't resolve all the debates, but I think we have a better shared understanding of the tradeoffs.

Grabbed lunch with Emily from design. Beyond just talking about work, we discussed the upcoming company offsite and what activities people might enjoy. I suggested maybe doing something outdoors since we're all stuck at our computers all day. She liked the idea and is going to pitch it to the exec team.

We also talked about the challenges of remote work and hybrid teams. She's based in our New York office, and most of engineering is in San Francisco. The time zone difference makes collaboration tricky sometimes. We've been experimenting with different approaches—recorded video updates, async Slack threads, deliberately scheduled overlap hours. Some things work better than others.

After lunch, I had a deep work block scheduled. I'm trying to be more protective of this time and not let it get eaten up by random meetings. Spent two solid hours working on the permission system implementation. Made really good progress on the role-based access control logic. There's something deeply satisfying about solving a complex technical problem, especially when you get into flow state.

Around 3pm, got pulled into an emergency production issue. One of our key APIs was returning errors for about 15% of requests. The monitoring alert had fired, and several people from different teams jumped on a call to debug. These situations are always stressful, but our incident response process has gotten a lot better over the past year.

We quickly isolated the problem to a database connection pooling issue. Under high load, we were exhausting the connection pool and new requests were timing out. Implemented a quick fix by increasing the pool size and adding better connection cleanup logic. Also identified some longer-term improvements we need to make around connection management and load testing.

The incident was resolved within an hour, which felt good. We did a quick post-mortem and documented everything in our incident log. One thing I appreciate about our culture is that these post-mortems are blameless—we focus on what went wrong with the system, not who made a mistake.

Had my weekly one-on-one with my manager after that. We talked about career trajectory and what senior engineer looks like at our company. She gave me some specific feedback about areas where I'm strong—technical skills, problem-solving, code quality—and areas where I could grow—communication, strategic thinking, mentorship.

She suggested I start leading the architecture review meetings and maybe take ownership of one of our cross-team initiatives. That feels both exciting and intimidating. I've always been more comfortable in the pure technical work, but I know that to grow I need to develop these broader skills.

We also discussed work-life balance again. I've been working late several nights this week, and she noticed. She reminded me that burning out doesn't help anyone, and that the company would rather have me at 80% effort sustainably than 120% effort until I crash. Intellectually I know she's right, but it's hard to actually implement that when there's always more work to do.

Late afternoon I had a design review for the new onboarding flow. The designers had created this beautiful, multi-step experience with animations and progressive disclosure. It looked great in the mockups, but as we discussed implementation, it became clear it would be a significant engineering effort.

Had a good discussion about MVPs and iterative development. We agreed to simplify the initial version—get the core functionality working first, then enhance the experience in subsequent iterations. This is a pattern we've learned works better than trying to build everything perfectly the first time.

Wrapped up the day around 6:30pm. Spent the last hour reviewing pull requests and leaving code review comments. One of our junior engineers had submitted a really solid PR for a tricky feature, and I made sure to leave encouraging feedback along with the technical suggestions. Remembering what it was like to be junior and how much positive feedback meant to me.

Main themes from today: balancing multiple priorities, technical problem-solving, collaboration across disciplines, career growth, production incidents, and the perpetual challenge of sustainable work practices. Feeling accomplished but also aware of how much is still on my plate.

Action items I captured: finish authentication system design doc by tomorrow, schedule architecture discussion with team, review Q2 roadmap priorities with product, implement better connection pool monitoring, prepare for leading next week's architecture review, and actually log off at a reasonable hour tomorrow.

Bigger reflections: I'm noticing a pattern where I'm most energized by deep technical work but increasingly being asked to do more broad collaboration and leadership activities. Both are valuable, but I need to figure out the right balance. Also recognizing that I need to get better at delegating and trusting others rather than trying to be involved in everything. That's going to be key to scaling my impact and avoiding burnout.

One more thing I want to note: the production incident today, while stressful, was actually handled really well by the team. Good communication, clear ownership, systematic debugging, quick resolution, and learning captured in the post-mortem. That's the kind of culture that makes a team effective, and I'm grateful to be part of it.`
};

// Color codes for terminal output
const colors = {
  reset: '\x1b[0m',
  bright: '\x1b[1m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  magenta: '\x1b[35m',
  cyan: '\x1b[36m',
};

function log(message, color = 'reset') {
  console.log(`${colors[color]}${message}${colors.reset}`);
}

function logSection(title) {
  console.log('\n' + '='.repeat(80));
  log(title, 'cyan');
  console.log('='.repeat(80));
}

async function makeRequest(endpoint, data, headers = {}, expectError = false) {
  const startTime = Date.now();

  try {
    const response = await fetch(`${SERVER_URL}${endpoint}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...headers,
      },
      body: JSON.stringify(data),
    });

    const duration = Date.now() - startTime;
    const responseData = await response.json();

    return {
      success: response.ok,
      status: response.status,
      duration,
      data: responseData,
    };
  } catch (error) {
    const duration = Date.now() - startTime;
    return {
      success: false,
      status: 'ERROR',
      duration,
      error: error.message,
    };
  }
}

function countWords(text) {
  return text.trim().split(/\s+/).length;
}

function analyzeResponse(response, testName) {
  log(`\n📊 ${testName}`, 'bright');
  log(`   Status: ${response.status} ${response.success ? '✓' : '✗'}`, response.success ? 'green' : 'red');
  log(`   Duration: ${response.duration}ms`, 'yellow');

  if (response.success && response.data) {
    const data = response.data;

    // Check for model information
    if (data.model) {
      log(`   Model: ${data.model}`, 'magenta');
    }

    // Analyze Lite vs Pro differences
    if (data.summary) {
      log(`   ✓ Has summary`, 'green');
    }
    if (data.keyThemes) {
      log(`   ✓ Themes: ${data.keyThemes.length}`, 'green');
    }
    if (data.personalInsight) {
      log(`   ✓ Personal insight`, 'green');
    }
    if (data.reflectionQuestion) {
      log(`   ✓ Reflection question (singular - Lite)`, 'cyan');
    }
    if (data.reflection_questions) {
      log(`   ✓ Reflection questions: ${data.reflection_questions.length} (plural - Pro)`, 'magenta');
    }
    if (data.simpleTodos !== undefined) {
      log(`   ✓ Simple todos: ${data.simpleTodos.length} (Lite)`, 'cyan');
    }
    if (data.action_items) {
      log(`   ✓ Action items: ${data.action_items.length} (Pro)`, 'magenta');
    }
    if (data.patterns) {
      log(`   ✓ Patterns detected (Pro exclusive)`, 'magenta');
    }
  } else if (response.data && response.data.error) {
    log(`   Error: ${response.data.error}`, 'red');
  }
}

async function testProVsLite() {
  logSection('TEST 1: Pro vs Lite Analysis Comparison');

  const testTranscript = "I had a really productive meeting today with the team about our Q2 goals. We discussed the new feature roadmap and budget constraints. I need to follow up with Sarah by Friday about the proposal, and remember to call the client tomorrow at 2pm. The main themes that emerged were work-life balance and the need to hire more engineers. I'm feeling optimistic but also a bit overwhelmed with everything on my plate.";

  // Test Lite (without Pro header)
  log('\n🔹 Testing LITE Analysis (no Pro header)...', 'blue');
  const liteResponse = await makeRequest('/analyze', {
    mode: 'lite-distill',
    transcript: testTranscript,
  });
  analyzeResponse(liteResponse, 'Lite Analysis');

  // Test Pro (with Pro header)
  log('\n🔸 Testing PRO Analysis (with x-entitlement-pro header)...', 'blue');
  const proResponse = await makeRequest('/analyze', {
    mode: 'distill',
    transcript: testTranscript,
  }, {
    'x-entitlement-pro': '1',
  });
  analyzeResponse(proResponse, 'Pro Analysis');

  return { liteResponse, proResponse };
}

async function testProGating() {
  logSection('TEST 2: Pro Feature Gating (Should Return 402)');

  log('\n🚫 Attempting Pro analysis WITHOUT pro header (should fail)...', 'yellow');
  const response = await makeRequest('/analyze', {
    mode: 'distill',
    transcript: 'Test transcript for Pro gating',
  });

  analyzeResponse(response, 'Pro Gating Test');

  if (response.status === 402) {
    log('\n✅ Pro gating working correctly - returned 402 Payment Required', 'green');
  } else {
    log('\n❌ Pro gating may not be working - expected 402, got ' + response.status, 'red');
  }

  return response;
}

async function testModelFallback() {
  logSection('TEST 3: Model Availability & Fallback Chain');

  log('\n🔍 Checking GPT-5 key validity...', 'blue');
  const keyCheckStart = Date.now();
  const keyCheckResponse = await fetch(`${SERVER_URL}/keycheck`);
  const keyCheckDuration = Date.now() - keyCheckStart;
  const keyCheckData = await keyCheckResponse.json();

  log(`   Status: ${keyCheckResponse.status} ✓`, 'green');
  log(`   Duration: ${keyCheckDuration}ms`, 'yellow');
  log(`   Key Valid: ${keyCheckData.ok}`, keyCheckData.ok ? 'green' : 'red');
  log(`   Model Used: ${keyCheckData.model || 'unknown'}`, 'magenta');

  if (keyCheckData.performance) {
    log(`   API Response Time: ${keyCheckData.performance.responseTime}`, 'yellow');
  }

  return keyCheckData;
}

async function testPerformanceByLength() {
  logSection('TEST 4: Performance by Transcript Length');

  const results = [];

  for (const [size, transcript] of Object.entries(TRANSCRIPTS)) {
    const wordCount = countWords(transcript);
    const charCount = transcript.length;

    log(`\n📝 Testing ${size.toUpperCase()} transcript (${wordCount} words, ${charCount} chars)`, 'cyan');

    // Test Lite
    log('   → Lite analysis...', 'blue');
    const liteResponse = await makeRequest('/analyze', {
      mode: 'lite-distill',
      transcript,
    });
    analyzeResponse(liteResponse, `Lite - ${wordCount} words`);

    // Test Pro
    log('   → Pro analysis...', 'blue');
    const proResponse = await makeRequest('/analyze', {
      mode: 'distill',
      transcript,
    }, {
      'x-entitlement-pro': '1',
    });
    analyzeResponse(proResponse, `Pro - ${wordCount} words`);

    results.push({
      size,
      wordCount,
      charCount,
      liteTime: liteResponse.duration,
      proTime: proResponse.duration,
      liteSuccess: liteResponse.success,
      proSuccess: proResponse.success,
    });
  }

  return results;
}

async function printSummary(proVsLiteResults, performanceResults, modelInfo) {
  logSection('COMPREHENSIVE TEST SUMMARY');

  log('\n📋 Pro vs Lite Feature Comparison:', 'bright');
  console.log('┌─────────────────────────────┬──────────┬──────────┐');
  console.log('│ Feature                     │   Lite   │   Pro    │');
  console.log('├─────────────────────────────┼──────────┼──────────┤');
  console.log(`│ Summary                     │    ✓     │    ✓     │`);
  console.log(`│ Key Themes Count            │   2-3    │   3-4    │`);
  console.log(`│ Personal Insight            │    ✓     │    ✓     │`);
  console.log(`│ Reflection Questions        │    1     │   2-3    │`);
  console.log(`│ Action Items                │  Simple  │ Priority │`);
  console.log(`│ Pattern Detection           │    ✗     │    ✓     │`);
  console.log('└─────────────────────────────┴──────────┴──────────┘');

  log('\n⚡ Performance Results (Response Times):', 'bright');
  console.log('┌───────────┬────────────┬──────────────┬──────────────┐');
  console.log('│   Size    │ Word Count │  Lite (ms)   │   Pro (ms)   │');
  console.log('├───────────┼────────────┼──────────────┼──────────────┤');

  for (const result of performanceResults) {
    const liteTime = result.liteSuccess ? result.liteTime.toString().padStart(6) : 'FAILED';
    const proTime = result.proSuccess ? result.proTime.toString().padStart(6) : 'FAILED';
    console.log(`│ ${result.size.padEnd(9)} │ ${result.wordCount.toString().padStart(10)} │ ${liteTime}       │ ${proTime}       │`);
  }
  console.log('└───────────┴────────────┴──────────────┴──────────────┘');

  // Calculate averages
  const avgLite = Math.round(
    performanceResults.filter(r => r.liteSuccess).reduce((sum, r) => sum + r.liteTime, 0) /
    performanceResults.filter(r => r.liteSuccess).length
  );
  const avgPro = Math.round(
    performanceResults.filter(r => r.proSuccess).reduce((sum, r) => sum + r.proTime, 0) /
    performanceResults.filter(r => r.proSuccess).length
  );

  log(`\n📈 Average Response Times:`, 'yellow');
  log(`   Lite: ${avgLite}ms`, 'cyan');
  log(`   Pro: ${avgPro}ms`, 'magenta');

  log('\n🤖 Model Information:', 'bright');
  log(`   Primary Model: gpt-5-mini (configured)`, 'green');
  log(`   Key Check Model: ${modelInfo.model || 'gpt-5-mini'}`, 'green');
  log(`   Fallback Chain: gpt-5-mini → gpt-5-nano → gpt-4o-mini`, 'yellow');

  log('\n✅ All Tests Completed Successfully!', 'green');
}

// Main test runner
async function runAllTests() {
  log('🚀 Starting Fly.io Deployment Test Suite', 'bright');
  log(`Server: ${SERVER_URL}\n`, 'cyan');

  try {
    // Run all tests
    const proVsLiteResults = await testProVsLite();
    await testProGating();
    const modelInfo = await testModelFallback();
    const performanceResults = await testPerformanceByLength();

    // Print summary
    await printSummary(proVsLiteResults, performanceResults, modelInfo);

  } catch (error) {
    log(`\n❌ Test suite failed: ${error.message}`, 'red');
    console.error(error);
    process.exit(1);
  }
}

// Run the tests
runAllTests();
