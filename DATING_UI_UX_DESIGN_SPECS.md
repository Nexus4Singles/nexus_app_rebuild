# Nexus Dating Discovery: UI/UX Design Specifications

## Design System Overview

### Color Palette
```
Primary Brand:      #DC143C (Crimson - Love & Connection)
Secondary:          #2E7D32 (Forest Green - Faith & Growth)
Accent:             #FFA500 (Amber - Hope & Warmth)
Neutral Background: #FFFFFF (White)
Surface:            #F8F9FA (Light Gray)
Border:             #E0E0E0 (Light Border)
Text Primary:       #212121 (Dark Gray)
Text Secondary:     #757575 (Medium Gray)
Text Tertiary:      #BDBDBD (Light Gray)
Error:              #D32F2F (Red)
Success:            #388E3C (Green)
Warning:            #F57C00 (Orange)
```

### Typography Scale
```
Display Large:      Poppins 32px SemiBold (Line: 40px)
Display Medium:     Poppins 28px SemiBold (Line: 36px)
Headline Large:     Poppins 24px Bold (Line: 32px)
Headline Medium:    Poppins 20px SemiBold (Line: 28px)
Title Large:        Poppins 18px SemiBold (Line: 26px)
Title Medium:       Poppins 16px SemiBold (Line: 24px)
Body Large:         Inter 16px Regular (Line: 24px)
Body Medium:        Inter 14px Regular (Line: 20px)
Body Small:         Inter 12px Regular (Line: 18px)
Label Large:        Poppins 12px SemiBold (Line: 16px)
Label Medium:       Poppins 11px Medium (Line: 16px)
Label Small:        Poppins 10px Medium (Line: 14px)
```

### Component Library

#### Buttons

**Primary Button**
```
State: Default
├─ Background: #DC143C (Crimson)
├─ Text: White
├─ Padding: 12px (v) × 16px (h)
├─ Border Radius: 8px
├─ Shadow: 0 2px 4px rgba(0,0,0,0.1)
├─ Typography: Label Large Bold
└─ Min Height: 44px

State: Hover
└─ Brightness: -10%

State: Active/Pressed
└─ Brightness: -20%

State: Disabled
├─ Background: #E0E0E0
├─ Text: #BDBDBD
└─ No shadow
```

**Secondary Button (Outline)**
```
State: Default
├─ Background: Transparent
├─ Border: 2px solid #DC143C
├─ Text: #DC143C
├─ Padding: 10px (v) × 14px (h)
├─ Border Radius: 8px
└─ Typography: Label Large SemiBold

State: Hover
└─ Background: #DC143C with 5% opacity
```

**Ghost Button**
```
State: Default
├─ Background: Transparent
├─ Text: #757575
├─ No border
├─ Padding: 8px (v) × 12px (h)
└─ Typography: Body Medium Medium

State: Hover
└─ Background: #F8F9FA
```

---

## Screen Designs

### 1. Welcome/Onboarding Screen

```
┌────────────────────────────────────────┐
│                                         │
│      🎯                                 │
│   [Logo - Heart icon]                   │
│                                         │
│  Welcome to Nexus Dating                │
│  "Find Your Partner With Purpose"       │
│                                         │
│  [Subtitle: Join Christian singles      │
│   seeking meaningful relationships]     │
│                                         │
├────────────────────────────────────────┤
│                                         │
│  Vision Alignment                       │
│                                         │
│  What are you looking for?              │
│                                         │
│  ○ Marriage-minded relationship         │
│    (Serious about finding spouse)       │
│                                         │
│  ○ Dating with intention                │
│    (Building towards commitment)        │
│                                         │
│  ○ Companionship                        │
│    (Getting to know Christian singles)  │
│                                         │
│  What's your timeline?                  │
│                                         │
│  ○ Within 1 year                        │
│  ○ 1-2 years                            │
│  ○ Open/not rushed                      │
│                                         │
├────────────────────────────────────────┤
│                                         │
│  [Next] or [Skip & Explore]             │
│                                         │
└────────────────────────────────────────┘
```

**Design Notes:**
- Large, friendly typography
- Illustration of couple/couple silhouette
- Radio buttons for vision selection
- Clear CTAs with secondary option

---

### 2. Quick Preference Setup Screen

