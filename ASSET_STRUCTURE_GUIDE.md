# Asset Structure Guide for Journeys & Activities

## Overview
The app loads journey content from JSON files and companion hero images, organized by relationship status (singles, married, divorced, widowed).

## Directory Structure

```
assets/
├── config/
│   └── journeys/
│       ├── journeys_singles.v1.json        (legacy v1 aggregate catalog)
│       ├── journeys_married.v1.json
│       ├── journeys_divorced.v1.json
│       ├── journeys_widowed.v1.json
│       │
│       └── singles_catalog_FLAGSHIP_FINAL/  (v2 individual journey files)
│           ├── singles_journey_01_*.json
│           ├── singles_journey_02_*.json
│           ├── ... (more journey files)
│           └── singles_journey_21_*.json
│
└── images/
    ├── journeys/                            (hero images referenced by JSON)
    │   ├── singles_cultural_lies_hero.jpg
    │   ├── singles_toxic_triggers_hero.jpg
    │   ├── singles_emotional_readiness_hero.jpg
    │   └── ... (more hero images)
    │
    └── ... (other image assets)
```

## How Assets Are Loaded

### 1. Journey JSON Files (Config)
- **Location**: `assets/config/journeys/`
- **Structure**: Each user category (singles, married, divorced, widowed) can have:
  - A legacy **v1 aggregate file** (e.g., `journeys_singles.v1.json`) containing all journeys in one file
  - Individual **v2 per-journey files** in a subfolder (e.g., `singles_catalog_FLAGSHIP_FINAL/`)

### 2. Loading Priority
The `JourneysService` tries the following in order:
1. **First**: Try loading the legacy v1 aggregate file for that status
2. **Fallback**: Scan the asset manifest for individual v2 JSON files matching the status prefix
3. **Discovery**: Files are discovered dynamically from folders defined in `pubspec.yaml`

### 3. Hero Images
- **Path Convention**: Referenced in JSON under `cover.heroImage` as relative asset paths
- **Example**: `"heroImage": "assets/images/journeys/singles_cultural_lies_hero.jpg"`
- **Graceful Fallback**: If an image doesn't exist, the hero container uses a solid color gradient instead

## Adding New Journeys

### Option A: Add to v1 Aggregate File (Simpler)
Edit `assets/config/journeys/journeys_singles.v1.json`:
```json
{
  "journeys": [
    { ... existing journey ... },
    {
      "id": "new_journey_id",
      "title": "New Journey Title",
      "summary": "...",
      "icon": "heart",
      "cover": {
        "themeTag": "Tag",
        "heroImage": "assets/images/journeys/new_journey_hero.jpg"
      },
      "missions": [ ... activities ... ]
    }
  ]
}
```

### Option B: Create Individual v2 File (Better for Organization)
1. Create a new JSON file in `assets/config/journeys/singles_catalog_FLAGSHIP_FINAL/`:
   ```
   singles_journey_22_your_topic_FLAGSHIP.json
   ```

2. Use the same structure as existing v2 files:
   ```json
   {
     "journeyId": "your_journey_id",
     "title": "Your Journey Title",
     "subtitle": "Tagline",
     "summary": "Full description...",
     "targetUserCategory": "singles",
     "cover": {
       "themeTag": "Your Tag",
       "heroImage": "assets/images/journeys/singles_your_topic_hero.jpg"
     },
     "missions": [
       { "id": "activity_1", "title": "...", "cards": [...] },
       ...
     ]
   }
   ```

3. Add the hero image to `assets/images/journeys/`

## Structure for Different User Categories

- **Singles**: 
  - Main folder: `singles_catalog_FLAGSHIP_FINAL/`
  - File prefix: `singles_journey_*.json`
  - Image path: `assets/images/journeys/singles_*.jpg`

- **Married**: 
  - File prefix: `married_journey_*.json` or aggregate `journeys_married.v1.json`
  - Image path: `assets/images/journeys/married_*.jpg`

- **Divorced**: 
  - File prefix: `divorced_journey_*.json` or aggregate `journeys_divorced.v1.json`
  - Image path: `assets/images/journeys/divorced_*.jpg`

- **Widowed**: 
  - File prefix: `widowed_journey_*.json` or aggregate `journeys_widowed.v1.json`
  - Image path: `assets/images/journeys/widowed_*.jpg`

## Important Configuration
The `pubspec.yaml` must declare these asset directories:
```yaml
assets:
  - assets/config/journeys/
  - assets/config/journeys/singles_catalog_FLAGSHIP_FINAL/
  - assets/images/journeys/
  - ... (others)
```

If adding a new category folder (e.g., `married_catalog_FLAGSHIP_FINAL/`), update pubspec.yaml to include it.

## Gender-Specific Visibility
Journeys can be filtered by gender via the `targetUserCategory` or `allowedGenders` field:
- Value: "singles", "men", "women", "married", etc.
- Implementation: `journeys_service.dart` maps these to the `allowedGenders` array
- Effect: Journeys appear only to users of the intended gender

## Troubleshooting

### Hero Images Not Loading
1. Check `assets/images/journeys/` folder exists (created at build time if in pubspec.yaml)
2. Verify image file path in JSON matches exactly: `assets/images/journeys/your_image.jpg`
3. Ensure image is listed or included in a glob pattern in pubspec.yaml
4. App will gracefully degrade to gradient color if image is missing

### Journeys Not Appearing
1. Check JSON file syntax is valid (paste into jsonlint.com)
2. Verify file is in the correct folder (matches user category)
3. Ensure file name matches the prefix pattern (e.g., `singles_journey_*.json`)
4. Check `assets/config/journeys/` is included in pubspec.yaml
5. Run `flutter clean && flutter pub get` to rebuild asset manifest

### Duplicate Journeys
- If both v1 aggregate and v2 individual files exist for the same journey, the app will load both
- Solution: Either use v1 aggregate OR individual v2 files, not both for the same journey
