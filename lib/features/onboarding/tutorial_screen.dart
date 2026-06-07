import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/device_service.dart';

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  static const _pages = [
    _TutorialPage(
      step: '1',
      title: 'Пополните баланс',
      description: 'Зайдите в профиль, нажмите пополнить\nи оплатите удобным вам способом',
      image: 'assets/images/screen1.jpg',
    ),
    _TutorialPage(
      step: '2',
      title: 'Включите VPN',
      description: 'Теперь вернитесь к тумблеру\nи нажмите на тумблер',
      image: 'assets/images/screen2.jpg',
    ),
    _TutorialPage(
      step: '3',
      title: 'Разрешите подключение',
      description: 'Дайте разрешение в появившемся окне\nнастроек вашего устройства',
      image: 'assets/images/screen3.jpg',
    ),
    _TutorialPage(
      step: '4',
      title: 'Вы делаете мир лучше',
      description: 'Пользуйтесь, и не забывайте что 20% дохода\nидет на благотворительность,\nи вы делаете этот мир лучше',
      image: 'assets/images/screen4.jpg',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() async {
    if (_currentPage < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } else {
      await DeviceService.markOnboardingDone();
      if (mounted) context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            // Logo
            const Text(
              'PAPAHA VPN',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 40),
            // Pages
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _pages.length,
                itemBuilder: (_, i) => _buildPage(_pages[i]),
              ),
            ),
            // Dots
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (i) {
                  final isActive = i == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: isActive
                          ? Colors.white
                          : Colors.white.withOpacity(0.2),
                    ),
                  );
                }),
              ),
            ),
            // Button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _next,
                  child: Text(
                    _currentPage < _pages.length - 1 ? 'Далее' : 'Начать',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(_TutorialPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Screenshot — адаптивная высота, не переполняет экран
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300, maxWidth: 200),
            child: AspectRatio(
              aspectRatio: 9 / 16,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF2A2A2A)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.asset(
                    page.image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFF1A1A1A),
                      child: Center(
                        child: Text(
                          page.step,
                          style: const TextStyle(
                              color: Color(0xFF333333),
                              fontSize: 48,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            page.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF666666),
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _TutorialPage {
  final String step;
  final String title;
  final String description;
  final String image;

  const _TutorialPage({
    required this.step,
    required this.title,
    required this.description,
    required this.image,
  });
}
