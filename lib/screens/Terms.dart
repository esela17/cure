// lib/screens/terms_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cure_app/utils/constants.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Stack(
        children: [
          // 1. الخلفية الأنيقة
          _buildBackground(context),

          // 2. المحتوى الرئيسي
          SafeArea(
            child: Column(
              children: [
                // 3. شريط العنوان المخصص
                _buildAppBar(context),

                // 4. حاوية الشروط الزجاجية
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                    child: _GlassContainer(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // تم تقسيم النص إلى فقرات وعناوين لتسهيل القراءة
                            _buildHeading('مقدمة'),
                            _buildParagraph(
                                'مرحبًا بك في تطبيق كيور (“التطبيق” أو “الخدمة”). يُرجى قراءة هذه الشروط والأحكام وسياسة الخصوصية بعناية قبل استخدام التطبيق.\n\nباستخدامك لتطبيق كيور، فإنك توافق على الالتزام بكافة الشروط والأحكام الواردة في هذه الوثيقة. إذا كنت لا توافق على أي جزء منها، يرجى عدم استخدام التطبيق.'),
                            _buildDivider(),
                            _buildHeading('1. التعريفات'),
                            _buildParagraph(
                                'كيور: التطبيق الإلكتروني الذي يعمل كمنصة وسيطة ومنظمة لربط المرضى بمقدمي الخدمات الطبية المنزلية.\nالمستخدم: أي شخص يستخدم التطبيق لطلب أو الحصول على الخدمات الطبية المنزلية.\nمقدم الخدمة: الأفراد أو الجهات المسجلة في كيور لتقديم خدمات طبية منزلية.'),
                            _buildDivider(),
                            _buildHeading('2. طبيعة الخدمة ومسؤوليات الأطراف'),
                            _buildParagraph(
                                'دور كيور هو وسيط منظم فقط يُسهل عملية التواصل والحجز بين المستخدمين ومقدمي الخدمات الطبية المنزلية. كيور لا يقدم الخدمات الطبية بنفسه، ولا يتدخل في كيفية تقديم الخدمة أو جودة الخدمات.'),
                            _buildDivider(),
                            _buildHeading('3. إخلاء المسؤولية'),
                            _buildParagraph(
                                'كيور غير مسؤول عن أي أضرار أو مضاعفات أو أخطاء طبية قد تحدث نتيجة للخدمات المقدمة من قبل مقدمي الخدمة. لا يتحمل كيور أية مسؤولية عن سلامة الخدمات الطبية أو نتائجها.'),
                            _buildDivider(),
                            _buildHeading('4. الخصوصية وحماية البيانات'),
                            _buildParagraph(
                                'يلتزم كيور باتخاذ الإجراءات التقنية والتنظيمية المناسبة لحماية البيانات الشخصية من الوصول غير المصرح به أو الاستخدام أو التعديل. لا يتم مشاركة بيانات المستخدمين مع أي طرف ثالث إلا في الحالات القانونية أو بموافقة المستخدم.'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- دوال مساعدة لبناء الواجهة ---

  Widget _buildBackground(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.3,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            kPrimaryColor.withOpacity(0.2),
            kPrimaryColor.withOpacity(0.0),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, left: 24, right: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _GlassButton(
            onPressed: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_ios_new,
                color: kPrimaryColor, size: 20),
          ),
          const Text(
            "الشروط والأحكام",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _buildHeading(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 16.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: kPrimaryColor,
        ),
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Text(
      text,
      textAlign: TextAlign.start,
      style: TextStyle(
        fontSize: 15,
        color: Colors.grey.shade800,
        height: 1.7,
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Divider(color: Colors.grey.shade200),
    );
  }
}

// --- المكونات الزجاجية المساعدة ---

class _GlassContainer extends StatelessWidget {
  final Widget child;
  const _GlassContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(24),
        topRight: Radius.circular(24),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.8),
                Colors.white.withOpacity(0.6),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.4),
              width: 1.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget child;
  const _GlassButton({required this.onPressed, required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.8)),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}
