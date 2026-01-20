#!/usr/bin/env node
import admin from "firebase-admin";

const projectId = (process.env.FIREBASE_PROJECT_ID || '').trim();
if (!projectId) {
  console.error("Missing FIREBASE_PROJECT_ID env var.");
  process.exit(1);
}

if (admin.apps.length === 0) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId,
  });
}

const db = admin.firestore();

function cap(s) {
  if (!s) return s;
  return s[0].toUpperCase() + s.slice(1);
}

function genderVariants(genderToShow) {
  const raw = (genderToShow || "").trim();
  if (!raw) return [];
  const lower = raw.toLowerCase();
  const set = new Set([raw, lower, lower.toUpperCase(), cap(lower)]);
  if (lower === "male") ["man", "Man", "MAN"].forEach(v => set.add(v));
  if (lower === "female") ["woman", "Woman", "WOMAN"].forEach(v => set.add(v));
  return Array.from(set);
}

async function countQuery(q) {
  const snap = await q.count().get();
  return snap.data().count || 0;
}

async function main() {
  const input = process.argv[2] || "female";
  const vars = genderVariants(input);

  console.log(`Project: ${projectId}`);
  console.log(`genderToShow=${input} -> variants=${JSON.stringify(vars)}`);

  for (const g of vars) {
    const base = db.collection("users").where("gender", "==", g);

    const verified = await countQuery(
      base.where("dating.verificationStatus", "==", "verified")
    );

    const legacy = await countQuery(
      base.where("dating.verificationStatus", "==", null)
    );

    const sample = await base.limit(5).get();
    const hasCreatedAt = sample.docs.filter(d => d.data()?.createdAt != null).length;

    console.log(
      `gender="${g}": verified=${verified}, legacy(isNull)=${legacy}, sampleHasCreatedAt=${hasCreatedAt}/${sample.size}`
    );
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
