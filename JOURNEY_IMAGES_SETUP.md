# Journey Images Setup Guide

## Overview
Journey images are automatically loaded and resized based on screen dimensions. The system supports both gender-neutral and gender-specific journey images.

## Image Folder Structure

```
assets/images/journeys/
├── journey_1_hero.png         # 12 gender-neutral journey images
├── journey_2_hero.png
├── ...
├── journey_12_hero.png
├── journey_12_masculine.png   # 9 gender-specific journey variants
├── journey_12_feminine.png
├── journey_13_masculine.png
├── journey_13_feminine.png
├── ...
├── journey_20_masculine.png
└── journey_20_feminine.png
```

## Image Naming Convention

**Format:** `journey_{id}_{type}.png`

- **{id}**: Journey number (1-21)
- **{type}**: 
  - `hero` = gender-neutral image (shown to all users)
  - `masculine` = shown to male users only
  - `feminine` = shown to female users only

## Image Specifications

### Recommended Dimensions
- **Width:** 1080px (for 1x scale on mobile)
- **Height:** 600px (16:9 aspect ratio for consistency)
- **File Format:** PNG (supports transparency if needed)
- **File Size:** 300-500KB per image

### Responsive Sizing
The app automatically resizes images to:
- Maintain 16:9 aspect ratio
- Fill the available width
- Cap at 220px height on large screens
- Use `BoxFit.cover` for proper scaling

## JSON Configuration

Each journey JSON should include the `heroImage` path in the cover object:

```json
{
  "id": "journey_1",
  "title": "Building Secure Confidence for Healthy Dating",
  "summary": "...",
  "cover": {
    "heroImage": "assets/images/journeys/journey_1_hero.png",
    "themeTag": "readiness"
  },
  "missions": [...]
}
```

For gender-specific journeys:

```json
{
  "id": "journey_12",
  "title": "Understanding Masculine Energy",
  "allowedGenders": ["male"],
  "cover": {
    "heroImage": "assets/images/journeys/journey_12_hero.png",
    "themeTag": "growth"
  },
  "missions": [...]
}
```

## How It Works

### 1. Image Loading Flow

```
JourneyDetailScreen
    ↓
_HeroHeader (ConsumerWidget)
    ↓
ref.watch(userProvider) → Get user.gender
    ↓
JourneyImageUtils.getHeroImagePath(journey, userGender)
    ↓
Returns gender-aware image path
    ↓
Image.asset() with BoxFit.cover
```

### 2. Gender-Aware Selection Logic

For a journey with `heroImage: "assets/images/journeys/journey_12_hero.png"`:

```
If user is male:
  → Load "assets/images/journeys/journey_12_masculine.png"

If user is female:
  → Load "assets/images/journeys/journey_12_feminine.png"

If journey has no gender targeting:
  → Load the base "_hero.png" image regardless of user gender
```

### 3. Fallback Behavior

- If gender-specific image doesn't exist, app falls back to base "_hero.png" image
- If no image exists, displays colored container with journey icon
- Error handling uses adaptive colors (light/dark mode aware)

## Code Usage

### In Journey Model (journey_v1_models.dart)
```dart
class JourneyV1 {
  final String? heroImage;  // Path like "assets/images/journeys/journey_1_hero.png"
  final List<String> allowedGenders;  // e.g., ["male"] or empty for all
}
```

### In Detail Screen
```dart
// Automatically handled in _HeroHeader
final userGender = userAsync.maybeWhen(
  data: (user) => user?.gender,
  orElse: () => null,
);

final heroImage = JourneyImageUtils.getHeroImagePath(
  journey,
  userGender: userGender,
);
```

### Utility Functions
```dart
// In core/utils/image_utils.dart

// Get gender-aware hero image
String path = JourneyImageUtils.getHeroImagePath(
  journey,
  userGender: 'male',
);

// Build standard path
String path = JourneyImageUtils.buildJourneyImagePath(
  'journey_12',
  variant: 'masculine',  // optional
);

// Get all variants (for pre-caching)
List<String> allVariants = JourneyImageUtils.getJourneyImageVariants(journey);
```

## pubspec.yaml Configuration

Already configured in pubspec.yaml:

```yaml
flutter:
  assets:
    - assets/images/journeys/
```

This recursively includes all PNG files in the journeys folder.

## Dark Mode Support

Images automatically adapt to dark/light mode:
- Images display with adjusted overlay opacity in dark mode
- Text colors (white on dark image, theme color on light) automatically adjust
- Progress bars and badges use theme-aware colors

## Performance Optimization

### Image Pre-caching (Optional)
```dart
// In app initialization or when loading journey list
final imagesToCache = JourneyImageUtils.getJourneyImageVariants(journey);
for (final imagePath in imagesToCache) {
  precacheImage(AssetImage(imagePath), context);
}
```

### Lazy Loading
- Images only load when journey detail screen opens
- No pre-loading needed (images are small 300-500KB)

## Troubleshooting

### Images not loading
1. **Check file paths** match exactly: `assets/images/journeys/journey_1_hero.png`
2. **Run** `flutter pub get` to update asset manifest
3. **Rebuild** with full clean: `flutter clean && flutter run`
4. **Verify** `pubspec.yaml` has asset path configured

### Gender-specific images not showing
1. Verify `allowedGenders` is set in journey JSON (e.g., `["male"]`)
2. Confirm gender variant file exists: `journey_12_masculine.png`
3. Check user profile has gender set in Firestore

### Image distortion/blurring
1. Ensure source images are at least 1080px wide
2. Use `BoxFit.cover` (already configured)
3. Check image quality and compression

## Next Steps

1. **Organize images** into `assets/images/journeys/` folder
2. **Name files** following convention: `journey_{id}_{type}.png`
3. **Update journey JSONs** with correct `heroImage` paths
4. **Run** `flutter run` to test loading
5. **Monitor logs** for any image loading errors

---

For questions about responsive sizing or gender-aware image loading, refer to `core/utils/image_utils.dart`.
