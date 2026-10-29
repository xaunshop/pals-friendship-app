import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/app_config.dart';
import 'services/backend_service.dart';

const purple = Color(0xFF7357E8);
const dark = Color(0xFF24213A);
const background = Color(0xFFF7F6FC);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (AppConfig.hasBackend) {
    await Supabase.initialize(url: AppConfig.supabaseUrl, anonKey: AppConfig.supabaseAnonKey);
  }
  runApp(const PalsApp());
}

class PalsApp extends StatelessWidget {
  const PalsApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: AppConfig.appName,
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: purple, primary: purple),
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(backgroundColor: background, foregroundColor: dark, elevation: 0, centerTitle: false),
      cardTheme: CardThemeData(color: Colors.white, elevation: 0, margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: const Color(0xFFF0EFF8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      ),
    ),
    home: AppConfig.hasBackend ? const AuthGate() : const BackendSetupScreen(),
  );
}

class BackendSetupScreen extends StatelessWidget {
  const BackendSetupScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(26), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 70, height: 70, decoration: BoxDecoration(color: purple, borderRadius: BorderRadius.circular(23)), child: const Icon(Icons.diversity_3_rounded, color: Colors.white, size: 38)),
        const SizedBox(height: 28),
        Text(AppConfig.appName, style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: dark, letterSpacing: -1.2)),
        const SizedBox(height: 6),
        const Text('Find your people. Keep it friendly.', style: TextStyle(fontSize: 16, color: purple, fontWeight: FontWeight.w600)),
        const SizedBox(height: 24),
        const Text('Your app is built. Connect its backend to enable real accounts, friends, posts, communities and chat across devices.', style: TextStyle(fontSize: 15, height: 1.55, color: dark)),
        const SizedBox(height: 22),
        const _SetupRow(icon: Icons.person_add_alt_1, title: 'Real sign-up and sign-in', subtitle: 'Secure accounts powered by Supabase Auth'),
        const _SetupRow(icon: Icons.dynamic_feed_outlined, title: 'Live social feed', subtitle: 'Posts and likes saved to a shared database'),
        const _SetupRow(icon: Icons.forum_outlined, title: 'Friends and messages', subtitle: 'Requests, communities and conversations'),
        const SizedBox(height: 16),
        Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFFECE8FF), borderRadius: BorderRadius.circular(18)), child: const Text('Setup required: create a Supabase project, run supabase/schema.sql, then add SUPABASE_URL and SUPABASE_ANON_KEY as GitHub Actions repository secrets and rebuild.', style: TextStyle(height: 1.5, color: dark))),
        const SizedBox(height: 12),
        const Text('Only the public anon/publishable key belongs in the Android app. Never add a service-role key.', style: TextStyle(fontSize: 12, color: Colors.black54)),
      ],
    )))),
  );
}

