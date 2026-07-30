const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function createDummyProfiles() {
  console.log('📝 Creating dummy dating profiles...\n');
  
  const dummyProfiles = [
    {
      displayName: 'Amara',
      gender: 'Female',
      age: 28,
      photoUrls: ['https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=400'],
      relationshipStatus: 'single_never_married',
      verificationStatus: 'verified',
      countryOfResidence: 'United Kingdom',
      city: 'London',
      hobbies: ['Reading', 'Yoga', 'Cooking'],
      desiredQualities: ['Kind', 'Ambitious', 'Humorous'],
      audioUrls: [],
      profileCompletionDate: new Date(),
      interestedInDating: true,
    },
    {
      displayName: 'Zainab',
      gender: 'Female',
      age: 25,
      photoUrls: ['https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400'],
      relationshipStatus: 'single_never_married',
      verificationStatus: 'verified',
      countryOfResidence: 'United Kingdom',
      city: 'Manchester',
      hobbies: ['Travel', 'Photography', 'Music'],
      desiredQualities: ['Honest', 'Caring', 'Adventurous'],
      audioUrls: [],
      profileCompletionDate: new Date(),
      interestedInDating: true,
    },
    {
      displayName: 'Chioma',
      gender: 'Female',
      age: 30,
      photoUrls: ['https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=400'],
      relationshipStatus: 'single_never_married',
      verificationStatus: 'verified',
      countryOfResidence: 'United Kingdom',
      city: 'Birmingham',
      hobbies: ['Fitness', 'Art', 'Volunteering'],
      desiredQualities: ['Compassionate', 'Intelligent', 'Loyal'],
      audioUrls: [],
      profileCompletionDate: new Date(),
      interestedInDating: true,
    },
    {
      displayName: 'Tunde',
      gender: 'Male',
      age: 32,
      photoUrls: ['https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400'],
      relationshipStatus: 'single_never_married',
      verificationStatus: 'verified',
      countryOfResidence: 'United Kingdom',
      city: 'London',
      hobbies: ['Football', 'Tech', 'Cooking'],
      desiredQualities: ['Loyal', 'Supportive', 'Witty'],
      audioUrls: [],
      profileCompletionDate: new Date(),
      interestedInDating: true,
    },
    {
      displayName: 'Obi',
      gender: 'Male',
      age: 29,
      photoUrls: ['https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400'],
      relationshipStatus: 'single_never_married',
      verificationStatus: 'verified',
      countryOfResidence: 'United Kingdom',
      city: 'Leeds',
      hobbies: ['Gaming', 'Hiking', 'Music'],
      desiredQualities: ['Independent', 'Ambitious', 'Kind'],
      audioUrls: [],
      profileCompletionDate: new Date(),
      interestedInDating: true,
    },
  ];

  let createdCount = 0;
  for (const profile of dummyProfiles) {
    try {
      await db.collection('users').add({
        ...profile,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      createdCount++;
      console.log(`✅ Created profile: ${profile.displayName} (${profile.gender})`);
    } catch (error) {
      console.error(`❌ Failed to create ${profile.displayName}:`, error.message);
    }
  }

  console.log(`\n📊 Total profiles created: ${createdCount}/5`);

  // Now create/update the gender stats document
  console.log('\n📊 Updating gender statistics...');
  try {
    const statsDoc = db.collection('config').doc('waitingListStats').collection('countries').doc('United Kingdom');
    
    await statsDoc.set({
      maleCount: 2,
      femaleCount: 3,
      totalCount: 5,
      lastUpdated: new Date().toISOString(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    
    console.log('✅ Gender statistics updated:\n');
    console.log('   👨 Males: 2');
    console.log('   👩 Females: 3');
    console.log('   👥 Total: 5');
  } catch (error) {
    console.error('❌ Failed to update stats:', error.message);
  }

  console.log('\n✨ Done! You can now see:');
  console.log('   1. Gender ratio in Admin Review screen');
  console.log('   2. 5 dummy profiles in the dating carousel');
  
  process.exit(0);
}

createDummyProfiles().catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});
