const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const bucket = admin.storage().bucket(process.env.FIREBASE_STORAGE_BUCKET || `${serviceAccount.project_id}.appspot.com`);

function getContentTypeFromExt(filePath) {
  const ext = path.extname(filePath).toLowerCase();
  if (ext === '.jpg' || ext === '.jpeg') return 'image/jpeg';
  if (ext === '.png') return 'image/png';
  if (ext === '.webp') return 'image/webp';
  return 'application/octet-stream';
}

async function uploadStoryImage(localPath, storyId) {
  const destination = `cms/stories/${storyId}${path.extname(localPath).toLowerCase() || '.jpg'}`;
  const contentType = getContentTypeFromExt(localPath);
  console.log(`🖼️ Uploading image to storage: ${destination}`);
  await bucket.upload(localPath, {
    destination,
    metadata: {
      contentType,
    },
  });
  const file = bucket.file(destination);
  const [url] = await file.getSignedUrl({ action: 'read', expires: '2500-01-01' });
  console.log(`🖼️ Image URL: ${url}`);
  return url;
}

async function updateContent(jsonFile) {
  try {
    console.log(`📖 Reading ${jsonFile}...`);
    const content = JSON.parse(fs.readFileSync(jsonFile, 'utf8'));
    
    const contentType = content.stories ? 'stories' : 'polls';
    const data = content[contentType];
    
    if (!data || data.length === 0) {
      console.error(`❌ No ${contentType} found in ${jsonFile}`);
      process.exit(1);
    }

    // Optional CLI args
    const args = process.argv.slice(3);
    const getArg = (name) => {
      const idx = args.indexOf(`--${name}`);
      return idx >= 0 ? args[idx + 1] : null;
    };
    const imagePath = getArg('image');
    const targetStoryId = getArg('storyId');

    // Normalize audiences helper
    const normalizeAudiences = (arr) => {
      if (!Array.isArray(arr)) return [];
      const expanded = arr.flatMap((a) => {
        if (a === 'divorced_widowed') return ['divorced', 'widowed'];
        return [a];
      });
      // canonical order (optional)
      const order = ['single_never_married', 'divorced', 'widowed', 'married'];
      const deduped = [...new Set(expanded)];
      // Warn unknowns
      deduped.forEach((a) => {
        if (!order.includes(a)) {
          console.warn(`⚠️ Unknown audience key detected: ${a}`);
        }
      });
      // sort by canonical order to keep things tidy
      return deduped.sort((a, b) => order.indexOf(a) - order.indexOf(b));
    };

    // Apply normalization for stories
    if (contentType === 'stories') {
      for (const s of data) {
        s.audiences = normalizeAudiences(s.audiences || []);
      }
    }

    // If image provided for stories, upload and inject URL
    if (contentType === 'stories' && imagePath) {
      const storyIdx = targetStoryId
        ? data.findIndex((s) => s.storyId === targetStoryId)
        : 0;
      if (storyIdx < 0) {
        console.error(`❌ storyId not found in JSON: ${targetStoryId}`);
        process.exit(1);
      }
      const storyId = data[storyIdx].storyId;
      const imageUrl = await uploadStoryImage(imagePath, storyId);
      // Add/replace headerImageUrl on the story object
      data[storyIdx].headerImageUrl = imageUrl;
    }

    // Step 1: Get current version
    const versionsRef = db.collection('cms').doc('versions');
    const versionsDoc = await versionsRef.get();
    const currentVersion = versionsDoc.data()[contentType].version || 0;
    const newVersion = currentVersion + 1;

    console.log(`📊 Current ${contentType} version: ${currentVersion}`);
    console.log(`📊 New ${contentType} version: ${newVersion}`);

    // Step 2: Update content document
    const contentRef = db.collection('cms').doc(contentType);
    await contentRef.set({
      version: content.version,
      [contentType]: data
    });

    console.log(`✅ Updated cms/${contentType} with ${data.length} item(s)`);

    // Step 3: Bump version number
    await versionsRef.update({
      [`${contentType}.version`]: newVersion,
      [`${contentType}.releaseNotes`]: `Updated ${contentType} - ${new Date().toISOString()}`
    });

    // Verification helper: read back and confirm
    const saved = (await contentRef.get()).data();
    if (contentType === 'stories') {
      const verifyIdx = targetStoryId
        ? saved.stories.findIndex((s) => s.storyId === targetStoryId)
        : 0;
      if (verifyIdx >= 0) {
        const st = saved.stories[verifyIdx];
        const hasImage = !!st.headerImageUrl;
        console.log(`🔎 Verify stories: count=${saved.stories.length}, imageForTarget=${hasImage}`);
        if (hasImage) console.log(`🔗 headerImageUrl: ${st.headerImageUrl}`);
        console.log(`👥 Audiences (${st.storyId}): [${(st.audiences||[]).join(', ')}]`);
      }
    } else {
      console.log(`🔎 Verify polls: count=${saved.polls?.length || 0}`);
    }

    console.log(`✅ Bumped version to ${newVersion} in cms/versions`);
    console.log(`\n🎉 Monday update complete! Users will see new ${contentType} shortly.`);

    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

// Get JSON file from command line argument
const jsonFile = process.argv[2];

if (!jsonFile) {
  console.error('❌ Usage: node update_firestore.js <json-file>');
  console.error('   Example: node update_firestore.js test-story-week2.json');
  process.exit(1);
}

if (!fs.existsSync(jsonFile)) {
  console.error(`❌ File not found: ${jsonFile}`);
  process.exit(1);
}

updateContent(jsonFile);