```
┌────────────────────────────────────────┐
│  [< Back]                               │
│                                         │
│  Let's Know Your Preferences            │
│  (Quick 3-question setup)               │
│                                         │
├────────────────────────────────────────┤
│                                         │
│  💚 What age range?                     │
│                                         │
│     [21 =========•======= 60]           │
│                                         │
│     Min: 21            Max: 60          │
│                                         │
│  🌍 Countries?                          │
│                                         │
│     [Select 1-3 countries]              │
│     [🇳🇬 Nigeria ✓]                     │
│     [🇺🇸 United States]                 │
│     [🇬🇧 United Kingdom]                │
│                                         │
│  🌐 Open to long distance?              │
│                                         │
│     ○ Yes, I'm open                     │
│     ○ Prefer same country               │
│     ○ Still deciding                    │
│                                         │
│  ℹ️  We'll use this to find matches.    │
│      You can adjust anytime.            │
│                                         │
├────────────────────────────────────────┤
│                                         │
│  [Skip & Explore] [Next → Matches]     │
│                                         │
└────────────────────────────────────────┘
```

**Design Notes:**
- Clean, spacious layout
- Range slider with clear min/max
- Multi-select dropdown for countries
- Info icon explaining each preference
- Secondary CTA to skip and explore

---

### 3. Discovery Screen - Main

```
┌─────────────────────────────────────────────┐
│  [Nexus Icon]         Today's Matches    [↻] │
├─────────────────────────────────────────────┤
│  Match 1 of 6                                │
│                                              │
│  ╔═══════════════════════════════════════╗  │
│  ║                                       ║  │
│  ║        ╔─────────────────────────╗    ║  │
│  ║        │  97% Compatibility   ⭐ │    ║  │
│  ║        │  🟢 Excellent Match     │    ║  │
│  ║        └─────────────────────────┘    ║  │
│  ║                                       ║  │
│  ║  Sarah • 26 • Lagos, Nigeria          ║  │
│  ║  ✓ Verified Profile                   ║  │
│  ║                                       ║  │
│  ║  [Primary Photo - 300x400]            ║  │
│  ║  [Swipe: 2 more photos] ◀️ ▶️          ║  │
│  ║                                       ║  │
│  ║  📍 Lagos, Nigeria • 📊 Marketing     ║  │
│  ║                                       ║  │
│  ║  "Worship leader passionate about     ║  │
│  ║   serving Christ and helping others"  ║  │
│  ║                                       ║  │
│  ║  ─────────────────────────────────   ║  │
│  ║  WHY YOU MATCH                        ║  │
│  ║  ✅ Same faith commitment             ║  │
│  ║     (Both believe in tithing)         ║  │
│  ║  ✅ Compatible timeline               ║  │
│  ║     (Both marriage-minded, 1-2yr)    ║  │
│  ║  ✅ Same kids preference              ║  │
│  ║     (Open to having kids together)   ║  │
│  ║                                       ║  │
│  ║  ⚠️  THINGS TO DISCUSS                ║  │
│  ║  Different on long distance          ║  │
│  ║  (You: Prefer same country,          ║  │
│  ║   She: Open to long distance)        ║  │
│  ║                                       ║  │
│  ║  💡 Opportunity: Her openness        ║  │
│  ║     could be a strength!             ║  │
│  ║                                       ║  │
│  ╚═══════════════════════════════════════╝  │
│                                              │
│  ┌──────────────┬──────────────┐            │
│  │ 🎵 Hear her  │ 👤 Full      │            │
│  │ voice intro  │ profile      │            │
│  └──────────────┴──────────────┘            │
│                                              │
│  ┌─────────────┬──────────────┬────────────┐ │
│  │  ❌ Pass    │  ❤️ Save     │ 💬 Connect │ │
│  └─────────────┴──────────────┴────────────┘ │
│                                              │
└─────────────────────────────────────────────┘
```

**Design Notes:**
- Full-screen card design
- Compatibility badge at top with color indicator
- Profile photo carousel
- Clear match reasoning with checkmarks
- Warnings styled as opportunities
- Three CTA buttons at bottom
- Shows progress (1 of 6)

---

### 4. Full Profile Modal

