import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

interface HashtagTrend {
  tag: string;
  count: number;
  engagement: number;
}

// Get trending hashtags based on recent engagement
export const getTrendingHashtags = onCall({ maxInstances: 10 }, async (_request: CallableRequest) => {
  try {
    const last24Hours = new Date(Date.now() - 24 * 60 * 60 * 1000);

    const videosRef = db.collection("videos");
    const recentVideos = await videosRef
      .where("createdAt", ">=", last24Hours)
      .get();

    const hashtagCounts = new Map<string, { count: number; engagement: number }>();

    recentVideos.docs.forEach((doc) => {
      const video = doc.data();
      const hashtags = video.hashtags || [];
      const engagement = (video.likes || 0) + (video.comments || 0) + (video.shares || 0);

      hashtags.forEach((tag: string) => {
        const current = hashtagCounts.get(tag) || { count: 0, engagement: 0 };
        hashtagCounts.set(tag, {
          count: current.count + 1,
          engagement: current.engagement + engagement,
        });
      });
    });

    const trends: HashtagTrend[] = Array.from(hashtagCounts.entries())
      .map(([tag, stats]) => ({
        tag,
        count: stats.count,
        engagement: stats.engagement,
      }))
      .sort((a, b) => b.engagement - a.engagement)
      .slice(0, 10);

    return { hashtags: trends };
  } catch (error) {
    console.error("Error getting trending hashtags:", error);
    throw new HttpsError("internal", "Failed to get trending hashtags");
  }
});

// Get optimal video length based on engagement
export const getOptimalVideoLength = onCall({ maxInstances: 10 }, async (_request: CallableRequest) => {
  try {
    const last7Days = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);

    const videosRef = db.collection("videos");
    const recentVideos = await videosRef
      .where("createdAt", ">=", last7Days)
      .get();

    let totalEngagement = 0;
    let weightedLengthSum = 0;

    recentVideos.docs.forEach((doc) => {
      const video = doc.data();
      const engagement = (video.likes || 0) + (video.comments || 0) + (video.shares || 0);
      const length = video.duration || 0;

      totalEngagement += engagement;
      weightedLengthSum += length * engagement;
    });

    const optimalLength = Math.round(weightedLengthSum / totalEngagement);

    return {
      insight: {
        optimalLength,
        explanation: `Videos around ${optimalLength} seconds tend to get the most engagement based on recent trends.`,
      },
    };
  } catch (error) {
    console.error("Error calculating optimal video length:", error);
    throw new HttpsError("internal", "Failed to calculate optimal video length");
  }
});

// Get personalized hashtag suggestions
export const getPersonalizedHashtags = onCall({ maxInstances: 10 }, async (request: CallableRequest) => {
  try {
    console.log("Starting getPersonalizedHashtags function");
    console.log("Full request:", JSON.stringify(request, null, 2));
    console.log("Auth context:", JSON.stringify(request.auth, null, 2));
    console.log("Raw request:", JSON.stringify(request.rawRequest, null, 2));

    // Check authentication
    if (!request.auth) {
      console.error("User not authenticated");
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }
    console.log(`User authenticated: ${request.auth.uid}`);
    console.log("User token:", JSON.stringify(request.auth.token, null, 2));

    const { data } = request;
    if (!data || typeof data.caption !== "string") {
      console.error("Invalid request data:", data);
      throw new HttpsError("invalid-argument", "Caption is required");
    }

    const caption = data.caption;
    console.log(`Processing caption: ${caption}`);

    // Get trending hashtags for reference
    console.log("Fetching trending hashtags");
    const trendingResult = await getTrendingHashtags.run({
      data: {},
      rawRequest: request.rawRequest,
      auth: request.auth,
      app: request.app,
      instanceIdToken: request.instanceIdToken,
      acceptsStreaming: false,
    });

    if (!trendingResult || !trendingResult.hashtags) {
      console.error("Failed to get trending hashtags:", trendingResult);
      throw new HttpsError("internal", "Failed to get trending hashtags");
    }
    console.log(`Got ${trendingResult.hashtags.length} trending hashtags`);

    // Simple matching based on caption keywords and trending tags
    const words = caption.toLowerCase().split(/\s+/);
    const suggestedTags = new Set<string>();

    // Add trending tags that match caption keywords
    trendingResult.hashtags.forEach((trend: HashtagTrend) => {
      const tagWords = trend.tag.toLowerCase().replace("#", "").split(/[^a-z0-9]/);
      if (words.some((word: string) =>
        tagWords.some((tagWord: string) => tagWord.includes(word) || word.includes(tagWord))
      )) {
        suggestedTags.add(trend.tag);
      }
    });
    console.log(`Found ${suggestedTags.size} matching tags`);

    // Add some trending tags as recommendations
    const remainingSlots = 5 - suggestedTags.size;
    if (remainingSlots > 0) {
      trendingResult.hashtags
        .slice(0, remainingSlots)
        .forEach((trend: HashtagTrend) => suggestedTags.add(trend.tag));
    }
    console.log(`Added trending tags, final count: ${suggestedTags.size}`);

    const result = {
      hashtags: Array.from(suggestedTags),
      explanation: "Based on your caption and current trends",
    };
    console.log("Returning result:", result);
    return result;
  } catch (error) {
    console.error("Error getting personalized hashtags:", error);
    if (error instanceof HttpsError) {
      throw error;
    }
    throw new HttpsError("internal", "Failed to get personalized hashtags");
  }
});
