#!/bin/bash

# ============================================================================
# NEXUS 2.0 FIREBASE SETUP SCRIPT
# ============================================================================
# 
# Bundle ID: com.nexus4singles.nexus (keeping existing for app update)
# Firebase Project: Nexus App
#
# Run this script from your nexus_app project directory:
#   chmod +x firebase_setup.sh
#   ./firebase_setup.sh
#
# ============================================================================

set -e  # Exit on error

echo ""
echo "🔥 Nexus 2.0 Firebase Setup"
echo "============================"
echo ""
echo "📦 Bundle ID: com.nexus4singles.nexus"
echo "🔥 Firebase Project: Nexus App"
echo ""

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed or not in PATH"
    echo "   Please install Flutter first: https://flutter.dev/docs/get-started/install"
    exit 1
fi

echo "✅ Flutter found: $(flutter --version | head -n 1)"
echo ""

# Check if we're in a Flutter project
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ Not in a Flutter project directory"
    echo "   Please run this script from your nexus_app folder"
    exit 1
fi

# Ensure android and ios folders exist
if [ ! -d "android" ] || [ ! -d "ios" ]; then
    echo "📱 Creating platform folders..."
    flutter create --org com.nexus4singles --project-name nexus .
    echo "✅ Platform folders created"
    echo ""
fi

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "📦 Firebase CLI not found. Installing..."
    
    # Try npm first
    if command -v npm &> /dev/null; then
        npm install -g firebase-tools
    else
        # Try curl install
        curl -sL https://firebase.tools | bash
    fi
    
    if ! command -v firebase &> /dev/null; then
        echo "❌ Failed to install Firebase CLI"
        echo "   Try manually: npm install -g firebase-tools"
        echo "   Or: curl -sL https://firebase.tools | bash"
        exit 1
    fi
fi

echo "✅ Firebase CLI found"
echo ""

# Check if FlutterFire CLI is installed
if ! command -v flutterfire &> /dev/null; then
    echo "📦 Installing FlutterFire CLI..."
    dart pub global activate flutterfire_cli
    
    # Add to PATH for this session
    export PATH="$PATH":"$HOME/.pub-cache/bin"
    
    if ! command -v flutterfire &> /dev/null; then
        echo ""
        echo "⚠️  FlutterFire installed but not in PATH"
        echo "   Add this to your ~/.zshrc or ~/.bashrc:"
        echo '   export PATH="$PATH":"$HOME/.pub-cache/bin"'
        echo ""
        echo "   Then run: source ~/.zshrc (or ~/.bashrc)"
        echo "   And run this script again"
        exit 1
    fi
fi

echo "✅ FlutterFire CLI found"
echo ""

# Check Firebase login status
echo "🔐 Checking Firebase authentication..."
if ! firebase projects:list &> /dev/null; then
    echo "📱 Opening browser for Firebase login..."
    firebase login
    if [ $? -ne 0 ]; then
        echo "❌ Firebase login failed"
        exit 1
    fi
fi

echo "✅ Firebase authenticated"
echo ""

# Run FlutterFire configure
echo "⚙️  Running FlutterFire configure..."
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 IMPORTANT - Select these options when prompted:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "   1. Project:  Select 'Nexus App'"
echo "   2. Platforms: Select 'android' and 'ios'"
echo "   3. Android package: com.nexus4singles.nexus"
echo "   4. iOS bundle: com.nexus4singles.nexus"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
read -p "Press Enter to continue..."
echo ""

flutterfire configure \
    --project=nexus-app \
    --android-package-name=com.nexus4singles.nexus \
    --ios-bundle-id=com.nexus4singles.nexus

if [ $? -eq 0 ]; then
    echo ""
    echo "============================================"
    echo "✅ Firebase configuration complete!"
    echo "============================================"
    echo ""
    echo "📝 Next steps:"
    echo ""
    echo "   1. Open lib/main.dart"
    echo ""
    echo "   2. Uncomment this import (around line 31):"
    echo "      import 'firebase_options.dart';"
    echo ""
    echo "   3. Uncomment Firebase.initializeApp (around line 47-49):"
    echo "      await Firebase.initializeApp("
    echo "        options: DefaultFirebaseOptions.currentPlatform,"
    echo "      );"
    echo ""
    echo "   4. Run these commands:"
    echo "      flutter pub get"
    echo "      flutter run"
    echo ""
    echo "============================================"
else
    echo ""
    echo "❌ FlutterFire configure failed"
    echo "   Please try running manually: flutterfire configure"
fi
