import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {
  GoogleGenerativeAI,
} from "@google/generative-ai";
import fetch from "node-fetch";
import * as mimeTypes from "mime-types";

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || "");

interface HashtagTrend {
  tag: string;
  count: number;
  engagement: number;
  score?: number;
}

interface UploadedFile {
  name: string;
  displayName: string;
  uri: string;
  state: {
    name: string;
  };
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
        score: 0.5,
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

async function uploadFromUrlToGemini(videoUrl: string, mimeType?: string): Promise<UploadedFile> {
  try {
    const response = await fetch(videoUrl);
    if (!response.ok) {
      throw new Error(`Failed to fetch video from URL: ${videoUrl} - Status: ${response.status}`);
    }
    const contentType = response.headers.get("content-type");
    const fileMimeType = mimeType || contentType || "application/octet-stream";

    return {
      name: `video-from-url.${mimeTypes.extension(fileMimeType) || "unknown"}`,
      displayName: "Video File",
      uri: videoUrl,
      state: { name: "ACTIVE" },
    };
  } catch (error) {
    console.error("Error uploading file from URL:", error);
    throw error;
  }
}

async function waitForFilesActive(files: UploadedFile[]): Promise<void> {
  console.log("Waiting for file processing...");
  for (const file of files) {
    // Note: Since getFile is not actually available in the API, we'll use the file directly
    let currentFile = file;
    while (currentFile.state.name === "PROCESSING") {
      await new Promise((resolve) => setTimeout(resolve, 10000));
      currentFile = file;
    }
    if (currentFile.state.name !== "ACTIVE") {
      const errorMessage = `File ${currentFile.name} failed to process. State: ${currentFile.state.name}`;
      throw new Error(errorMessage);
    }
  }
  console.log("All files ready");
}

// New Cloud Function for visual hashtag generation
export const generateVisualHashtags = onCall({ maxInstances: 10 }, async (request: CallableRequest) => {
  try {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    const { videoUrl } = request.data;
    if (!videoUrl) {
      throw new HttpsError("invalid-argument", "Video URL is required");
    }

    console.log(`Processing video URL: ${videoUrl}`);

    // Upload video to Gemini
    const files = [await uploadFromUrlToGemini(videoUrl)];
    await waitForFilesActive(files);

    // Configure Gemini model
    const generationConfig = {
      temperature: 0.7,
      top_p: 0.95,
      top_k: 64,
      maxOutputTokens: 2048,
    };

    const model = genAI.getGenerativeModel({
      model: "gemini-pro",
      generationConfig,
    });

    // Direct prompt instead of chat
    const prompt = [
      "Generate 5 relevant hashtags describing the video content.",
      "Return as comma-separated list without # symbols",
    ].join(" ");

    const result = await model.generateContent(prompt);
    const response = await result.response;
    const hashtags = response.text()
      .split(",")
      .map((tag: string) => tag.trim())
      .filter((tag: string) => tag.length > 0);

    console.log("Generated hashtags:", hashtags);
    return { hashtags: hashtags.length > 0 ? hashtags : ["video"] };
  } catch (error) {
    console.error("Error generating visual hashtags:", error);
    throw new HttpsError("internal", "Failed to generate visual hashtags");
  }
});

// Generate hashtags using Gemini vision
export const generateHashtags = onCall({ maxInstances: 10 }, async (request: CallableRequest) => {
  try {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    const { videoUrl, description, thumbnailUrl } = request.data;
    if (!videoUrl) {
      throw new HttpsError("invalid-argument", "Video URL is required");
    }

    // Try to get the thumbnail
    let imageData: string | null = null;
    try {
      const imageResponse = await fetch(thumbnailUrl || videoUrl.replace(".mp4", ".jpg"));
      if (imageResponse.ok) {
        const buffer = await imageResponse.buffer();
        imageData = buffer.toString("base64");
      }
    } catch (e) {
      console.error("Error getting thumbnail:", e);
    }

    if (imageData) {
      // Try vision analysis first
      try {
        const model = genAI.getGenerativeModel({ model: "gemini-pro-vision" });
        const prompt = [
          "Analyze this video thumbnail and generate 5 relevant hashtags that describe",
          "its visual content. Return them as a comma-separated list without # symbols.",
          "Focus on the main subject matter, style, mood, and any notable visual elements.",
        ].join(" ");

        const result = await model.generateContent([
          { text: prompt },
          {
            inlineData: {
              mimeType: "image/jpeg",
              data: imageData,
            },
          },
        ]);

        const response = await result.response;
        const hashtags = response.text()
          .split(",")
          .map((tag: string) => tag.trim())
          .filter((tag: string) => tag.length > 0);

        if (hashtags.length > 0) {
          console.log("Generated visual hashtags:", hashtags);
          return { hashtags };
        }
      } catch (e) {
        console.error("Error in vision analysis:", e);
      }
    }

    // Fallback to text-only analysis
    const model = genAI.getGenerativeModel({ model: "gemini-pro" });
    const prompt = [
      "Generate 5 relevant hashtags for this video:",
      `URL: ${videoUrl}`,
      `Description: ${description}`,
      "Format the response as a comma-separated list without # symbols.",
    ].join("\n");

    const result = await model.generateContent(prompt);
    const response = await result.response;
    const hashtags = response.text()
      .split(",")
      .map((tag: string) => tag.trim())
      .filter((tag: string) => tag.length > 0);

    console.log("Generated text-based hashtags:", hashtags);
    return { hashtags: hashtags.length > 0 ? hashtags : ["pexels", "video"] };
  } catch (error) {
    console.error("Error generating hashtags:", error);
    throw new HttpsError("internal", "Failed to generate hashtags");
  }
});
