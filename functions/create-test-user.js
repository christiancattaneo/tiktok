const admin = require('firebase-admin');
const serviceAccount = require('../reelai-35b9e-firebase-adminsdk-fbsvc-3b7f9222fd.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

async function updateTestUser() {
  try {
    // Get the user
    const userRecord = await admin.auth().getUserByEmail('test@example.com');
    console.log('Found test user:', userRecord.uid);
    
    // Update password
    await admin.auth().updateUser(userRecord.uid, {
      password: 'Test123!@#',
      emailVerified: true
    });
    console.log('Updated test user password');
    
    // Update or create Firestore document
    await admin.firestore().collection('users').doc(userRecord.uid).set({
      id: userRecord.uid,
      email: 'test@example.com',
      username: 'testuser',
      photoUrl: '',
      bio: 'Test account',
      likedVideos: [],
      followersCount: 0,
      followingCount: 0,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });
    console.log('Updated user document in Firestore');
    
  } catch (error) {
    console.error('Error updating test user:', error);
  } finally {
    process.exit();
  }
}

updateTestUser(); 