// lib/screens/home_screen.dart

import 'package:cure_app/providers/cart_provider.dart';
import 'package:cure_app/providers/servers_provider.dart';
import 'package:cure_app/providers/ads_provider.dart';
import 'package:cure_app/providers/categories_provider.dart';
import 'package:cure_app/providers/active_order_provider.dart';
import 'package:cure_app/utils/constants.dart';
import 'package:cure_app/widgets/ads_banner_widget.dart';
import 'package:cure_app/widgets/category_shortcut_grid.dart';
import 'package:cure_app/widgets/empty_state.dart';
import 'package:cure_app/widgets/error_message.dart';
import 'package:cure_app/widgets/loading_indicator.dart';
import 'package:cure_app/widgets/servers_card.dart';
import 'package:cure_app/widgets/active_order_banner.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ✅ تم تحويلها إلى StatelessWidget لأنها لم تعد بحاجة لإدارة حالة خاصة بها
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ✅ يمكن استدعاء refreshActiveOrder هنا بأمان
    // Provider سيمنع استدعائها في كل مرة يتم فيها إعادة بناء الواجهة
    Provider.of<ActiveOrderProvider>(context, listen: false)
        .refreshActiveOrder();

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: Consumer2<CartProvider, ActiveOrderProvider>(
        builder: (context, cartProvider, activeOrderProvider, child) {
          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  SliverAppBar(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
                    title: const Text(
                      'الخدمات المتاحة',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    floating: true,
                    snap: true,
                    elevation: 4,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(bottom: Radius.circular(30)),
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.history),
                        tooltip: 'سجل الطلبات',
                        onPressed: () {
                          Navigator.pushNamed(context, ordersRoute);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.account_circle_rounded),
                        tooltip: 'الملف الشخصي',
                        onPressed: () {
                          Navigator.pushNamed(context, profileRoute);
                        },
                      ),
                    ],
                  ),
                  SliverToBoxAdapter(
                    child: Consumer<AdsProvider>(
                      builder: (context, adsProvider, _) {
                        if (adsProvider.ads.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 0.0),
                          child: AdsBannerWidget(ads: adsProvider.ads),
                        );
                      },
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Consumer<CategoriesProvider>(
                      builder: (context, categoriesProvider, _) {
                        if (categoriesProvider.categories.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return const CategoryShortcutGrid();
                      },
                    ),
                  ),
                  _buildServicesList(),
                ],
              ),
              if (activeOrderProvider.activeOrder != null)
                Positioned(
                  bottom: cartProvider.cartItems.isNotEmpty ? 100 : 20,
                  left: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        '/order-tracking',
                        arguments: activeOrderProvider.activeOrder!.id,
                      );
                    },
                    child: ActiveOrderBanner(
                      order: activeOrderProvider.activeOrder!,
                    ),
                  ),
                ),
              if (cartProvider.cartItems.isNotEmpty)
                _buildFloatingCartBanner(cartProvider, context),
            ],
          );
        },
      ),
    );
  }

  Widget _buildServicesList() {
    return Consumer2<ServicesProvider, CartProvider>(
      builder: (context, servicesProvider, cartProvider, child) {
        if (servicesProvider.isLoading) {
          return const SliverFillRemaining(child: LoadingIndicator());
        } else if (servicesProvider.errorMessage != null) {
          return SliverFillRemaining(
            child: ErrorMessage(message: servicesProvider.errorMessage!),
          );
        } else if (servicesProvider.availableServices.isEmpty) {
          return const SliverFillRemaining(
            child: EmptyState(
              message: 'لا توجد خدمات متاحة حالياً.',
              icon: Icons.medical_services_outlined,
            ),
          );
        } else {
          return SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final service = servicesProvider.availableServices[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: ServiceCard(
                      service: service,
                      isSelected: cartProvider.isServiceSelected(service),
                      onCheckboxChanged: (bool? selected) {
                        cartProvider.toggleServiceSelection(service);
                      },
                    ),
                  );
                },
                childCount: servicesProvider.availableServices.length,
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildFloatingCartBanner(
      CartProvider cartProvider, BuildContext context) {
    return Positioned(
      bottom: 20,
      left: 10,
      right: 10,
      child: GestureDetector(
        onTap: () {
          Navigator.pushNamed(context, cartRoute);
        },
        child: Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: kPrimaryColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 15,
                offset: const Offset(0, 5),
              )
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${cartProvider.cartItems.length} خدمة في السلة',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'الإجمالي: ${cartProvider.totalPrice.toStringAsFixed(2)} جنيه',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              const Row(
                children: [
                  Text(
                    'عرض السلة',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
