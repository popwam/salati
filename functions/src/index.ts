import * as admin from "firebase-admin";
import {google} from "googleapis";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";

admin.initializeApp();

const bootstrapAdminSecret = defineSecret("BOOTSTRAP_ADMIN_SECRET");

const quranAssetsCollectionPath = "content/quran_assets/items";
const adhanSoundsCollectionPath = "content/adhan_sounds/items";
const hadithPacksCollectionPath = "content/hadith_packs/packs";
const lessonMediaCollectionPath = "content/lesson_media/items";
const halaqaRoomsCollectionPath = "content/halaqat/rooms";

type PurchasePlatform = "android" | "ios";

interface VerifyPurchaseInput {
  platform: PurchasePlatform;
  purchaseToken: string;
  productId: string;
}

interface VerificationSuccess {
  transactionId?: string;
  expiresAt?: number;
  rawStatus?: string | number;
}

type PointsSource = "prayer" | "adhkar" | "dua" | "qiyam";
type PrayerAwardStatus = "onTime" | "late" | "missed" | "completed";

interface AwardPointsInput {
  source: PointsSource;
  eventId: string;
  status?: PrayerAwardStatus;
  dateKey: string;
  prayerName?: string;
  title?: string;
}

interface PlanPointsRule {
  prayerOnTime: number;
  prayerLate: number;
  prayerMissed: number;
  adhkarCompletion: number;
  duaCompletion: number;
  qiyamCompletion: number;
}

interface AwardPointsResult {
  awarded: boolean;
  amount: number;
  before: number;
  after: number;
  ledgerId: string;
  duplicate: boolean;
  message: string;
}

const defaultPointsRules: Record<string, PlanPointsRule> = {
  free: {
    prayerOnTime: 10,
    prayerLate: 5,
    prayerMissed: -1,
    adhkarCompletion: 10,
    duaCompletion: 10,
    qiyamCompletion: 50,
  },
  plus: {
    prayerOnTime: 20,
    prayerLate: 5,
    prayerMissed: -1,
    adhkarCompletion: 15,
    duaCompletion: 15,
    qiyamCompletion: 50,
  },
  pro: {
    prayerOnTime: 20,
    prayerLate: 5,
    prayerMissed: -1,
    adhkarCompletion: 15,
    duaCompletion: 15,
    qiyamCompletion: 50,
  },
};

export const setAdminClaim = onDocumentWritten("users/{uid}", async (event) => {
  const uid = event.params.uid;
  const role = event.data?.after.data()?.role;

  if (role === "admin" || role === "superAdmin" || role === "super_admin") {
    await admin.auth().setCustomUserClaims(uid, {
      role: role === "super_admin" ? "superAdmin" : role,
    });
    return;
  }

  await clearRoleClaim(uid);
});

export const verifyAdminClaim = onCall((request) => {
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "You must be signed in to read custom claims.",
    );
  }

  return {
    uid: request.auth.uid,
    claims: request.auth.token,
  };
});

