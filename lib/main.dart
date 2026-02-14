import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:local_auth/local_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Hive Database
  await Hive.initFlutter();
  await Hive.openBox('merchantBox');

  runApp(const SmartApp());
}

class SmartApp extends StatelessWidget {
  const SmartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      debugShowCheckedModeBanner: false,
      theme: CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: Color(0xFF0054A6),
        scaffoldBackgroundColor: CupertinoColors.systemGroupedBackground,
      ),
      home: LoginPage(),
    );
  }
}

// --- CUPERTINO LOGIN PAGE ---
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final Box _box = Hive.box('merchantBox');
  final LocalAuthentication auth = LocalAuthentication();

  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  bool _bioEnabled = false;
  bool _isPasswordVisible = false;
  final Color primaryBlue = const Color(0xFF0054A6);

  @override
  void initState() {
    super.initState();
    // Default to 'admin' as requested
    _userController.text = "admin";
    _bioEnabled = _box.get('bioEnabled', defaultValue: false);

    // Auto-trigger biometrics if enabled
    if (_bioEnabled) {
      Future.delayed(const Duration(milliseconds: 500), _handleBiometricLogin);
    }
  }

  Future<void> _handleBiometricLogin() async {
    try {
      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Scan fingerprint to login',
        options: const AuthenticationOptions(stickyAuth: true),
      );

      if (didAuthenticate && mounted) {
        _navigateToDashboard(bypassCheck: true);
      }
    } on PlatformException catch (e) {
      debugPrint("Bio Error: $e");
    }
  }

  void _navigateToDashboard({bool bypassCheck = false}) {
    // Check for hardcoded credentials: admin / 123
    if (bypassCheck || (_userController.text == "admin" && _passController.text == "123")) {
      Navigator.pushReplacement(
          context,
          CupertinoPageRoute(builder: (context) => const MainTabController())
      );
    } else {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text("Login Failed"),
          content: const Text("Incorrect username or password."),
          actions: [
            CupertinoDialogAction(
              child: const Text("OK"),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: primaryBlue,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 2),
              const Text(
                "Login",
                style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: CupertinoColors.white
                ),
              ),
              const SizedBox(height: 40),

              // Username Field
              _buildCupertinoInput(
                controller: _userController,
                placeholder: "Username",
                icon: CupertinoIcons.person,
              ),
              const SizedBox(height: 25),

              // Password Field
              _buildCupertinoInput(
                controller: _passController,
                placeholder: "Password",
                icon: CupertinoIcons.lock,
                obscureText: !_isPasswordVisible,
                suffix: CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: Icon(
                    _isPasswordVisible ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
                    color: CupertinoColors.white.withOpacity(0.7),
                    size: 18,
                  ),
                  onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                ),
              ),

              const Spacer(flex: 2),

              Center(
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoButton(
                        color: CupertinoColors.white,
                        borderRadius: BorderRadius.circular(30),
                        onPressed: () => _navigateToDashboard(),
                        child: Text(
                            "Login",
                            style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold)
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Fingerprint Button (Shows if enabled in Settings)
                    if (_bioEnabled)
                      GestureDetector(
                        onTap: _handleBiometricLogin,
                        child: const Icon(
                            CupertinoIcons.device_phone_portrait,
                            size: 60,
                            color: CupertinoColors.white
                        ),
                      ),

                    const SizedBox(height: 10),
                    CupertinoButton(
                      child: Text(
                          "Reset Data",
                          style: TextStyle(color: CupertinoColors.white.withOpacity(0.7))
                      ),
                      onPressed: () {
                        _box.clear();
                        setState(() {
                          _bioEnabled = false;
                          _userController.text = "admin";
                          _passController.clear();
                        });
                      },
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCupertinoInput({
    required TextEditingController controller,
    required String placeholder,
    required IconData icon,
    bool obscureText = false,
    Widget? suffix,
  }) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x4DFFFFFF), width: 1)),
      ),
      child: CupertinoTextField(
        controller: controller,
        placeholder: placeholder,
        placeholderStyle: TextStyle(color: CupertinoColors.white.withOpacity(0.5)),
        prefix: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Icon(icon, color: CupertinoColors.white, size: 20),
        ),
        suffix: suffix,
        obscureText: obscureText,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: null,
        style: const TextStyle(color: CupertinoColors.white),
        cursorColor: CupertinoColors.white,
      ),
    );
  }
}

// --- MAIN TAB CONTROLLER ---
class MainTabController extends StatelessWidget {
  const MainTabController({super.key});
  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        backgroundColor: CupertinoColors.systemBackground.withOpacity(0.9),
        activeColor: const Color(0xFF0054A6),
        items: const [
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.house_fill), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.settings), label: 'Settings'),
        ],
      ),
      tabBuilder: (context, index) => index == 0 ? const DashboardPage() : const SettingsPage(),
    );
  }
}

