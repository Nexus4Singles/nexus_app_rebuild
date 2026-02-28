/**
 * NEXUS 2.0 - CLOUD FUNCTIONS (v1 API, Node 22)
 *
 * Uses process.env for config (loaded from .env.nexus-visibility-app)
 * and runWith({ secrets }) for Secret Manager values.
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');
const crypto = require('crypto');

admin.initializeApp();

exports.getPresignedUploadUrl = functions
  .runWith({ secrets: ['SPACES_SECRET'] })
  .https.onRequest(async (req, res) => {
  try {
    if (req.method !== 'POST') return res.status(405).send('Method not allowed');
    
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) return res.status(401).send('Unauthorized');
    const token = authHeader.slice(7);
    const decoded = await admin.auth().verifyIdToken(token);
    const uid = decoded.uid;

    const { type } = req.body || {};
    if (type !== 'photo' && type !== 'audio') return res.status(400).send('Invalid type');

    // Read config from process.env (populated by .env.nexus-visibility-app + Secret Manager)
    const rawEndpoint = process.env.SPACES_ENDPOINT || 'https://ams3.digitaloceanspaces.com';
    const bucket = process.env.SPACES_BUCKET || 'nexus-v2-users';
    const region = process.env.SPACES_REGION || 'ams3';
    const accessKey = process.env.SPACES_KEY || '';
    const secretKey = process.env.SPACES_SECRET || '';

    const hostname = rawEndpoint.replace(/^https?:\/\//, '').replace(/\/+$/, '');
    const cleanEndpoint = `https://${hostname}`;

    const client = new S3Client({
      region,
      endpoint: cleanEndpoint,
      forcePathStyle: true,
      credentials: {
        accessKeyId: accessKey,
        secretAccessKey: secretKey,
      },
    });

    const ext = type === 'photo' ? 'jpg' : 'm4a';
    const contentType = type === 'photo' ? 'image/jpeg' : 'audio/mp4';
    const objectKey = `users/${uid}/${type}s/${type}_${Date.now()}_${crypto.randomBytes(4).toString('hex')}.${ext}`;

    const cmd = new PutObjectCommand({
      Bucket: bucket,
      Key: objectKey,
      ContentType: contentType,
      ACL: 'public-read',
    });
    
    const uploadUrl = await getSignedUrl(client, cmd, { expiresIn: 300 });
    const publicUrl = `https://${hostname}/${bucket}/${objectKey}`;

    res.json({ uploadUrl, publicUrl, objectKey, contentType });
  } catch (e) {
    console.error('Presign error:', e);
    res.status(500).send('Internal Error');
  }
});