export const verifyPurchase = onCall(async (request) => {
  const auth = request.auth;
  const uid = auth?.uid;
  if (!uid || !auth) {
    throw new HttpsError(
      "unauthenticated",
      "You must be signed in to verify a purchase.",
    );
  }

  const input = parseInput(request.data);
  const verification = input.platform === "android" ?
    await verifyAndroidPurchase(input) :
    await verifyIosPurchase(input);

  await admin
    .firestore()
    .collection("users")
    .doc(uid)
    .collection("entitlements")
    .doc(input.productId)
    .set(
      {
        featureKey: input.productId,
        enabled: true,
        source: "in_app_purchase",
        platform: input.platform,
        productId: input.productId,
        transactionId: verification.transactionId ?? null,
        expiresAt: verification.expiresAt ?
          admin.firestore.Timestamp.fromMillis(verification.expiresAt) :
          null,
        rawStatus: verification.rawStatus ?? null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
    );

  return {success: true};
});

export const awardPoints = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError(
      "unauthenticated",
      "You must be signed in to receive points.",
    );
  }

  const input = parseAwardPointsInput(request.data);
  const ledgerId = ledgerIdForAward(input);
  const db = admin.firestore();
  const userRef = db.collection("users").doc(uid);
  const ledgerRef = userRef.collection("points_ledger").doc(ledgerId);

  return await db.runTransaction(async (transaction) => {
    const existingLedger = await transaction.get(ledgerRef);
    if (existingLedger.exists) {
      const data = existingLedger.data() ?? {};
      const amount = numberFromValue(data.amount) ?? 0;
      const signedAmount = data.type === "spend" ? -amount : amount;
      const before = numberFromValue(data.before) ?? 0;
      const after = numberFromValue(data.after) ?? before;
      return {
        awarded: false,
        amount: signedAmount,
        before,
        after,
        ledgerId,
        duplicate: true,
        message: "Points were already awarded for this event.",
      };
    }

    const userSnapshot = await transaction.get(userRef);
    if (!userSnapshot.exists) {
      throw new HttpsError("failed-precondition", "User profile is missing.");
    }

    const userData = userSnapshot.data() ?? {};
    const planId = normalizedPlanId(
      stringFromValue(userData.planId) ?? stringFromValue(userData.plan),
    );
    const rules = await loadPointsRules(transaction, db);
    const amount = pointsForAward(rules[planId] ?? rules.free, input);
    if (amount === 0) {
      return {
        awarded: false,
        amount,
        before: pointBalance(userData.points),
        after: pointBalance(userData.points),
        ledgerId,
        duplicate: false,
        message: "No points configured for this event.",
      };
    }

    const before = pointBalance(userData.points);
    const after = Math.max(0, before + amount);
    transaction.set(
      userRef,
      {
        points: after,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        pointsUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
    transaction.set(ledgerRef, {
      type: amount < 0 ? "spend" : "earn",
      amount: Math.abs(amount),
      reason: ledgerId,
      before,
      after,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      awarded: true,
      amount,
      before,
      after,
      ledgerId,
      duplicate: false,
      message: "Points awarded.",
    };
  }) as AwardPointsResult;
});

export const bootstrapFirstAdmin = onCall({
  secrets: [bootstrapAdminSecret],
}, async (request) => {
  const auth = request.auth;
  const uid = auth?.uid;
  if (!uid || !auth) {
    throw new HttpsError(
      "unauthenticated",
      "You must be signed in to bootstrap the first admin.",
    );
  }

  const payload = requireRecord(request.data, "Missing bootstrap payload.");
  rejectUnknownFields(payload, ["secret"]);
  const providedSecret = requireString(payload.secret, "secret", 12, 256);
  const expectedSecret = bootstrapAdminSecret.value();
  if (!expectedSecret || expectedSecret.length < 12) {
    throw new HttpsError(
      "failed-precondition",
      "Bootstrap admin secret is not configured.",
    );
  }
  if (providedSecret !== expectedSecret) {
    throw new HttpsError("permission-denied", "Invalid bootstrap secret.");
  }

  const db = admin.firestore();
  const superAdminSnapshot = await db
    .collection("users")
    .where("role", "in", ["superAdmin", "super_admin"])
    .limit(1)
    .get();
  if (!superAdminSnapshot.empty) {
    throw new HttpsError(
      "failed-precondition",
      "A super admin already exists.",
    );
  }

  const permissions = [
    "dashboard.view",
  ];
  const userRef = db.collection("users").doc(uid);
  const email = typeof auth.token.email === "string" ?
    auth.token.email :
    null;

  const result = await db.runTransaction(async (transaction) => {
    const beforeSnapshot = await transaction.get(userRef);
    const existing = beforeSnapshot.data() ?? {};
    const now = admin.firestore.FieldValue.serverTimestamp();
    const after = {
      ...existing,
      uid,
      email: email ?? existing.email ?? null,
      role: "superAdmin",
      isAdmin: true,
      permissions,
      planId: existing.planId ?? "free",
      plan: existing.plan ?? "free",
      subscriptionStatus: existing.subscriptionStatus ?? "active",
      points: existing.points ?? 0,
      isBlocked: false,
      createdAt: beforeSnapshot.exists && existing.createdAt ?
        existing.createdAt :
        now,
      updatedAt: now,
    };

    transaction.set(userRef, after, {merge: true});
    return {
      before: beforeSnapshot.data() ?? {},
      after: {
        uid,
        email: email ?? existing.email ?? null,
        role: "superAdmin",
        isAdmin: true,
        permissions,
        planId: after.planId,
        plan: after.plan,
        subscriptionStatus: after.subscriptionStatus,
        points: after.points,
        isBlocked: false,
      },
    };
  });

  await writeAdminAuditLog({
    uid,
    action: "bootstrap_first_admin",
    targetPath: `users/${uid}`,
    before: result.before,
    after: result.after,
  });

  return {
    ok: true,
    uid,
    email,
    role: "superAdmin",
  };
});

export const saveAdhkarCategory = onCall(async (request) => {
  const context = await requireAdminContext(request.auth?.uid, [
    "dashboard.view",
  ]);
  return saveAdminDocument({
    context,
    data: request.data,
    collectionPath: "content/adhkar/categories",
    idField: "categoryId",
    allowedFields: contentCategoryFields,
    action: "save_adhkar_category",
  });
});

export const saveAdhkarItem = onCall(async (request) => {
  const context = await requireAdminContext(request.auth?.uid, [
    "dashboard.view",
  ]);
  const payload = requireRecord(request.data, "Missing adhkar item payload.");
  const categoryId = safeDocumentId(payload.categoryId, "categoryId");
  return saveAdminDocument({
    context,
    data: payload,
    collectionPath: `content/adhkar/categories/${categoryId}/items`,
    idField: "itemId",
    allowedFields: contentItemFields,
    action: "save_adhkar_item",
    extraReservedFields: ["categoryId"],
  });
});

export const saveDuaCategory = onCall(async (request) => {
  const context = await requireAdminContext(request.auth?.uid, [
    "dashboard.view",
  ]);
  return saveAdminDocument({
    context,
    data: request.data,
    collectionPath: "content/dua/categories",
    idField: "categoryId",
    allowedFields: contentCategoryFields,
    action: "save_dua_category",
  });
});

export const saveDuaItem = onCall(async (request) => {
  const context = await requireAdminContext(request.auth?.uid, [
    "dashboard.view",
  ]);
  const payload = requireRecord(request.data, "Missing dua item payload.");
  const categoryId = safeDocumentId(payload.categoryId, "categoryId");
  return saveAdminDocument({
    context,
    data: payload,
    collectionPath: `content/dua/categories/${categoryId}/items`,
    idField: "itemId",
    allowedFields: contentItemFields,
    action: "save_dua_item",
    extraReservedFields: ["categoryId"],
  });
});

export const saveStoreItem = onCall(async (request) => {
  const context = await requireAdminContext(request.auth?.uid, [
    "dashboard.view",
  ]);
  const payload = enrichStorePayload(requireRecord(
    request.data,
    "Missing store item payload.",
  ));
  return saveAdminDocument({
    context,
    data: payload,
    collectionPath: "store_items",
    idField: "itemId",
    allowedFields: storeItemFields,
    action: "save_store_item",
    validator: validateStoreItemPayload,
  });
});

export const savePlan = onCall(async (request) => {
  const context = await requireAdminContext(request.auth?.uid, [
    "dashboard.view",
  ]);
  const payload = requireRecord(request.data, "Missing plan payload.");
  const planId = safeDocumentId(payload.planId, "planId");
  if (!["free", "plus", "pro"].includes(planId)) {
    throw new HttpsError("invalid-argument", "planId must be free, plus, or pro.");
  }
  return saveAdminDocument({
    context,
    data: payload,
    collectionPath: "plans",
    idField: "planId",
    allowedFields: planFields,
    action: "save_plan",
    fixedId: planId,
  });
});

export const saveAppConfigDraft = onCall(async (request) => {
  const context = await requireAdminContext(request.auth?.uid, [
    "dashboard.view",
  ]);
  const payload = requireRecord(request.data, "Missing app config payload.");
  rejectUnknownFields(payload, appConfigFields);
  const cleaned = sanitizePayload(payload, appConfigFields);
  cleaned.status = "draft";
  const db = admin.firestore();
  const ref = db.collection("remote_app_config").doc("draft");
  const before = await ref.get();
  await ref.set(
    {
      ...cleaned,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: before.exists ?
        before.data()?.createdAt ?? admin.firestore.FieldValue.serverTimestamp() :
        admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
  await writeAdminAuditLog({
    uid: context.uid,
    action: "save_app_config_draft",
    targetPath: "remote_app_config/draft",
    before: before.data() ?? {},
    after: cleaned,
  });
  return {success: true, id: "draft"};
});

export const publishAppConfig = onCall(async (request) => {
  rejectUnknownFields(requireRecord(request.data ?? {}, "Invalid payload."), []);
  const context = await requireAdminContext(request.auth?.uid, [
    "dashboard.view",
  ]);
  const db = admin.firestore();
  const draftRef = db.collection("remote_app_config").doc("draft");
  const publishedRef = db.collection("remote_app_config").doc("published");
  const settingsRef = db.collection("settings").doc("app_config");
  const draft = await draftRef.get();
  if (!draft.exists) {
    throw new HttpsError("failed-precondition", "Draft app config is missing.");
  }
  const publishedBefore = await publishedRef.get();
  const data = sanitizePayload(draft.data() ?? {}, appConfigFields);
  data.status = "published";
  const writeData = {
    ...data,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    publishedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  await db.runTransaction(async (transaction) => {
    transaction.set(publishedRef, writeData, {merge: true});
    transaction.set(settingsRef, writeData, {merge: true});
  });
  await writeAdminAuditLog({
    uid: context.uid,
    action: "publish_app_config",
    targetPath: "remote_app_config/published",
    before: publishedBefore.data() ?? {},
    after: data,
  });
  return {success: true, id: "published"};
});

export const saveQuranAsset = onCall(async (request) => {
  const context = await requireAdminContext(request.auth?.uid, [
    "dashboard.view",
  ]);
  return saveAdminDocument({
    context,
    data: request.data,
    collectionPath: quranAssetsCollectionPath,
    idField: "assetId",
    allowedFields: quranAssetFields,
    action: "save_quran_asset",
    validator: validateQuranAssetPayload,
  });
});

export const saveQuranManifest = onCall(async (request) => {
  const context = await requireAdminContext(request.auth?.uid, [
    "dashboard.view",
  ]);
  const payload = validateQuranManifestPayload(request.data);
  const db = admin.firestore();
  const assetId = payload.assetId;
  const ref = db.collection(quranAssetsCollectionPath).doc(assetId);
  const before = await ref.get();
  const now = admin.firestore.FieldValue.serverTimestamp();
  const pageMap = payload.pageMap;
  const summary = {
    pageCount: pageMap.length,
    firstPage: pageMap[0]?.page ?? payload.pageStart,
    lastPage: pageMap[pageMap.length - 1]?.page ?? payload.pageEnd,
    missingPages: payload.missingPages,
  };
  await ref.set(
    {
      type: "mushaf_pack",
      titleAr: payload.titleAr,
      titleEn: payload.titleEn,
      titleFr: payload.titleFr,
      pricePoints: payload.pricePoints,
      assetKind: payload.assetKind,
      pagesBaseUrl: payload.pagesBaseUrl,
      pageFilePattern: payload.pageFilePattern,
      pageStart: payload.pageStart,
      pageEnd: payload.pageEnd,
      pageMapSummary: summary,
      runtimeSupportStatus: "metadata_ready",
      isActive: payload.active,
      updatedAt: now,
      createdAt: before.exists ?
        before.data()?.createdAt ?? now :
        now,
    },
    {merge: true},
  );

  await deleteSmallCollection(ref.collection("page_map"), 700);
  await writeDocumentsInChunks(
    pageMap.map((page) => ({
      ref: ref.collection("page_map").doc(`${page.page}`.padStart(3, "0")),
      data: {
        ...page,
        updatedAt: now,
        createdAt: now,
      },
    })),
  );
  await writeAdminAuditLog({
    uid: context.uid,
    action: "save_quran_manifest",
    targetPath: `${quranAssetsCollectionPath}/${assetId}`,
    before: before.data() ?? {},
    after: {assetId, ...summary},
  });
  return {success: true, id: assetId, ...summary};
});

export const saveAdhanSound = onCall(async (request) => {
  const context = await requireAdminContext(request.auth?.uid, [
    "dashboard.view",
  ]);
  return saveAdminDocument({
    context,
    data: request.data,
    collectionPath: adhanSoundsCollectionPath,
    idField: "soundId",
    allowedFields: adhanSoundFields,
    action: "save_adhan_sound",
    validator: validateAdhanSoundPayload,
  });
});

export const importHadithPack = onCall(async (request) => {
  const context = await requireAdminContext(request.auth?.uid, [
    "dashboard.view",
  ]);
  const payload = validateHadithPackPayload(request.data);
  const db = admin.firestore();
  const packRef = db.collection(hadithPacksCollectionPath).doc(payload.packId);
  const before = await packRef.get();
  const now = admin.firestore.FieldValue.serverTimestamp();
  await packRef.set(
    {
      titleAr: payload.titleAr,
      titleEn: payload.titleEn,
      titleFr: payload.titleFr,
      pricePoints: payload.pricePoints,
      isActive: payload.active,
      itemCount: payload.items.length,
      updatedAt: now,
      createdAt: before.exists ?
        before.data()?.createdAt ?? now :
        now,
    },
    {merge: true},
  );
  await deleteSmallCollection(packRef.collection("items"), 700);
  await writeDocumentsInChunks(
    payload.items.map((item, index) => {
      const itemId = requireString(item.itemId, "itemId", 1, 80);
      return {
        ref: packRef.collection("items").doc(itemId),
        data: {
          ...item,
          order: index,
          updatedAt: now,
          createdAt: now,
        },
      };
    }),
  );
  await writeAdminAuditLog({
    uid: context.uid,
    action: "import_hadith_pack",
    targetPath: `${hadithPacksCollectionPath}/${payload.packId}`,
    before: before.data() ?? {},
    after: {packId: payload.packId, itemCount: payload.items.length},
  });
  return {success: true, id: payload.packId, itemCount: payload.items.length};
});

export const saveLessonMedia = onCall(async (request) => {
  const context = await requireAdminContext(request.auth?.uid, [
    "dashboard.view",
  ]);
  return saveAdminDocument({
    context,
    data: request.data,
    collectionPath: lessonMediaCollectionPath,
    idField: "lessonId",
    allowedFields: lessonMediaFields,
    action: "save_lesson_media",
    validator: validateLessonMediaPayload,
  });
});

export const saveHalaqaRoomMetadata = onCall(async (request) => {
  const context = await requireAdminContext(request.auth?.uid, [
    "dashboard.view",
  ]);
  return saveAdminDocument({
    context,
    data: request.data,
    collectionPath: halaqaRoomsCollectionPath,
    idField: "roomId",
    allowedFields: halaqaRoomFields,
    action: "save_halaqa_room_metadata",
    validator: validateHalaqaRoomPayload,
  });
});

export const searchDashboardUsersForHost = onCall(async (request) => {
  await requireAdminContext(request.auth?.uid, ["dashboard.view"]);
  const payload = requireRecord(request.data ?? {}, "Invalid search payload.");
  rejectUnknownFields(payload, ["query", "limit"]);
  const query = requireString(payload.query, "query", 1, 120).toLowerCase();
  const limit = Math.min(Math.max(intFromValue(payload.limit) ?? 10, 1), 20);
  const db = admin.firestore();
  const results = new Map<string, Record<string, unknown>>();

  const direct = await db.collection("users").doc(query).get();
  if (direct.exists) {
    results.set(direct.id, userSearchResult(direct.id, direct.data() ?? {}));
  }

  for (const field of ["email", "phone", "name", "displayName"]) {
    const snapshot = await db.collection("users")
      .where(field, "==", query)
      .limit(limit)
      .get();
    for (const doc of snapshot.docs) {
      results.set(doc.id, userSearchResult(doc.id, doc.data()));
    }
  }

  return {
    success: true,
    users: [...results.values()].slice(0, limit),
  };
});

export const updateDashboardUserStatus = onCall(async (request) => {
  const context = await requireAdminContext(request.auth?.uid, [
    "dashboard.view",
  ]);
  const payload = requireRecord(request.data ?? {}, "Invalid user status payload.");
  rejectUnknownFields(payload, ["uid", "isBlocked"]);
  const targetUid = requireString(payload.uid, "uid", 1, 160);
  const isBlocked = payload.isBlocked === true;
  if (targetUid === context.uid && isBlocked) {
    throw new HttpsError("failed-precondition", "You cannot block your own account.");
  }

  const db = admin.firestore();
  const targetRef = db.collection("users").doc(targetUid);
  const before = await targetRef.get();
  if (!before.exists) {
    throw new HttpsError("not-found", "User profile was not found.");
  }

  const beforeData = before.data() ?? {};
  const targetRole = stringFromValue(beforeData.role) ?? "user";
  const targetIsSuperAdmin = targetRole === "superAdmin" ||
    targetRole === "super_admin";
  const callerIsSuperAdmin = context.role === "superAdmin" ||
    context.role === "super_admin";
  if (targetIsSuperAdmin && !callerIsSuperAdmin) {
    throw new HttpsError(
      "permission-denied",
      "Only superAdmin can change a superAdmin account.",
    );
  }

  await targetRef.set(
    {
      isBlocked,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
  await writeAdminAuditLog({
    uid: context.uid,
    action: "update_user_status",
    targetPath: `users/${targetUid}`,
    before: {isBlocked: beforeData.isBlocked === true},
    after: {isBlocked},
  });
  return {success: true, uid: targetUid, isBlocked};
});

export const listAdminAuditLogs = onCall(async (request) => {
  await requireAdminContext(request.auth?.uid, ["dashboard.view"]);
  const payload = requireRecord(request.data ?? {}, "Invalid audit log payload.");
  rejectUnknownFields(payload, ["limit"]);
  const limit = Math.min(Math.max(intFromValue(payload.limit) ?? 20, 1), 100);
  const snapshot = await admin.firestore()
    .collection("admin_audit_logs")
    .orderBy("createdAt", "desc")
    .limit(limit)
    .get();
  return {
    success: true,
    logs: snapshot.docs.map((doc) => ({id: doc.id, ...doc.data()})),
  };
});

export const redeemStoreItemWithPoints = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError(
      "unauthenticated",
      "You must be signed in to redeem store items.",
    );
  }

  const payload = requireRecord(request.data ?? {}, "Invalid store payload.");
  rejectUnknownFields(payload, ["itemId"]);
  const itemId = safeDocumentId(payload.itemId, "itemId");
  const db = admin.firestore();
  const userRef = db.collection("users").doc(uid);
  const itemRef = db.collection("store_items").doc(itemId);
  const entitlementRef = userRef.collection("entitlements").doc(itemId);
  const ledgerRef = userRef.collection("points_ledger").doc(`store_${itemId}`);

  return await db.runTransaction(async (transaction) => {
    const [userSnapshot, itemSnapshot, entitlementSnapshot] =
      await Promise.all([
        transaction.get(userRef),
        transaction.get(itemRef),
        transaction.get(entitlementRef),
      ]);

    if (!userSnapshot.exists) {
      throw new HttpsError("failed-precondition", "User profile is missing.");
    }
    if (!itemSnapshot.exists) {
      throw new HttpsError("not-found", "Store item was not found.");
    }

    const item = itemSnapshot.data() ?? {};
    if (item.isActive === false || item.active === false) {
      throw new HttpsError("failed-precondition", "Store item is not active.");
    }

    const pricePoints = intFromValue(item.pricePoints) ?? 0;
    if (pricePoints <= 0) {
      return {
        success: true,
        remainingPoints: pointBalance(userSnapshot.data()?.points),
        message: "Free item is already available.",
        entitlementId: itemId,
      };
    }

    const existingEntitlement = entitlementSnapshot.data();
    if (existingEntitlement?.enabled === true) {
      return {
        success: true,
        remainingPoints: pointBalance(userSnapshot.data()?.points),
        message: "Store item is already unlocked.",
        entitlementId: itemId,
      };
    }

    const userData = userSnapshot.data() ?? {};
    const before = pointBalance(userData.points);
    if (before < pricePoints) {
      throw new HttpsError(
        "failed-precondition",
        `Insufficient points. Current balance ${before}, required ${pricePoints}.`,
      );
    }

    const after = before - pricePoints;
    const now = admin.firestore.FieldValue.serverTimestamp();
    const featureKey = featureKeyForStoreItem(itemId, item);
    const title = stringFromValue(item.titleAr) ??
      stringFromValue(item.titleEn) ??
      stringFromValue(item.title) ??
      itemId;

    transaction.set(userRef, {
      points: after,
      updatedAt: now,
      pointsUpdatedAt: now,
    }, {merge: true});
    transaction.set(ledgerRef, {
      type: "spend",
      amount: pricePoints,
      reason: `store:${itemId}`,
      storeItemId: itemId,
      featureKey,
      before,
      after,
      createdAt: now,
    });
    transaction.set(entitlementRef, {
      featureKey,
      enabled: true,
      source: "points_store",
      storeItemId: itemId,
      title,
      description: stringFromValue(item.descriptionAr) ??
        stringFromValue(item.descriptionEn) ??
        stringFromValue(item.description) ??
        null,
      assetKind: stringFromValue(item.assetKind) ?? null,
      assetUrl: stringFromValue(item.assetUrl) ??
        stringFromValue(item.previewUrl) ??
        null,
      unlockKey: stringFromValue(item.unlockKey) ?? null,
      metadata: isRecord(item.metadata) ? item.metadata : {},
      pricePoints,
      updatedAt: now,
      createdAt: now,
    }, {merge: true});

    return {
      success: true,
      remainingPoints: after,
      message: `Redeemed ${title} for ${pricePoints} points.`,
      entitlementId: itemId,
      featureKey,
    };
  });
});

const contentCategoryFields = [
  "titleAr",
  "titleEn",
  "titleFr",
  "descriptionAr",
  "descriptionEn",
  "descriptionFr",
  "icon",
  "active",
  "isActive",
  "order",
  "accessPlan",
  "translations",
];

const contentItemFields = [
  "titleAr",
  "titleEn",
  "titleFr",
  "textAr",
  "textEn",
  "textFr",
  "source",
  "repeatCount",
  "active",
  "isActive",
  "order",
  "accessPlan",
  "translations",
];

const storeItemFields = [
  "type",
  "title",
  "titleAr",
  "titleEn",
  "titleFr",
  "description",
  "descriptionAr",
  "descriptionEn",
  "descriptionFr",
  "previewUrl",
  "value",
  "assetKind",
  "assetUrl",
  "unlockKey",
  "metadata",
  "theme",
  "pricePoints",
  "requiredPlan",
  "active",
  "isActive",
];

const planFields = [
  "title",
  "name",
  "priceMonthly",
  "priceYearly",
  "priceLabel",
  "aiDailyLimit",
  "maxFavorites",
  "maxReflections",
  "allowQuranAyahMode",
  "allowQuranWordMode",
  "allowQuranAi",
  "allowPremiumThemes",
  "maxCustomDhikrCategories",
  "maxCustomDhikrItemsPerCategory",
  "maxCustomDuaCategories",
  "maxCustomDuaItemsPerCategory",
  "isActive",
  "active",
  "sortOrder",
];

const appConfigFields = [
  "status",
  "homeCardOrder",
  "hiddenHomeSections",
  "onboardingTitle",
  "onboardingBody",
  "paywallTitle",
  "paywallBody",
  "globalMessage",
  "themeName",
  "primaryColorHex",
  "secondaryColorHex",
  "backgroundColorHex",
  "surfaceColorHex",
  "textColorHex",
  "defaultWidgetStyle",
  "availableAiTokens",
  "themePalette",
  "featureFlags",
  "pointsRules",
  "quranLimits",
  "defaultUserPlanId",
];

const quranAssetFields = [
  "type",
  "titleAr",
  "titleEn",
  "titleFr",
  "descriptionAr",
  "descriptionEn",
  "descriptionFr",
  "assetKind",
  "fontFamily",
  "fontAssetPath",
  "fontUrl",
  "pagesBaseUrl",
  "pageFilePattern",
  "pageStart",
  "pageEnd",
  "pageMapSummary",
  "runtimeSupportStatus",
  "metadataUrl",
  "manifestUrl",
  "manifestJson",
  "zipUrl",
  "coverImageUrl",
  "reciterName",
  "audioManifestUrl",
  "audioManifestJson",
  "audioBaseUrl",
  "surahFilePattern",
  "surahStart",
  "surahEnd",
  "license",
  "pricePoints",
  "requiredPlan",
  "active",
  "isActive",
];

const adhanSoundFields = [
  "type",
  "titleAr",
  "titleEn",
  "titleFr",
  "descriptionAr",
  "descriptionEn",
  "descriptionFr",
  "assetKind",
  "rawResourceName",
  "audioUrl",
  "imageUrl",
  "mimeType",
  "durationSeconds",
  "previewEnabled",
  "pricePoints",
  "requiredPlan",
  "active",
  "isActive",
];

const lessonMediaFields = [
  "type",
  "titleAr",
  "titleEn",
  "titleFr",
  "descriptionAr",
  "descriptionEn",
  "descriptionFr",
  "pricePoints",
  "categoryId",
  "categoryTitleAr",
  "categoryTitleEn",
  "categoryTitleFr",
  "sheikhName",
  "icon",
  "imageUrl",
  "mediaKind",
  "mediaUrl",
  "storagePath",
  "durationSeconds",
  "active",
  "isActive",
];

const halaqaRoomFields = [
  "title",
  "titleAr",
  "roomCode",
  "hostUid",
  "hostName",
  "hostEmail",
  "status",
  "mode",
  "scheduledAt",
  "durationMinutes",
  "maxActiveReaders",
  "activeReadersCount",
  "listenerCount",
  "pricePoints",
  "recordingEnabled",
  "videoEnabled",
  "active",
  "isActive",
];

interface AdminContext {
  uid: string;
  role: string;
  permissions: Set<string>;
}

interface SaveAdminDocumentOptions {
  context: AdminContext;
  data: unknown;
  collectionPath: string;
  idField: string;
  allowedFields: string[];
  action: string;
  fixedId?: string;
  extraReservedFields?: string[];
  validator?: (payload: Record<string, unknown>) => void;
}

async function requireAdminContext(
  uid: string | undefined,
  requiredPermissions: string[],
): Promise<AdminContext> {
  void requiredPermissions;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Admin sign-in is required.");
  }
  const snapshot = await admin.firestore().collection("users").doc(uid).get();
  if (!snapshot.exists) {
    throw new HttpsError("permission-denied", "Admin user profile is missing.");
  }
  const data = snapshot.data() ?? {};
  const role = stringFromValue(data.role) ?? "user";
  const permissions = stringSetFromValue(data.permissions);
  const isAdmin = data.isAdmin === true;
  const isSuperAdmin = role === "superAdmin" || role === "super_admin";
  const hasDashboardEntry = role === "admin" ||
    isAdmin ||
    permissions.has("dashboard.view");
  const canAccess = isSuperAdmin ||
    hasDashboardEntry;
  if (!canAccess) {
    throw new HttpsError("permission-denied", "Admin permission is required.");
  }
  return {uid, role, permissions};
}

async function saveAdminDocument(
  options: SaveAdminDocumentOptions,
): Promise<Record<string, unknown>> {
  const payload = requireRecord(options.data, "Missing admin payload.");
  rejectUnknownFields(payload, [
    options.idField,
    ...(options.extraReservedFields ?? []),
    ...options.allowedFields,
  ]);
  options.validator?.(payload);
  const db = admin.firestore();
  ensureCollectionPath(options.collectionPath);
  const collection = db.collection(options.collectionPath);
  const id = options.fixedId ??
    optionalDocumentId(payload[options.idField], options.idField) ??
    collection.doc().id;
  const ref = collection.doc(id);
  const before = await ref.get();
  const cleaned = sanitizePayload(payload, options.allowedFields);
  normalizeActiveField(cleaned);
  await ref.set(
    {
      ...cleaned,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: before.exists ?
        before.data()?.createdAt ?? admin.firestore.FieldValue.serverTimestamp() :
        admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
  await writeAdminAuditLog({
    uid: options.context.uid,
    action: options.action,
    targetPath: `${options.collectionPath}/${id}`,
    before: before.data() ?? {},
    after: cleaned,
  });
  return {success: true, id};
}

function ensureCollectionPath(path: string): void {
  const segments = path.split("/").filter((segment) => segment.length > 0);
  if (segments.length % 2 === 0) {
    throw new HttpsError(
      "internal",
      `Invalid admin collection path: ${path}`,
    );
  }
}

function validateStoreItemPayload(payload: Record<string, unknown>): void {
  const type = stringFromValue(payload.type);
  if (type && ![
    "gift",
    "gift_card",
    "adhan",
    "adhan_sound",
    "theme",
    "font",
    "quran_font",
    "mushaf",
    "mushaf_pack",
    "widget",
    "widget_unlock",
    "other_reward",
  ].includes(type)) {
    throw new HttpsError("invalid-argument", "Unsupported store item type.");
  }
  if (type === "theme") {
    const theme = payload.theme;
    if (theme !== undefined) {
      validateThemePayload(theme);
    }
  }
  validateNonNegativeInt(payload.pricePoints, "pricePoints");
}

function enrichStorePayload(
  payload: Record<string, unknown>,
): Record<string, unknown> {
  const enriched = {...payload};
  const type = stringFromValue(enriched.type) ?? "other_reward";
  const title =
    stringFromValue(enriched.titleAr) ??
    stringFromValue(enriched.titleEn) ??
    stringFromValue(enriched.title) ??
    type;
  const value = stringFromValue(enriched.value) ?? slugFromTitle(title, type);
  enriched.value = value;
  if (!stringFromValue(enriched.unlockKey)) {
    enriched.unlockKey = unlockKeyForStoreItem(type, value);
  }
  if (!stringFromValue(enriched.assetKind)) {
    enriched.assetKind = defaultAssetKindForStoreItem(type);
  }
  return enriched;
}

function slugFromTitle(title: string, fallback: string): string {
  const slug = title
    .toLowerCase()
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/_+/g, "_")
    .replace(/^_|_$/g, "");
  return slug || `${fallback}_${Date.now()}`;
}

function unlockKeyForStoreItem(type: string, value: string): string {
  switch (type.trim().toLowerCase()) {
  case "widget":
  case "widget_unlock":
    return `widget.${value}`;
  case "theme":
    return `theme.${value}`;
  case "adhan":
  case "adhan_sound":
    return `adhan.${value}`;
  case "mushaf":
  case "mushaf_pack":
    return `mushaf.${value}`;
  case "quran_font":
    return `quran_font.${value}`;
  default:
    return value;
  }
}

function featureKeyForStoreItem(
  itemId: string,
  item: Record<string, unknown>,
): string {
  const normalizedType = (stringFromValue(item.type) ?? "reward")
    .trim()
    .toLowerCase();
  const value = stringFromValue(item.value) ?? itemId;
  switch (normalizedType) {
  case "theme":
    return `theme:${value}`;
  case "adhan_sound":
  case "adhan":
    return `adhan:${value}`;
  case "widget_unlock":
  case "widget":
    return `widget:${value}`;
  case "mushaf_pack":
  case "mushaf":
    return `mushaf:${value}`;
  case "font":
    return `font:${value}`;
  case "quran_font":
    return `quran_font:${value}`;
  case "calendar":
    return `calendar:${value}`;
  case "gift_card":
    return `gift_card:${value}`;
  case "paid_feature":
    return `paid_feature:${value}`;
  case "pro_trial":
    return `pro_trial:${value}`;
  default:
    return `${normalizedType}:${value}`;
  }
}

function defaultAssetKindForStoreItem(type: string): string {
  switch (type.trim().toLowerCase()) {
  case "theme":
    return "theme_hex_palette";
  case "quran_font":
  case "mushaf":
  case "mushaf_pack":
    return "metadata_only";
  case "adhan":
  case "adhan_sound":
    return "bundled_raw";
  case "widget":
  case "widget_unlock":
    return "widget_unlock";
  default:
    return "metadata_only";
  }
}

function validateThemePayload(value: unknown): void {
  const theme = requireRecord(value, "theme must be an object.");
  const colorFields = [
    "primaryColor",
    "secondaryColor",
    "backgroundColor",
    "surfaceColor",
    "textColor",
  ];
  for (const field of colorFields) {
    const color = stringFromValue(theme[field]);
    if (color && !/^#[0-9a-fA-F]{6}$/.test(color)) {
      throw new HttpsError("invalid-argument", `${field} must be #RRGGBB.`);
    }
  }
}

function validateQuranAssetPayload(payload: Record<string, unknown>): void {
  const type = stringFromValue(payload.type);
  if (type && !["quran_font", "mushaf_pack", "audio_mushaf"].includes(type)) {
    throw new HttpsError("invalid-argument", "Unsupported Quran asset type.");
  }
  const assetKind = stringFromValue(payload.assetKind);
  if (assetKind && ![
    "bundled_font",
    "remote_font",
    "remote_pages",
    "metadata_only",
    "remote_audio",
  ].includes(assetKind)) {
    throw new HttpsError("invalid-argument", "Unsupported Quran asset kind.");
  }
  validateNonNegativeInt(payload.pricePoints, "pricePoints");
}

function validateAdhanSoundPayload(payload: Record<string, unknown>): void {
  const type = stringFromValue(payload.type);
  if (type && type !== "adhan_sound") {
    throw new HttpsError("invalid-argument", "type must be adhan_sound.");
  }
  const assetKind = stringFromValue(payload.assetKind);
  if (assetKind && !["bundled_raw", "remote_audio"].includes(assetKind)) {
    throw new HttpsError("invalid-argument", "Unsupported adhan asset kind.");
  }
  validateNonNegativeInt(payload.pricePoints, "pricePoints");
  validateNonNegativeInt(payload.durationSeconds, "durationSeconds");
}

function validateLessonMediaPayload(payload: Record<string, unknown>): void {
  const type = stringFromValue(payload.type);
  if (type && !["lesson", "nasheed"].includes(type)) {
    throw new HttpsError("invalid-argument", "type must be lesson or nasheed.");
  }
  const hasTitle = [
    payload.titleAr,
    payload.titleEn,
    payload.titleFr,
  ].some((value) => stringFromValue(value) !== undefined);
  if (!hasTitle) {
    throw new HttpsError(
      "invalid-argument",
      "titleAr, titleEn, or titleFr is required.",
    );
  }
  const mediaKind = stringFromValue(payload.mediaKind);
  if (mediaKind !== "video" && mediaKind !== "audio") {
    throw new HttpsError("invalid-argument", "mediaKind must be video or audio.");
  }
  const mediaUrl = stringFromValue(payload.mediaUrl);
  const storagePath = stringFromValue(payload.storagePath);
  if (!mediaUrl && !storagePath) {
    throw new HttpsError(
      "invalid-argument",
      "mediaUrl or storagePath is required.",
    );
  }
  validateNonNegativeInt(payload.pricePoints, "pricePoints");
  validateNonNegativeInt(payload.durationSeconds, "durationSeconds");
}

function validateHalaqaRoomPayload(payload: Record<string, unknown>): void {
  requireString(payload.titleAr ?? payload.title, "title", 1, 180);
  safeDocumentId(payload.roomCode, "roomCode");
  safeDocumentId(payload.hostUid, "hostUid");
  const status = stringFromValue(payload.status) ?? "scheduled";
  if (!["scheduled", "live", "ended", "archived"].includes(status)) {
    throw new HttpsError("invalid-argument", "Unsupported room status.");
  }
  const mode = stringFromValue(payload.mode) ?? "limited_session";
  if (!["limited_session", "24h_room"].includes(mode)) {
    throw new HttpsError("invalid-argument", "Unsupported room mode.");
  }
  const maxActiveReaders = intFromValue(payload.maxActiveReaders) ?? 20;
  if (maxActiveReaders < 1 || maxActiveReaders > 20) {
    throw new HttpsError(
      "invalid-argument",
      "maxActiveReaders must be between 1 and 20.",
    );
  }
  validateNonNegativeInt(payload.durationMinutes, "durationMinutes");
  validateNonNegativeInt(payload.activeReadersCount, "activeReadersCount");
  validateNonNegativeInt(payload.listenerCount, "listenerCount");
  if (payload.recordingEnabled === true || payload.videoEnabled === true) {
    throw new HttpsError(
      "invalid-argument",
      "Recording and video are not supported for halaqat rooms.",
    );
  }
}

function validateQuranManifestPayload(data: unknown): {
  assetId: string;
  titleAr: string;
  titleEn?: string;
  titleFr?: string;
  pricePoints: number;
  assetKind: string;
  pagesBaseUrl?: string;
  pageFilePattern: string;
  pageStart: number;
  pageEnd: number;
  active: boolean;
  pageMap: Record<string, unknown>[];
  missingPages: number[];
} {
  const payload = requireRecord(data, "Missing Quran manifest payload.");
  rejectUnknownFields(payload, [
    "id",
    "assetId",
    "nameAr",
    "nameEn",
    "nameFr",
    "titleAr",
    "titleEn",
    "titleFr",
    "pricePoints",
    "assetKind",
    "pagesBaseUrl",
    "pageFilePattern",
    "pageStart",
    "pageEnd",
    "pages",
    "active",
  ]);
  const assetId = safeDocumentId(payload.assetId ?? payload.id, "id");
  const titleAr = requireString(
    payload.titleAr ?? payload.nameAr,
    "nameAr",
    1,
    240,
  );
  const titleEn = stringFromValue(payload.titleEn) ??
    stringFromValue(payload.nameEn);
  const titleFr = stringFromValue(payload.titleFr) ??
    stringFromValue(payload.nameFr);
  const pricePoints = intFromValue(payload.pricePoints) ?? 0;
  if (pricePoints < 0) {
    throw new HttpsError("invalid-argument", "pricePoints must be >= 0.");
  }
  const assetKind = stringFromValue(payload.assetKind) ?? "remote_pages";
  if (!["remote_pages", "metadata_only"].includes(assetKind)) {
    throw new HttpsError("invalid-argument", "Unsupported Quran manifest kind.");
  }
  const pageFilePattern = stringFromValue(payload.pageFilePattern) ??
    "%03d.png";
  const pageStart = intFromValue(payload.pageStart) ?? 1;
  const pageEnd = intFromValue(payload.pageEnd) ?? pageStart;
  if (pageStart < 1 || pageEnd < pageStart || pageEnd > 10000) {
    throw new HttpsError("invalid-argument", "Invalid page range.");
  }
  const expectedPages = pageEnd - pageStart + 1;
  const rawPages = Array.isArray(payload.pages) ? payload.pages : [];
  if (rawPages.length > 1000) {
    throw new HttpsError("invalid-argument", "Too many Quran pages.");
  }
  const pageMap = rawPages.length > 0 ?
    rawPages.map((item) => normalizeQuranPage(item, pageFilePattern)) :
    Array.from({length: expectedPages}, (_, index) => {
      const page = pageStart + index;
      return {
        page,
        file: formatPageFile(pageFilePattern, page),
      };
    });
  const seen = new Set<number>();
  for (const page of pageMap) {
    const pageNumber = page.page as number;
    if (pageNumber < pageStart || pageNumber > pageEnd || seen.has(pageNumber)) {
      throw new HttpsError("invalid-argument", "Invalid Quran page sequence.");
    }
    seen.add(pageNumber);
  }
  const missingPages: number[] = [];
  for (let page = pageStart; page <= pageEnd; page += 1) {
    if (!seen.has(page)) {
      missingPages.push(page);
    }
  }
  return {
    assetId,
    titleAr,
    titleEn,
    titleFr,
    pricePoints,
    assetKind,
    pagesBaseUrl: stringFromValue(payload.pagesBaseUrl),
    pageFilePattern,
    pageStart,
    pageEnd,
    active: payload.active !== false,
    pageMap,
    missingPages,
  };
}

function normalizeQuranPage(
  value: unknown,
  pageFilePattern: string,
): Record<string, unknown> {
  const page = requireRecord(value, "Invalid page map item.");
  rejectUnknownFields(page, [
    "page",
    "file",
    "surahStart",
    "ayahStart",
    "surahEnd",
    "ayahEnd",
    "juz",
    "hizb",
    "url",
  ]);
  const pageNumber = intFromValue(page.page);
  if (pageNumber === undefined || pageNumber < 1) {
    throw new HttpsError("invalid-argument", "Invalid page number.");
  }
  const file = stringFromValue(page.file) ?? formatPageFile(
    pageFilePattern,
    pageNumber,
  );
  if (!/^[a-zA-Z0-9_.-]+\.(png|jpg|jpeg|webp)$/i.test(file)) {
    throw new HttpsError("invalid-argument", "Invalid Quran page file name.");
  }
  return sanitizePayload(
    {...page, page: pageNumber, file},
    [
      "page",
      "file",
      "surahStart",
      "ayahStart",
      "surahEnd",
      "ayahEnd",
      "juz",
      "hizb",
      "url",
    ],
  );
}

function validateHadithPackPayload(data: unknown): {
  packId: string;
  titleAr: string;
  titleEn?: string;
  titleFr?: string;
  pricePoints: number;
  active: boolean;
  items: Record<string, unknown>[];
} {
  const payload = requireRecord(data, "Missing hadith pack payload.");
  rejectUnknownFields(payload, [
    "id",
    "packId",
    "metadata",
    "chapters",
    "hadiths",
    "titleAr",
    "titleEn",
    "titleFr",
    "pricePoints",
    "active",
    "items",
  ]);
  const metadata = isRecord(payload.metadata) ? payload.metadata : {};
  const metadataArabic = isRecord(metadata.arabic) ? metadata.arabic : {};
  const metadataEnglish = isRecord(metadata.english) ? metadata.english : {};
  const packId = safeDocumentId(payload.packId ?? payload.id, "id");
  const titleAr = repairMojibake(
    requireString(
      payload.titleAr ?? metadataArabic.title,
      "titleAr",
      1,
      240,
    ),
  );
  const pricePoints = intFromValue(payload.pricePoints) ?? 0;
  if (pricePoints < 0) {
    throw new HttpsError("invalid-argument", "pricePoints must be >= 0.");
  }
  const rawItems = Array.isArray(payload.items) ?
    payload.items :
    Array.isArray(payload.hadiths) ?
    payload.hadiths :
    [];
  if (rawItems.length === 0) {
    throw new HttpsError("invalid-argument", "Hadith items are required.");
  }
  if (rawItems.length > 2000) {
    throw new HttpsError("invalid-argument", "Hadith pack limit is 2000 items.");
  }
  return {
    packId,
    titleAr,
    titleEn: stringFromValue(payload.titleEn) ??
      stringFromValue(metadataEnglish.title),
    titleFr: stringFromValue(payload.titleFr),
    pricePoints,
    active: payload.active !== false,
    items: rawItems.map(normalizeHadithItem),
  };
}

function normalizeHadithItem(value: unknown): Record<string, unknown> {
  const item = requireRecord(value, "Invalid hadith item.");
  rejectUnknownFields(item, [
    "id",
    "idInBook",
    "chapterId",
    "bookId",
    "hadithNumber",
    "arabic",
    "english",
    "french",
    "source",
    "grade",
  ]);
  const number = requireString(
    stringOrNumberFromValue(item.hadithNumber) ??
      stringOrNumberFromValue(item.idInBook) ??
      stringOrNumberFromValue(item.id),
    "hadithNumber",
    1,
    40,
  );
  const arabic = repairMojibake(requireString(item.arabic, "arabic", 1, 5000));
  const english = isRecord(item.english) ?
    stringFromValue(item.english.text) :
    stringFromValue(item.english);
  const narrator = isRecord(item.english) ?
    stringFromValue(item.english.narrator) :
    undefined;
  return sanitizePayload(
    {
      itemId: safeDocumentId(number.replace(/[^a-zA-Z0-9_-]/g, "_"), "itemId"),
      hadithNumber: number,
      arabic,
      english: english ?? "",
      french: stringFromValue(item.french) ?? "",
      source: stringFromValue(item.source) ?? "",
      grade: stringFromValue(item.grade) ?? "",
      narrator: narrator ?? "",
      chapterId: numberFromValue(item.chapterId) ?? null,
      bookId: numberFromValue(item.bookId) ?? null,
    },
    [
      "itemId",
      "hadithNumber",
      "arabic",
      "english",
      "french",
      "source",
      "grade",
      "narrator",
      "chapterId",
      "bookId",
    ],
  );
}

function formatPageFile(pattern: string, page: number): string {
  const padded = `${page}`.padStart(3, "0");
  return pattern
    .replace("%03d", padded)
    .replace("page_%03d", `page_${padded}`);
}

function repairMojibake(value: string): string {
  if (!/[\u00c3\u00d8\u00d9]/.test(value)) {
    return value;
  }
  try {
    const repaired = Buffer.from(value, "latin1").toString("utf8");
    return repaired.includes("\uFFFD") ? value : repaired;
  } catch {
    return value;
  }
}

function userSearchResult(
  uid: string,
  data: Record<string, unknown>,
): Record<string, unknown> {
  return {
    uid,
    name: stringFromValue(data.name) ??
      stringFromValue(data.displayName) ??
      "",
    email: stringFromValue(data.email) ?? "",
    phone: stringFromValue(data.phone) ?? "",
  };
}

async function deleteSmallCollection(
  collection: FirebaseFirestore.CollectionReference,
  maxDocs: number,
): Promise<void> {
  const snapshot = await collection.limit(maxDocs).get();
  await writeDocumentsInChunks(
    snapshot.docs.map((doc) => ({ref: doc.ref, data: null})),
  );
}

async function writeDocumentsInChunks(
  entries: Iterable<{
    ref: FirebaseFirestore.DocumentReference;
    data: Record<string, unknown> | null;
  }>,
): Promise<void> {
  const db = admin.firestore();
  let batch = db.batch();
  let count = 0;
  for (const entry of entries) {
    if (entry.data === null) {
      batch.delete(entry.ref);
    } else {
      batch.set(entry.ref, entry.data, {merge: true});
    }
    count += 1;
    if (count === 450) {
      await batch.commit();
      batch = db.batch();
      count = 0;
    }
  }
  if (count > 0) {
    await batch.commit();
  }
}

function validateNonNegativeInt(value: unknown, field: string): void {
  if (value === undefined) {
    return;
  }
  const parsed = intFromValue(value);
  if (parsed === undefined || parsed < 0) {
    throw new HttpsError("invalid-argument", `${field} must be >= 0.`);
  }
}

async function writeAdminAuditLog(input: {
  uid: string;
  action: string;
  targetPath: string;
  before: Record<string, unknown>;
  after: Record<string, unknown>;
}): Promise<void> {
  await admin.firestore().collection("admin_audit_logs").add({
    actorUid: input.uid,
    action: input.action,
    targetPath: input.targetPath,
    before: input.before,
    after: input.after,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

function requireRecord(
  value: unknown,
  message: string,
): Record<string, unknown> {
  if (!isRecord(value)) {
    throw new HttpsError("invalid-argument", message);
  }
  return value;
}

function rejectUnknownFields(
  payload: Record<string, unknown>,
  allowedFields: string[],
): void {
  const allowed = new Set(allowedFields);
  for (const key of Object.keys(payload)) {
    if (!allowed.has(key)) {
      throw new HttpsError("invalid-argument", `Unknown field: ${key}`);
    }
  }
}

function sanitizePayload(
  payload: Record<string, unknown>,
  allowedFields: string[],
): Record<string, unknown> {
  const cleaned: Record<string, unknown> = {};
  for (const key of allowedFields) {
    if (payload[key] !== undefined) {
      cleaned[key] = sanitizeValue(payload[key], key);
    }
  }
  return cleaned;
}

function sanitizeValue(value: unknown, field: string): unknown {
  if (typeof value === "string") {
    if (value.length > 5000) {
      throw new HttpsError("invalid-argument", `${field} is too long.`);
    }
    return value.trim();
  }
  if (
    typeof value === "number" ||
    typeof value === "boolean" ||
    value === null
  ) {
    return value;
  }
  if (Array.isArray(value)) {
    if (value.length > 200) {
      throw new HttpsError("invalid-argument", `${field} has too many items.`);
    }
    return value.map((item) => sanitizeValue(item, field));
  }
  if (isRecord(value)) {
    const entries = Object.entries(value);
    if (entries.length > 100) {
      throw new HttpsError("invalid-argument", `${field} has too many keys.`);
    }
    return Object.fromEntries(
      entries.map(([key, item]) => {
        if (!/^[a-zA-Z0-9_.-]{1,64}$/.test(key)) {
          throw new HttpsError(
            "invalid-argument",
            `${field} contains an invalid nested key.`,
          );
        }
        return [key, sanitizeValue(item, field)];
      }),
    );
  }
  throw new HttpsError("invalid-argument", `${field} has unsupported value.`);
}

function normalizeActiveField(payload: Record<string, unknown>): void {
  if (payload.active !== undefined && payload.isActive === undefined) {
    payload.isActive = payload.active === true;
    delete payload.active;
  }
}

function optionalDocumentId(value: unknown, field: string): string | undefined {
  if (value === undefined || value === null || `${value}`.trim().length === 0) {
    return undefined;
  }
  return safeDocumentId(value, field);
}

function safeDocumentId(value: unknown, field: string): string {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${field} must be a string.`);
  }
  const id = value.trim();
  if (!/^[a-zA-Z0-9_-]{1,80}$/.test(id)) {
    throw new HttpsError(
      "invalid-argument",
      `${field} must be 1-80 letters, numbers, underscores, or hyphens.`,
    );
  }
  return id;
}

function requireString(
  value: unknown,
  field: string,
  minLength: number,
  maxLength: number,
): string {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${field} must be a string.`);
  }
  const trimmed = value.trim();
  if (trimmed.length < minLength || trimmed.length > maxLength) {
    throw new HttpsError(
      "invalid-argument",
      `${field} length is invalid.`,
    );
  }
  return trimmed;
}

function stringSetFromValue(value: unknown): Set<string> {
  if (!Array.isArray(value)) {
    return new Set<string>();
  }
  return new Set(
    value
      .filter((item): item is string => typeof item === "string")
      .map((item) => item.trim())
      .filter((item) => item.length > 0),
  );
}

function parseAwardPointsInput(data: unknown): AwardPointsInput {
  if (!isRecord(data)) {
    throw new HttpsError("invalid-argument", "Missing points payload.");
  }

  const source = data.source;
  const eventId = data.eventId;
  const status = data.status;
  const dateKey = data.dateKey;
  const prayerName = data.prayerName;
  const title = data.title;

  if (
    source !== "prayer" &&
    source !== "adhkar" &&
    source !== "dua" &&
    source !== "qiyam"
  ) {
    throw new HttpsError(
      "invalid-argument",
      "source must be 'prayer', 'adhkar', 'dua', or 'qiyam'.",
    );
  }
  if (
    typeof eventId !== "string" ||
    !/^[a-z0-9_-]{1,64}$/i.test(eventId.trim())
  ) {
    throw new HttpsError(
      "invalid-argument",
      "eventId must be 1-64 letters, numbers, underscores, or hyphens.",
    );
  }
  if (
    source === "prayer" &&
    !(
      status === "onTime" ||
      status === "late" ||
      status === "missed" ||
      (eventId.trim().toLowerCase() === "qiyam" && status === "completed")
    )
  ) {
    throw new HttpsError(
      "invalid-argument",
      "status must be 'onTime', 'late', 'missed', or qiyam 'completed'.",
    );
  }
  if (source !== "prayer" && status !== undefined) {
    throw new HttpsError(
      "invalid-argument",
      "status is only accepted for prayer awards.",
    );
  }
  if (
    typeof dateKey !== "string" ||
    !/^\d{4}-\d{2}-\d{2}$/.test(dateKey.trim())
  ) {
    throw new HttpsError(
      "invalid-argument",
      "dateKey must use YYYY-MM-DD format.",
    );
  }
  if (
    prayerName !== undefined &&
    (typeof prayerName !== "string" || prayerName.trim().length > 80)
  ) {
    throw new HttpsError(
      "invalid-argument",
      "prayerName must be a string up to 80 characters.",
    );
  }
  if (
    title !== undefined &&
    (typeof title !== "string" || title.trim().length > 80)
  ) {
    throw new HttpsError(
      "invalid-argument",
      "title must be a string up to 80 characters.",
    );
  }

  return {
    source,
    eventId: eventId.trim().toLowerCase(),
    status: source === "prayer" ? status as PrayerAwardStatus : undefined,
    dateKey: dateKey.trim(),
    prayerName: typeof prayerName === "string" ?
      prayerName.trim() :
      undefined,
    title: typeof title === "string" ? title.trim() : undefined,
  };
}

function ledgerIdForAward(input: AwardPointsInput): string {
  if (input.source === "prayer") {
    return `${input.source}:${input.dateKey}:${input.eventId}:` +
      `${input.status}`;
  }
  return `${input.source}:${input.dateKey}:${input.eventId}`;
}

async function loadPointsRules(
  transaction: admin.firestore.Transaction,
  db: admin.firestore.Firestore,
): Promise<Record<string, PlanPointsRule>> {
  const settingsRef = db.collection("settings").doc("app_config");
  const settingsSnapshot = await transaction.get(settingsRef);
  const settingsRules = rulesFromValue(settingsSnapshot.data()?.pointsRules);
  if (settingsRules) {
    return settingsRules;
  }

  const publishedRef = db.collection("remote_app_config").doc("published");
  const publishedSnapshot = await transaction.get(publishedRef);
  return rulesFromValue(publishedSnapshot.data()?.pointsRules) ??
    defaultPointsRules;
}

function rulesFromValue(
  value: unknown,
): Record<string, PlanPointsRule> | null {
  if (!isRecord(value)) {
    return null;
  }

  const resolved: Record<string, PlanPointsRule> = {...defaultPointsRules};
  for (const [rawPlanId, rawRule] of Object.entries(value)) {
    const planId = normalizedPlanId(rawPlanId);
    if (!isRecord(rawRule)) {
      continue;
    }
    resolved[planId] = {
      prayerOnTime: intFromValue(rawRule.prayerOnTime) ??
        resolved[planId]?.prayerOnTime ??
        defaultPointsRules.free.prayerOnTime,
      prayerLate: intFromValue(rawRule.prayerLate) ??
        resolved[planId]?.prayerLate ??
        defaultPointsRules.free.prayerLate,
      prayerMissed: intFromValue(rawRule.prayerMissed) ??
        resolved[planId]?.prayerMissed ??
        defaultPointsRules.free.prayerMissed,
      adhkarCompletion: intFromValue(rawRule.adhkarCompletion) ??
        resolved[planId]?.adhkarCompletion ??
        defaultPointsRules.free.adhkarCompletion,
      duaCompletion: intFromValue(rawRule.duaCompletion) ??
        resolved[planId]?.duaCompletion ??
        defaultPointsRules.free.duaCompletion,
      qiyamCompletion: intFromValue(rawRule.qiyamCompletion) ??
        resolved[planId]?.qiyamCompletion ??
        defaultPointsRules.free.qiyamCompletion,
    };
  }
  return resolved;
}

function pointsForAward(
  rule: PlanPointsRule,
  input: AwardPointsInput,
): number {
  if (input.source === "adhkar") {
    return rule.adhkarCompletion;
  }
  if (input.source === "dua") {
    return rule.duaCompletion;
  }
  if (input.source === "qiyam") {
    return rule.qiyamCompletion;
  }
  if (input.source === "prayer" &&
      input.eventId === "qiyam" &&
      input.status === "completed") {
    return rule.qiyamCompletion;
  }
  switch (input.status) {
  case "onTime":
    return rule.prayerOnTime;
  case "late":
    return rule.prayerLate;
  case "missed":
    return rule.prayerMissed;
  default:
    throw new HttpsError("invalid-argument", "Invalid prayer award status.");
  }
}

function normalizedPlanId(planId: string | undefined): string {
  const normalized = planId?.trim().toLowerCase();
  return normalized && normalized.length > 0 ? normalized : "free";
}

function pointBalance(value: unknown): number {
  return Math.max(0, intFromValue(value) ?? 0);
}

function intFromValue(value: unknown): number | undefined {
  const parsed = numberFromValue(value);
  return parsed === undefined ? undefined : Math.trunc(parsed);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return !!value && typeof value === "object" && !Array.isArray(value);
}

async function clearRoleClaim(uid: string): Promise<void> {
  const user = await admin.auth().getUser(uid);
  const claims = {...user.customClaims};
  if (!("role" in claims)) {
    return;
  }

  delete claims.role;
  await admin.auth().setCustomUserClaims(
    uid,
    Object.keys(claims).length > 0 ? claims : null,
  );
}

function parseInput(data: unknown): VerifyPurchaseInput {
  if (!data || typeof data !== "object") {
    throw new HttpsError("invalid-argument", "Missing purchase payload.");
  }

  const payload = data as Record<string, unknown>;
  const platform = payload.platform;
  const purchaseToken = payload.purchaseToken;
  const productId = payload.productId;

  if (platform !== "android" && platform !== "ios") {
    throw new HttpsError(
      "invalid-argument",
      "platform must be either 'android' or 'ios'.",
    );
  }
  if (typeof purchaseToken !== "string" || purchaseToken.trim().length === 0) {
    throw new HttpsError("invalid-argument", "purchaseToken is required.");
  }
  if (typeof productId !== "string" || productId.trim().length === 0) {
    throw new HttpsError("invalid-argument", "productId is required.");
  }

  return {
    platform,
    purchaseToken: purchaseToken.trim(),
    productId: productId.trim(),
  };
}

async function verifyAndroidPurchase(
  input: VerifyPurchaseInput,
): Promise<VerificationSuccess> {
  const packageName = process.env.ANDROID_PACKAGE_NAME;
  // TODO(api-credentials): set ANDROID_PACKAGE_NAME and deploy with a Google
  // service account that has Google Play Developer API access for this app.
  if (!packageName) {
    throw new HttpsError(
      "failed-precondition",
      "Android package name is not configured.",
    );
  }

  const auth = new google.auth.GoogleAuth({
    scopes: ["https://www.googleapis.com/auth/androidpublisher"],
  });
  const publisher = google.androidpublisher({version: "v3", auth});

  const subscription = await tryVerifyAndroidSubscription(
    publisher,
    packageName,
    input,
  );
  if (subscription) {
    return subscription;
  }

  const product = await tryVerifyAndroidProduct(publisher, packageName, input);
  if (product) {
    return product;
  }

  throw new HttpsError(
    "permission-denied",
    "Android purchase could not be verified.",
  );
}

async function tryVerifyAndroidSubscription(
  publisher: ReturnType<typeof google.androidpublisher>,
  packageName: string,
  input: VerifyPurchaseInput,
): Promise<VerificationSuccess | null> {
  try {
    const response = await publisher.purchases.subscriptions.get({
      packageName,
      subscriptionId: input.productId,
      token: input.purchaseToken,
    });
    const purchase = response.data;
    const expiresAt = Number(purchase.expiryTimeMillis ?? 0);
    const isActive = expiresAt > Date.now() &&
      purchase.cancelReason === undefined;

    if (!isActive) {
      throw new HttpsError("permission-denied", "Subscription is not active.");
    }

    return {
      transactionId: purchase.orderId ?? undefined,
      expiresAt,
      rawStatus: purchase.paymentState ?? undefined,
    };
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }
    return null;
  }
}

async function tryVerifyAndroidProduct(
  publisher: ReturnType<typeof google.androidpublisher>,
  packageName: string,
  input: VerifyPurchaseInput,
): Promise<VerificationSuccess | null> {
  try {
    const response = await publisher.purchases.products.get({
      packageName,
      productId: input.productId,
      token: input.purchaseToken,
    });
    const purchase = response.data;
    if (purchase.purchaseState !== 0) {
      throw new HttpsError("permission-denied", "Product purchase is invalid.");
    }

    return {
      transactionId: purchase.orderId ?? undefined,
      rawStatus: purchase.purchaseState,
    };
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }
    return null;
  }
}

async function verifyIosPurchase(
  input: VerifyPurchaseInput,
): Promise<VerificationSuccess> {
  const sharedSecret = process.env.APPLE_SHARED_SECRET;
  // TODO(api-credentials): set APPLE_SHARED_SECRET for auto-renewable
  // subscriptions. Non-subscription receipt checks may not require it.
  const production = await postAppleReceipt(
    "https://buy.itunes.apple.com/verifyReceipt",
    input.purchaseToken,
    sharedSecret,
  );

  const receipt = production.status === 21007 ?
    await postAppleReceipt(
      "https://sandbox.itunes.apple.com/verifyReceipt",
      input.purchaseToken,
      sharedSecret,
    ) :
    production;

  if (receipt.status !== 0) {
    throw new HttpsError(
      "permission-denied",
      `iOS receipt validation failed with status ${receipt.status}.`,
    );
  }

  const purchase = findApplePurchase(receipt, input.productId);
  if (!purchase) {
    throw new HttpsError(
      "permission-denied",
      "iOS receipt does not contain the requested product.",
    );
  }

  const expiresAt = numberFromValue(purchase.expires_date_ms);
  if (expiresAt !== undefined && expiresAt <= Date.now()) {
    throw new HttpsError("permission-denied", "iOS subscription is expired.");
  }
  if (purchase.cancellation_date_ms !== undefined) {
    throw new HttpsError("permission-denied", "iOS purchase was cancelled.");
  }

  return {
    transactionId: stringFromValue(purchase.transaction_id),
    expiresAt,
    rawStatus: receipt.status,
  };
}

async function postAppleReceipt(
  url: string,
  receiptData: string,
  sharedSecret?: string,
): Promise<Record<string, unknown>> {
  const response = await fetch(url, {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify({
      "receipt-data": receiptData,
      "password": sharedSecret,
      "exclude-old-transactions": true,
    }),
  });

  if (!response.ok) {
    throw new HttpsError(
      "unavailable",
      `Apple receipt endpoint returned HTTP ${response.status}.`,
    );
  }

  return await response.json() as Record<string, unknown>;
}

function findApplePurchase(
  receipt: Record<string, unknown>,
  productId: string,
): Record<string, unknown> | null {
  const latest = purchaseArray(receipt.latest_receipt_info);
  const inApp = purchaseArray(
    (receipt.receipt as Record<string, unknown> | undefined)?.in_app,
  );
  const purchases = [...latest, ...inApp];

  const matching = purchases
    .filter((purchase) => purchase.product_id === productId)
    .sort((left, right) => {
      const leftExpires = numberFromValue(left.expires_date_ms) ?? 0;
      const rightExpires = numberFromValue(right.expires_date_ms) ?? 0;
      return rightExpires - leftExpires;
    });

  return matching[0] ?? null;
}

function purchaseArray(value: unknown): Record<string, unknown>[] {
  if (!Array.isArray(value)) {
    return [];
  }
  return value.filter((item): item is Record<string, unknown> => {
    return !!item && typeof item === "object";
  });
}

function numberFromValue(value: unknown): number | undefined {
  if (typeof value === "number") {
    return value;
  }
  if (typeof value === "string" && value.trim().length > 0) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : undefined;
  }
  return undefined;
}

function stringFromValue(value: unknown): string | undefined {
  return typeof value === "string" && value.trim().length > 0 ?
    value.trim() :
    undefined;
}

function stringOrNumberFromValue(value: unknown): string | undefined {
  if (typeof value === "number" && Number.isFinite(value)) {
    return `${value}`;
  }
  return stringFromValue(value);
}