class _SetupRow extends StatelessWidget {
  const _SetupRow({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 15), child: Row(children: [
    Container(width: 46, height: 46, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)), child: Icon(icon, color: purple)),
    const SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: dark)), const SizedBox(height: 3), Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54))])),
  ]));
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override Widget build(BuildContext context) => StreamBuilder<AuthState>(
    stream: Supabase.instance.client.auth.onAuthStateChange,
    builder: (context, snapshot) {
      final user = Supabase.instance.client.auth.currentUser;
      return user == null ? const AuthScreen() : const ProfileCompletionGate();
    },
  );
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final identifier = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  final username = TextEditingController();
  final phone = TextEditingController();
  final otp = TextEditingController();
  DateTime? dob;
  bool signup = false, waitingForOtp = false, busy = false, obscure = true, consent = false, checkingUsername = false;
  bool? usernameAvailable;
  String? error;
  late final BackendService api = BackendService(Supabase.instance.client);

  @override
  void dispose() {
    identifier.dispose(); password.dispose(); name.dispose(); username.dispose(); phone.dispose(); otp.dispose();
    super.dispose();
  }

  Future<void> chooseDob() async {
    final now = DateTime.now();
    final last = DateTime(now.year - 12, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: dob ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: last,
      helpText: 'You must be at least 12 years old',
    );
    if (picked != null && mounted) setState(() { dob = picked; error = null; });
  }

  Future<void> checkUsername() async {
    final value = username.text.trim().replaceFirst(RegExp(r'^@'), '').toLowerCase();
    if (!RegExp(r'^[a-z0-9_]{1,35}$').hasMatch(value)) {
      setState(() { usernameAvailable = false; error = 'Use 1–35 lowercase letters, numbers or underscores.'; });
      return;
    }
    setState(() { checkingUsername = true; usernameAvailable = null; error = null; });
    try {
      final result = await api.usernameAvailable(value);
      if (mounted) setState(() { usernameAvailable = result; if (!result) error = 'That username is unavailable.'; });
    } catch (_) {
      if (mounted) setState(() => error = 'Could not check username. Confirm the LAMA database migration has run.');
    } finally {
      if (mounted) setState(() => checkingUsername = false);
    }
  }

  Future<void> submit() async {
    setState(() { busy = true; error = null; });
    try {
      if (signup) {
        if (name.text.trim().isEmpty) throw Exception('Enter your name.');
        if (!identifier.text.trim().contains('@')) throw Exception('Enter a valid email address.');
        if (password.text.length < 8) throw Exception('Use a password with at least 8 characters.');
        if (!RegExp(r'^[a-z0-9_]{1,35}$').hasMatch(username.text.trim().replaceFirst(RegExp(r'^@'), '').toLowerCase())) throw Exception('Username must be 1–35 characters using letters, numbers or underscores.');
        final phoneDigits = phone.text.replaceAll(RegExp(r'[^0-9]'), '');
        if (phoneDigits.length < 7 || phoneDigits.length > 15) throw Exception('Enter a valid phone number.');
        if (dob == null) throw Exception('Choose your date of birth.');
        if (!consent) throw Exception('Please accept the terms and privacy consent.');
        await api.requestSignupOtp(
          email: identifier.text, password: password.text, displayName: name.text,
          username: username.text, phoneNumber: phone.text, dateOfBirth: dob!, consentAccepted: consent,
        );
        if (mounted) setState(() { waitingForOtp = true; error = 'We sent a verification code to your email. Enter it below.'; });
      } else {
        if (identifier.text.trim().isEmpty) throw Exception('Enter your email or username.');
        if (password.text.isEmpty) throw Exception('Enter your password.');
        await api.signInWithUsernameOrEmail(identifier.text, password.text);
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', '').replaceAll(')', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> verifyOtp() async {
    setState(() { busy = true; error = null; });
    try {
      if (otp.text.trim().length != 6 || int.tryParse(otp.text.trim()) == null) throw Exception('Enter the 6-digit code from your email.');
      await api.verifySignupOtp(email: identifier.text, token: otp.text);
    } catch (e) {
      if (mounted) setState(() => error = 'Could not verify code: ${e.toString().replaceFirst('Exception: ', '').replaceAll(')', '')}');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> resendOtp() async {
    setState(() { busy = true; error = null; });
    try {
      await api.resendSignupOtp(identifier.text);
      if (mounted) setState(() => error = 'A new verification code has been sent.');
    } catch (e) {
      if (mounted) setState(() => error = 'Could not resend code: ${e.toString().replaceFirst('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Center(child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 64, height: 64, decoration: BoxDecoration(color: purple, borderRadius: BorderRadius.circular(21)), child: const Icon(Icons.diversity_3_rounded, color: Colors.white, size: 34)),
          const SizedBox(height: 24),
          Text(waitingForOtp ? 'Check your inbox.' : signup ? 'Join the circle.' : 'Good friends start here.', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: dark, letterSpacing: -.7)),
          const SizedBox(height: 8),
          Text(waitingForOtp ? 'Enter the 6-digit email verification code to activate your LAMA account.' : 'A social space for shared interests, good conversations and platonic friendships.', style: const TextStyle(color: Colors.black54, height: 1.45)),
          const SizedBox(height: 24),
          if (waitingForOtp) ...[
            TextField(controller: otp, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(labelText: 'Email verification code', prefixIcon: Icon(Icons.mark_email_read_outlined))),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, height: 52, child: FilledButton(onPressed: busy ? null : verifyOtp, child: Text(busy ? 'Verifying…' : 'Verify email and continue'))),
            Center(child: TextButton(onPressed: busy ? null : resendOtp, child: const Text('Resend code'))),
          ] else ...[
            if (signup) ...[
              TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(Icons.person_outline))),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: username, autocorrect: false, onChanged: (_) => setState(() => usernameAvailable = null), decoration: const InputDecoration(labelText: 'Username', prefixText: '@'))),
                const SizedBox(width: 8),
                IconButton.filledTonal(onPressed: checkingUsername ? null : checkUsername, tooltip: 'Check username', icon: checkingUsername ? const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)) : const Icon(Icons.check_circle_outline)),
              ]),
              if (usernameAvailable == true) const Padding(padding: EdgeInsets.only(top:5,left:4), child: Text('Username available', style: TextStyle(color: Colors.green, fontSize: 12))),
              const SizedBox(height: 12),
              TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone number (private)', prefixIcon: Icon(Icons.phone_outlined))),
              const SizedBox(height: 12),
              OutlinedButton.icon(onPressed: chooseDob, icon: const Icon(Icons.calendar_month_outlined), label: Text(dob == null ? 'Choose date of birth (private)' : 'Date of birth: ${dob!.day.toString().padLeft(2,'0')}/${dob!.month.toString().padLeft(2,'0')}/${dob!.year}')),
              const SizedBox(height: 8),
              CheckboxListTile(value: consent, onChanged: (v) => setState(() => consent = v ?? false), contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading, title: const Text('I acknowledge and consent', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)), subtitle: const Text('I agree to the Terms of Service and Privacy Policy and confirm my details are accurate.', style: TextStyle(fontSize: 12, height: 1.35))),
              const SizedBox(height: 8),
            ],
            TextField(controller: identifier, keyboardType: signup ? TextInputType.emailAddress : TextInputType.text, autocorrect: false, decoration: InputDecoration(labelText: signup ? 'Email address' : 'Email or username', prefixIcon: const Icon(Icons.mail_outline))),
            const SizedBox(height: 12),
            TextField(controller: password, obscureText: obscure, decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed: () => setState(() => obscure = !obscure), icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined)))),
            if (error != null) ...[
              const SizedBox(height: 12),
              Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: error!.startsWith('We sent') ? const Color(0xFFE8F7EC) : const Color(0xFFFFE9E9), borderRadius: BorderRadius.circular(12)), child: Text(error!, style: TextStyle(color: error!.startsWith('We sent') ? const Color(0xFF176B35) : const Color(0xFF9A2727), fontSize: 13))),
            ],
            const SizedBox(height: 18),
            SizedBox(width: double.infinity, height: 52, child: FilledButton(onPressed: busy ? null : submit, child: busy ? const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)) : Text(signup ? 'Send email verification code' : 'Sign in', style: const TextStyle(fontWeight: FontWeight.w800)))),
            const SizedBox(height: 12),
            Center(child: TextButton(onPressed: busy ? null : () => setState(() { signup = !signup; error = null; waitingForOtp = false; }), child: Text(signup ? 'Already have an account? Sign in' : 'New to LAMA? Create account with email'))),
          ],
          if (error != null && waitingForOtp) ...[
            const SizedBox(height: 10),
            Text(error!, style: const TextStyle(color: purple, fontSize: 13)),
          ],
          const SizedBox(height: 12),
          const Center(child: Text('Be kind • Respect boundaries • Stay safe', style: TextStyle(fontSize: 12, color: Colors.black45))),
        ],
      )),
    ))),
  );
}