// --- DASHBOARD PAGE ---
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final Box _box = Hive.box('merchantBox');
  double currentLoad = 0.0;
  String _mobileNumber = "0920 318 3773";

  @override
  void initState() {
    super.initState();
    currentLoad = _box.get('balance', defaultValue: 0.0);
    _mobileNumber = _box.get('mobileNumber', defaultValue: "0920 318 3773");
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          const CupertinoSliverNavigationBar(largeTitle: Text('Merchant')),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildAccountCard(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFF27421), Color(0xFFE65100)]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _balanceItem('Load', '₱${currentLoad.toStringAsFixed(2)}', true),
              _balanceItem('Points', '0.00', false),
            ],
          ),
          const SizedBox(height: 20),
          Text(
              'Account • $_mobileNumber',
              style: const TextStyle(color: CupertinoColors.white, fontWeight: FontWeight.bold)
          ),
        ],
      ),
    );
  }

  Widget _balanceItem(String label, String value, bool isLoad) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: CupertinoColors.white.withOpacity(0.8))),
        Row(
          children: [
            Text(value, style: const TextStyle(color: CupertinoColors.white, fontWeight: FontWeight.bold, fontSize: 30)),
            if (isLoad)
              CupertinoButton(
                padding: EdgeInsets.zero,
                child: const Icon(CupertinoIcons.add_circled_solid, color: Color(0xFF00ADEF)),
                onPressed: () async {
                  final amount = await Navigator.push(context, CupertinoPageRoute(builder: (c) => const AddLoadPage()));
                  if (amount != null) {
                    setState(() {
                      currentLoad += double.parse(amount);
                      _box.put('balance', currentLoad);
                    });
                  }
                },
              )
          ],
        ),
      ],
    );
  }
}

// --- SETTINGS PAGE ---
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final Box _box = Hive.box('merchantBox');
  bool _bioEnabled = false;

  @override
  void initState() {
    super.initState();
    _bioEnabled = _box.get('bioEnabled', defaultValue: false);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Settings')),
      child: ListView(
        children: [
          CupertinoListSection.insetGrouped(
            header: const Text("SECURITY"),
            children: [
              CupertinoListTile(
                title: const Text("Biometric Login"),
                subtitle: const Text("Use fingerprint to unlock"),
                trailing: CupertinoSwitch(
                  value: _bioEnabled,
                  onChanged: (val) {
                    setState(() {
                      _bioEnabled = val;
                      _box.put('bioEnabled', val);
                    });
                  },
                ),
              ),
              CupertinoListTile(
                title: const Text("Logout"),
                onTap: () => Navigator.of(context, rootNavigator: true).pushReplacement(
                    CupertinoPageRoute(builder: (_) => const LoginPage())
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- ADD LOAD PAGE (XENDIT INTEGRATED) ---
class AddLoadPage extends StatefulWidget {
  const AddLoadPage({super.key});
  @override
  State<AddLoadPage> createState() => _AddLoadPageState();
}

class _AddLoadPageState extends State<AddLoadPage> {
  final TextEditingController _amountController = TextEditingController(text: '300');
  final LocalAuthentication auth = LocalAuthentication();
  final Box _box = Hive.box('merchantBox');
  bool _isLoading = false;

  Future<void> _processPayment() async {
    if (_amountController.text.isEmpty) return;

    // Biometric Check
    bool bioEnabled = _box.get('bioEnabled', defaultValue: false);
    if (bioEnabled) {
      bool authenticated = await auth.authenticate(
        localizedReason: 'Scan fingerprint to confirm payment',
        options: const AuthenticationOptions(stickyAuth: true),
      );
      if (!authenticated) return;
    }

    await _launchXendit();
  }

  Future<void> _launchXendit() async {
    setState(() => _isLoading = true);

    const String apiKey = 'xnd_development_h1hwGWu8GxQIlaid0rWvMPlgDRYaAP6721G4aLcFa3QiUDUtZg9yKY64vMgBvdEb';
    final String basicAuth = 'Basic ${base64Encode(utf8.encode('$apiKey:'))}';
    final Uri url = Uri.parse('https://api.xendit.co/v2/invoices');

    final body = {
      'external_id': 'inv_${DateTime.now().millisecondsSinceEpoch}',
      'amount': int.parse(_amountController.text),
      'currency': 'PHP',
    };

    try {
      final response = await http.post(
        url,
        headers: {'Authorization': basicAuth, 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          await Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (c) => PaymentWebView(url: data['invoice_url']),
              fullscreenDialog: true,
            ),
          );
          if (mounted) Navigator.pop(context, _amountController.text);
        }
      }
    } catch (e) {
      debugPrint("Xendit Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Add Load')),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CupertinoTextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                prefix: const Padding(padding: EdgeInsets.only(left: 10), child: Text("₱")),
              ),
              const SizedBox(height: 20),
              CupertinoButton.filled(
                onPressed: _isLoading ? null : _processPayment,
                child: _isLoading ? const CupertinoActivityIndicator() : const Text('Pay Now'),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// --- PAYMENT WEBVIEW ---
class PaymentWebView extends StatefulWidget {
  final String url;
  const PaymentWebView({super.key, required this.url});
  @override
  State<PaymentWebView> createState() => _PaymentWebViewState();
}

class _PaymentWebViewState extends State<PaymentWebView> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(onPageFinished: (s) => setState(() => _loading = false)))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text("Payment"),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Text("Done"),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      child: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const Center(child: CupertinoActivityIndicator()),
        ],
      ),
    );
  }
}