// ✅ الاستيرادات الأساسية
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { HttpsError, onCall } = require('firebase-functions/v2/https');
const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const admin = require('firebase-admin');

// ✅ تهيئة Firebase Admin SDK
initializeApp();
const db = getFirestore();
const messaging = getMessaging();

// ═══════════════════════════════════════════════════════════════════════════
// 🆕 Helper: الحصول على FCM Token للمستخدم
// ═══════════════════════════════════════════════════════════════════════════
async function getUserFCMToken(userId) {
    try {
        const userDoc = await db.collection('users').doc(userId).get();
        
        if (!userDoc.exists) {
            console.log(`User ${userId} not found`);
            return null;
        }

        const fcmToken = userDoc.data().fcmToken;
        return fcmToken || null;
    } catch (error) {
        console.error(`Error getting FCM token for user ${userId}:`, error);
        return null;
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// 🆕 Helper: إرسال إشعار
// ═══════════════════════════════════════════════════════════════════════════
async function sendNotification(token, title, body, data = {}) {
    if (!token) {
        console.log('No FCM token provided, skipping notification');
        return;
    }

    try {
        await messaging.send({
            token: token,
            notification: {
                title: title,
                body: body,
                sound: 'default'
            },
            data: data,
            android: {
                priority: 'high',
                notification: {
                    sound: 'default',
                    priority: 'high',
                    channelId: 'high_importance_channel'
                }
            },
            apns: {
                payload: {
                    aps: {
                        sound: 'default',
                        badge: 1
                    }
                }
            }
        });
        console.log(`✅ Notification sent successfully to token: ${token.substring(0, 20)}...`);
    } catch (error) {
        console.error('❌ Failed to send notification:', error);
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// 1️⃣ Trigger: إرسال إشعار عند إنشاء طلب جديد
// ═══════════════════════════════════════════════════════════════════════════
exports.onRequestCreated = onDocumentCreated('requests/{requestId}', async (event) => {
    const requestData = event.data.data();
    const requestId = event.params.requestId;

    const patientName = requestData.patientName || 'مريض';
    const totalPrice = requestData.totalPrice || 0;

    console.log(`📦 تم إنشاء طلب جديد من ${patientName} (ID: ${requestId})`);

    try {
        // إرسال إشعار لجميع الممرضين عبر Topic
        const payload = {
            notification: {
                title: '🔔 طلب خدمة جديد!',
                body: `لديك طلب جديد من "${patientName}" بقيمة ${totalPrice.toFixed(2)} ج.م.`,
                sound: "default",
            },
            topic: 'nurses',
            data: {
                orderId: requestId,
                type: 'new_order',
                click_action: 'FLUTTER_NOTIFICATION_CLICK',
            }
        };

        await messaging.send(payload);
        console.log('🚀 تم إرسال الإشعار بنجاح للممرضين');
    } catch (error) {
        console.error('❌ فشل في إرسال الإشعار:', error);
    }
});

// ═══════════════════════════════════════════════════════════════════════════
// 2️⃣ Trigger: تنفيذ المحاسبة عند اكتمال طلب نقدي
// ═══════════════════════════════════════════════════════════════════════════
exports.processCashOrderCompletion = onDocumentUpdated('requests/{orderId}', async (event) => {
    const orderBefore = event.data.before.data();
    const orderAfter = event.data.after.data();
    const orderId = event.params.orderId;

    if (
        orderBefore.status !== 'completed' &&
        orderAfter.status === 'completed' &&
        orderAfter.paymentMethod === 'cash' &&
        orderAfter.nurseId
    ) {
        const nurseId = orderAfter.nurseId;
        const orderTotal = orderAfter.totalPrice || 0;
        const discountAmount = orderAfter.discountAmount || 0;
        const commissionRate = orderAfter.platformCommissionRate || 0;
        const commission = orderTotal * commissionRate;

        try {
            await db.runTransaction(async (transaction) => {
                const nurseRef = db.collection('users').doc(nurseId);
                const nurseDoc = await transaction.get(nurseRef);

                if (!nurseDoc.exists) throw new Error("Nurse not found: " + nurseId);

                const currentPayoutBalance = nurseDoc.data().payoutBalance || 0;
                const newPayoutBalance = currentPayoutBalance - commission;

                transaction.update(nurseRef, {
                    payoutBalance: newPayoutBalance,
                    lastPayoutUpdate: admin.firestore.FieldValue.serverTimestamp()
                });

                transaction.set(db.collection('transactions').doc(), {
                    orderId,
                    userId: nurseId,
                    type: 'commission_due',
                    paymentMethod: 'cash',
                    amount: -commission,
                    status: 'succeeded',
                    currency: 'SAR',
                    timestamp: admin.firestore.FieldValue.serverTimestamp(),
                    note: `Commission debt (${(commissionRate * 100).toFixed(0)}%) for cash order.`
                });

                if (discountAmount > 0) {
                    transaction.set(db.collection('transactions').doc(), {
                        orderId,
                        userId: orderAfter.userId,
                        type: 'discount_cost',
                        paymentMethod: 'cash',
                        amount: -discountAmount,
                        status: 'succeeded',
                        currency: 'SAR',
                        timestamp: admin.firestore.FieldValue.serverTimestamp(),
                        note: `Coupon discount applied: ${orderAfter.couponCode || 'N/A'}`
                    });

                    if (orderAfter.couponCode) {
                        transaction.update(
                            db.collection('coupons').doc(orderAfter.couponCode),
                            { usedCount: admin.firestore.FieldValue.increment(1) }
                        );
                    }
                }

                console.log(`✅ Cash order ${orderId} accounting completed`);
            });
        } catch (error) {
            console.error("❌ Cash order accounting failed:", error);
            throw error;
        }
    }
});

// ═══════════════════════════════════════════════════════════════════════════
// 🆕 3️⃣ Scheduled Function: تفعيل زر الإلغاء بعد 20 دقيقة
// ═══════════════════════════════════════════════════════════════════════════
exports.enableCancellationButton = onSchedule('every 1 minutes', async (event) => {
    try {
        const now = admin.firestore.Timestamp.now();
        
        // البحث عن الطلبات المقبولة والتي مر عليها 20 دقيقة
        const ordersSnapshot = await db.collection('requests')
            .where('status', '==', 'accepted')
            .where('canPatientCancelAfterAccept', '==', false)
            .where('cancellationAvailableAt', '<=', now)
            .get();

        if (ordersSnapshot.empty) {
            console.log('No orders to update for cancellation');
            return null;
        }

        // تحديث الطلبات
        const batch = db.batch();
        ordersSnapshot.docs.forEach((doc) => {
            batch.update(doc.ref, {
                canPatientCancelAfterAccept: true,
                lastUpdated: admin.firestore.FieldValue.serverTimestamp()
            });
        });

        await batch.commit();
        console.log(`✅ Updated ${ordersSnapshot.size} orders - enabled cancellation button`);

        return null;
    } catch (error) {
        console.error('❌ Error enabling cancellation buttons:', error);
        return null;
    }
});

// ═══════════════════════════════════════════════════════════════════════════
// 🆕 4️⃣ Trigger: إشعارات فورية عند تحديث الطلب
// ═══════════════════════════════════════════════════════════════════════════
exports.sendOrderStatusNotification = onDocumentUpdated('requests/{orderId}', async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    const orderId = event.params.orderId;

    try {
        // ═══════════════════════════════════════════════════════════════════
        // Case 1: الممرض أكد التحرك → إشعار للمريض
        // ═══════════════════════════════════════════════════════════════════
        if (!before.isNurseMovingConfirmed && after.isNurseMovingConfirmed) {
            const patientToken = await getUserFCMToken(after.userId);
            
            await sendNotification(
                patientToken,
                '🚗 الممرض في الطريق',
                `${after.nurseName || 'الممرض'} يتحرك الآن نحو موقعك`,
                {
                    type: 'nurse_moving_confirmed',
                    orderId: orderId
                }
            );
        }

        // ═══════════════════════════════════════════════════════════════════
        // Case 2: المريض طلب تأكيد التحرك → إشعار عاجل للممرض
        // ═══════════════════════════════════════════════════════════════════
        if (!before.isNurseMovingRequested && after.isNurseMovingRequested) {
            const nurseToken = await getUserFCMToken(after.nurseId);
            
            await sendNotification(
                nurseToken,
                '🚨 تنبيه هام - تحرك الآن',
                'المريض ينتظر تأكيدك بأنك تتحرك نحوه',
                {
                    type: 'movement_confirmation_requested',
                    orderId: orderId,
                    priority: 'high'
                }
            );
        }

        // ═══════════════════════════════════════════════════════════════════
        // Case 3: المريض أكد رؤية الممرض يتحرك → إشعار للممرض
        // ═══════════════════════════════════════════════════════════════════
        if (!before.patientConfirmedNurseMoving && after.patientConfirmedNurseMoving) {
            const nurseToken = await getUserFCMToken(after.nurseId);
            
            await sendNotification(
                nurseToken,
                '✅ تأكيد من المريض',
                'المريض أكد أنك في طريقك إليه',
                {
                    type: 'patient_confirmed_movement',
                    orderId: orderId
                }
            );
        }

        // ═══════════════════════════════════════════════════════════════════
        // Case 4: الممرض سجّل استلام الدفع النقدي → إشعار للمريض
        // ═══════════════════════════════════════════════════════════════════
        if (!before.isPaymentConfirmedByNurse && after.isPaymentConfirmedByNurse) {
            const patientToken = await getUserFCMToken(after.userId);
            
            await sendNotification(
                patientToken,
                '💰 الممرض سجّل استلام الدفع',
                `يرجى تأكيد تسليم ${after.finalPrice || after.totalPrice} ج.م نقداً`,
                {
                    type: 'cash_payment_registered_by_nurse',
                    orderId: orderId
                }
            );
        }

        // ═══════════════════════════════════════════════════════════════════
        // Case 5: المريض أكد تسليم الدفع النقدي → إشعار للممرض
        // ═══════════════════════════════════════════════════════════════════
        if (!before.isPaymentConfirmedByPatient && after.isPaymentConfirmedByPatient) {
            const nurseToken = await getUserFCMToken(after.nurseId);
            
            await sendNotification(
                nurseToken,
                '✅ المريض أكد الدفع',
                'المريض أكد تسليم المبلغ النقدي',
                {
                    type: 'cash_payment_confirmed_by_patient',
                    orderId: orderId
                }
            );
        }

        // ═══════════════════════════════════════════════════════════════════
        // Case 6: تغيير حالة الطلب الرئيسية
        // ═══════════════════════════════════════════════════════════════════
        if (before.status !== after.status) {
            await handleStatusChange(before, after, orderId);
        }

        return null;
    } catch (error) {
        console.error('❌ Error sending notification:', error);
        return null;
    }
});

// ═══════════════════════════════════════════════════════════════════════════
// 🆕 Helper: معالجة تغيير حالة الطلب
// ═══════════════════════════════════════════════════════════════════════════
async function handleStatusChange(before, after, orderId) {
    const oldStatus = before.status;
    const newStatus = after.status;

    console.log(`📊 Status changed: ${oldStatus} → ${newStatus} for order ${orderId}`);

    // إشعارات للمريض
    const patientNotifications = {
        'accepted': {
            title: '✅ تم قبول طلبك',
            body: `${after.nurseName || 'الممرض'} قبل طلبك وسيصل قريباً`
        },
        'arrived': {
            title: '📍 الممرض وصل',
            body: `${after.nurseName || 'الممرض'} وصل إلى موقعك`
        },
        'completed': {
            title: '🎉 تم إكمال الخدمة',
            body: 'شكراً لاستخدامك خدماتنا. نتمنى لك الشفاء العاجل'
        },
        'rejected': {
            title: '❌ تم رفض الطلب',
            body: after.rejectReason || 'تم رفض طلبك من قبل الممرض'
        },
        'cancelled': {
            title: '🚫 تم إلغاء الطلب',
            body: 'تم إلغاء الطلب'
        }
    };

    // إشعارات للممرض
    const nurseNotifications = {
        'cancelled': {
            title: '🚫 المريض ألغى الطلب',
            body: `تم إلغاء الطلب #${orderId.substring(0, 8)}`
        }
    };

    // إرسال إشعار للمريض
    if (patientNotifications[newStatus]) {
        const patientToken = await getUserFCMToken(after.userId);
        await sendNotification(
            patientToken,
            patientNotifications[newStatus].title,
            patientNotifications[newStatus].body,
            {
                type: `order_status_${newStatus}`,
                orderId: orderId
            }
        );
    }

    // إرسال إشعار للممرض
    if (after.nurseId && nurseNotifications[newStatus]) {
        const nurseToken = await getUserFCMToken(after.nurseId);
        await sendNotification(
            nurseToken,
            nurseNotifications[newStatus].title,
            nurseNotifications[newStatus].body,
            {
                type: `order_status_${newStatus}`,
                orderId: orderId
            }
        );
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// 5️⃣ Callable: تسوية رصيد الممرض (زيادة الرصيد)
// ═══════════════════════════════════════════════════════════════════════════
exports.manualBalanceSettlement = onCall(async (request) => {
    if (!request.auth || request.auth.token.role !== 'admin') {
        throw new HttpsError('unauthenticated', 'غير مصرح — يجب أن تكون أدمن.');
    }

    const { nurseId, amount, note } = request.data;
    const nurseRef = db.collection('users').doc(nurseId);

    try {
        const result = await db.runTransaction(async (transaction) => {
            const nurseDoc = await transaction.get(nurseRef);
            if (!nurseDoc.exists) throw new Error("Nurse not found");

            const currentPayoutBalance = nurseDoc.data().payoutBalance || 0;
            const newPayoutBalance = currentPayoutBalance + amount;

            transaction.update(nurseRef, {
                payoutBalance: newPayoutBalance,
                lastPayoutUpdate: admin.firestore.FieldValue.serverTimestamp()
            });

            transaction.set(db.collection('transactions').doc(), {
                orderId: null,
                userId: nurseId,
                type: 'commission_payment',
                paymentMethod: 'cash',
                amount,
                status: 'succeeded',
                currency: 'SAR',
                timestamp: admin.firestore.FieldValue.serverTimestamp(),
                note: note || `Manual settlement by Admin`
            });

            return { success: true, newBalance: newPayoutBalance };
        });

        return result;
    } catch (error) {
        throw new HttpsError('internal', 'فشل التسوية', error.message);
    }
});

// ═══════════════════════════════════════════════════════════════════════════
// 6️⃣ Callable: صرف رصيد للممرض (خصم الرصيد)
// ═══════════════════════════════════════════════════════════════════════════
exports.processNursePayout = onCall(async (request) => {
    if (!request.auth || request.auth.token.role !== 'admin') {
        throw new HttpsError('unauthenticated', 'غير مصرح — يجب أن تكون أدمن.');
    }

    const { nurseId, amount, note } = request.data;
    const nurseRef = db.collection('users').doc(nurseId);

    try {
        const result = await db.runTransaction(async (transaction) => {
            const nurseDoc = await transaction.get(nurseRef);
            if (!nurseDoc.exists) throw new Error("Nurse not found");

            const currentPayoutBalance = nurseDoc.data().payoutBalance || 0;
            if (currentPayoutBalance < amount) {
                throw new HttpsError('failed-precondition', 'رصيد غير كافٍ للسحب');
            }

            const newPayoutBalance = currentPayoutBalance - amount;

            transaction.update(nurseRef, {
                payoutBalance: newPayoutBalance,
                lastPayoutUpdate: admin.firestore.FieldValue.serverTimestamp()
            });

            transaction.set(db.collection('transactions').doc(), {
                orderId: null,
                userId: nurseId,
                type: 'payout',
                paymentMethod: 'manual',
                amount: -amount,
                status: 'succeeded',
                currency: 'SAR',
                timestamp: admin.firestore.FieldValue.serverTimestamp(),
                note: note || `Manual payout by Admin`
            });

            return { success: true, newBalance: newPayoutBalance };
        });

        return result;
    } catch (error) {
        throw new HttpsError('internal', 'فشل الصرف', error.message);
    }
});

// ═══════════════════════════════════════════════════════════════════════════
// 🆕 7️⃣ Scheduled: تنظيف الطلبات القديمة (أرشفة بعد 90 يوم)
// ═══════════════════════════════════════════════════════════════════════════
exports.cleanupOldOrders = onSchedule('every 24 hours', async (event) => {
    try {
        const ninetyDaysAgo = admin.firestore.Timestamp.fromDate(
            new Date(Date.now() - 90 * 24 * 60 * 60 * 1000)
        );

        const oldOrdersSnapshot = await db.collection('requests')
            .where('status', 'in', ['completed', 'cancelled', 'rejected'])
            .where('orderDate', '<=', ninetyDaysAgo)
            .limit(500) // معالجة 500 طلب في كل مرة
            .get();

        if (oldOrdersSnapshot.empty) {
            console.log('No old orders to clean up');
            return null;
        }

        // أرشفة الطلبات القديمة
        const batch = db.batch();
        const archiveBatch = db.batch();

        oldOrdersSnapshot.docs.forEach((doc) => {
            // نسخ إلى الأرشيف
            archiveBatch.set(
                db.collection('archived_orders').doc(doc.id),
                {
                    ...doc.data(),
                    archivedAt: admin.firestore.FieldValue.serverTimestamp()
                }
            );
            
            // حذف من الطلبات الرئيسية
            batch.delete(doc.ref);
        });

        await archiveBatch.commit();
        await batch.commit();

        console.log(`✅ Archived and deleted ${oldOrdersSnapshot.size} old orders`);
        return null;
    } catch (error) {
        console.error('❌ Error cleaning up old orders:', error);
        return null;
    }
});

// ═══════════════════════════════════════════════════════════════════════════
// ✅ END OF CLOUD FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════