import 'dart:async';
import 'package:cure_app/models/ad_banner.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AdsBannerWidget extends StatefulWidget {
  final List<AdBanner> ads;
  const AdsBannerWidget({super.key, required this.ads});

  @override
  State<AdsBannerWidget> createState() => _AdsBannerWidgetState();
}

class _AdsBannerWidgetState extends State<AdsBannerWidget>
    with TickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _indicatorController;
  late final AnimationController _shimmerController;
  late final AnimationController _scaleController;

  Timer? _timer;
  int _currentPage = 0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: 0.88,
      initialPage: 0,
    );

    _indicatorController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );

    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    if (widget.ads.length > 1) {
      _startAutoSlide();
    }
  }

  void _startAutoSlide() {
    _indicatorController.reset();
    _indicatorController.forward();

    _timer = Timer.periodic(const Duration(seconds: 4), (Timer timer) {
      if (!_isDragging && mounted) {
        if (_currentPage < widget.ads.length - 1) {
          _currentPage++;
        } else {
          _currentPage = 0;
        }

        if (_pageController.hasClients) {
          _pageController.animateToPage(
            _currentPage,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOutCubic,
          );
        }

        _indicatorController.reset();
        _indicatorController.forward();
      }
    });
  }

  void _onPanStart() {
    setState(() => _isDragging = true);
    _timer?.cancel();
  }

  void _onPanEnd() {
    setState(() => _isDragging = false);
    if (widget.ads.length > 1) {
      _startAutoSlide();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    _indicatorController.dispose();
    _shimmerController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $urlString');
    }
  }

  Widget _buildShimmerEffect() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                Colors.white.withOpacity(0.4),
                Colors.transparent,
              ],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment(-1.5 + _shimmerController.value * 3, -1.0),
              end: Alignment(1.5 + _shimmerController.value * 3, 1.0),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModernProgressIndicator() {
    if (widget.ads.length <= 1) return const SizedBox.shrink();

    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(widget.ads.length, (index) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            width: index == _currentPage ? 32 : 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: index == _currentPage
                  ? Colors.white
                  : Colors.white.withOpacity(0.4),
              boxShadow: index == _currentPage
                  ? [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: index == _currentPage
                ? AnimatedBuilder(
                    animation: _indicatorController,
                    builder: (context, child) {
                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          gradient: LinearGradient(
                            colors: [
                              Colors.white,
                              Colors.white.withOpacity(0.8),
                              Colors.white.withOpacity(0.6),
                            ],
                            stops: [
                              0.0,
                              _indicatorController.value,
                              1.0,
                            ],
                          ),
                        ),
                      );
                    },
                  )
                : null,
          );
        }),
      ),
    );
  }

  Widget _buildPremiumCard(AdBanner ad, int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        // Classic Silver Frame
        border: Border.all(
          width: 2,
          color: const Color(0xFFE5E5E5),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFF8F8F8),
            const Color(0xFFE8E8E8),
            const Color(0xFFD3D3D3),
            const Color(0xFFE8E8E8),
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ),
        boxShadow: [
          // Outer shadow for depth
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          // Inner highlight
          BoxShadow(
            color: Colors.white.withOpacity(0.8),
            blurRadius: 1,
            offset: const Offset(0, 1),
            spreadRadius: 0,
          ),
          // Subtle silver glow
          BoxShadow(
            color: const Color(0xFFD3D3D3).withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(3),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(21),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(21),
            ),
            child: Stack(
              children: [
                // Main Background Image
                Positioned.fill(
                  child: Image.network(
                    ad.imageUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(21),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFFF8F9FA),
                              const Color(0xFFE9ECEF),
                              const Color(0xFFF8F9FA),
                            ],
                          ),
                        ),
                        child: Stack(
                          children: [
                            _buildShimmerEffect(),
                            const Center(
                              child: SizedBox(
                                width: 32,
                                height: 32,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF007AFF),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(21),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFFFF6B6B).withOpacity(0.1),
                              const Color(0xFFFF8E53).withOpacity(0.1),
                            ],
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            size: 40,
                            color: Color(0xFFFF6B6B),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Subtle Gradient Overlay for Content Readability
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(21),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.0),
                          Colors.black.withOpacity(0.15),
                        ],
                        stops: const [0.6, 1.0],
                      ),
                    ),
                  ),
                ),

                // Premium Glass Effect
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(21),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.15),
                        width: 0.5,
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.05),
                          Colors.transparent,
                          Colors.white.withOpacity(0.02),
                        ],
                      ),
                    ),
                  ),
                ),

                // Sponsored Label
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 0.5,
                      ),
                    ),
                    child: const Text(
                      'ممول',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ads.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 200,
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Stack(
        children: [
          GestureDetector(
            onPanStart: (_) => _onPanStart(),
            onPanEnd: (_) => _onPanEnd(),
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.ads.length,
              physics: const BouncingScrollPhysics(),
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
                if (!_isDragging) {
                  _indicatorController.reset();
                  _indicatorController.forward();
                }
              },
              itemBuilder: (context, index) {
                final ad = widget.ads[index];
                return GestureDetector(
                  onTapDown: (_) {
                    _scaleController.forward();
                  },
                  onTapUp: (_) {
                    _scaleController.reverse();
                    _launchUrl(ad.targetUrl);
                  },
                  onTapCancel: () {
                    _scaleController.reverse();
                  },
                  child: AnimatedBuilder(
                    animation: _scaleController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: 1.0 - (_scaleController.value * 0.03),
                        child: _buildPremiumCard(ad, index),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          _buildModernProgressIndicator(),
        ],
      ),
    );
  }
}
