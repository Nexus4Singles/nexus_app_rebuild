#!/usr/bin/env python3
import firebase_admin
from firebase_admin import credentials, firestore

try:
    firebase_admin.get_app()
except ValueError:
    cred = credentials.Certificate('serviceAccount.json')
    firebase_admin.initialize_app(cred)

db = firestore.client()
users = list(db.collection('users').where('email', '==', 'sunkykush007@gmail.com').limit(1).stream())
if users:
    user_id = users[0].id
    user_data = users[0].to_dict()
    sub = user_data.get('subscription')
    print('✅ User found:', user_id)
    print('Email:', user_data.get('email'))
    print('Username:', user_data.get('username'))
    print('\nV1 Legacy Fields:')
    print('  onPremium:', user_data.get('onPremium'))
    print('  subExpDate:', user_data.get('subExpDate'))
    print('\nV2 Subscription Object:')
    if sub:
        print('  ✅ EXISTS')
        print('    isActive:', sub.get('isActive'))
        print('    tier:', sub.get('tier'))
        print('    expiryDate:', sub.get('expiryDate'))
    else:
        print('  ❌ MISSING')
else:
    print('❌ User not found')
