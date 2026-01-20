"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.getPresignedUploadUrl = void 0;
const firebase_functions_1 = require("firebase-functions");
const https_1 = require("firebase-functions/v2/https");
const logger = __importStar(require("firebase-functions/logger"));
const app_1 = require("firebase-admin/app");
const auth_1 = require("firebase-admin/auth");
const client_s3_1 = require("@aws-sdk/client-s3");
const s3_request_presigner_1 = require("@aws-sdk/s3-request-presigner");
const crypto = __importStar(require("crypto"));
(0, app_1.initializeApp)();
const params_1 = require("firebase-functions/params");
// Config via params/secrets (functions.config() is deprecated)
const SPACES_KEY = (0, params_1.defineString)("SPACES_KEY");
const SPACES_ENDPOINT = (0, params_1.defineString)("SPACES_ENDPOINT"); // e.g. https://ams3.digitaloceanspaces.com
const SPACES_BUCKET = (0, params_1.defineString)("SPACES_BUCKET"); // e.g. nexus-v2-users
const SPACES_REGION = (0, params_1.defineString)("SPACES_REGION"); // e.g. ams3
const SPACES_SECRET = (0, params_1.defineSecret)("SPACES_SECRET");
(0, firebase_functions_1.setGlobalOptions)({ maxInstances: 10 });
function readSpacesConfig() {
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
exports.getPresignedUploadUrl = (0, https_1.onRequest)({ secrets: [SPACES_SECRET] }, async (req, res) => {
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
        const decoded = await (0, auth_1.getAuth)().verifyIdToken(token);
        const uid = decoded.uid;
        const body = (req.body || {});
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
        const ext = type === "photo"
            ? (contentType.includes("png") ? "png" : "jpg")
            : (contentType.includes("mpeg") ? "mp3" : "m4a");
        const rand = crypto.randomBytes(8).toString("hex");
        const objectKey = `users/${uid}/${type}s/${type}_${Date.now()}_${rand}.${ext}`;
        const client = new client_s3_1.S3Client({
            region,
            endpoint,
            credentials: {
                accessKeyId: key,
                secretAccessKey: secret,
            },
        });
        const cmd = new client_s3_1.PutObjectCommand({
            Bucket: bucket,
            Key: objectKey,
            ContentType: contentType,
            ACL: "public-read",
        });
        const uploadUrl = await (0, s3_request_presigner_1.getSignedUrl)(client, cmd, { expiresIn: 300 });
        // Stable public URL: endpoint + bucket + objectKey (strip trailing slash).
        const ep = endpoint.replace(/\/$/, "");
        const publicUrl = `${ep}/${bucket}/${objectKey}`;
        logger.info("Presigned upload issued", { uid, type, objectKey });
        res.json({ uploadUrl, publicUrl, objectKey });
    }
    catch (e) {
        logger.error("Presign failed", e);
        res.status(500).send("Failed to generate upload URL");
    }
});
//# sourceMappingURL=index.js.map