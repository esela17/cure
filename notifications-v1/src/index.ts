import {onDocumentCreated} from "firebase-functions/v2/firestore"; // استيراد v2
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger"; // استخدام logger أفضل

admin.initializeApp();

export const sendNewMessageNotification = onDocumentCreated("messages/{messageId}", async (event) => {
  // 1. الحصول على بيانات الرسالة الجديدة
  const messageData = event.data?.data(); // صيغة v2
  if (!messageData) {
    logger.error("No data associated with the event");
    return;
  }

  const senderName = messageData.senderName;
  const messageText = messageData.text;
  const recipientId = messageData.recipientId;

  logger.info(`New message for user ${recipientId} from ${senderName}`);

  // 2. التحقق من وجود معرّف المستقبِل
  if (!recipientId) {
    logger.warn("Recipient ID not found.");
    return;
  }

  // 3. جلب بيانات المستقبِل للحصول على fcmToken
  const userDoc = await admin.firestore().collection("users").doc(recipientId).get();

  if (!userDoc.exists) {
    logger.error(`User document for ${recipientId} does not exist.`);
    return;
  }

  const fcmToken = userDoc.data()?.fcmToken;
  if (!fcmToken) {
    logger.warn(`FCM token for user ${recipientId} not found.`);
    return;
  }

  // 4. تجهيز رسالة الإشعار
  const payload = {
    notification: {
      title: `رسالة جديدة من ${senderName}!`,
      body: messageText,
      sound: "default",
    },
    token: fcmToken, // في v2، يتم وضع التوكن هنا مباشرة
  };

  // 5. إرسال الإشعار
  try {
    logger.info(`Sending notification to token: ${fcmToken}`);
    const response = await admin.messaging().send(payload); // استخدام send بدلاً من sendToDevice
    logger.info("Successfully sent message:", response);
  } catch (error) {
    logger.error("Error sending message:", error);
  }
});
