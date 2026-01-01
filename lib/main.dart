import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // 2025/12/21 - 웹 플랫폼 체크용 - 작성자: 진원
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:tkbank/providers/auth_provider.dart';
import 'package:tkbank/providers/register_provider.dart';
import 'package:tkbank/providers/seed_event_provider.dart';
import 'package:tkbank/screens/camera/vision_test_screen.dart';
import 'package:tkbank/screens/chatbot/chatbot_screen.dart';
import 'package:tkbank/screens/cs/cs_support_screen.dart';
import 'package:tkbank/screens/event/seed_event_screen.dart';
import 'package:tkbank/screens/member/security_center_screen.dart';
import 'package:tkbank/screens/product/news_analysis_screen.dart';
import 'package:tkbank/services/FcmService.dart';
import 'package:tkbank/screens/member/login_screen.dart';
import 'package:tkbank/services/seed_event_service.dart';
import 'package:tkbank/services/token_storage_service.dart';
import 'package:tkbank/screens/splash_screen.dart';
import 'screens/product/product_main_screen.dart';
import 'screens/member/point_history_screen.dart';
import 'screens/game/game_menu_screen.dart';
import 'package:tkbank/screens/product/join/join_step4_screen.dart';
import 'package:tkbank/screens/product/join/join_step3_screen.dart';
import 'package:tkbank/screens/product/join/join_step2_screen.dart';
import 'package:tkbank/models/product_join_request.dart';
import 'screens/my_page/my_page_screen.dart';
import 'screens/product/interest_calculator_screen.dart';  // ✅ 추가!
import 'package:camera/camera.dart'; // 25.12.23 천수빈
import 'package:permission_handler/permission_handler.dart'; // 25.12.23 천수빈
import 'package:model_viewer_plus/model_viewer_plus.dart'; // 25.12.23 천수빈
import 'package:tkbank/theme/app_colors.dart'; // 25.12.30 천수빈
import 'package:tkbank/widgets/home_menu_bar.dart'; // 25.12.30 천수빈
import 'package:tkbank/core/menu/main_menu_config.dart'; // 25.12.30 천수빈


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR', null);

  // 2025/12/21 - 웹에서는 Firebase 초기화 건너뛰기 - 작성자: 진원
  if (!kIsWeb) {
    await FcmService.init();
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => RegisterProvider()),
        // 2025/12/23 -  금열매 이벤트 Provider 추가 - 작성자: 오서정
        ChangeNotifierProvider(create: (_) => SeedEventProvider(SeedEventService()),),

      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const String baseUrl = 'http://10.0.2.2:8080/busanbank/api';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TK 딸깍은행',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: AppColors.white, // [25.12.29] 전체 배경 연보라색 제거 - 수빈

        // 👇 전체 앱에 폰트 적용!
        fontFamily: 'Pretendard',
      ),
      onGenerateRoute: (settings) {
        if (settings.name == '/product/join/step2') {
          final request = settings.arguments as ProductJoinRequest;
          return MaterialPageRoute(
            builder: (context) => JoinStep2Screen(
              baseUrl: baseUrl,
              request: request,
            ),
          );
        }

        if (settings.name == '/product/join/step3') {
          final request = settings.arguments as ProductJoinRequest;
          return MaterialPageRoute(
            builder: (context) => JoinStep3Screen(request: request),
          );
        }

        if (settings.name == '/product/join/step4') {
          final request = settings.arguments as ProductJoinRequest;
          return MaterialPageRoute(
            builder: (context) => JoinStep4Screen(
              baseUrl: baseUrl,
              request: request,
            ),
          );
        }

        return null;
      },
      home: const SplashScreen(),
    );
  }
}

// 2025.12.23 _ Home Screen 수정 - 수정자: 천수빈
class HomeScreen extends StatefulWidget {
  final String baseUrl;

  const HomeScreen({super.key, required this.baseUrl});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// _HomeScreenState 클래스 수정 (HomeScreen은 그대로)
class _HomeScreenState extends State<HomeScreen> {
  static const double _messageInputHeight = 64.0;

