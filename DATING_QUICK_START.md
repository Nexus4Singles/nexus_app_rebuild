# 🚀 Quick Start Guide - Dating Profile Setup Testing

## Get Started in 5 Minutes

### Step 1: Launch the Flow
```dart
// From any screen in the app, navigate to:
Navigator.pushNamed(context, '/dating/setup/age');
```

Or from the dating gate or profile screen - these should already have buttons to start.

### Step 2: Complete Each Step

#### Step 1: Age Selection
- Scroll the wheel to select age 25-40 (any valid age)
- Click "Continue"

#### Step 2: Extra Information
- City: Enter any city name
- Country: Tap and select a country
- Nationality: Tap and select nationality
- Education: Tap and select education level
- Profession: Tap and select profession
- Church: Tap and select church (or "Other" + type custom)
- Click "Continue"

#### Step 3: Hobbies
- Tap to select 3-5 hobbies from the list
- Can search to filter
- Click "Continue"

#### Step 4: Desired Qualities ⭐ NEW
- Tap to select 5-8 qualities from the list
- Can search to filter
- Click "Continue"

#### Step 5: Photos
- Tap the "+" icon
- Select 2-3 photos from your gallery
- Each must have a face detected
- Click "Continue"

#### Step 6: Audio Recording
- Read the instructions
- Click "Start Recording"

#### Step 6a: Record Question 1
- Tap the red mic button to start
- Speak about your relationship with God
- Record for 10-40 seconds
- Tap mic button to stop
- Click "Next" to proceed to Q2

#### Step 6b: Record Question 2
- Same process for Question 2
- Topic: Husband and wife roles in marriage
- Click "Next"

#### Step 6c: Record Question 3
- Same process for Question 3
- Topic: Your favorite qualities about yourself
- This time, click "Next" to go to summary

#### Step 6d: Audio Summary
- You'll see all 3 recordings listed
- Can tap play button to listen to each
- Click "Continue" (or left arrow to go back)

#### Step 7: Contact Information
- Fill at least ONE contact method:
  - Instagram: @yourhandle
  - X: @yourhandle
  - Facebook: facebook.com/yourname
  - WhatsApp: +234... (phone number)
  - Phone: +234...
  - Email: your@email.com
- Click "Continue"

#### Step 8: Profile Complete!
- See celebration screen
- It will check if you've completed the compatibility quiz
- If yes → Goes to your profile
- If no → Goes to compatibility quiz

---

## 🧪 Quick Test Scenarios

### Test 1: Happy Path (10 min)
```
1. Start → Age → Continue
2. Extra Info → Fill all → Continue
3. Hobbies → Select 3 → Continue
4. Qualities → Select 5 → Continue ⭐
5. Photos → Add 2 → Continue
6. Audio → Start Recording
7. Q1 → Record 15s → Next
8. Q2 → Record 15s → Next
9. Q3 → Record 15s → Next
10. Summary → Review → Continue
11. Contact → Fill Instagram → Continue
12. Complete → See celebration
✅ PASSED
```

### Test 2: Form Validation (5 min)
```
1. Age Screen → Click Continue without selecting → ERROR
2. Extra Info → Leave city empty → Button disabled → ERROR ✓
3. Hobbies → Try selecting 6th hobby → Haptic feedback + ERROR ✓
4. Qualities → Try selecting 9th quality → Haptic feedback + ERROR ✓
5. Photos → Try with 1 photo → Button disabled → ERROR ✓
6. Audio Q1 → Record for 2 seconds → "Too short" ERROR ✓
7. Contact → Try to continue with no fields → ERROR ✓
✅ PASSED
```

### Test 3: Data Persistence (5 min)
```
1. Age → Select 30 → Go Back → Verify 30 still selected ✓
2. Extra → Fill city → Go Back → City still there ✓
3. Hobbies → Select 3 → Go Back → All 3 still selected ✓
4. Qualities → Select 5 → Go Back → All 5 still selected ✓ NEW
5. Photos → Add 2 → Go Back → Photos still there ✓
6. Audio Q1 → Record → Go Back → Recording preserved ✓
✅ PASSED
```

