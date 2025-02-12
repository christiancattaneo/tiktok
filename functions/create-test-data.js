const admin = require('firebase-admin');
const serviceAccount = require('../reelai-35b9e-firebase-adminsdk-fbsvc-3b7f9222fd.json');

// Initialize Firebase Admin with service account
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function createTestData() {
  try {
    const videosRef = db.collection('videos');
    const now = new Date();

    // Create test videos with hashtags and engagement metrics
    const testVideos = [
      {
        createdAt: now,
        hashtags: ['dance', 'trending', 'viral'],
        likes: 1000,
        comments: 500,
        shares: 200
      },
      {
        createdAt: now,
        hashtags: ['comedy', 'funny', 'viral'],
        likes: 800,
        comments: 300,
        shares: 150
      },
      {
        createdAt: now,
        hashtags: ['tutorial', 'howto', 'tips'],
        likes: 600,
        comments: 400,
        shares: 100
      }
    ];

    console.log('Adding test videos to Firestore...');
    
    for (const video of testVideos) {
      await videosRef.add(video);
    }

    console.log('Test data created successfully!');
  } catch (error) {
    console.error('Error creating test data:', error);
  } finally {
    process.exit(0);
  }
}

createTestData(); 