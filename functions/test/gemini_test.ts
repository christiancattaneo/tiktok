import { GoogleGenerativeAI } from "@google/generative-ai";
import * as dotenv from "dotenv";
import * as path from "path";

// Load environment variables from the root directory
dotenv.config({ path: path.resolve(__dirname, "../../.env") });

const API_KEY = process.env.GOOGLE_AI_API_KEY || "";
const genAI = new GoogleGenerativeAI(API_KEY);

async function generateHashtags(videoUrl: string, description: string) {
  try {
    const model = genAI.getGenerativeModel({
      model: "gemini-pro",
    });

    const prompt = `
    Analyze this video content and generate relevant hashtags:
    Video URL: ${videoUrl}
    Description: ${description}

    The video shows a serene snowy forest at sunrise. Generate 5-10 relevant hashtags that describe:
    1. The visual content and mood
    2. The natural elements shown
    3. The time of day
    4. The season
    5. The overall aesthetic

    Format the response as a simple array of hashtags without numbers or explanations.
    Example format: ["hashtag1", "hashtag2", "hashtag3"]
    `;

    const result = await model.generateContent(prompt);
    const response = await result.response;
    const text = response.text();

    // Parse the response into an array
    const hashtags = JSON.parse(text.replace(/```json\n|\n```/g, ""));
    console.log("Generated Hashtags:", hashtags);
    return hashtags;
  } catch (error) {
    console.error("Error generating hashtags:", error);
    throw error;
  }
}

// Test the function
const videoUrl = "https://www.pexels.com/video/serene-snowy-forest-at-sunrise-30123241/";
const description = "";

generateHashtags(videoUrl, description)
  .then(() => console.log("Test completed"))
  .catch((error) => console.error("Test failed:", error));
