# Firestore Provider Best Practices

## Problem
Firestore-dependent providers can hang indefinitely when:
- Network is slow
- User logs in/out quickly  
- Firestore stream doesn't emit data properly
- Running via Xcode (state caching issues)

## Solution: Standardized Pattern

### 1. **Base Data Providers - Always Have Fallback**
```dart
// ❌ BAD
final statusProvider = Provider<Status?>((ref) {
  final doc = ref.watch(firebaseDocProvider);
  return doc?.status; // Can be null forever!
});

// ✅ GOOD
final statusProvider = Provider<Status>((ref) {
  final doc = ref.watch(firebaseDocProvider);
  return doc?.status ?? Status.defaultValue;
});
```

### 2. **Async Providers - Add Timeout**
```dart
final dataProvider = FutureProvider<MyData>((ref) async {
  final service = ref.watch(myServiceProvider);
  
  return service.fetchData().timeout(
    const Duration(seconds: 8),
    onTimeout: () => MyData.empty(),
  );
});
```

### 3. **UI Screens - Always Add Retry**
```dart
body: dataAsync.when(
  loading: () => _LoadingWithRetry(
    onRetry: () => ref.invalidate(dataProvider),
  ),
  error: (e, _) => _ErrorWithRetry(
    onRetry: () => ref.invalidate(dataProvider),
  ),
  data: (data) => _Content(data),
),
```

### 4. **Apply These Patterns To:**
- All FutureProvider usage
- All StreamProvider watching
- All screens with loading state

---

## Screens Needing Fix

### HIGH PRIORITY (User-Facing):
1. ✅ Challenges Screen (DONE)
2. ✅ Search Results Screen (DONE)
3. ✅ Search Screen (DONE)
4. 🔄 Journey Detail Screen
5. 🔄 Assessment Screens
6. 🔄 Dating Preferences Screen
7. 🔄 Chat Screens

### MEDIUM PRIORITY:
8. Story/Poll Screens
9. Blocked Users Screen
10. Admin Review Queue Screen

---

## Implementation Plan

1. **Create reusable loading widget:**
   - `AppLoadingWithRetry` component
   - Takes `onRetry` callback

2. **Apply to all FutureProvider screens:**
   - Add timeout to the provider
   - Add retry button to loading state
   - Add retry button to error state

3. **Test:**
   - Run via Xcode play button
   - Toggle airplane mode mid-load
   - Restart simulator with app open

---

## Quick Checklist for New Screens

Before adding any Firestore-dependent screen:

- [ ] FutureProvider has `.timeout()` call
- [ ] Loading state has "Retry" button
- [ ] Error state has "Retry" button
- [ ] Tested with poor network
- [ ] Logged loading transitions with `debugPrint`

---

## Code Generation Opportunity

Could generate a reusable builder pattern:
```dart
@immutable
class FutureProviderBuilder<T> extends ConsumerWidget {
  final FutureProvider<T> provider;
  final Widget Function(T) builder;
  final String? loadingLabel;
  
  const FutureProviderBuilder({
    required this.provider,
    required this.builder,
    this.loadingLabel,
  });
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(provider);
    
    return async.when(
      loading: () => _LoadingWithRetry(
        label: loadingLabel,
        onRetry: () => ref.invalidate(provider),
      ),
      error: (e, _) => _ErrorWithRetry(
        onRetry: () => ref.invalidate(provider),
      ),
      data: (data) => builder(data),
    );
  }
}
```

Then use like:
```dart
FutureProviderBuilder<List<Journey>>(
  provider: journeyCatalogProvider,
  loadingLabel: 'Loading journeys...',
  builder: (journeys) => JourneyList(journeys),
)
```

