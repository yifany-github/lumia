# Lumia Differentiation and User Research Brief

Last updated: 2026-05-11

## Research Signal Summary

Lumia should not position itself as "AI therapy" or a generic meditation/chat app. The strongest defensible position is:

> A private, low-pressure emotional support companion that converts moments of stress into tiny, user-controlled support actions, using local context and clear safety boundaries.

This direction is supported by the existing Lumia architecture work:

- Therapy has explicit Listen / Coach / Plan modes.
- Safety triage and crisis routing run before model generation.
- JITAI has reason codes, fatigue limits, quiet hours, and user controls.
- HealthKit uses daily aggregate context rather than raw high-frequency samples.
- Journal, Garden, Sanctuary, and Therapy already form a loop: notice -> stabilize -> reflect -> act -> follow up.

The main product risk is not "lack of features." It is making users feel watched, judged, clinically labeled, or pressured to perform wellness. The app must feel optional, calm, and useful within 30-90 seconds.

## External Research Findings

1. Demand is real, especially among young adults.
   - NIMH reports that in 2022 more than one in five U.S. adults had any mental illness, and adults 18-25 had the highest prevalence at 36.2%.
   - This does not mean Lumia should treat mental illness. It means there is a large population with recurring emotional-support needs and access gaps.

2. Mental health apps are crowded but shallow.
   - A JAMA Network Open assessment of 578 mental health apps found common features were mostly psychoeducation, goal setting/habits, and mindfulness.
   - This suggests "more content cards" is not differentiation. The gap is orchestration: choosing the right small action at the right moment, with safety and privacy.

3. Engagement should not be measured as "daily app addiction."
   - BMC Digital Health notes that assuming more frequent engagement is always ideal sets the bar unrealistically high for digital mental health interventions.
   - Lumia should optimize for successful short sessions, return during need, and completion of tiny support actions.

4. Conversational agent attrition is meaningful.
   - A 2024 JMIR systematic review found attrition varied by delivery channel, with messaging-app based conversational interventions showing high attrition.
   - Lumia should avoid becoming only "another chatbot." Chat should be one mode inside a larger support system.

5. Privacy can be a competitive advantage.
   - The FTC BetterHelp order shows that sensitive mental health data misuse creates major trust damage.
   - Lumia should make privacy visible in the product itself: local-first defaults, no ad targeting, clear deletion, reason codes, and "why am I seeing this?"

6. Young users use online support but remain skeptical.
   - Hopelab/Common Sense Media's 2024 survey found over half of U.S. teens and young adults surveyed had used at least one app for mental health or well-being, but only 47% of app users found apps at least somewhat helpful.
   - This supports a design goal of immediate usefulness, not feature breadth.

7. Evaluation frameworks emphasize the same foundations.
   - The APA app evaluation model focuses on accessibility, privacy/security, clinical foundation, engagement/usability, and interoperability.
   - Lumia can use this as a product quality checklist, even if it stays in general wellness / emotional support territory.

## Target User Segments

### Primary Segment: Overloaded Young Adults

Profile:
- Age 18-35.
- Students, early-career workers, creators, founders, caregivers, or people in unstable routines.
- They are not necessarily seeking therapy; they want relief, clarity, and a small next step.

Core jobs:
- "I feel tense or scattered and need to calm down quickly."
- "I want to talk without being judged."
- "I want one tiny thing I can actually do today."
- "I do not want a clinical label."

Best Lumia surfaces:
- Home: quiet state summary and one suggested action.
- Sanctuary: 30-90 second stabilization.
- Therapy: Listen / Coach / Plan.
- Garden: small action becomes visible progress.

### Secondary Segment: Therapy-Adjacent Users

Profile:
- Already in therapy, on a waitlist, between sessions, or considering therapy.
- They need continuity, journaling, practice, and reflection.

Core jobs:
- "Help me remember what I was working on."
- "Help me turn therapy insight into a small behavior."
- "Help me track patterns without overanalyzing myself."

Best Lumia surfaces:
- Therapy session summaries.
- Journal timeline and tags.
- Micro-plans and follow-ups.
- Optional export/share-with-therapist later.

### Secondary Segment: Privacy-Sensitive Self-Helpers

Profile:
- Introverted, skeptical of online therapy platforms, concerned about data use.
- May prefer solo tools over communities or human matching.

