# Deploy Firebase Cloud Functions

## Setup (One-time)

If you haven't set up Firebase Functions yet:

```bash
# 1. Install Firebase CLI globally (if not already installed)
npm install -g firebase-tools

# 2. Login to Firebase
firebase login

# 3. Initialize functions in your project
firebase init functions

# When prompted:
# - Choose "Use an existing project"
# - Select your Firebase project
# - Choose JavaScript (not TypeScript)
# - Install dependencies with npm: Yes
```

## Deploy Functions

```bash
# Deploy all functions
firebase deploy --only functions

# Or deploy specific function
firebase deploy --only functions:onUserDeleted
```

## What's Included

### 1. `onUserDeleted` (NEW!)
**Automatically deletes Firebase Auth user when Firestore document is deleted**

- Triggered when: A document is deleted from `users/{userId}`
- Action: Deletes the corresponding Firebase Auth user
- Bonus: Sends account deletion confirmation email
- Failsafe: Handles case where Auth user is already deleted

### 2. `onSupportRequestCreated`
Sends email notifications when support requests are submitted

### 3. `onUserCreated`
Sends welcome email when new users sign up

## Testing

After deployment, test by:
1. Creating a test user in Firebase Console
2. Delete the user document from Firestore → users collection
3. Check that the Auth user is also deleted automatically
4. Check Firebase Functions logs: `firebase functions:log`

## Gmail Configuration (Required for email functions)

```bash
firebase functions:config:set gmail.password="YOUR_GMAIL_APP_PASSWORD"
```

To get Gmail App Password:
1. Enable 2FA on nexusgodlydating@gmail.com
2. Go to myaccount.google.com → Security → App passwords
3. Create new app password for "Mail"
4. Use that password in the command above