class ProfileCompletionGate extends StatefulWidget {
  const ProfileCompletionGate({super.key});
  @override State<ProfileCompletionGate> createState() => _ProfileCompletionGateState();
}
class _ProfileCompletionGateState extends State<ProfileCompletionGate> {
  late Future<bool> future;
  @override void initState() { super.initState(); future = BackendService(Supabase.instance.client).needsProfileCompletion(); }
  void refresh() => setState(() => future = BackendService(Supabase.instance.client).needsProfileCompletion());
  @override Widget build(BuildContext context) => FutureBuilder<bool>(
    future: future,
    builder: (context, s) {
      if (s.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
      if (s.hasError) return Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off_outlined, size: 42, color: purple),
        const SizedBox(height: 12),
        const Text('Your LAMA database setup is incomplete. Run supabase/migrations/20261029_lama_release_readiness.sql in Supabase SQL Editor, then retry.', textAlign: TextAlign.center),
        const SizedBox(height: 12),
        FilledButton(onPressed: refresh, child: const Text('Retry')),
        TextButton(onPressed: () => Supabase.instance.client.auth.signOut(), child: const Text('Sign out')),
      ]))));
      if (s.data == true) return ProfileCompletionScreen(onCompleted: refresh);
      return MainShell(key: ValueKey(Supabase.instance.client.auth.currentUser!.id));
    },
  );
}

class ProfileCompletionScreen extends StatefulWidget {
  const ProfileCompletionScreen({super.key, required this.onCompleted});
  final VoidCallback onCompleted;
  @override State<ProfileCompletionScreen> createState() => _ProfileCompletionScreenState();
}
class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
  final name = TextEditingController();
  final username = TextEditingController();
  final phone = TextEditingController();
  DateTime? dob;
  bool consent = false, busy = false, checking = false;
  bool? available;
  String? error;
  late final BackendService api = BackendService(Supabase.instance.client);

  @override void initState() { super.initState(); loadExisting(); }
  @override void dispose() { name.dispose(); username.dispose(); phone.dispose(); super.dispose(); }
  Future<void> loadExisting() async {
    try {
      final p = await api.myProfile();
      if (!mounted) return;
      setState(() {
        name.text = (p['display_name'] ?? '').toString();
        username.text = (p['username'] ?? '').toString();
        phone.text = (p['phone_number'] ?? '').toString();
        if (p['date_of_birth'] != null) dob = DateTime.tryParse(p['date_of_birth'].toString());
        consent = p['consent_accepted'] == true;
      });
    } catch (_) {}
  }
  Future<void> checkUsername() async {
    setState(() { checking = true; available = null; error = null; });
    try {
      final result = await api.usernameAvailable(username.text);
      if (mounted) setState(() { available = result; if (!result) error = 'That username is unavailable.'; });
    } catch (_) { if (mounted) setState(() => error = 'Could not check username. Run supabase/migrations/20261029_lama_release_readiness.sql in Supabase SQL Editor, then retry.'); }
    finally { if (mounted) setState(() => checking = false); }
  }
  Future<void> chooseDob() async {
    final now = DateTime.now(); final last = DateTime(now.year - 12, now.month, now.day);
    final picked = await showDatePicker(context: context, initialDate: dob ?? DateTime(now.year - 18), firstDate: DateTime(1900), lastDate: last);
    if (picked != null && mounted) setState(() => dob = picked);
  }
  Future<void> save() async {
    setState(() { busy = true; error = null; });
    try {
      if (name.text.trim().isEmpty) throw Exception('Enter your name.');
      if (!RegExp(r'^\+?[0-9 ()-]{7,20}$').hasMatch(phone.text.trim())) throw Exception('Enter a valid phone number.');
      if (dob == null) throw Exception('Choose your date of birth.');
      if (!consent) throw Exception('Please acknowledge and consent before continuing.');
      await api.completeProfile(displayName: name.text, username: username.text, phoneNumber: phone.text, dateOfBirth: dob!, consentAccepted: consent);
      widget.onCompleted();
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', '').replaceAll(')', ''));
    } finally { if (mounted) setState(() => busy = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Complete your LAMA profile'), actions: [TextButton(onPressed: () => api.signOut(), child: const Text('Sign out'))]),
    body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('One last step', style: TextStyle(fontSize:28,fontWeight:FontWeight.w900,color:dark)),
        const SizedBox(height:8),
        const Text('Add the required details to keep your account safe. Your phone number and date of birth are stored separately and only you can read them.', style: TextStyle(color:Colors.black54,height:1.45)),
        const SizedBox(height:20),
        TextField(controller:name,textCapitalization:TextCapitalization.words,decoration:const InputDecoration(labelText:'Name')),
        const SizedBox(height:12),
        Row(children:[Expanded(child:TextField(controller:username,decoration:const InputDecoration(labelText:'Username',prefixText:'@'),onChanged:(_)=>setState(()=>available=null))),IconButton.filledTonal(onPressed:checking?null:checkUsername,icon:checking?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.check_circle_outline))]),
        if(available==true)const Text('Username available',style:TextStyle(color:Colors.green,fontSize:12)),
        const SizedBox(height:12),
        TextField(controller:phone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'Phone number (private)')),
        const SizedBox(height:12),
        OutlinedButton.icon(onPressed:chooseDob,icon:const Icon(Icons.calendar_month_outlined),label:Text(dob==null?'Choose date of birth (private)':'Date of birth: ${dob!.day.toString().padLeft(2,'0')}/${dob!.month.toString().padLeft(2,'0')}/${dob!.year}')),
        const SizedBox(height:10),
        CheckboxListTile(value:consent,onChanged:(v)=>setState(()=>consent=v??false),contentPadding:EdgeInsets.zero,controlAffinity:ListTileControlAffinity.leading,title:const Text('I acknowledge and consent',style:TextStyle(fontWeight:FontWeight.w800,fontSize:13)),subtitle:const Text('I agree to the Terms of Service and Privacy Policy and confirm the information is accurate.',style:TextStyle(fontSize:12,height:1.35))),
        if(error!=null)Padding(padding:const EdgeInsets.only(top:10),child:Text(error!,style:const TextStyle(color:Colors.red))),
        const SizedBox(height:16),
        SizedBox(width:double.infinity,height:52,child:FilledButton(onPressed:busy?null:save,child:busy?const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Text('Save and continue'))),
      ]),
    )))),
  );
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override State<MainShell> createState() => _MainShellState();
}
class _MainShellState extends State<MainShell> {
  int index = 0;
  late final BackendService api = BackendService(Supabase.instance.client);
  String displayName = 'Friend';
  @override void initState() { super.initState(); loadName(); }
  Future<void> loadName() async { try { final p = await api.myProfile(); if (mounted) setState(() => displayName = (p['display_name'] ?? 'Friend').toString()); } catch (_) {} }
  @override Widget build(BuildContext context) {
    final pages = [FeedPage(api: api), DiscoverPage(api: api), CommunitiesPage(api: api), ConversationsPage(api: api), ProfilePage(api: api, onSignOut: api.signOut, onChanged: loadName)];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: index, children: pages)),
      floatingActionButton: index == 0 ? FloatingActionButton.extended(onPressed: () async {
        final controller = TextEditingController();
        final body = await showModalBottomSheet<String>(context: context, isScrollControlled: true, useSafeArea: true, builder: (ctx) => Padding(padding: EdgeInsets.fromLTRB(18, 22, 18, MediaQuery.of(ctx).viewInsets.bottom + 18), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Share with your circle', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)), const SizedBox(height: 14),
          TextField(controller: controller, autofocus: true, maxLines: 5, maxLength: 2000, decoration: const InputDecoration(hintText: 'A thought, a question, a little win...')),
          const SizedBox(height: 12), SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Publish post'))),
        ])));
        if (body != null && body.trim().isNotEmpty) { try { await api.createPost(body); if (mounted) { setState(() => index = 0); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post published!'))); } } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not publish: $e'))); } }
        controller.dispose();
      }, backgroundColor: purple, foregroundColor: Colors.white, icon: const Icon(Icons.add), label: const Text('Post')) : null,
      bottomNavigationBar: NavigationBar(selectedIndex: index, onDestinationSelected: (v) => setState(() => index = v), backgroundColor: Colors.white, indicatorColor: const Color(0xFFE9E4FF), destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people_rounded), label: 'Discover'),
        NavigationDestination(icon: Icon(Icons.diversity_3_outlined), selectedIcon: Icon(Icons.diversity_3), label: 'Groups'),
        NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Chats'),
        NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
      ]),
    );
  }
}