Core jobs:
- "Give me help without exposing my private life."
- "Do not sell, share, or overcollect sensitive data."
- "Explain why you suggested this."

Best Lumia surfaces:
- Data control center.
- Local-first storage explanation.
- Health context with derived summaries only.
- JITAI reason codes and quiet controls.

### Later Segment: Underserved / Marginalized Young People

Profile:
- Young users with access, stigma, affordability, identity-safety, or cultural-fit barriers.

Important caution:
- Do not claim this segment until the product has participatory research, localization, crisis routing, and stronger safety testing.

## Who Lumia Is Not For Initially

- Acute crisis as the primary use case.
- Diagnosis, treatment decisions, medication guidance, or replacing therapy.
- Users under 18 unless a dedicated youth safety, consent, content, and crisis model is designed.
- Severe impairment requiring clinician-led care.

The app can support crisis routing, but crisis routing is not the product's core promise.

## Differentiation Thesis

### Market Categories

Current market patterns:
- Meditation apps: strong content libraries, weak personalization and action loop.
- Online therapy apps: human provider access, expensive/trust-sensitive, not always immediate.
- AI chatbots: available and conversational, but safety, trust, and retention risks.
- Mood trackers/journals: good capture, weak intervention and follow-through.
- Habit apps: action-oriented, often too performance-driven for emotional distress.

### Lumia's Wedge

Lumia should be:

> The emotional support app for people who do not want pressure, diagnosis, or endless content, but do want one calm next step.

Concrete differentiators:

1. "One quiet minute" as the core interaction.
   - Every screen should answer: what can the user do in under one minute?

2. Context-aware but not creepy.
   - Use derived check-in, journal, Garden, follow-up, and optional Health aggregate context.
   - Always show uncertainty and user control.

3. Support loop, not content library.
   - Listen -> stabilize -> reflect -> micro-plan -> Garden progress -> follow-up.

4. Private by design as visible UX.
   - Data control should be a product feature, not buried policy text.

5. Emotional progress without productivity pressure.
   - Garden should reward showing up and tiny actions, not streak anxiety.

6. Safety boundary as a trust feature.
   - The app should clearly say what it can and cannot do.

## Product Principles

1. Ask less.
   - Avoid long onboarding, long forms, and heavy tracking.

2. Recommend one thing.
   - Do not show too many tools at once. One primary recommendation plus two or three alternatives.

3. Use softer metrics.
   - Avoid dashboards that imply the user is failing.
   - Prefer "steady / tender / overloaded / recovering" over numeric performance language unless needed.

4. Make every intervention user-initiated or explainable.
   - If Lumia suggests something, it must be able to say why.

5. Keep clinical claims out of UI.
   - Use "support," "practice," "reset," "reflection," "small step."
   - Avoid "treat," "diagnose," "cure," "detect depression," "stress score from heart rate."

6. Treat disengagement as normal.
   - The app should not guilt users for returning after days or weeks.

## Feature Direction

### Home

Goal: one glance, one next step.

Should include:
- Current gentle context.
- One recommended action.
- Small entry points to Journal, Therapy, Garden, Sanctuary.
- No overloaded analytics.

Avoid:
- Too many numbers.
- Feeling like a health dashboard.
- Strong claims from passive data.

### Sanctuary

Goal: immediate stabilization.

Make it the "panic-to-grounded" or "tense-to-settled" module.

Core tools:
- Slow exhale.
- Grounding.
- Body scan.
- Gentle prompt.
- Support choice.
- Crisis resources.

Differentiation:
- State first, tool second.
- No library browsing.
- Short enough to use in real life.

### Therapy

Goal: private conversation with structure.

Modes:
- Listen: validation and affect labeling.
- Coach: clarify and reframe.
- Plan: tiny if-then action.

Differentiation:
- Doctor personas should not be just style skins. Each should map to a real support strategy.
- Session history should show "what we worked on," not just transcripts.

### Journal

Goal: pattern-making without rumination.

Should include:
- Search and timeline.
- Soft tags.
- Prompted reflection.
- "What helped" extraction.

Differentiation:
- Journal entries can become context for better support, but only as derived summaries.

### Garden

Goal: make tiny care actions feel visible and alive.

Important:
- Garden should not become another productivity/streak board.
- It should represent emotional repair, routine, and care.

Differentiation:
- Micro-plans and follow-ups change the world.
- NPC/visitor events should reflect support themes.
- Rewards should be narrative and aesthetic, not just points.