```
┌──────────────────────────────────────┐
│  [✕]                                  │
│                                        │
│  Sarah • 26                            │
│  97% Compatibility ⭐ (Saved)         │
│                                        │
├──────────────────────────────────────┤
│                                        │
│  PHOTO GALLERY                         │
│  [Large photo] ◀ Page 1 of 3 ▶       │
│  [Tap to expand fullscreen]            │
│                                        │
│  ABOUT HER                             │
│  ┌────────────────────────────────┐   │
│  │ Age             26             │   │
│  │ Gender          Female         │   │
│  │ Location        Lagos, Nigeria │   │
│  │ Genotype        AA             │   │
│  │ Marital Status  Never Married  │   │
│  │ Has Kids        No, but open   │   │
│  │ Education       B.Sc Marketing │   │
│  │ Profession      Worship Leader │   │
│  └────────────────────────────────┘   │
│                                        │
│  COMPATIBILITY BREAKDOWN               │
│  ╔════════════════════════════════╗   │
│  ║ Core Values:        95% ✅      ║   │
│  ║ • Same tithing belief           ║   │
│  ║ • No cohabitation               ║   │
│  ║ • Different: Tongues theology   ║   │
│  ╠════════════════════════════════╣   │
│  ║ Lifestyle:          94% ✅      ║   │
│  ║ • Never married (same)          ║   │
│  ║ • Open to kids (compatible)     ║   │
│  ║ • Long distance gap (discuss!)  ║   │
│  ╠════════════════════════════════╣   │
│  ║ Life Stage:         102% ✅     ║   │
│  ║ • Age difference: 3 years       ║   │
│  ║ • Same country                  ║   │
│  ║ • Timeline alignment            ║   │
│  ╚════════════════════════════════╝   │
│                                        │
│  VOICE INTRO                           │
│  [🎵 Play 45-second intro]             │
│                                        │
│  INTERESTS & HOBBIES                   │
│  🎵 Worship  📚 Reading  ✝️ Service   │
│  🎨 Art      🎭 Drama    💃 Dance    │
│                                        │
│  DESIRED QUALITIES IN PARTNER          │
│  • Spiritual leader & strong faith     │
│  • Faithful and committed              │
│  • Good sense of humor                 │
│  • Ambitious and goal-driven           │
│  • Kind and compassionate              │
│                                        │
├──────────────────────────────────────┤
│  [❤️ Save]  [💬 Send Message]         │
│  [❌ Not for me]                       │
│                                        │
└──────────────────────────────────────┘
```

**Design Notes:**
- Clean modal with close button
- Large photo gallery at top
- Tabular display of key info
- Color-coded compatibility sections
- Audio player integrated
- Interests displayed as pills/chips
- Multiple action buttons

---

### 5. Voice Intro Player Modal

```
┌────────────────────────────────────┐
│  [< Back]  Sarah's Voice Intro  [✕] │
├────────────────────────────────────┤
│                                     │
│           💬 🎤 💬                 │
│        (Animated waveform)          │
│                                     │
│       (Thin animated lines)         │
│                                     │
│       ────●────────                │
│                                     │
│  Sarah is speaking...               │
│                                     │
│  "Hi, I'm Sarah, 26, passionate    │
│   about worship and service to    │
│   others. I'm looking for someone  │
│   spiritually grounded who wants   │
│   to build a marriage centered     │
│   on Christ..."                    │
│                                     │
│  (Audio continues)                  │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ ▶️  |═══════════════|    ⏸  │   │
│  │ 0:45  out of 1:00         🔊   │
│  └─────────────────────────────┘   │
│                                     │
├────────────────────────────────────┤
│                                     │
│  What you get from voice intros:    │
│  • Authentic personality            │
│  • Speech clarity                   │
│  • Confidence level                 │
│  • Faith conviction                 │
│                                     │
│  [❤️ Love it]  [👉 Next intro]     │
│                                     │
└────────────────────────────────────┘
```

**Design Notes:**
- Animated waveform visualization
- Large, easy-to-read transcript
- Familiar audio player controls
- Educational info about what audio reveals
- Quick action buttons

---

### 6. Pass/Feedback Screen

