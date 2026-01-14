import { setGlobalOptions } from "firebase-functions";
import { onRequest } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";

import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";

import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import * as crypto from "crypto";

initializeApp();

import { defineString, defineSecret } from "firebase-functions/params";

// Config via params/secrets (functions.config() is deprecated)
const SPACES_KEY = defineString("SPACES_KEY");
const SPACES_ENDPOINT = defineString("SPACES_ENDPOINT"); // e.g. https://ams3.digitaloceanspaces.com
const SPACES_BUCKET = defineString("SPACES_BUCKET");     // e.g. nexus-v2-users
const SPACES_REGION = defineString("SPACES_REGION");     // e.g. ams3
const SPACES_SECRET = defineSecret("SPACES_SECRET");

setGlobalOptions({ maxInstances: 10 });

type SpacesConfig = {
  key: string;
  secret: string;
  endpoint: string; // e.g. https://nyc3.digitaloceanspaces.com
  bucket: string;
  region: string;   // e.g. nyc3
};

function readSpacesConfig(): SpacesConfig {
  const key = SPACES_KEY.value();
  const secret = SPACES_SECRET.value();
  const endpoint = SPACES_ENDPOINT.value();
  const bucket = SPACES_BUCKET.value();
  const region = SPACES_REGION.value();

  if (!key || !secret || !endpoint || !bucket || !region) {
    throw new Error("Missing Spaces params/secrets. Ensure functions/.env.nexus-visibility-app sets SPACES_KEY/SPACES_ENDPOINT/SPACES_BUCKET/SPACES_REGION and Secret Manager sets SPACES_SECRET.");
  }

  return { key, secret, endpoint, bucket, region };
}

/**
 * POST /getPresignedUploadUrl
 * Headers: Authorization: Bearer <Firebase ID token>
 * Body: { type: "photo" | "audio", contentType: string }
 * Response: { uploadUrl, publicUrl, objectKey }
 */
export const getPresignedUploadUrl = onRequest({ secrets: [SPACES_SECRET] }, async (req, res) => {
  try {
    if (req.method !== "POST") {
      res.status(405).send("Method not allowed");
      return;
    }

    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      res.status(401).send("Missing auth token");
      return;
    }

    const token = authHeader.slice("Bearer ".length);
    const decoded = await getAuth().verifyIdToken(token);
    const uid = decoded.uid;

    const body = (req.body || {}) as { type?: string; contentType?: string };
    const type = body.type;
    const contentType = body.contentType;

    if (type !== "photo" && type !== "audio") {
      res.status(400).send("Invalid type. Use 'photo' or 'audio'.");
      return;
    }
    if (!contentType || typeof contentType !== "string") {
      res.status(400).send("Missing contentType.");
      return;
    }

    const { key, secret, endpoint, bucket, region } = readSpacesConfig();

    const ext =
      type === "photo"
        ? (contentType.includes("png") ? "png" : "jpg")
        : (contentType.includes("mpeg") ? "mp3" : "m4a");

    const rand = crypto.randomBytes(8).toString("hex");
    const objectKey = `users/${uid}/${type}s/${type}_${Date.now()}_${rand}.${ext}`;

    const client = new S3Client({
      region,
      endpoint,
      credentials: {
        accessKeyId: key,
        secretAccessKey: secret,
      },
    });

    const cmd = new PutObjectCommand({
      Bucket: bucket,
      Key: objectKey,
      ContentType: contentType,
      ACL: "public-read",
    });

    const uploadUrl = await getSignedUrl(client, cmd, { expiresIn: 300 });

    // Stable public URL: endpoint + bucket + objectKey (strip trailing slash).
    const ep = endpoint.replace(/\/$/, "");
    const publicUrl = `${ep}/${bucket}/${objectKey}`;

    logger.info("Presigned upload issued", { uid, type, objectKey });
    res.json({ uploadUrl, publicUrl, objectKey });
  } catch (e) {
    logger.error("Presign failed", e as Error);
    res.status(500).send("Failed to generate upload URL");
  }
});
