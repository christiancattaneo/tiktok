"use strict";
Object.defineProperty(exports, "__esModule", {value: true});
exports.getPersonalizedHashtags = exports.getOptimalVideoLength = exports.getTrendingHashtags = void 0;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();
// Get trending hashtags based on recent engagement
exports.getTrendingHashtags = functions.https.onCall(async (data, context) => {
  try {
    // Get videos from the last 24 hours
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    const videosSnapshot = await db.collection("videos")
        .where("createdAt", ">=", yesterday)
        .get();
    // Collect hashtags and their engagement metrics
    const hashtagStats = new Map();
    videosSnapshot.docs.forEach((doc) => {
      const video = doc.data();
      const hashtags = video.hashtags || [];
      hashtags.forEach((tag) => {
        const stats = hashtagStats.get(tag) || {likes: 0, views: 0, count: 0};
        stats.likes += video.likes || 0;
        stats.views += video.views || 0;
        stats.count += 1;
        hashtagStats.set(tag, stats);
      });
    });
    // Calculate trend scores
    const trends = Array.from(hashtagStats.entries())
        .map(([tag, stats]) => {
          // Score = (likes * 2 + views) / count to favor engagement rate
          const score = ((stats.likes * 2) + stats.views) / (stats.count || 1);
          return {
            tag,
            score: Number((score / 100).toFixed(2)),
            count: stats.count,
          };
        })
        .filter((trend) => trend.count >= 3) // Only include tags used at least 3 times
        .sort((a, b) => b.score - a.score)
        .slice(0, 10); // Get top 10 trending hashtags
    return {hashtags: trends};
  } catch (error) {
    console.error("Error getting trending hashtags:", error);
    throw new functions.https.HttpsError("internal", "Failed to get trending hashtags");
  }
});
// Get optimal video length recommendations
exports.getOptimalVideoLength = functions.https.onCall(async (data, context) => {
  try {
    // Get videos from the last 7 days
    const lastWeek = new Date();
    lastWeek.setDate(lastWeek.getDate() - 7);
    const videosSnapshot = await db.collection("videos")
        .where("createdAt", ">=", lastWeek)
        .get();
    // Group videos by duration ranges and calculate average engagement
    const durationStats = new Map();
    videosSnapshot.docs.forEach((doc) => {
      const video = doc.data();
      const duration = video.duration || 0;
      const engagement = (video.likes || 0) * 2 + (video.views || 0);
      // Group into ranges: 0-15s, 15-30s, 30-60s, 60s+
      let range = "";
      if (duration <= 15) {
        range = "0-15";
      } else if (duration <= 30) {
        range = "15-30";
      } else if (duration <= 60) {
        range = "30-60";
      } else {
        range = "60+";
      }
      const stats = durationStats.get(range) || {totalEngagement: 0, count: 0};
      stats.totalEngagement += engagement;
      stats.count += 1;
      durationStats.set(range, stats);
    });
    // Find the range with highest average engagement
    let bestRange = "";
    let bestEngagement = 0;
    durationStats.forEach((stats, range) => {
      const avgEngagement = stats.totalEngagement / stats.count;
      if (avgEngagement > bestEngagement) {
        bestEngagement = avgEngagement;
        bestRange = range;
      }
    });
    // Generate recommendation text
    let optimalLength = "";
    let explanation = "";
    switch (bestRange) {
      case "0-15":
        optimalLength = "15 seconds or less";
        explanation = "Short, snappy content is performing best right now";
        break;
      case "15-30":
        optimalLength = "15-30 seconds";
        explanation = "Mid-length videos are getting the most engagement";
        break;
      case "30-60":
        optimalLength = "30-60 seconds";
        explanation = "Longer form content is resonating with viewers";
        break;
      case "60+":
        optimalLength = "60+ seconds";
        explanation = "Detailed content is currently trending";
        break;
      default:
        optimalLength = "15-30 seconds";
        explanation = "This is a good general range for most content";
    }
    return {
      optimalLength,
      explanation,
      stats: Object.fromEntries(durationStats),
    };
  } catch (error) {
    console.error("Error getting optimal video length:", error);
    throw new functions.https.HttpsError("internal", "Failed to get optimal video length");
  }
});
// Get personalized hashtag recommendations
exports.getPersonalizedHashtags = functions.https.onCall(async (data, context) => {
  try {
    const caption = data.caption;
    if (!caption) {
      throw new functions.https.HttpsError("invalid-argument", "Caption is required");
    }
    // Get trending hashtags for context
    const trendingResult = await (0, exports.getTrendingHashtags)({}, context);
    const trendingTags = new Set(trendingResult.hashtags.map((h) => h.tag));
    // Use content analysis to suggest relevant hashtags
    const suggestions = new Set();
    // Add relevant trending tags
    trendingResult.hashtags.forEach((trend) => {
      if (caption.toLowerCase().includes(trend.tag.toLowerCase())) {
        suggestions.add(trend.tag);
      }
    });
    // Extract key terms from caption
    const words = caption.toLowerCase()
        .replace(/[^\w\s]/g, "")
        .split(/\s+/)
        .filter((word) => word.length > 3);
    // Add relevant terms as hashtags
    words.forEach((word) => {
      if (!suggestions.has(word)) {
        suggestions.add(word);
      }
    });
    // Combine with some trending tags that might be relevant
    trendingResult.hashtags
        .slice(0, 3)
        .forEach((trend) => {
          suggestions.add(trend.tag);
        });
    return {
      hashtags: Array.from(suggestions).slice(0, 8), // Return up to 8 suggestions
    };
  } catch (error) {
    console.error("Error getting personalized hashtags:", error);
    throw new functions.https.HttpsError("internal", "Failed to get personalized hashtags");
  }
});
// # sourceMappingURL=trendlens.js.map
