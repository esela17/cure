// في ملف functions/index.js

exports.onRequestCreated = onDocumentCreated('requests/{requestId}', async (event) => {
  const requestData = event.data.data();
  const requestId = event.params.requestId;

  // استخراج معلومات مفيدة من الطلب
  const patientName = requestData.patientName || 'مريض';
  const totalPrice = requestData.totalPrice || 0;
  
  console.log(`📦 تم إنشاء طلب جديد من ${patientName}`);

  // ✅ تجهيز إشعار بمعلومات غنية
  const payload = {
    notification: {
      title: 'طلب خدمة جديد!',
      body: `لديك طلب جديد من "${patientName}" بقيمة ${totalPrice.toFixed(2)} جنيه.`,
      sound: "default",
    },
    topic: 'nurses', // 🎯 إرسال لكل الممرضين المشتركين
    data: {
      // ✅ إضافة البيانات هنا مهم جداً للخطوة التالية
      'orderId': requestId,
      'click_action': 'FLUTTER_NOTIFICATION_CLICK', 
    }
  };

  try {
    const response = await messaging.send(payload);
    console.log('🚀 إشعار غني بالمعلومات تم إرساله:', response);
  } catch (error) {
    console.error('❌ فشل في إرسال الإشعار:', error);
  }
});