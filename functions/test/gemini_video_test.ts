import { GoogleGenerativeAI } from "@google/generative-ai";
import * as fs from "fs";
import * as path from "path";
import * as dotenv from "dotenv";
import { execSync } from "child_process";
import fetch from "node-fetch";

// Load environment variables from the root directory
dotenv.config({ path: path.resolve(__dirname, "../../.env") });

const API_KEY = process.env.GOOGLE_AI_API_KEY || "";
const genAI = new GoogleGenerativeAI(API_KEY);

async function downloadImage(url: string): Promise<Buffer> {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Failed to fetch image: ${response.statusText}`);
  }
  return Buffer.from(await response.arrayBuffer());
}

async function generateHashtagsGemini(videoSource: string): Promise<string[]> {
  try {
    let frameData: Buffer;
    if (videoSource.startsWith("http")) {
      // For Pexels URLs, construct the preview image URL
      // Example: https://player.vimeo.com/external/372333241.sd.mp4 -> https://i.vimeocdn.com/video/372333241.jpg
      const videoId = videoSource.split("/").pop()?.split(".")[0];
      if (!videoId) {
        throw new Error("Could not extract video ID from URL");
      }
      const previewUrl = `https://i.vimeocdn.com/video/${videoId}.jpg`;
      console.log("Downloading preview from:", previewUrl);
      frameData = await downloadImage(previewUrl);
    } else {
      // For local files, extract frame using ffmpeg
      const frameOutputPath = path.join(__dirname, "temp_frame_%03d.jpg");
      execSync(`ffmpeg -i "${videoSource}" -vf "select=eq(n\\,0)" -vframes 1 "${frameOutputPath}"`);
      const actualFramePath = path.join(__dirname, "temp_frame_001.jpg");
      frameData = fs.readFileSync(actualFramePath);
      fs.unlinkSync(actualFramePath);
    }

    const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });
    const prompt = [
      "Analyze this video frame and generate relevant hashtags that describe what you see in the image.",
      "Return only a comma-separated list of hashtags.",
      "Do not reference the URL or any text descriptions.",
    ].join(" ");

    const result = await model.generateContent([
      prompt,
      {
        inlineData: {
          mimeType: "image/jpeg",
          data: frameData.toString("base64"),
        },
      },
    ]);

    const response = await result.response;
    const text = response.text();
    return text.split(",").map((tag) => tag.trim());
  } catch (error) {
    console.error("Error generating hashtags with Gemini:", error);
    return ["video"];
  }
}

// Test both local file and Pexels URL
const localVideoPath = path.resolve(__dirname, "testvideo.mp4");
const pexelsUrl = "https://player.vimeo.com/external/372333241.sd.mp4";

console.log("Testing with local video...");
generateHashtagsGemini(localVideoPath)
  .then((hashtags) => {
    console.log("Generated hashtags for local video:", hashtags);
    console.log("\nTesting with Pexels URL...");
    return generateHashtagsGemini(pexelsUrl);
  })
  .then((hashtags) => {
    console.log("Generated hashtags for Pexels URL:", hashtags);
  })
  .catch((error) => {
    console.error("Error:", error);
  });
