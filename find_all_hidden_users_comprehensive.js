#!/usr/bin/env node

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function findAllHiddenUsers() {
  console.log('=== COMPREHENSIVE HIDDEN USERS SCAN ===\n');

  const hiddenUsers = new Map(); // Map of uid -> user data + reason

  try {
    // Get all users
    console.log('Fetching all users from Firestore...');
    const usersSnapshot = await db.collection('users').get();
    const allUsers = usersSnapshot.docs.map(d => ({ uid: d.id, ...d.data() }));
    console.log(`Total users: ${allUsers.length}\n`);

    // Check each hiding mechanism
    console.log('Checking hiding mechanisms:\n');

    // 1. Check for disabled: true
    console.log('1️⃣  Checking disabled: true');
    const disabledTrue = allUsers.filter(u => u.disabled === true);
    console.log(`   Found: ${disabledTrue.length}`);
    disabledTrue.forEach(u => {
      hiddenUsers.set(u.uid, {
        email: u.email,
        username: u.username,
        reasons: ['disabled: true'],
        data: u,
      });
    });

    // 2. Check for accountStatus: 'disabled'
    console.log('2️⃣  Checking accountStatus: disabled');
    const accountStatusDisabled = allUsers.filter(
      u =>
        (u.accountStatus || '').toString().toLowerCase() === 'disabled',
    );
    console.log(`   Found: ${accountStatusDisabled.length}`);
    accountStatusDisabled.forEach(u => {
      const existing = hiddenUsers.get(u.uid);
      if (existing) {
        existing.reasons.push('accountStatus: disabled');
      } else {
        hiddenUsers.set(u.uid, {
          email: u.email,
          username: u.username,
          reasons: ['accountStatus: disabled'],
          data: u,
        });
      }
    });

    // 3. Check for status: 'disabled'
    console.log('3️⃣  Checking status: disabled');
    const statusDisabled = allUsers.filter(
      u => (u.status || '').toString().toLowerCase() === 'disabled',
    );
    console.log(`   Found: ${statusDisabled.length}`);
    statusDisabled.forEach(u => {
      const existing = hiddenUsers.get(u.uid);
      if (existing) {
        existing.reasons.push('status: disabled');
      } else {
        hiddenUsers.set(u.uid, {
          email: u.email,
          username: u.username,
          reasons: ['status: disabled'],
          data: u,
        });
      }
    });

    // 4. Check for isAdmin: true
    console.log('4️⃣  Checking isAdmin: true');
    const adminUsers = allUsers.filter(u => u.isAdmin === true);
    console.log(`   Found: ${adminUsers.length}`);
    adminUsers.forEach(u => {
      const existing = hiddenUsers.get(u.uid);
      if (existing) {
        existing.reasons.push('isAdmin: true');
      } else {
        hiddenUsers.set(u.uid, {
          email: u.email,
          username: u.username,
          reasons: ['isAdmin: true'],
          data: u,
        });
      }
    });

    // 5. Check for other visibility flags
    console.log('5️⃣  Checking other visibility flags (hidden, isHidden, etc)');
    const otherHidden = allUsers.filter(
      u =>
        u.hidden === true ||
        u.isHidden === true ||
        u.testAccount === true ||
        u.internalAccount === true ||
        u.archived === true ||
        u.banned === true ||
        u.suspended === true,
    );
    console.log(`   Found: ${otherHidden.length}`);
    otherHidden.forEach(u => {
      const reasons = [];
      if (u.hidden === true) reasons.push('hidden: true');
      if (u.isHidden === true) reasons.push('isHidden: true');
      if (u.testAccount === true) reasons.push('testAccount: true');
      if (u.internalAccount === true) reasons.push('internalAccount: true');
      if (u.archived === true) reasons.push('archived: true');
      if (u.banned === true) reasons.push('banned: true');
      if (u.suspended === true) reasons.push('suspended: true');

      const existing = hiddenUsers.get(u.uid);
      if (existing) {
        existing.reasons.push(...reasons);
      } else {
        hiddenUsers.set(u.uid, {
          email: u.email,
          username: u.username,
          reasons,
          data: u,
        });
      }
    });

    // 6. Check for blocked emails list (from dating_search_service.dart)
    console.log('6️⃣  Checking blocked emails');
    const blockedEmailsRef = db.collection('config').doc('dating');
    const blockedEmailsDoc = await blockedEmailsRef.get();
    const blockedEmails = blockedEmailsDoc.exists
      ? blockedEmailsDoc.data()?.blockedEmails || []
      : [];
    console.log(`   Found: ${blockedEmails.length}`);

    const blockedEmailUsers = allUsers.filter(u =>
      blockedEmails.includes((u.email || '').toLowerCase().trim()),
    );
    blockedEmailUsers.forEach(u => {
      const existing = hiddenUsers.get(u.uid);
      if (existing) {
        existing.reasons.push('in blockedEmails list');
      } else {
        hiddenUsers.set(u.uid, {
          email: u.email,
          username: u.username,
          reasons: ['in blockedEmails list'],
          data: u,
        });
      }
    });

    // 7. Check for missing/incomplete profiles (might auto-hide)
    console.log('7️⃣  Checking for incomplete profiles or missing dating data');
    let incompleteCount = 0;
    const incompleteProfiles = allUsers.filter(u => {
      // V2 schema should have dating data
      if (u.dating) {
        return !u.dating.verificationStatus || u.dating.verificationStatus === 'incomplete';
      }
      // V1 schema should have registration_progress or specific fields
      return !u.registration_progress || u.registration_progress !== 'completed';
    });
    console.log(`   Found: ${incompleteProfiles.length}`);

    console.log(`\n${'='.repeat(60)}\n`);
    console.log(`📊 SUMMARY OF HIDDEN USERS: ${hiddenUsers.size}\n`);

    // Sort by reason
    const sortedUsers = Array.from(hiddenUsers.values()).sort((a, b) => {
      const aIsAdmin = a.reasons.includes('isAdmin: true');
      const bIsAdmin = b.reasons.includes('isAdmin: true');
      if (aIsAdmin && !bIsAdmin) return -1;
      if (!aIsAdmin && bIsAdmin) return 1;
      return a.email.localeCompare(b.email);
    });

    sortedUsers.forEach((userInfo, idx) => {
      console.log(`${idx + 1}. ${userInfo.email || '(no email)'}`);
      console.log(`   UID: ${userInfo.data.uid || 'N/A'}`);
      console.log(`   Username: ${userInfo.username || 'N/A'}`);
      console.log(`   Reasons: ${userInfo.reasons.join(', ')}`);
      console.log('');
    });

    // Provide breakdown
    console.log(`${'='.repeat(60)}`);
    console.log('\n📋 BREAKDOWN BY REASON:\n');

    const reasonStats = new Map();
    sortedUsers.forEach(u => {
      u.reasons.forEach(r => {
        reasonStats.set(r, (reasonStats.get(r) || 0) + 1);
      });
    });

    Array.from(reasonStats.entries())
      .sort((a, b) => b[1] - a[1])
      .forEach(([reason, count]) => {
        console.log(`  ${reason}: ${count}`);
      });

    console.log(`\n${'='.repeat(60)}\n`);
    console.log('✅ Scan complete!\n');
  } catch (error) {
    console.error('Error during scan:', error);
  } finally {
    await admin.app().delete();
  }
}

findAllHiddenUsers().catch(console.error);