class PageHeader extends StatelessWidget {
  const PageHeader(this.title, {super.key, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(20, 15, 20, 16), child: Row(children: [
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: dark, letterSpacing: -.6)), if (subtitle != null) ...[const SizedBox(height: 4), Text(subtitle!, style: const TextStyle(color: Colors.black54, fontSize: 13))]])),
    if (trailing != null) trailing!,
  ]));
}

String initials(String value) => value.trim().split(RegExp(r'\s+')).take(2).where((e) => e.isNotEmpty).map((e) => e[0].toUpperCase()).join();
String ago(dynamic value) { try { final d = DateTime.parse(value.toString()).toLocal(); final diff = DateTime.now().difference(d); if (diff.inMinutes < 1) return 'now'; if (diff.inHours < 1) return '${diff.inMinutes}m'; if (diff.inDays < 1) return '${diff.inHours}h'; return '${diff.inDays}d'; } catch (_) { return ''; } }
Widget avatar(String name, {double size = 44, String? url}) => CircleAvatar(radius: size / 2, backgroundColor: const Color(0xFFE8E2FF), backgroundImage: url != null && url.isNotEmpty ? NetworkImage(url) : null, child: url == null || url.isEmpty ? Text(initials(name).isEmpty ? 'F' : initials(name), style: const TextStyle(color: purple, fontWeight: FontWeight.w900)) : null);
Widget emptyState(IconData icon, String title, String body) => Padding(padding: const EdgeInsets.all(34), child: Column(children: [Container(width:68,height:68,decoration:BoxDecoration(color:const Color(0xFFECE8FF),borderRadius:BorderRadius.circular(22)),child:Icon(icon,color:purple,size:32)),const SizedBox(height:14),Text(title,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900,color:dark)),const SizedBox(height:6),Text(body,textAlign:TextAlign.center,style:const TextStyle(color:Colors.black54,height:1.4))]));