```
┌─────────────────────────────────────┐
│  Why aren't you interested?          │
│  (This helps us improve matches)     │
│                                       │
│  [Optional - tap reason]             │
│                                       │
│  ○ Different faith values            │
│  ○ Long distance concerns            │
│  ○ Not my type/aesthetic             │
│  ○ Already talking to someone       │
│  ○ Just exploring / browsing        │
│  ○ Different life stage goals        │
│  ○ No specific reason / just vibe   │
│                                       │
│  [Send Feedback]                     │
│  [Skip Feedback]                     │
│                                       │
└─────────────────────────────────────┘
```

**Design Notes:**
- Non-judgmental tone
- Clear, specific reasons
- Educates user on value of feedback
- Easy skip option (doesn't force)

---

### 7. Empty State / Come Back Tomorrow

```
┌─────────────────────────────────────┐
│                                      │
│  ✨                                  │
│                                      │
│  You've Seen Today's Matches!        │
│                                      │
│  Great job exploring intentionally.  │
│                                      │
│  📍 WHAT'S NEXT?                     │
│                                      │
│  [Review Saved Profiles]             │
│  6 people you really liked           │
│  Pick one to reach out to now        │
│                                      │
│  [Refine Your Preferences]           │
│  Adjust what you're looking for      │
│  Next week's matches will be even    │
│  more tailored                       │
│                                      │
│  ⏰ Fresh matches available tomorrow │
│  at 8 AM                             │
│                                      │
│  💬 You have 2 active conversations  │
│  Keep building those connections!    │
│                                      │
│  [See Saved] [View Messages]         │
│                                      │
└─────────────────────────────────────┘
```

**Design Notes:**
- Positive, encouraging tone
- Clear next steps
- Shows active conversations count
- Builds habit for next day

---

### 8. Message Composer with Suggested Openers

```
┌──────────────────────────────────────┐
│  [< Back to Profile]                 │
│                                       │
│  Send Sarah a Message                │
│  Start the conversation               │
│                                       │
├──────────────────────────────────────┤
│                                       │
│  💡 SUGGESTED OPENERS                │
│  (Click to use as starter)            │
│                                       │
│  "Hi Sarah! Loved your passion for   │
│   worship and service. That's        │
│   something I really value too."     │
│  [Use this]                           │
│                                       │
│  "Your audio intro was amazing—      │
│   the conviction in your voice was   │
│   beautiful. Tell me more about      │
│   what you're looking for?"          │
│  [Use this]                           │
│                                       │
│  "I'm also into community service!   │
│   What causes are you most           │
│   passionate about?"                 │
│  [Use this]                           │
│                                       │
├──────────────────────────────────────┤
│                                       │
│  OR COMPOSE YOUR OWN:                │
│                                       │
│  ┌──────────────────────────────────┐ │
│  │ Type your message...              │ │
│  │                                   │ │
│  │ (Mention something from her       │ │
│  │  profile for best results)        │ │
│  │                                   │ │
│  │ Min 10 characters                 │ │
│  │ Current: 0                        │ │
│  └──────────────────────────────────┘ │
│                                       │
│  ℹ️  Tips for great first messages:  │
│  • Reference her profile             │
│  • Ask a genuine question            │
│  • Show personality                  │
│  • Keep it positive                  │
│                                       │
│  [Send Introduction]                 │
│                                       │
└──────────────────────────────────────┘
```

**Design Notes:**
- Suggested openers show personalization
- Easy one-tap usage
- Compose option still available
- Character count + minimum threshold
- Educational tips

---

## Animations & Interactions

### Profile Card Transitions
```
Swipe right (Save):
├─ Card animates: ↗️ rotation + fade
├─ Heart icon appears, scales up
├─ Toast notification: "✓ Saved"
└─ Next card fades in from bottom

Swipe left (Pass):
├─ Card animates: ↙️ rotation + fade
├─ X icon appears, scales up
├─ Optional: Feedback modal slides up
└─ Next card fades in from bottom

Tap "Full Profile":
├─ Card expands to fullscreen
├─ Modal slides up from bottom
├─ Blur background
└─ Close button appears (X)

Audio Play:
├─ Play button → Pause icon animation
├─ Waveform animates left-to-right
├─ Progress bar updates smoothly
└─ Auto-advance to next profile when done
```

### Compatibility Badge Animation
```
On Card Load:
├─ Badge starts at 0%
├─ Counter animates up: 0 → 97%
├─ Color transitions: Gray → Green (if 80%+)
├─ Subtle scale pulse on completion
└─ Done in 1.5 seconds
```

---

## Accessibility Features

### Semantic Labels
```
Profile card:
├─ "Sarah, 26, Lagos Nigeria"
├─ "97% compatibility with Sarah"
├─ "Save Sarah to favorites"
└─ "Send message to Sarah"

Buttons:
├─ [aria-label="Save profile"]
├─ [aria-label="Listen to voice intro"]
└─ [aria-label="Next profile"]

Icons:
├─ 🎵 = "Play audio"
├─ ❤️ = "Save"
└─ ✓ = "Verified"
```

### Screen Reader Support
```
• All interactive elements have labels
• Focus indicators visible on all buttons
• Loading states announced
• Status updates read aloud
• Form errors clearly labeled
```

### High Contrast Mode
```
• Text contrast: 4.5:1 minimum
• Button contrast: 3:1 minimum
• Color not sole indicator (use icons too)
• Adjustable text size supported
```

---

## Responsive Design

### Breakpoints
```
Mobile: 320px - 480px
  └─ Full-width cards
  └─ Single-column layout

Tablet: 481px - 768px
  └─ 80% width cards
  └─ Centered layout

Desktop: 769px+
  └─ Max 600px card width
  └─ Centered with sidebar
```

---

## Performance Metrics

### Target Loading Times
```
Screen Load:        < 2 seconds
Profile Card:       < 1 second
Audio Playback:     < 500ms to start
Photo Gallery:      < 300ms swipe
Message Send:       < 1 second
```

### Optimization Techniques
```
• Image optimization (WebP, lazy loading)
• Code splitting (route-based)
• Local caching (compatibility scores)
• Preload next profile card
• Service workers for offline support
```

---

## Brand Voice & Copy Tone

### Key Principles
1. **Hopeful:** "Fresh matches available tomorrow"
2. **Intentional:** "Start the conversation with purpose"
3. **Respectful:** "Your preferences matter"
4. **Empowering:** "You're building something meaningful"
5. **Christian:** "Faith-centered matching"

### Sample Copy

**Match Reason (Positive):**
"Same faith commitment (Both believe in tithing)"

**Match Warning (Constructive):**
"Different on long distance (She: Open, You: Prefer same country) — Great opportunity to discuss!"

**Empty State:**
"Fresh matches available tomorrow at 8 AM — New members join daily!"

**Message Tip:**
"Reference her profile for better results — genuine interest gets genuine responses"

---

## Design Assets

### Icon Set (Ionicons/Material Icons)
```
❤️  Favorite/Save
💬  Message/Chat
🎵  Audio/Sound
👤  Profile
✓   Check/Verified
⚠️  Warning
🌍  Location/World
👥  People
🎯  Target/Goal
```

### Illustrations (Nexus Brand)
```
• Couple silhouette (onboarding)
• Handshake (connection)
• Heart with cross (faith + love)
• Compass (finding direction)
• Puzzle pieces (compatibility)
```

---

## Testing Checklist

### Usability Testing
- [ ] Can new users complete onboarding in <3 min?
- [ ] Is compatibility score explanation clear?
- [ ] Do users understand match reasons?
- [ ] Is "pass" feedback helpful?
- [ ] Can users easily message?

### Design QA
- [ ] Responsive on all screen sizes?
- [ ] Animations smooth (60fps)?
- [ ] Colors accessible (contrast OK)?
- [ ] Touch targets 44px minimum?
- [ ] Loading states visible?

---

## Design Implementation Priority

### Phase 1 (MVP)
- [ ] Discovery screen with cards
- [ ] Compatibility score display
- [ ] Save/Pass actions
- [ ] Message composer
- [ ] Empty state

### Phase 2 (Polish)
- [ ] Full profile modal
- [ ] Voice intro player
- [ ] Animations
- [ ] Empty states variations

### Phase 3 (Advanced)
- [ ] Personalized suggested openers
- [ ] Advanced filters
- [ ] Analytics dashboard
- [ ] A/B testing variants

---

This design system provides a complete, cohesive UI/UX for Nexus Dating Discovery. All components follow Material Design 3 principles while maintaining Nexus brand identity.
