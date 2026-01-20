import admin from "firebase-admin";
import fs from "node:fs";

function usage() {
  console.log(
    "Usage:\n" +
      "  node tool/firestore_search_probe.mjs <male|female> <serviceAccountJsonPath>\n\n" +
      "Example:\n" +
      "  node tool/firestore_search_probe.mjs female ./serviceAccount.json\n"
  );
}

function cap(s) {
  if (!s) return s;
  return s[0].toUpperCase() + s.slice(1);
}

function genderVariants(genderToShow) {
  const raw = (genderToShow || "").trim();
  if (!raw) return [];
  const lower = raw.toLowerCase();

  const set = new Set([raw, lower, lower.toUpperCase(), cap(lower)]);
  if (lower === "male") ["man", "Man", "MAN"].forEach((v) => set.add(v));
  if (lower === "female") ["woman", "Woman", "WOMAN"].forEach((v) => set.add(v));

  return [...set].filter((v) => String(v).trim().length > 0);
}

function isDisabledUserDoc(data) {
  const accountStatus = String(data?.accountStatus ?? "").toLowerCase();
  if (accountStatus === "disabled") return true;

  const status = String(data?.status ?? "").toLowerCase();
  if (status === "disabled") return true;

  if (data?.disabled === true) return true;

  return false;
}

function isLegacyEligible(data) {
  const photos = data?.photos;
  const hasPhotos = Array.isArray(photos) && photos.length > 0;
  if (!hasPhotos) return false;

  const hasProfileCompletedOn = data?.profile_completed_on != null;

  const compatOk = data?.compatibility_setted === true;

  const reg = String(data?.registration_progress ?? "").toLowerCase();
  const regOk = reg === "completed";

  return hasProfileCompletedOn || (compatOk && regOk);
}

async function main() {
  const genderToShow = process.argv[2];
  const serviceAccountPath = process.argv[3];

  if (!genderToShow || !serviceAccountPath) {
    usage();
    process.exit(1);
  }
  if (!fs.existsSync(serviceAccountPath)) {
    console.error(`Service account file not found: ${serviceAccountPath}`);
    process.exit(1);
  }

  const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, "utf8"));

  if (!admin.apps.length) {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
  }

  const db = admin.firestore();

  const variants = genderVariants(genderToShow);
  console.log(`genderToShow=${genderToShow} -> variants=${JSON.stringify(variants)}`);

  const limit = 200; // increase if you want more coverage

  let v2VerifiedCount = 0;
  let legacyEligibleCount = 0;
  let legacyCandidatesSeen = 0;
  let disabledFiltered = 0;

  const v2VerifiedSamples = [];
  const legacyEligibleSamples = [];

  for (const g of variants) {
    // v2 verified query
    const v2Snap = await db
      .collection("users")
      .where("gender", "==", g)
      .where("dating.verificationStatus", "==", "verified")
      .limit(limit)
      .get();

    for (const doc of v2Snap.docs) {
      const data = doc.data() || {};
      if (isDisabledUserDoc(data)) {
        disabledFiltered += 1;
        continue;
      }
      v2VerifiedCount += 1;
      if (v2VerifiedSamples.length < 5) v2VerifiedSamples.push(doc.id);
    }

    // legacy candidates (gender-only), then filter in-memory
    const legacySnap = await db
      .collection("users")
      .where("gender", "==", g)
      .limit(limit)
      .get();

    legacyCandidatesSeen += legacySnap.size;

    for (const doc of legacySnap.docs) {
      const data = doc.data() || {};
      if (isDisabledUserDoc(data)) {
        disabledFiltered += 1;
        continue;
      }

      const dating = data?.dating;
      const status = (dating && typeof dating === "object" ? String(dating.verificationStatus ?? "") : "").toLowerCase().trim();

      // skip v2 verified here to avoid double counting
      if (status === "verified") continue;

      if (isLegacyEligible(data)) {
        legacyEligibleCount += 1;
        if (legacyEligibleSamples.length < 5) legacyEligibleSamples.push(doc.id);
      }
    }
  }

  console.log("\n=== Summary ===");
  console.log("v2 verified count:", v2VerifiedCount);
  console.log("legacy candidates seen (gender-only):", legacyCandidatesSeen);
  console.log("legacy eligible count (v1 heuristic):", legacyEligibleCount);
  console.log("disabled filtered:", disabledFiltered);

  console.log("\nSamples:");
  console.log("v2 verified sample uids:", v2VerifiedSamples);
  console.log("legacy eligible sample uids:", legacyEligibleSamples);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
