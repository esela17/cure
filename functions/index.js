// ✅ الاستيرادات الأساسية
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { HttpsError, onCall } = require('firebase-functions/v2/https');
const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');

// ✅ تهيئة Firebase Admin SDK
initializeApp();
const db = getFirestore();
const messaging = getMessaging();

// -------------------------------------------------------------
// 1) Trigger: إرسال إشعار عند إنشاء طلب جديد
// -------------------------------------------------------------
exports.onRequestCreated = onDocumentCreated('requests/{requestId}', async (event) => {
    const requestData = event.data.data();
    const requestId = event.params.requestId;

    const patientName = requestData.patientName || 'مريض';
    const totalPrice = requestData.totalPrice || 0;

    console.log(`📦 V2: تم إنشاء طلب جديد من ${patientName} (ID: ${requestId})`);

    const payload = {
        notification: {
            title: 'طلب خدمة جديد!',
            body: `لديك طلب جديد من "${patientName}" بقيمة ${totalPrice.toFixed(2)} جنيه.`,
            sound: "default",
        },
        topic: 'nurses',
        data: {
            orderId: requestId,
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
        }
    };

    try {
        await messaging.send(payload);
        console.log('🚀 تم إرسال الإشعار بنجاح');
    } catch (error) {
        console.error('❌ فشل في إرسال الإشعار:', error);
    }
});

// -------------------------------------------------------------
// 2) Trigger: تنفيذ المحاسبة عند اكتمال طلب نقدي
// -------------------------------------------------------------
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

                console.log(`✅ V2: Cash order ${orderId} accounting completed`);
            });
        } catch (error) {
            console.error("❌ Cash order accounting failed:", error);
            throw error;
        }
    }
});

// -------------------------------------------------------------
// 3) Callable: تسوية رصيد الممرض (زيادة الرصيد)
// -------------------------------------------------------------
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

// -------------------------------------------------------------
// 4) Callable: صرف رصيد للممرض (خصم الرصيد)
// -------------------------------------------------------------
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