### Test 4: Search Functionality (3 min)
```
1. Hobbies → Search "read" → Only hobbies with "read" show ✓
2. Clear search → All hobbies show again ✓
3. Qualities → Search "hon" → Only matching qualities show ✓
4. Clear search → All qualities show again ✓ NEW
✅ PASSED
```

### Test 5: Edge Cases (5 min)
```
1. Long church name → Type 100+ chars → No overflow ✓
2. Audio → Record exactly 3 seconds → Can continue ✓
3. Audio → Record 60 seconds → Auto-stops ✓
4. Photo → Select image → Face detection working ✓
5. Photo → Select non-face image → Error shows ✓
6. Multiple contacts → Fill 2-3 → All saved ✓
✅ PASSED
```

---

## 📊 Key Metrics to Track During Testing

### Performance
- [ ] Age selection: <100ms
- [ ] Form submission: <500ms per field
- [ ] Photo upload: <5s per photo
- [ ] Audio recording: No lag/stutter

### Stability
- [ ] No crashes on any screen
- [ ] No memory leaks
- [ ] App doesn't freeze
- [ ] Smooth navigation between screens

### UX Quality
- [ ] All text readable
- [ ] All buttons clickable
- [ ] Images load properly
- [ ] No overlapping text

---

## 🐛 Common Issues & Solutions

### Issue: "Cannot find datingOnboardingDraftProvider"
**Solution**: Ensure imports are from `dating_onboarding_draft.dart`, not `dating_onboarding_provider.dart`

### Issue: Photo shows as rotated
**Solution**: This is expected for some orientations. Will be fixed in backend.

### Issue: Audio file not saving
**Solution**: Check microphone permissions in device settings

### Issue: Back button doesn't work
**Solution**: All screens have back buttons. If missing, it's intentional (age screen, profile complete).

### Issue: Face detection failing on valid photos
**Solution**: Ensure face is clearly visible. ML Kit requires clear face regions.

---

## ✅ Sign-Off Checklist

Before saying it's ready:

- [ ] Can select age 21-70
- [ ] Can fill all extra info fields
- [ ] Can select 1-5 hobbies
- [ ] Can select 1-8 qualities ⭐
- [ ] Can add 2+ photos
- [ ] Can record 3 audio clips
- [ ] Can play back recordings
- [ ] Can fill contact info
- [ ] Can complete profile
- [ ] Can navigate back with data preserved
- [ ] All form validations work
- [ ] No crashes or errors
- [ ] UI looks polished
- [ ] No compilation errors

**When all items checked: ✅ READY FOR STAGING**

---

## 📱 Device Testing

### Test on Multiple Devices
- [ ] iPhone 12/13
- [ ] iPhone SE
- [ ] Pixel 4/5
- [ ] Pixel 6+
- [ ] Tablet (iPad/Samsung)

### Test Different Orientations
- [ ] Portrait
- [ ] Landscape
- [ ] Rotation during recording

### Test Different Screen Sizes
- [ ] Small phones (5-6 inches)
- [ ] Large phones (6.5+ inches)
- [ ] Tablets (10+ inches)

---

## 🎯 Success Criteria

✅ **READY FOR PRODUCTION WHEN:**
1. All 8 steps work end-to-end
2. All form validations work
3. Data persists across navigation
4. No crashes or errors
5. No compilation warnings
6. Tested on min 2 different devices
7. Backend integration planned
8. Analytics tracking planned

---

## 🚀 Launch Command

When ready to test on real device:

```bash
# Terminal
flutter clean
flutter pub get
flutter run

# Or specific device
flutter run -d <device_id>
```

---

## 📞 Quick Reference

| Item | Location |
|------|----------|
| Complete Guide | `DATING_PROFILE_SETUP_COMPLETE.md` |
| Quick Ref | `DATING_PROFILE_QUICK_REF.md` |
| Checklist | `DATING_IMPLEMENTATION_CHECKLIST.md` |
| Testing | `DATING_TESTING_INTEGRATION.md` |
| Summary | `DATING_IMPLEMENTATION_SUMMARY.md` |

---

**Happy Testing! 🎉**

If you encounter any issues, check the documentation files above or review the screens in:
```
lib/features/dating_onboarding/presentation/screens/
```
