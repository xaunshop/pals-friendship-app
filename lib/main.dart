import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(PalsApp(prefs: prefs));
}

const ink = Color(0xFF20203A);
const violet = Color(0xFF7157E8);
const canvas = Color(0xFFF7F6FC);

class PalsApp extends StatelessWidget {
  const PalsApp({super.key, required this.prefs});
  final SharedPreferences prefs;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: AppConfig.appName,
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: violet, primary: violet),
      scaffoldBackgroundColor: canvas,
      appBarTheme: const AppBarTheme(backgroundColor: canvas, foregroundColor: ink, elevation: 0),
      cardTheme: CardThemeData(color: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: const Color(0xFFF0EFF7),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    ),
    home: HomeShell(prefs: prefs),
  );
}

class SocialPost {
  SocialPost({required this.author, required this.handle, required this.initials, required this.color, required this.body, required this.time, this.likes = 0, this.comments = 0, this.liked = false});
  final String author, handle, initials, body, time;
  final Color color;
  int likes, comments;
  bool liked;
}
class Community {
  Community(this.name, this.category, this.description, this.members, this.icon, {this.joined = false});
  final String name, category, description;
  int members;
  final IconData icon;
  bool joined;
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.prefs});
  final SharedPreferences prefs;
  @override State<HomeShell> createState() => _HomeShellState();
}
class _HomeShellState extends State<HomeShell> {
  int tab = 0;
  String displayName = 'Alex Morgan';
  String bio = 'Curious mind. Music, tech and good conversations.';
  final composer = TextEditingController();
  late final List<SocialPost> posts = [
    SocialPost(author:'Maya Chen', handle:'@mayamakes', initials:'MC', color:const Color(0xFFFFD9C8), body:'Started learning guitar this week 🎸 What song should a total beginner learn first?', time:'12 min', likes:18, comments:6),
    SocialPost(author:'Dev Patel', handle:'@devbuilds', initials:'DP', color:const Color(0xFFDCD7FF), body:'Tiny win: finally shipped my first personal website! Happy to share what I learned with anyone starting out.', time:'38 min', likes:32, comments:9),
    SocialPost(author:'Sam Rivera', handle:'@samoutside', initials:'SR', color:const Color(0xFFD5F2DE), body:'Weekend challenge: get outside, take one photo of something beautiful, and share the story behind it. 🌿', time:'1 hr', likes:24, comments:4),
  ];
  late final List<Community> communities = [
    Community('Creative Corner','Art & design','Share your work, prompts and creative process.',1240,Icons.palette_outlined,joined:true),
    Community('Study Buddies','Learning','Study sessions, accountability and helpful notes.',2860,Icons.menu_book_outlined),
    Community('Game Night','Gaming','Find teammates for casual games and weekly events.',1940,Icons.sports_esports_outlined,joined:true),
    Community('Code Together','Technology','Build projects, solve bugs and learn in public.',3280,Icons.code),
    Community('Music People','Music','Discover artists and talk instruments, playlists and gigs.',980,Icons.headphones_outlined),
    Community('Outside Club','Outdoors','Walks, hikes, photography and fresh-air plans.',760,Icons.park_outlined),
  ];
  final friends = const [
    {'name':'Maya Chen','handle':'@mayamakes','initials':'MC','interest':'Music · Art'},
    {'name':'Dev Patel','handle':'@devbuilds','initials':'DP','interest':'Coding · Design'},
    {'name':'Sam Rivera','handle':'@samoutside','initials':'SR','interest':'Outdoors · Photos'},
    {'name':'Jordan Lee','handle':'@jordanplays','initials':'JL','interest':'Gaming · Movies'},
  ];
  final Set<String> friendRequests = {};
  final chats = <Map<String,String>>[
    {'name':'Maya Chen','message':'Thanks for the song suggestions!','initials':'MC','time':'2m'},
    {'name':'Code Together','message':'Jordan: I pushed the fix ✨','initials':'CT','time':'18m'},
    {'name':'Dev Patel','message':'That portfolio looks great!','initials':'DP','time':'1h'},
  ];
  @override void dispose() { composer.dispose(); super.dispose(); }
  void toast(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s),behavior:SnackBarBehavior.floating));
  String initialsFor(String name) => name.trim().split(RegExp(r'\s+')).take(2).map((e)=>e.isNotEmpty?e[0].toUpperCase():'').join();
  void createPost() {
    final text = composer.text.trim();
    if (text.isEmpty) { toast('Write something before posting.'); return; }
    setState(() { posts.insert(0,SocialPost(author:displayName,handle:'@you',initials:initialsFor(displayName),color:const Color(0xFFE0DAFF),body:text,time:'now')); composer.clear(); tab=0; });
    FocusScope.of(context).unfocus(); toast('Your post is live on this device.');
  }
  @override Widget build(BuildContext context) {
    final pages = [feedPage(), discoverPage(), communitiesPage(), messagesPage(), profilePage()];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index:tab,children:pages)),
      floatingActionButton: tab==0 ? FloatingActionButton.extended(onPressed:openComposer,backgroundColor:violet,foregroundColor:Colors.white,icon:const Icon(Icons.add),label:const Text('Post')) : null,
      bottomNavigationBar: NavigationBar(selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),backgroundColor:Colors.white,indicatorColor:const Color(0xFFE9E4FF),destinations:const [
        NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home),label:'Home'),
        NavigationDestination(icon:Icon(Icons.people_outline),selectedIcon:Icon(Icons.people),label:'Discover'),
        NavigationDestination(icon:Icon(Icons.diversity_3_outlined),selectedIcon:Icon(Icons.diversity_3),label:'Groups'),
        NavigationDestination(icon:Icon(Icons.chat_bubble_outline),selectedIcon:Icon(Icons.chat_bubble),label:'Chats'),
        NavigationDestination(icon:Icon(Icons.person_outline),selectedIcon:Icon(Icons.person),label:'Profile'),
      ]),
    );
  }
  Widget header(String title,{String? subtitle,Widget? action}) => Padding(
    padding:const EdgeInsets.fromLTRB(20,14,20,12),
    child:Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:27,fontWeight:FontWeight.w800,color:ink,letterSpacing:-.6)),if(subtitle!=null)...[const SizedBox(height:4),Text(subtitle,style:TextStyle(color:Colors.grey.shade600,fontSize:13))]])),if(action!=null)action]),
  );
  Widget feedPage() => CustomScrollView(slivers:[
    SliverToBoxAdapter(child:header('Hey, ${displayName.split(' ').first} 👋',subtitle:'A little good in your feed today.',action:CircleAvatar(backgroundColor:const Color(0xFFE6E0FF),child:Text(initialsFor(displayName),style:const TextStyle(color:violet,fontWeight:FontWeight.bold))))),
    SliverToBoxAdapter(child:SizedBox(height:126,child:ListView(scrollDirection:Axis.horizontal,padding:const EdgeInsets.symmetric(horizontal:16),children:[
      story('Your story','＋',const Color(0xFFE9E4FF),onTap:openComposer),story('Maya','MC',const Color(0xFFFFD9C8)),story('Dev','DP',const Color(0xFFDCD7FF)),story('Sam','SR',const Color(0xFFD5F2DE)),story('Jordan','JL',const Color(0xFFFFE6A8)),
    ]))),
    SliverToBoxAdapter(child:Padding(padding:const EdgeInsets.fromLTRB(20,10,20,8),child:Row(children:[const Text('Your community',style:TextStyle(fontSize:19,fontWeight:FontWeight.w800,color:ink)),const Spacer(),TextButton(onPressed:()=>setState(()=>tab=2),child:const Text('Explore groups'))]))),
    SliverToBoxAdapter(child:SizedBox(height:92,child:ListView(scrollDirection:Axis.horizontal,padding:const EdgeInsets.symmetric(horizontal:16),children:communities.where((c)=>c.joined).map(miniCommunity).toList()))),
    SliverToBoxAdapter(child:Padding(padding:const EdgeInsets.fromLTRB(20,14,20,8),child:const Text('Happening in your circles',style:TextStyle(fontSize:19,fontWeight:FontWeight.w800,color:ink)))),
    SliverList(delegate:SliverChildBuilderDelegate((context,index)=>postCard(posts[index]),childCount:posts.length)),
    const SliverToBoxAdapter(child:SizedBox(height:90)),
  ]);
  Widget story(String label,String initials,Color color,{VoidCallback? onTap}) => GestureDetector(onTap:onTap??()=>toast('$label’s story is a demo preview.'),child:Container(width:76,margin:const EdgeInsets.only(right:12),child:Column(children:[
    Container(width:66,height:66,padding:const EdgeInsets.all(3),decoration:BoxDecoration(shape:BoxShape.circle,border:Border.all(color:violet,width:2)),child:CircleAvatar(backgroundColor:color,child:Text(initials,style:const TextStyle(color:ink,fontWeight:FontWeight.w800,fontSize:17)))),
    const SizedBox(height:7),Text(label,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w600),maxLines:1,overflow:TextOverflow.ellipsis),
  ])));
  Widget miniCommunity(Community c) => Container(width:178,margin:const EdgeInsets.only(right:10),padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(18)),child:Row(children:[Container(width:42,height:42,decoration:BoxDecoration(color:const Color(0xFFEDE9FF),borderRadius:BorderRadius.circular(13)),child:Icon(c.icon,color:violet)),const SizedBox(width:9),Expanded(child:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.start,children:[Text(c.name,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:12),maxLines:1,overflow:TextOverflow.ellipsis),Text('${compact(c.members)} members',style:TextStyle(color:Colors.grey.shade500,fontSize:11))]))]));
  Widget postCard(SocialPost p) => Card(margin:const EdgeInsets.fromLTRB(16,6,16,10),child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[CircleAvatar(backgroundColor:p.color,child:Text(p.initials,style:const TextStyle(color:ink,fontWeight:FontWeight.bold))),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(p.author,style:const TextStyle(fontWeight:FontWeight.w800)),Text('${p.handle} · ${p.time} ago',style:TextStyle(color:Colors.grey.shade500,fontSize:12))])),IconButton(onPressed:()=>showPostMenu(p),icon:const Icon(Icons.more_horiz))]),
    const SizedBox(height:10),Text(p.body,style:const TextStyle(fontSize:14,height:1.45)),
    const SizedBox(height:10),Row(children:[IconButton(onPressed:()=>setState(()=>{p.liked=!p.liked;p.likes+=p.liked?1:-1;}),icon:Icon(p.liked?Icons.favorite:Icons.favorite_border,color:p.liked?Colors.pink:ink)),Text('${p.likes}'),const SizedBox(width:18),IconButton(onPressed:()=>comments(p),icon:const Icon(Icons.chat_bubble_outline)),Text('${p.comments}'),const Spacer(),IconButton(onPressed:()=>toast('Post saved on this device (demo).'),icon:const Icon(Icons.bookmark_border))]),
  ])));
  void showPostMenu(SocialPost p) => showModalBottomSheet(context:context,builder:(ctx)=>SafeArea(child:Column(mainAxisSize:MainAxisSize.min,children:[
    ListTile(leading:const Icon(Icons.flag_outlined),title:const Text('Report post'),onTap:(){Navigator.pop(ctx);report(p.author);}),
    ListTile(leading:const Icon(Icons.block),title:const Text('Block account'),onTap:(){Navigator.pop(ctx);confirmBlock(p.author);}),
    ListTile(leading:const Icon(Icons.close),title:const Text('Cancel'),onTap:()=>Navigator.pop(ctx)),
  ])));
  Widget discoverPage() => ListView(padding:const EdgeInsets.only(bottom:24),children:[
    header('Find your people',subtitle:'Make friends around shared interests.'),
    Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:TextField(onChanged:(_)=>setState((){}),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Search people and interests'))),
    const Padding(padding:EdgeInsets.fromLTRB(20,20,20,8),child:Text('People you may know',style:TextStyle(fontSize:19,fontWeight:FontWeight.w800))),
    ...friends.map((f){final sent=friendRequests.contains(f['handle']);return Card(margin:const EdgeInsets.fromLTRB(16,5,16,5),child:ListTile(leading:CircleAvatar(backgroundColor:const Color(0xFFE9E4FF),child:Text(f['initials']!,style:const TextStyle(color:violet,fontWeight:FontWeight.w800))),title:Text(f['name']!,style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('${f['handle']} · ${f['interest']}'),trailing:FilledButton.tonal(onPressed:()=>setState(()=>sent?friendRequests.remove(f['handle']):friendRequests.add(f['handle']!)),child:Text(sent?'Requested':'Add friend'))));}),
    const Padding(padding:EdgeInsets.all(20),child:Text('Suggestions are sample profiles. Real accounts require a backend.',style:TextStyle(color:Colors.grey,fontSize:12))),
  ]);
  Widget communitiesPage() => ListView(padding:const EdgeInsets.only(bottom:24),children:[
    header('Communities',subtitle:'Belong to something you love.'),
    Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:TextField(decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Search communities'))),
    ...communities.map((c)=>Card(margin:const EdgeInsets.fromLTRB(16,8,16,4),child:Padding(padding:const EdgeInsets.all(12),child:Row(children:[
      Container(width:54,height:54,decoration:BoxDecoration(color:const Color(0xFFEDE9FF),borderRadius:BorderRadius.circular(16)),child:Icon(c.icon,color:violet,size:27)),const SizedBox(width:12),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(c.name,style:const TextStyle(fontWeight:FontWeight.w800)),Text(c.category,style:const TextStyle(color:violet,fontSize:12)),const SizedBox(height:4),Text(c.description,style:TextStyle(color:Colors.grey.shade600,fontSize:12)),Text('${compact(c.members)} members',style:TextStyle(color:Colors.grey.shade500,fontSize:11))])),
      const SizedBox(width:8),OutlinedButton(onPressed:()=>setState(()=>{c.joined=!c.joined;c.members+=c.joined?1:-1;}),child:Text(c.joined?'Joined ✓':'Join')),
    ])))),
  ]);
  Widget messagesPage() => Column(children:[
    header('Messages',subtitle:'Conversations make a community.'),
    Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:TextField(decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Search conversations'))),
    Expanded(child:ListView(children:[for(final chat in chats)ListTile(contentPadding:const EdgeInsets.symmetric(horizontal:20,vertical:8),leading:CircleAvatar(radius:26,backgroundColor:const Color(0xFFE7E1FF),child:Text(chat['initials']!,style:const TextStyle(color:violet,fontWeight:FontWeight.bold))),title:Text(chat['name']!,style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text(chat['message']!,maxLines:1,overflow:TextOverflow.ellipsis),trailing:Text(chat['time']!,style:TextStyle(color:Colors.grey.shade500,fontSize:11)),onTap:()=>openChat(chat['name']!)),const Padding(padding:EdgeInsets.all(20),child:Text('Sample conversations are shown here. Real-time messaging needs a configured backend.',style:TextStyle(color:Colors.grey,fontSize:12)))])),
  ]);
  void openChat(String name){
    final controller=TextEditingController();final messages=<String>['Hey! Great to connect here.','What are you working on lately?'];
    showModalBottomSheet(context:context,isScrollControlled:true,useSafeArea:true,builder:(ctx)=>StatefulBuilder(builder:(ctx,setSheet)=>SizedBox(height:MediaQuery.of(ctx).size.height*.75,child:Column(children:[
      ListTile(leading:const CircleAvatar(child:Icon(Icons.person)),title:Text(name,style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:const Text('Friend conversation')),const Divider(height:1),
      Expanded(child:ListView(padding:const EdgeInsets.all(16),children:messages.map((m)=>Align(alignment:Alignment.centerLeft,child:Container(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:const Color(0xFFEDE9FF),borderRadius:BorderRadius.circular(16)),child:Text(m)))).toList())),
      Padding(padding:EdgeInsets.fromLTRB(12,8,12,MediaQuery.of(ctx).viewInsets.bottom+12),child:Row(children:[Expanded(child:TextField(controller:controller,decoration:const InputDecoration(hintText:'Write a message...'))),IconButton(onPressed:(){if(controller.text.trim().isNotEmpty){setSheet(()=>messages.add(controller.text.trim()));controller.clear();}},icon:const Icon(Icons.send,color:violet))])),
    ]))));
  }
  Widget profilePage()=>ListView(padding:const EdgeInsets.only(bottom:24),children:[
    header('Your profile',subtitle:'Make it feel like you.'),const SizedBox(height:8),
    Center(child:CircleAvatar(radius:48,backgroundColor:const Color(0xFFE4DEFF),child:Text(initialsFor(displayName),style:const TextStyle(fontSize:28,color:violet,fontWeight:FontWeight.w800)))),
    const SizedBox(height:12),Center(child:Text(displayName,style:const TextStyle(fontSize:23,fontWeight:FontWeight.w800,color:ink))),const SizedBox(height:4),
    Center(child:Text('@you · Here for good conversations',style:TextStyle(color:Colors.grey.shade600))),
    Padding(padding:const EdgeInsets.symmetric(horizontal:28,vertical:12),child:Center(child:Text(bio,textAlign:TextAlign.center,style:const TextStyle(height:1.4)))),
    Row(mainAxisAlignment:MainAxisAlignment.center,children:[stat('${posts.where((p)=>p.handle=='@you').length}','Posts'),stat('${communities.where((c)=>c.joined).length}','Groups'),stat('${friendRequests.length}','Requests')]),
    const SizedBox(height:20),Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:Card(child:Column(children:[
      ListTile(leading:const Icon(Icons.edit_outlined,color:violet),title:const Text('Edit profile'),trailing:const Icon(Icons.chevron_right),onTap:editProfile),
      ListTile(leading:const Icon(Icons.notifications_none,color:violet),title:const Text('Notifications'),trailing:const Icon(Icons.chevron_right),onTap:()=>toast('Notification preferences can be connected in a future version.')),
      ListTile(leading:const Icon(Icons.lock_outline,color:violet),title:const Text('Privacy & safety'),trailing:const Icon(Icons.chevron_right),onTap:privacy),
      ListTile(leading:const Icon(Icons.info_outline,color:violet),title:Text('About ${AppConfig.appName}'),trailing:const Icon(Icons.chevron_right),onTap:()=>showAboutDialog(context:context,applicationName:AppConfig.appName,applicationVersion:AppConfig.appVersion,children:const[Text('A friendship-first community for interests, conversations and belonging. This starter app uses local demo data.')])),
    ]))),
  ]);
  Widget stat(String n,String label)=>Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:Column(children:[Text(n,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:19,color:ink)),Text(label,style:TextStyle(color:Colors.grey.shade600,fontSize:12))]));
  String compact(int n)=>n>=1000?'${(n/1000).toStringAsFixed(1)}k':'$n';
  void openComposer()=>showModalBottomSheet(context:context,isScrollControlled:true,useSafeArea:true,builder:(ctx)=>Padding(padding:EdgeInsets.fromLTRB(18,20,18,MediaQuery.of(ctx).viewInsets.bottom+20),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Text('Share something good',style:TextStyle(fontSize:21,fontWeight:FontWeight.w800)),const SizedBox(height:12),
    TextField(controller:composer,autofocus:true,maxLines:5,maxLength:500,decoration:const InputDecoration(hintText:'A thought, a small win, a question...')),const SizedBox(height:8),
    SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:(){Navigator.pop(ctx);createPost();},icon:const Icon(Icons.send),label:const Text('Share with community'))),
  ])));
  void comments(SocialPost p){final controller=TextEditingController();showModalBottomSheet(context:context,isScrollControlled:true,builder:(ctx)=>Padding(padding:EdgeInsets.fromLTRB(18,20,18,MediaQuery.of(ctx).viewInsets.bottom+20),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text('Conversation · ${p.comments} replies',style:const TextStyle(fontWeight:FontWeight.w800,fontSize:19)),const SizedBox(height:12),const Text('Be kind, stay curious, and keep it friendly.',style:TextStyle(color:Colors.grey)),const SizedBox(height:12),
    TextField(controller:controller,decoration:const InputDecoration(hintText:'Add a friendly reply...')),const SizedBox(height:10),
    SizedBox(width:double.infinity,child:FilledButton(onPressed:(){if(controller.text.trim().isNotEmpty){setState(()=>p.comments++);Navigator.pop(ctx);toast('Reply added locally (demo).');}},child:const Text('Reply'))),
  ])));}
  void editProfile(){final name=TextEditingController(text:displayName);final about=TextEditingController(text:bio);showDialog(context:context,builder:(ctx)=>AlertDialog(title:const Text('Edit profile'),content:Column(mainAxisSize:MainAxisSize.min,children:[
    TextField(controller:name,decoration:const InputDecoration(labelText:'Display name')),const SizedBox(height:12),TextField(controller:about,maxLines:3,decoration:const InputDecoration(labelText:'About you')),
  ]),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),FilledButton(onPressed:(){if(name.text.trim().isNotEmpty)setState(()=>{displayName=name.text.trim();bio=about.text.trim();});Navigator.pop(ctx);},child:const Text('Save'))]));}
  void privacy()=>showModalBottomSheet(context:context,builder:(ctx)=>SafeArea(child:Padding(padding:const EdgeInsets.all(20),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Text('Privacy & safety',style:TextStyle(fontWeight:FontWeight.w800,fontSize:21)),const SizedBox(height:8),const Text('Stay in control of your experience.',style:TextStyle(color:Colors.grey)),
    ListTile(leading:const Icon(Icons.flag_outlined),title:const Text('Report a concern'),onTap:(){Navigator.pop(ctx);report('community content');}),
    ListTile(leading:const Icon(Icons.block),title:const Text('Block an account'),onTap:(){Navigator.pop(ctx);confirmBlock('an account');}),
    const ListTile(leading:Icon(Icons.visibility_off_outlined),title:Text('Keep personal details private'),subtitle:Text('Avoid sharing your address, passwords or financial information.')),
  ]))));
  void report(String subject)=>showDialog(context:context,builder:(ctx)=>AlertDialog(title:const Text('Report content'),content:Text('Would you like to flag $subject for review? This demo records no report on a server.'),actions:[
    TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),FilledButton(onPressed:(){Navigator.pop(ctx);toast('Report flow previewed. Backend moderation is not configured.');},child:const Text('Continue')),
  ]));
  void confirmBlock(String subject)=>showDialog(context:context,builder:(ctx)=>AlertDialog(title:const Text('Block account?'),content:Text('Blocking $subject would hide their content and prevent contact in a live version. This demo does not sync blocks.'),actions:[
    TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),FilledButton(onPressed:(){Navigator.pop(ctx);toast('Block action previewed. Connect a backend to enforce it.');},child:const Text('Got it')),
  ]));
}