  int _step = 0;
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          setState(() => _isCameraInitialized = false);
        }
        return;
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController?.initialize();

      if (mounted) {
        setState(() => _isCameraInitialized = true);
      }
    } catch (e) {
      print('카메라 초기화 실패: $e');
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _messageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _logout(BuildContext context) async {
    await TokenStorageService().deleteToken();

    if (context.mounted) {
      final authProvider = context.read<AuthProvider>();
      authProvider.logout();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그아웃되었습니다')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isLoggedIn = authProvider.isLoggedIn;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          _buildCameraBackground(),
          _buildMascot(),
          if (_step == 0) _buildGreeting(),
          if (_step == 1) _buildQuestion(),

          // 하단 슬라이드 메뉴
          Positioned(
            bottom: _messageInputHeight + MediaQuery.of(context).padding.bottom,
            left: 0,
            right: 0,
            child: HomeMenuBar(
              menuType: MainMenuType.normal,
              baseUrl: widget.baseUrl,
              onMorePressed: _showAllMenuModal,
            ),
          ),

          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildCameraBackground() {
    if (_isCameraInitialized && _cameraController != null) {
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _cameraController!.value.previewSize!.height,
            height: _cameraController!.value.previewSize!.width,
            child: CameraPreview(_cameraController!),
          ),
        ),
      );
    }

    return Container(
      color: AppColors.gray3,
      child: const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildMascot() {
    final screenHeight = MediaQuery
        .of(context)
        .size
        .height;

    return Positioned(
      top: screenHeight * 0.28,
      left: 0,
      right: 0,
      child: Center(
        child: SizedBox(
          width: 350,
          height: 450,
          child: ModelViewer(
            src: 'assets/models/penguinman_hi.glb',
            alt: "딸깍은행 마스코트",
            autoRotate: false,
            cameraControls: false,
            backgroundColor: Colors.transparent,
          ),
        ),
      ),
    );
  }

  Widget _buildGreeting() {
    final screenHeight = MediaQuery
        .of(context)
        .size
        .height;

    return Positioned(
      top: screenHeight * 0.10,
      left: 24,
      right: 24,
      child: GestureDetector(
        onTap: () => setState(() => _step = 1),
        child: SizedBox(
          height: 180,
          child: Stack(
            children: [
              Image.asset(
                'assets/images/dialog_box.png',
                fit: BoxFit.contain,
                width: double.infinity,
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        '안녕하세요. 저는 딸깍이에요!',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppColors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '탭하여 계속',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: AppColors.gray4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestion() {
    final screenHeight = MediaQuery
        .of(context)
        .size
        .height;

    return Positioned(
      top: screenHeight * 0.1,
      left: 24,
      right: 24,
      child: GestureDetector(
        onTap: () {
          _focusNode.requestFocus();
        },
        child: SizedBox(
          height: 180,
          child: Stack(
            children: [
              Image.asset(
                'assets/images/dialog_box.png',
                fit: BoxFit.contain,
                width: double.infinity,
              ),
              Positioned.fill(
                child: Padding(
                  // 꼬리 때문에 아래 여백을 더 주고, 위 여백을 줄임
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 34),
                  child: Align(
                    alignment: const Alignment(0, 0), // 👈 아래로 살짝 (0.05~0.12 사이 조절)
                    child: const Text(
                      '무엇을 도와드릴까요?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: AppColors.black,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: MediaQuery
              .of(context)
              .padding
              .bottom + 8,
        ),
        decoration: BoxDecoration(
          color: AppColors.white,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  hintText: '딸깍이에게 무엇이든 물어보세요.',
                  hintStyle: TextStyle(color: AppColors.gray4, fontSize: 16),
                  filled: true,
                  fillColor: AppColors.gray2,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                ),
                onSubmitted: (value) {
                  _handleSendMessage(value);
                },
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send, color: AppColors.white),
                onPressed: () {
                  _handleSendMessage(_messageController.text);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSendMessage(String message) {
    if (message
        .trim()
        .isEmpty) return;

    print('AI 챗봇에게 메시지 전송: $message');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ChatbotScreen(),
      ),
    );

    _messageController.clear();
    _focusNode.unfocus();
  }

  // 더보기 모달
  void _showAllMenuModal() {
    final authProvider = context.read<AuthProvider>();
    final isLoggedIn = authProvider.isLoggedIn;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          Container(
            height: MediaQuery
                .of(context)
                .size
                .height * 0.85,
            decoration: const BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // 핸들
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.gray3,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // 타이틀
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Text(
                    '전체 메뉴',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),

                // 메뉴 리스트
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _tossMenuButton('금융상품 보기', Icons.shopping_bag, () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ProductMainScreen(baseUrl: widget.baseUrl),
                            ),
                          );
                        }),
                        _tossMenuButton('금리 계산기', Icons.calculate, () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const InterestCalculatorScreen(),
                            ),
                          );
                        }),
                        _tossMenuButton('금융게임', Icons.games, () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  GameMenuScreen(baseUrl: widget.baseUrl),
                            ),
                          );
                        }),
                        _tossMenuButton('AI 뉴스', Icons.auto_awesome, () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  NewsAnalysisMainScreen(
                                      baseUrl: widget.baseUrl),
                            ),
                          );
                        }),
                        _tossMenuButton('포인트 이력', Icons.stars, () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  PointHistoryScreen(baseUrl: widget.baseUrl),
                            ),
                          );
                        }),
                        _tossMenuButton('고객센터', Icons.support_agent, () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CustomerSupportScreen(),
                            ),
                          );
                        }),

                        if (isLoggedIn) ...[
                          _tossMenuButton('금열매 이벤트', Icons.eco, () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SeedEventScreen(),
                              ),
                            );
                          }),
                          _tossMenuButton('인증센터', Icons.lock_outline, () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SecurityCenterScreen(),
                              ),
                            );
                          }),
                          _tossMenuButton('마이페이지', Icons.person, () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const MyPageScreen(),
                              ),
                            );
                          }),
                        ],

                        _tossMenuButton('OCR 테스트', Icons.camera_alt, () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const VisionTestScreen(),
                            ),
                          );
                        }),

                        const SizedBox(height: 20),

                        // 로그인/로그아웃
                        if (!isLoggedIn)
                          _tossLoginButton()
                        else
                          _tossLogoutButton(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  // 기존 토스 스타일 버튼들은 그대로 유지
  Widget _tossMenuButton(String label, IconData icon, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          splashColor: AppColors.gray1,
          highlightColor: AppColors.gray1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: AppColors.gray3,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.gray2,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: AppColors.primary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.black,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: AppColors.gray4,
                  size: 26,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tossLoginButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const LoginScreen(),
            ),
          );
        },
        borderRadius: BorderRadius.circular(15),
        splashColor: AppColors.primary.withOpacity(0.1),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.login, color: AppColors.white),
              SizedBox(width: 8),
              Text(
                '로그인',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tossLogoutButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {

          final confirm = await showDialog<bool>(
            context: context,
            builder: (dialogContext) =>
                AlertDialog(

                  // 25.12.30 스타일 수정 - 수빈
                  backgroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),

                  title: const Text(
                    '로그아웃',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.black,
                    ),
                  ),

                  content: const Text(
                    '로그아웃 하시겠습니까?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: AppColors.gray5,
                    ),
                  ),

                  actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text(
                        '취소',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.red,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text(
                        '로그아웃',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.gray5,
                        ),
                      ),
                    ),
                  ],
                ),
          );

          if (confirm == true && mounted) { // 👈 context.mounted 대신 mounted
            Navigator.pop(context); // 👈 이 줄 추가! (모달 닫기)
            await _logout(context);
          }
        },
        borderRadius: BorderRadius.circular(15),
        splashColor: AppColors.red.withOpacity(0.1),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: AppColors.red, width: 2),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout, color: AppColors.red),
              SizedBox(width: 8),
              Text(
                '로그아웃',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.red,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 👇 메뉴 아이템 클래스 (HomeScreen 밖에 추가)
class _MenuItem {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  _MenuItem({
    required this.label,
    required this.icon,
    required this.onPressed,
  });
}