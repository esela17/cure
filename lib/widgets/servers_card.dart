import 'package:flutter/material.dart';
import 'package:cure_app/models/service.dart';
import 'package:cure_app/utils/constants.dart';

class ServiceCard extends StatelessWidget {
  final Service service;
  final bool isSelected;
  final ValueChanged<bool?> onCheckboxChanged;
  final VoidCallback? onTap;

  const ServiceCard({
    super.key,
    required this.service,
    required this.isSelected,
    required this.onCheckboxChanged,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap, // ✅ لو عايز تفعل التنقل بعدين
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ✅ صورة الخدمة
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  service.imageUrl,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey[200],
                    child: const Icon(Icons.broken_image,
                        color: Colors.grey, size: 40),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // ✅ تفاصيل الخدمة
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: kPrimaryColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${service.price.toStringAsFixed(2)} جنيه مصري',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color.fromARGB(255, 99, 251, 5),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // ✅ Checkbox
              Checkbox(
                value: isSelected,
                onChanged: onCheckboxChanged,
                activeColor: kPrimaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
