/**
 * Backfill script: Fix existing users who have audio on DO Spaces but missing from Firestore.
 * Also fixes file ACLs to public-read for all existing files.
 *
 * Run: node scripts/backfill_audio_and_acl.js
 *
 * Prerequisites:
 *   npm install @aws-sdk/client-s3   (in project root or functions/)
 */

const admin = require('firebase-admin');
const sa = require('../serviceAccount.json');
// Use the @aws-sdk from functions/node_modules since it's already installed there
const { S3Client, ListObjectsV2Command, PutObjectAclCommand } = require('../functions/node_modules/@aws-sdk/client-s3');

admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

// DO Spaces config (match .env.nexus-visibility-app)
const SPACES_ENDPOINT = 'https://ams3.digitaloceanspaces.com';
const SPACES_BUCKET = 'nexus-v2-users';
const SPACES_REGION = 'ams3';
const SPACES_KEY = process.env.SPACES_KEY || 'DO00Z66HV38EZ3R76VJF';
const SPACES_SECRET = process.env.SPACES_SECRET;

if (!SPACES_SECRET) {
  console.error('❌ SPACES_SECRET env var required. Run with:');
  console.error('   SPACES_SECRET=your_secret node scripts/backfill_audio_and_acl.js');
  process.exit(1);
}

const s3 = new S3Client({
  region: SPACES_REGION,
  endpoint: SPACES_ENDPOINT,
  forcePathStyle: true,
  credentials: {
    accessKeyId: SPACES_KEY,
    secretAccessKey: SPACES_SECRET,
  },
});

const PUBLIC_BASE = `https://ams3.digitaloceanspaces.com/${SPACES_BUCKET}`;

async function listAllObjects(prefix) {
  const objects = [];
  let continuationToken;
  do {
    const cmd = new ListObjectsV2Command({
      Bucket: SPACES_BUCKET,
      Prefix: prefix,
      ContinuationToken: continuationToken,
    });
    const resp = await s3.send(cmd);
    if (resp.Contents) objects.push(...resp.Contents);
    continuationToken = resp.IsTruncated ? resp.NextContinuationToken : undefined;
  } while (continuationToken);
  return objects;
}

async function makePublic(key) {
  try {
    await s3.send(new PutObjectAclCommand({
      Bucket: SPACES_BUCKET,
      Key: key,
      ACL: 'public-read',
    }));
    return true;
  } catch (e) {
    console.error(`  ⚠️ Failed to set ACL for ${key}: ${e.message}`);
    return false;
  }
}

async function main() {
  console.log('🔍 Listing all objects in DO Spaces...');
  const allObjects = await listAllObjects('users/');

  // Group by user UID
  const userFiles = {};
  for (const obj of allObjects) {
    // Key format: users/{uid}/photos/photo_xxx.jpg or users/{uid}/audios/audio_xxx.m4a
    const parts = obj.Key.split('/');
    if (parts.length < 4) continue;
    const uid = parts[1];
    const type = parts[2]; // 'photos' or 'audios'
    if (!userFiles[uid]) userFiles[uid] = { photos: [], audios: [] };
    if (type === 'photos') userFiles[uid].photos.push(obj.Key);
    if (type === 'audios') userFiles[uid].audios.push(obj.Key);
  }

  console.log(`\n📊 Found ${Object.keys(userFiles).length} users with files on DO Spaces`);

  let aclFixed = 0;
  let audioBackfilled = 0;
  let photoUrlsFixed = 0;

  for (const [uid, files] of Object.entries(userFiles)) {
    console.log(`\n=== User: ${uid} ===`);
    console.log(`  Photos: ${files.photos.length}, Audios: ${files.audios.length}`);

    // Step 1: Fix ACLs for ALL files
    for (const key of [...files.photos, ...files.audios]) {
      const ok = await makePublic(key);
      if (ok) aclFixed++;
    }

    // Step 2: Check Firestore for missing audio/photo URLs
    const userDoc = await db.collection('users').doc(uid).get();
    if (!userDoc.exists) {
      console.log(`  ⚠️ No Firestore doc found, skipping`);
      continue;
    }

    const data = userDoc.data();
    const dating = data.dating || {};
    const reviewPack = dating.reviewPack || {};

    // Build correct URLs from DO Spaces keys
    const audioUrls = files.audios
      .sort() // Sort by timestamp in filename
      .slice(-3) // Take latest 3
      .map(key => `${PUBLIC_BASE}/${key}`);

    const photoUrls = files.photos
      .sort()
      .slice(-2) // Take latest 2 (or more if needed)
      .map(key => `${PUBLIC_BASE}/${key}`);

    // Check if audio needs backfill
    const existingAudio = [
      ...(reviewPack.audioUrls || []),
      ...(dating.audioPrompts || []),
      ...(data.audioPrompts || []),
    ].filter(u => u && u.trim());

    // Check if photos in Firestore are accessible (check URL format)
    const existingPhotos = data.photos || [];

    const updates = {};

    if (audioUrls.length > 0 && existingAudio.length === 0) {
      console.log(`  🎵 Backfilling ${audioUrls.length} audio URLs`);
      // Write to all 3 locations UserModel.fromMap checks
      updates['audioPrompts'] = audioUrls; // Root level
      updates['dating.audioPrompts'] = audioUrls; // dating.audioPrompts
      updates['dating.reviewPack.audioUrls'] = audioUrls; // dating.reviewPack.audioUrls
      audioBackfilled++;
    } else if (existingAudio.length > 0) {
      console.log(`  ✅ Audio already in Firestore (${existingAudio.length} URLs)`);
      // Still ensure all 3 locations have the URLs
      if (!data.audioPrompts || data.audioPrompts.length === 0) {
        updates['audioPrompts'] = existingAudio;
      }
      if (!dating.audioPrompts || dating.audioPrompts.length === 0) {
        updates['dating.audioPrompts'] = existingAudio;
      }
    }

    // Fix photo URLs if they use the old nexus-v2-users.ams3 format (CDN subdomain)
    // Old format: https://nexus-v2-users.ams3.digitaloceanspaces.com/users/...
    // New format: https://ams3.digitaloceanspaces.com/nexus-v2-users/users/...
    // Both work but let's ensure consistency
    if (existingPhotos.length === 0 && photoUrls.length > 0) {
      console.log(`  📸 Backfilling ${photoUrls.length} photo URLs`);
      updates['photos'] = photoUrls;
      photoUrlsFixed++;
    }

    if (Object.keys(updates).length > 0) {
      await db.collection('users').doc(uid).update(updates);
      console.log(`  ✅ Firestore updated: ${Object.keys(updates).join(', ')}`);
    } else {
      console.log(`  ✅ No Firestore updates needed`);
    }
  }

  console.log('\n========== SUMMARY ==========');
  console.log(`ACLs fixed: ${aclFixed} files`);
  console.log(`Audio backfilled: ${audioBackfilled} users`);
  console.log(`Photo URLs fixed: ${photoUrlsFixed} users`);
  console.log('Done!');

  process.exit(0);
}

main().catch(e => {
  console.error('Fatal error:', e);
  process.exit(1);
});