class FeedPage extends StatefulWidget {
  const FeedPage({super.key, required this.api});
  final BackendService api;
  @override State<FeedPage> createState() => _FeedPageState();
}
class _FeedPageState extends State<FeedPage> {
  late Future<List<Map<String, dynamic>>> future;
  @override void initState() { super.initState(); future = widget.api.posts(); }
  void refresh() => setState(() => future = widget.api.posts());
  @override Widget build(BuildContext context) => RefreshIndicator(onRefresh: () async { refresh(); await future; }, child: ListView(padding: const EdgeInsets.only(bottom: 100), children: [
    PageHeader('Your circle ✨', subtitle: 'A little good in your feed today.', trailing: IconButton(onPressed: refresh, icon: const Icon(Icons.refresh_rounded))),
    Padding(padding: const EdgeInsets.fromLTRB(16,0,16,18), child: Container(padding: const EdgeInsets.all(17), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF7A60ED), Color(0xFF9A83F5)]), borderRadius: BorderRadius.circular(24)), child: const Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Good vibes live here.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 19)), SizedBox(height: 5), Text('Share a win. Ask a question. Be a friend.', style: TextStyle(color: Colors.white, fontSize: 12))])),
      SizedBox(width:12), Icon(Icons.waving_hand_rounded, color: Colors.white, size: 38),
    ]))),
    const Padding(padding: EdgeInsets.fromLTRB(20,0,20,12), child: Text('From the community', style: TextStyle(fontSize:19,fontWeight:FontWeight.w900,color:dark))),
    FutureBuilder<List<Map<String,dynamic>>>(future: future, builder: (context,s) {
      if (s.connectionState == ConnectionState.waiting) return const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()));
      if (s.hasError) return _ErrorCard(message: 'Could not load the feed. Check your database policies and connection.', onRetry: refresh);
      final rows = s.data ?? [];
      if (rows.isEmpty) return emptyState(Icons.forum_outlined, 'Start the conversation', 'Your feed is ready. Be the first to share something with the community.');
      return Column(children: rows.map((p) {
        final author = Map<String,dynamic>.from(p['author'] ?? {});
        final liked = p['liked_by_me'] == true;
        return Card(margin: const EdgeInsets.fromLTRB(16,0,16,12), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [avatar((author['display_name'] ?? 'Friend').toString(), url: author['avatar_url']?.toString()), const SizedBox(width:10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text((author['display_name'] ?? 'Friend').toString(), style: const TextStyle(fontWeight:FontWeight.w900,color:dark)), Text('@${author['username'] ?? 'friend'} · ${ago(p['created_at'])}', style: const TextStyle(color:Colors.black45,fontSize:12))])), TextButton.icon(onPressed: () => _ghostPost(context,p), icon: const Icon(Icons.visibility_off_outlined, size:18), label: const Text('Ghost'), style: TextButton.styleFrom(foregroundColor: Colors.black54, padding: const EdgeInsets.symmetric(horizontal:8)))]),
          const SizedBox(height:10), Text(p['body'].toString(), style: const TextStyle(height:1.5,fontSize:14,color:dark)),
          const SizedBox(height:10), Row(children: [
            IconButton(onPressed: () async { try { await widget.api.toggleLike(p['id'].toString(), liked); refresh(); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Like failed: $e'))); } }, icon: Icon(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: liked ? Colors.pink : dark)),
            Text('${p['likes_count'] ?? 0}', style: const TextStyle(fontWeight:FontWeight.w700)), const SizedBox(width:18), IconButton(tooltip:'Comments', onPressed:()=>_showComments(context,p), icon:const Icon(Icons.chat_bubble_outline,size:20,color:dark)), Text('${p['comments_count'] ?? 0}',style:const TextStyle(fontWeight:FontWeight.w700)),
          ]),
        ])));
      }).toList());
    }),
  ]));
  Future<void> _showComments(BuildContext context, Map<String,dynamic> post) async {
    final controller = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) => Padding(
        padding: EdgeInsets.fromLTRB(16, 18, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: SizedBox(height: MediaQuery.of(ctx).size.height * .68, child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Friendly conversation', style: TextStyle(fontSize:20,fontWeight:FontWeight.w900,color:dark)),
            const SizedBox(height:12),
            Expanded(child: FutureBuilder<List<Map<String,dynamic>>>(
              future: widget.api.comments(post['id'].toString()),
              builder:(context,s){
                if(s.connectionState==ConnectionState.waiting)return const Center(child:CircularProgressIndicator());
                if(s.hasError)return const Center(child:Text('Could not load comments.'));
                final rows=s.data??[];
                if(rows.isEmpty)return const Center(child:Text('No replies yet. Start kindly.'));
                return ListView(children:rows.map((c){final author=Map<String,dynamic>.from(c['author']??{});return ListTile(contentPadding:EdgeInsets.zero,leading:avatar((author['display_name']??'Friend').toString(),size:36),title:Text((author['display_name']??'Friend').toString(),style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text(c['body'].toString()));}).toList());
              },
            )),
            const SizedBox(height:8),
            Row(children:[
              Expanded(child:TextField(controller:controller,maxLength:1000,maxLines:2,decoration:const InputDecoration(hintText:'Write a friendly reply...'))),
              const SizedBox(width:8),
              IconButton.filled(onPressed:()async{final body=controller.text.trim();if(body.isEmpty)return;try{await widget.api.addComment(post['id'].toString(),body);controller.clear();if(mounted){Navigator.pop(ctx);setState(()=>future=widget.api.posts());}}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Comment failed: $e')));}},icon:const Icon(Icons.send),style:IconButton.styleFrom(backgroundColor:purple,foregroundColor:Colors.white)),
            ]),
          ],
        )),
      )),
    );
    controller.dispose();
  }

  Future<void> _ghostPost(BuildContext context, Map<String,dynamic> p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ghost this post?'),
        content: const Text('This post will be hidden from your feed. You can still see it if you choose to unghost it in a future version.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ghost post')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await widget.api.ghostPost(p['id'].toString());
      refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post ghosted and hidden from your feed.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not ghost post: $e')));
    }
  }
}

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key, required this.api});
  final BackendService api;
  @override State<DiscoverPage> createState() => _DiscoverPageState();
}
class _DiscoverPageState extends State<DiscoverPage> {
  late Future<List<Map<String,dynamic>>> future;
  late Future<List<Map<String,dynamic>>> requestsFuture;
  final Set<String> sent = {};
  final search = TextEditingController();
  @override void initState() { super.initState(); future = widget.api.people(); requestsFuture = widget.api.friendRequests(); }
  @override void dispose() { search.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.only(bottom:30), children: [
    PageHeader('Find your people', subtitle:'Friendship starts with shared interests.', trailing:IconButton(onPressed:()=>setState((){future=widget.api.people();requestsFuture=widget.api.friendRequests();}),icon:const Icon(Icons.refresh))),
    Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:TextField(controller:search,onChanged:(_)=>setState((){}),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Search names or usernames'))),
    FutureBuilder<List<Map<String,dynamic>>>(future:requestsFuture,builder:(context,rs){
      if(rs.connectionState==ConnectionState.waiting)return const SizedBox.shrink();
      if(rs.hasError)return const SizedBox.shrink();
      final all=rs.data??[];
      final me=widget.api.user!.id;
      final incoming=all.where((r)=>r['status']=='pending'&&r['addressee_id']==me).toList();
      final accepted=all.where((r)=>r['status']=='accepted').toList();
      final outgoing=all.where((r)=>r['status']=='pending'&&r['requester_id']==me).toList();
      if(incoming.isEmpty&&accepted.isEmpty&&outgoing.isEmpty)return const SizedBox.shrink();
      return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        if(incoming.isNotEmpty)...[
          const Padding(padding:EdgeInsets.fromLTRB(20,20,20,10),child:Text('Friend requests',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900,color:dark))),
          ...incoming.map((r){final p=Map<String,dynamic>.from(r['other']??{});return Card(margin:const EdgeInsets.fromLTRB(16,0,16,8),child:ListTile(leading:avatar((p['display_name']??'Friend').toString()),title:Text((p['display_name']??'Friend').toString(),style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('@${p['username']??'friend'}'),trailing:Wrap(spacing:4,children:[
            IconButton(tooltip:'Decline',onPressed:()async{try{await widget.api.respondFriendRequest(r['id'].toString(),'declined');if(mounted)setState(()=>requestsFuture=widget.api.friendRequests());}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Could not decline: $e')));}},icon:const Icon(Icons.close,color:Colors.redAccent)),
            IconButton(tooltip:'Accept',onPressed:()async{try{await widget.api.respondFriendRequest(r['id'].toString(),'accepted');if(mounted)setState(()=>requestsFuture=widget.api.friendRequests());}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Could not accept: $e')));}},icon:const Icon(Icons.check_circle,color:purple)),
          ])));}),
        ],
        if(accepted.isNotEmpty)...[
          const Padding(padding:EdgeInsets.fromLTRB(20,16,20,10),child:Text('Your friends',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900,color:dark))),
          ...accepted.map((r){final p=Map<String,dynamic>.from(r['other']??{});final otherId=(r['requester_id']==me?r['addressee_id']:r['requester_id']).toString();return Card(margin:const EdgeInsets.fromLTRB(16,0,16,8),child:ListTile(leading:avatar((p['display_name']??'Friend').toString()),title:Text((p['display_name']??'Friend').toString(),style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('@${p['username']??'friend'}'),trailing:IconButton(tooltip:'Message friend',onPressed:()async{try{final id=await widget.api.startConversation(otherId);if(context.mounted)await Navigator.push(context,MaterialPageRoute(builder:(_)=>ChatScreen(api:widget.api,conversationId:id,title:(p['display_name']??'Friend').toString())));if(mounted)setState(()=>requestsFuture=widget.api.friendRequests());}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Could not start chat: $e')));}},icon:const Icon(Icons.chat_bubble_outline,color:purple))));}),
        ],
        if(outgoing.isNotEmpty)Padding(padding:const EdgeInsets.fromLTRB(20,8,20,8),child:Text('${outgoing.length} friend request${outgoing.length==1?'':'s'} waiting for a reply',style:const TextStyle(color:Colors.black45,fontSize:12))),
      ]);
    }),
    const Padding(padding:EdgeInsets.fromLTRB(20,22,20,12),child:Text('People to know',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900,color:dark))),
    FutureBuilder<List<Map<String,dynamic>>>(future:future,builder:(context,s){
      if(s.connectionState==ConnectionState.waiting)return const Padding(padding:EdgeInsets.all(30),child:Center(child:CircularProgressIndicator()));
      if(s.hasError)return _ErrorCard(message:'Could not load people. Try again.',onRetry:()=>setState(()=>future=widget.api.people()));
      final q=search.text.toLowerCase();
      final rows=(s.data??[]).where((p)=>p['display_name'].toString().toLowerCase().contains(q)||p['username'].toString().toLowerCase().contains(q)).toList();
      if(rows.isEmpty)return emptyState(Icons.people_outline,'Your circle starts here','When other people create accounts, they will appear here.');
      return Column(children:rows.map((p){final id=p['id'].toString();return Card(margin:const EdgeInsets.fromLTRB(16,0,16,9),child:Padding(padding:const EdgeInsets.all(12),child:Row(children:[
        avatar(p['display_name'].toString(),url:p['avatar_url']?.toString()),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(p['display_name'].toString(),style:const TextStyle(fontWeight:FontWeight.w900,color:dark)),Text('@${p['username']}',style:const TextStyle(color:Colors.black45,fontSize:12)),if((p['bio']??'').toString().isNotEmpty)Text(p['bio'].toString(),maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:12))])),
        const SizedBox(width:6),FilledButton.tonal(onPressed:sent.contains(id)?null:()async{try{await widget.api.sendFriendRequest(id);if(mounted)setState(()=>sent.add(id));}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Could not send request: $e')));}},child:Text(sent.contains(id)?'Sent':'Add friend')),
      ])));}).toList());
    }),
  ]);
}

class CommunitiesPage extends StatefulWidget {
  const CommunitiesPage({super.key,required this.api});
  final BackendService api;
  @override State<CommunitiesPage> createState()=>_CommunitiesPageState();
}
class _CommunitiesPageState extends State<CommunitiesPage>{
  late Future<List<Map<String,dynamic>>> future;
  @override void initState(){super.initState();future=widget.api.communities();}
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.only(bottom:24),children:[
    PageHeader('Communities',subtitle:'Shared interests. Real belonging.',trailing:IconButton(onPressed:()=>setState(()=>future=widget.api.communities()),icon:const Icon(Icons.refresh))),
    FutureBuilder<List<Map<String,dynamic>>>(future:future,builder:(context,s){
      if(s.connectionState==ConnectionState.waiting)return const Padding(padding:EdgeInsets.all(30),child:Center(child:CircularProgressIndicator()));
      if(s.hasError)return _ErrorCard(message:'Could not load communities. Check your database setup.',onRetry:()=>setState(()=>future=widget.api.communities()));
      final rows=s.data??[];
      if(rows.isEmpty)return emptyState(Icons.diversity_3_outlined,'Communities are on the way','Run the Supabase schema to add starter communities.');
      return Column(children:rows.map((c){final joined=c['joined_by_me']==true;final icon=c['category'].toString().toLowerCase().contains('music')?Icons.headphones: c['category'].toString().toLowerCase().contains('tech')?Icons.code: c['category'].toString().toLowerCase().contains('game')?Icons.sports_esports:Icons.diversity_3;return Card(margin:const EdgeInsets.fromLTRB(16,0,16,10),child:Padding(padding:const EdgeInsets.all(15),child:Row(children:[
        Container(width:54,height:54,decoration:BoxDecoration(color:const Color(0xFFECE8FF),borderRadius:BorderRadius.circular(17)),child:Icon(icon,color:purple,size:26)),const SizedBox(width:13),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(c['name'].toString(),style:const TextStyle(fontWeight:FontWeight.w900,color:dark)),Text(c['category'].toString(),style:const TextStyle(color:purple,fontSize:12,fontWeight:FontWeight.w700)),const SizedBox(height:4),Text(c['description'].toString(),style:const TextStyle(fontSize:12,color:Colors.black54))])),const SizedBox(width:8),OutlinedButton(onPressed:()async{try{await widget.api.toggleCommunity(c['id'].toString(),joined);if(mounted)setState(()=>future=widget.api.communities());}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Could not update membership: $e')));}},child:Text(joined?'Joined ✓':'Join')),
      ])));}).toList());
    }),
  ]);
}

class ConversationsPage extends StatefulWidget {
  const ConversationsPage({super.key,required this.api});
  final BackendService api;
  @override State<ConversationsPage> createState()=>_ConversationsPageState();
}
class _ConversationsPageState extends State<ConversationsPage>{
  late Future<List<Map<String,dynamic>>> future;
  @override void initState(){super.initState();future=widget.api.conversations();}
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.only(bottom:24),children:[
    PageHeader('Messages',subtitle:'Good conversations live here.',trailing:IconButton(onPressed:()=>setState(()=>future=widget.api.conversations()),icon:const Icon(Icons.refresh))),
    FutureBuilder<List<Map<String,dynamic>>>(future:future,builder:(context,s){
      if(s.connectionState==ConnectionState.waiting)return const Padding(padding:EdgeInsets.all(30),child:Center(child:CircularProgressIndicator()));
      if(s.hasError)return _ErrorCard(message:'Could not load chats. Check your database policies.',onRetry:()=>setState(()=>future=widget.api.conversations()));
      final rows=s.data??[];
      if(rows.isEmpty)return emptyState(Icons.chat_bubble_outline,'Say hello to a friend','Send a friend request first, then start a conversation from Discover.');
      return Column(children:rows.map((c)=>ListTile(contentPadding:const EdgeInsets.symmetric(horizontal:20,vertical:8),leading:avatar(c['other_name'].toString()),title:Text(c['other_name'].toString(),style:const TextStyle(fontWeight:FontWeight.w900)),subtitle:Text(c['last_message'].toString(),maxLines:1,overflow:TextOverflow.ellipsis),trailing:const Icon(Icons.chevron_right),onTap:()async{final id=c['id'].toString();await Navigator.push(context,MaterialPageRoute(builder:(_)=>ChatScreen(api:widget.api,conversationId:id,title:c['other_name'].toString())));if(mounted)setState(()=>future=widget.api.conversations());})).toList());
    }),
  ]);
}

class ChatScreen extends StatefulWidget{
  const ChatScreen({super.key,required this.api,required this.conversationId,required this.title});
  final BackendService api;final String conversationId;final String title;
  @override State<ChatScreen> createState()=>_ChatScreenState();
}
class _ChatScreenState extends State<ChatScreen>{
  final controller=TextEditingController();bool sending=false;
  @override void dispose(){controller.dispose();super.dispose();}
  Future<void> send()async{final text=controller.text.trim();if(text.isEmpty||sending)return;setState(()=>sending=true);try{await widget.api.sendMessage(widget.conversationId,text);controller.clear();if(mounted)setState((){});}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Message failed: $e')));}finally{if(mounted)setState(()=>sending=false);}}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(widget.title,style:const TextStyle(fontWeight:FontWeight.w900))),body:Column(children:[
    Expanded(child:StreamBuilder<List<Map<String,dynamic>>>(stream:Supabase.instance.client.from('messages').stream(primaryKey:['id']).eq('conversation_id',widget.conversationId).order('created_at'),builder:(context,s){
      if(s.hasError)return const Center(child:Text('Could not load messages.'));
      final rows=s.data??[];
      if(rows.isEmpty)return emptyState(Icons.waving_hand_outlined,'Start with hello','Keep it friendly and respect each other’s boundaries.');
      return ListView(padding:const EdgeInsets.all(16),children:rows.map((m){final mine=m['sender_id']==widget.api.user!.id;return Align(alignment:mine?Alignment.centerRight:Alignment.centerLeft,child:Container(constraints:const BoxConstraints(maxWidth:300),margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.symmetric(horizontal:14,vertical:11),decoration:BoxDecoration(color:mine?purple:Colors.white,borderRadius:BorderRadius.circular(18)),child:Text(m['body'].toString(),style:TextStyle(color:mine?Colors.white:dark,height:1.35))));}).toList());
    })),
    SafeArea(top:false,child:Padding(padding:const EdgeInsets.fromLTRB(12,8,12,12),child:Row(children:[Expanded(child:TextField(controller:controller,minLines:1,maxLines:4,decoration:const InputDecoration(hintText:'Write a friendly message...'))),const SizedBox(width:8),IconButton.filled(onPressed:sending?null:send,style:IconButton.styleFrom(backgroundColor:purple,foregroundColor:Colors.white),icon:sending?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Icon(Icons.send_rounded))]))),
  ]));
}

class ProfilePage extends StatefulWidget{
  const ProfilePage({super.key,required this.api,required this.onSignOut,required this.onChanged});
  final BackendService api;final Future<void> Function() onSignOut;final Future<void> Function() onChanged;
  @override State<ProfilePage> createState()=>_ProfilePageState();
}
class _ProfilePageState extends State<ProfilePage>{
  late Future<Map<String,dynamic>> future;bool private=false;
  @override void initState(){super.initState();future=widget.api.myProfile();}
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.only(bottom:24),children:[
    PageHeader('Your profile',subtitle:'Your corner of the community.',trailing:IconButton(onPressed:()=>setState(()=>future=widget.api.myProfile()),icon:const Icon(Icons.refresh))),
    FutureBuilder<Map<String,dynamic>>(future:future,builder:(context,s){
      if(s.connectionState==ConnectionState.waiting)return const Padding(padding:EdgeInsets.all(30),child:Center(child:CircularProgressIndicator()));
      if(s.hasError)return _ErrorCard(message:'Could not load your profile.',onRetry:()=>setState(()=>future=widget.api.myProfile()));
      final p=s.data??{};private=p['is_private']==true;
      return Column(children:[
        const SizedBox(height:10),avatar((p['display_name']??'Friend').toString(),size:94,url:p['avatar_url']?.toString()),const SizedBox(height:13),
        Text((p['display_name']??'Friend').toString(),style:const TextStyle(fontSize:24,fontWeight:FontWeight.w900,color:dark)),
        Text('@${p['username']??'friend'}',style:const TextStyle(color:purple,fontWeight:FontWeight.w700)),
        Padding(padding:const EdgeInsets.fromLTRB(30,10,30,22),child:Text((p['bio']??'Add a little introduction about yourself.').toString(),textAlign:TextAlign.center,style:const TextStyle(color:Colors.black54,height:1.45))),
        Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:Card(child:Column(children:[
          ListTile(
            leading: const Icon(Icons.lock_outline, color: purple),
            title: const Text('Private details — only you can see these'),
            subtitle: Text('Phone: ${(p['phone_number'] ?? 'Not added').toString()}\\nDate of birth: ${(p['date_of_birth'] ?? 'Not added').toString()}'),
            isThreeLine: true,
          ),
          const Divider(height:1),
          ListTile(leading:const Icon(Icons.edit_outlined,color:purple),title:const Text('Edit profile'),trailing:const Icon(Icons.chevron_right),onTap:()=>edit(p)),
          SwitchListTile(secondary:const Icon(Icons.lock_outline,color:purple),title:const Text('Private profile'),subtitle:const Text('Control your visibility in the community'),value:private,onChanged:(v)async{try{await widget.api.updateProfile(displayName:(p['display_name']??'Friend').toString(),bio:(p['bio']??'').toString(),username:(p['username']??'friend').toString(),isPrivate:v);if(mounted)setState(()=>future=widget.api.myProfile());}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Could not update privacy: $e')));}}),
          ListTile(leading:const Icon(Icons.shield_outlined,color:purple),title:const Text('Safety & community rules'),subtitle:const Text('Friendship only. No harassment or spam.'),onTap:()=>showAboutDialog(context:context,applicationName:AppConfig.appName,children:const[Text('This community is for platonic friendships and shared interests. Block and report harmful behavior. Do not share passwords, financial details or your home address.') ])),
          ListTile(leading:const Icon(Icons.logout,color:Colors.redAccent),title:const Text('Sign out'),onTap:()async{await widget.onSignOut();}),
        ]))),
      ]);
    }),
  ]);
  Future<void> edit(Map<String,dynamic> p)async{
    final name=TextEditingController(text:(p['display_name']??'').toString());final username=TextEditingController(text:(p['username']??'').toString());final bio=TextEditingController(text:(p['bio']??'').toString());
    final save=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Edit profile'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,decoration:const InputDecoration(labelText:'Display name')),const SizedBox(height:10),TextField(controller:username,decoration:const InputDecoration(labelText:'Username')),const SizedBox(height:10),TextField(controller:bio,maxLines:3,decoration:const InputDecoration(labelText:'Bio (240 characters max)'))])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Save'))]));
    if(save==true){try{await widget.api.updateProfile(displayName:name.text,bio:bio.text,username:username.text,isPrivate:private);if(mounted)setState(()=>future=widget.api.myProfile());await widget.onChanged();}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Profile update failed: $e')));}}
    name.dispose();username.dispose();bio.dispose();
  }
}

class _ErrorCard extends StatelessWidget{
  const _ErrorCard({required this.message,required this.onRetry});final String message;final VoidCallback onRetry;
  @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.all(18),child:Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(20)),child:Column(children:[const Icon(Icons.cloud_off_outlined,color:purple,size:34),const SizedBox(height:10),Text(message,textAlign:TextAlign.center,style:const TextStyle(color:dark,height:1.4)),const SizedBox(height:12),OutlinedButton(onPressed:onRetry,child:const Text('Try again'))])));
}
