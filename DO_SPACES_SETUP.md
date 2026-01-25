# DigitalOcean Spaces Configuration

## Your Credentials

```
Endpoint: https://ams3.digitaloceanspaces.com
Region: ams3
Bucket: nexus-v2-users
Firebase Functions URL: https://us-central1-nexus-visibility-app.cloudfunctions.net/getPresignedUploadUrl
```

## How to Run the App with DO Spaces

You need to provide these credentials via `--dart-define` when running the app:

```bash
flutter run --dart-define=DO_SPACES_ENDPOINT=ams3.digitaloceanspaces.com \
  --dart-define=DO_SPACES_REGION=ams3 \
  --dart-define=DO_SPACES_BUCKET=nexus-v2-users \
  --dart-define=SPACES_PRESIGN_URL=https://us-central1-nexus-visibility-app.cloudfunctions.net/getPresignedUploadUrl
```

## Building for Release

### Android
```bash
flutter build apk --release \
  --dart-define=DO_SPACES_ENDPOINT=ams3.digitaloceanspaces.com \
  --dart-define=DO_SPACES_REGION=ams3 \
  --dart-define=DO_SPACES_BUCKET=nexus-v2-users \
  --dart-define=SPACES_PRESIGN_URL=https://us-central1-nexus-visibility-app.cloudfunctions.net/getPresignedUploadUrl
```

### iOS
```bash
flutter build ios --release \
  --dart-define=DO_SPACES_ENDPOINT=ams3.digitaloceanspaces.com \
  --dart-define=DO_SPACES_REGION=ams3 \
  --dart-define=DO_SPACES_BUCKET=nexus-v2-users \
  --dart-define=SPACES_PRESIGN_URL=https://us-central1-nexus-visibility-app.cloudfunctions.net/getPresignedUploadUrl
```

## What's Configured

### ✅ Completed
- **Firebase Cloud Function**: `getPresignedUploadUrl` is deployed and working
- **Storage Service**: `DoSpacesStorageService` handles presigned URL flow
- **Photo Upload**: Dating onboarding photos automatically upload to DO Spaces
- **Audio Upload**: Dating onboarding audio now uploads all 3 recordings before completing profile
- **Audio Playback**: Users can play audio recordings on the summary screen

### 📝 Implementation Details

#### Audio Upload Flow
1. User records 3 audio prompts (60s max, 45s min each)
2. Files are saved locally during recording
3. On "Complete Profile" button:
   - All 3 audio files are uploaded to DO Spaces via presigned URLs
   - Upload progress is shown with loading indicator
   - URLs are saved to dating draft
   - Navigation continues to contact-info screen

#### Storage Architecture
- **Security**: App never holds DO Spaces access keys
- **Backend**: Firebase Function generates presigned PUT URLs
- **Upload**: App uploads directly to DO Spaces using presigned URLs
- **Result**: Public URLs are returned and stored in Firestore

#### File Naming
- Photos: `users/{uid}/photos/photo_{timestamp}_{random}.jpg`
- Audio: `users/{uid}/audios/audio_{timestamp}_{random}.m4a`

## Testing

1. Run app with credentials above
2. Go through dating onboarding
3. Upload 2-5 photos (step 5)
4. Record 3 audio prompts (step 6)
5. Review audio summary screen (step 7)
6. Click "Complete Profile" - audio uploads automatically
7. Check DO Spaces bucket to verify files uploaded

## Troubleshooting

### "DigitalOcean Spaces is not configured"
- Make sure you're running with all 4 `--dart-define` flags

### Upload fails with 401
- Firebase Function requires authenticated user
- Make sure user is signed in before uploading

### Upload fails with 500
- Check Firebase Functions logs: `firebase functions:log`
- Verify DO Spaces credentials in Functions config

### Audio doesn't play
- Make sure files were recorded successfully (local paths exist)
- Check file permissions on device
- Verify audio format is supported (m4a/AAC)
