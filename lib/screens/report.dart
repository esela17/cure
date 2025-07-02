// ------------ بداية الكود لـ report.dart (النسخة المصححة) ------------
import 'package:cure_app/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cure_app/utils/constants.dart';
import 'package:provider/provider.dart'; // ✅ الخطوة 1: إضافة Provider

class ReportScreen extends StatefulWidget {
  final String nurseId;
  final String orderId;

  const ReportScreen({
    super.key,
    required this.nurseId,
    required this.orderId,
  });

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final TextEditingController _reportController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSending = false;

  // ✅ الخطوة 2: تعديل دالة إرسال الشكوى بالكامل
  Future<void> _submitReport() async {
    // التحقق من صحة حقل الإدخال
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSending = true;
    });

    try {
      // استخدام Provider لجلب بيانات المستخدم الموثوقة
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userProfile = authProvider.currentUserProfile;

      // التأكد من أن المستخدم مسجل ولديه ملف شخصي
      if (userProfile == null) {
        throw Exception("لا يمكن العثور على بيانات المستخدم.");
      }

      // إنشاء مستند الشكوى بالبيانات الصحيحة
      await FirebaseFirestore.instance.collection('reports').add({
        'message': _reportController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'nurseId': widget.nurseId,
        'orderId': widget.orderId,
        'patientId': userProfile.id, // استخدام ID من النموذج
        'patientName': userProfile.name, // استخدام الاسم من النموذج
        'status': 'new', // الحالة الأولية للشكوى
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم إرسال الشكوى بنجاح'),
              backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('حدث خطأ: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _reportController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تقديم شكوى'),
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('صف المشكلة التي واجهتها بالتفصيل:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _reportController,
                maxLines: 8,
                decoration: InputDecoration(
                  hintText: 'اكتب هنا...',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kPrimaryColor),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'هذا الحقل إجباري.';
                  }
                  return null;
                },
              ),
              const Spacer(), // لدفع الزر إلى الأسفل
              ElevatedButton.icon(
                onPressed: _isSending ? null : _submitReport,
                icon: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded),
                label: Text(_isSending ? 'جاري الإرسال...' : 'إرسال الشكوى'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
// ------------ نهاية الكود لـ report.dart (النسخة المصححة) ------------
