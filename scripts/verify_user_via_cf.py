#!/usr/bin/env python3

"""
Script: Verify User Via Cloud Function (Python Alternative)

This script manually verifies a user's dating profile by calling
the verifyUserProfile Cloud Function.

PREREQUISITES:
- You must be an admin (have admin: true custom claim)
- Firebase CLI must be installed: npm install -g firebase-tools
- You must be signed in to Firebase CLI: firebase login

USAGE:
python3 scripts/verify_user_via_cf.py <target_email> [verification_status]

EXAMPLES:
- Verify as "verified":
  python3 scripts/verify_user_via_cf.py arc.prosperchukwuka@gmail.com

- Reject a user:
  python3 scripts/verify_user_via_cf.py arc.prosperchukwuka@gmail.com rejected

- Mark as "pending":
  python3 scripts/verify_user_via_cf.py arc.prosperchukwuka@gmail.com pending
"""

import json
import requests
import sys
import subprocess
from pathlib import Path

# Colors for output
class Colors:
    RED = '\033[91m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    RESET = '\033[0m'

def print_header(text):
    print(f"\n{Colors.BLUE}{'='*70}{Colors.RESET}")
    print(f"{Colors.BLUE}{text}{Colors.RESET}")
    print(f"{Colors.BLUE}{'='*70}{Colors.RESET}\n")

def print_success(text):
    print(f"{Colors.GREEN}✅ {text}{Colors.RESET}")

def print_error(text):
    print(f"{Colors.RED}❌ {text}{Colors.RESET}")

def print_warning(text):
    print(f"{Colors.YELLOW}⚠️  {text}{Colors.RESET}")

def print_info(text):
    print(f"{Colors.BLUE}ℹ️  {text}{Colors.RESET}")

def get_id_token_from_firebase_cli():
    """Try to get ID token using Firebase CLI"""
    try:
        print_info("Attempting to get ID token from Firebase CLI...")
        
        # Try to get the token from Firebase
        result = subprocess.run(
            ['firebase', 'login:ci', '--no-localhost'],
            capture_output=True,
            text=True,
            timeout=30
        )
        
        if result.returncode == 0 and result.stdout.strip():
            return result.stdout.strip()
    except Exception as e:
        print_warning(f"Firebase CLI method failed: {e}")
    
    return None

def get_id_token_from_gcloud():
    """Try to get ID token using gcloud"""
    try:
        print_info("Attempting to get ID token from gcloud...")
        
        project_id = 'nexus-visibility-app'
        audience = f'https://us-central1-{project_id}.cloudfunctions.net/verifyUserProfile'
        
        result = subprocess.run(
            ['gcloud', 'auth', 'identity-token', f'--audiences={audience}'],
            capture_output=True,
            text=True,
            timeout=30
        )
        
        if result.returncode == 0 and result.stdout.strip():
            return result.stdout.strip()
    except Exception as e:
        print_warning(f"gcloud method failed: {e}")
    
    return None

def get_id_token_manual_instructions():
    """Show instructions for manually getting token"""
    print_warning("Could not automatically obtain ID token.")
    print("\n📝 MANUAL INSTRUCTIONS:\n")
    print("1. Sign into your Nexus app with your admin account")
    print("2. Open browser DevTools (F12 or Cmd+Option+I)")
    print("3. Go to Console tab")
    print("4. Paste and run this code:\n")
    print(f"{Colors.YELLOW}firebase.auth().currentUser.getIdToken().then(t => {{{Colors.RESET}")
    print(f"{Colors.YELLOW}  const token = t;{Colors.RESET}")
    print(f"{Colors.YELLOW}  console.log('ID_TOKEN:' + token);{Colors.RESET}")
    print(f"{Colors.YELLOW}  // Copy the token value above{Colors.RESET}")
    print(f"{Colors.YELLOW}}});{Colors.RESET}\n")
    print("5. Copy the token value")
    print(f"6. Then run this command in terminal:\n")
    
    return None

def verify_user(email: str, status: str = 'verified') -> bool:
    """Verify a user via Cloud Function"""
    
    print_header(f"🔐 Verify User Via Cloud Function")
    
    print_info(f"Target Email: {email}")
    print_info(f"Status: {status}")
    
    # Try to get ID token
    id_token = get_id_token_from_firebase_cli()
    if not id_token:
        id_token = get_id_token_from_gcloud()
    
    if not id_token:
        get_id_token_manual_instructions()
        print("Run with your token:")
        print(f"  FIREBASE_TOKEN='YOUR_TOKEN_HERE' python3 scripts/verify_user_via_cf.py {email} {status}")
        return False
    
    print_success("Got ID token")
    
    # Call Cloud Function
    print_info("Calling Cloud Function...")
    
    url = 'https://us-central1-nexus-visibility-app.cloudfunctions.net/verifyUserProfile'
    headers = {
        'Authorization': f'Bearer {id_token}',
        'Content-Type': 'application/json'
    }
    payload = {
        'email': email.lower().strip(),
        'verificationStatus': status
    }
    
    try:
        response = requests.post(url, headers=headers, json=payload, timeout=30)
        response_data = response.json()
        
        if response.status_code == 200 and response_data.get('success'):
            print_success(f"User verified!")
            print("\n📊 Details:")
            print(f"  User ID: {response_data.get('userId')}")
            print(f"  Username: {response_data.get('userName')}")
            print(f"  Email: {response_data.get('userEmail')}")
            updated = response_data.get('updated', {})
            print(f"  Status: {updated.get('verificationStatus')}")
            print(f"  Verified At: {updated.get('verifiedAt')}")
            print(f"  Verified By: {updated.get('verifiedBy')}")
            return True
        else:
            print_error(f"Failed to verify user")
            print(f"  Status Code: {response.status_code}")
            print(f"  Error: {response_data.get('error', 'Unknown error')}")
            if 'note' in response_data:
                print(f"  Note: {response_data['note']}")
            return False
            
    except requests.exceptions.RequestException as e:
        print_error(f"Request failed: {e}")
        return False
    except json.JSONDecodeError as e:
        print_error(f"Invalid response: {e}")
        print(f"Response body: {response.text}")
        return False

def main():
    # Parse arguments
    if len(sys.argv) < 2:
        print_error("Usage: python3 scripts/verify_user_via_cf.py <email> [status]")
        print("\nExamples:")
        print("  python3 scripts/verify_user_via_cf.py arc.prosperchukwuka@gmail.com")
        print("  python3 scripts/verify_user_via_cf.py arc.prosperchukwuka@gmail.com rejected")
        sys.exit(1)
    
    email = sys.argv[1]
    status = sys.argv[2] if len(sys.argv) > 2 else 'verified'
    
    # Validate email
    if '@' not in email:
        print_error("Invalid email address")
        sys.exit(1)
    
    # Verify user
    success = verify_user(email, status)
    
    print()
    if success:
        sys.exit(0)
    else:
        sys.exit(1)

if __name__ == '__main__':
    main()