## UX Research Plan

### Research Questions

1. Which first-session promise is most compelling?
   - "One quiet minute"
   - "Talk privately"
   - "Turn feelings into one small step"
   - "A gentle companion between therapy sessions"

2. Which target segment understands Lumia fastest?
   - Young professionals.
   - College students.
   - Therapy-adjacent adults.
   - Privacy-sensitive self-helpers.

3. What makes users trust or distrust Lumia?
   - AI label.
   - Health data.
   - Personas.
   - Crisis language.
   - Local storage and deletion controls.

4. What is the minimum useful session?
   - 30 seconds.
   - 90 seconds.
   - 3 minutes.
   - Chat only when user wants depth.

### Validation Methods

1. Five-user concept test.
   - Show Home, Sanctuary, Therapy, Garden.
   - Ask users what they think the app does before explaining.

2. First-session usability test.
   - Task: "You feel tense before sleep. Use the app."
   - Measure: time to first useful action, confusion points, pressure points.

3. Seven-day diary pilot.
   - Small group, no clinical claims.
   - Track: moments opened, chosen actions, perceived helpfulness, annoyance.

4. Privacy comprehension test.
   - Ask users what data Lumia uses and why.
   - If they cannot answer, the UI is not transparent enough.

5. Retention without guilt.
   - Measure meaningful return, not daily addiction.
   - Track successful support completions and voluntary return after stress moments.

## Metrics

### Product Metrics

- Time to first useful action.
- Completion rate of one-minute tools.
- User-rated helpfulness after support.
- Repeat use after stressful moment.
- Therapy session wrap-up completion.
- Micro-plan created and later checked in.
- Notification dismiss / suppress rate.

### Safety Metrics

- Crisis route shown.
- Crisis resource tapped.
- Safety false-positive feedback.
- High-risk message blocked from normal AI response.
- User data deletion / revoke events.

### Trust Metrics

- Privacy screen comprehension.
- "Why am I seeing this?" opens.
- Health data opt-in rate.
- Health data revoke rate.
- User confidence in recommendation reason.

## Product Roadmap Recommendation

### Next 1-2 Weeks

- Strengthen Sanctuary as the best first-use experience.
- Simplify Home around one recommendation.
- Add "Why this?" to every contextual suggestion.
- Make Therapy personas map to clear support strategies.
- Add session summaries focused on need, support mode, and next tiny step.

### Next 3-6 Weeks

- Build a lightweight onboarding that chooses support style without long forms.
- Add privacy/data control as a first-class Profile section.
- Convert Journal insights into user-visible, editable summaries.
- Make Garden rewards reflect completed emotional-support actions, not generic tasks.
- Run a five-user concept/usability test.

### Later

- Add optional HealthKit context explanations.
- Add therapist-share/export mode for therapy-adjacent users.
- Add cultural/language adaptation only after participatory testing.
- Consider clinician-reviewed content packs if making stronger evidence claims.

## Sources

- [NIMH: Mental Illness statistics, 2022 NSDUH](https://www.nimh.nih.gov/health/statistics/mental-illness).
- [WHO: 2023 mhGAP guideline update](https://www.who.int/news/item/20-11-2023-who-issues-new-and-updated-recommendations-on-treatment-of-mental--neurological-and-substance-use-conditions).
- [JMIR 2024: Attrition in conversational-agent mental health interventions](https://www.jmir.org/2024/1/e48168/).
- [BMC Digital Health 2024: Engagement and retention in digital mental health interventions](https://bmcdigitalhealth.biomedcentral.com/counter/pdf/10.1186/s44247-024-00105-9.pdf).
- [JAMA Network Open 2022: Assessment of 578 mental health apps](https://jamanetwork.com/journals/jamanetworkopen/fullarticle/2799953).
- [FTC 2023: BetterHelp sensitive health data order](https://www.ftc.gov/news-events/news/press-releases/2023/07/ftc-gives-final-approval-order-banning-betterhelp-sharing-sensitive-health-data-advertising).
- [Hopelab / Common Sense Media 2024: Getting Help Online](https://hopelab.org/stories/getting-help-online).
- [APA App Evaluation Model summary in Frontiers Digital Health](https://www.frontiersin.org/journals/digital-health/articles/10.3389/fdgth.2022.1003181/full).
