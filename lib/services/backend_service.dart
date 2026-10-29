import 'package:supabase_flutter/supabase_flutter.dart';

class BackendService {
  BackendService(this.client);
  final SupabaseClient client;

  User? get user => client.auth.currentUser;

  Future<void> signIn(String email, String password) async {
    await client.auth.signInWithPassword(email: email.trim(), password: password);
  }

  Future<void> requestSignupOtp({
    required String email,
    required String password,
    required String displayName,
    required String username,
    required String phoneNumber,
    required DateTime dateOfBirth,
    required bool consentAccepted,
  }) async {
    if (!consentAccepted) throw Exception('Please accept the terms and privacy consent.');
    if (ageOn(dateOfBirth) < 12) throw Exception('You must be at least 12 years old to use LAMA.');
    final cleanUsername = username.trim().replaceFirst(RegExp(r'^@'), '').toLowerCase();
    if (!RegExp(r'^[a-z0-9_]{1,35}$').hasMatch(cleanUsername)) {
      throw Exception('Username must be 1–35 characters using letters, numbers or underscores.');
    }
    if (!await usernameAvailable(cleanUsername)) throw Exception('That username is already taken. Try another one.');
    await client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'display_name': displayName.trim(),
        'username': cleanUsername,
        'phone_number': phoneNumber.trim(),
        'date_of_birth': dateOfBirth.toIso8601String().split('T').first,
        'consent_accepted': consentAccepted,
      },
    );
  }

  Future<void> verifySignupOtp({required String email, required String token}) async {
    await client.auth.verifyOTP(
      type: OtpType.signup,
      email: email.trim(),
      token: token.trim(),
    );
  }

  Future<void> resendSignupOtp(String email) async {
    await client.auth.resend(type: OtpType.signup, email: email.trim());
  }

  Future<void> signInWithUsernameOrEmail(String identifier, String password) async {
    final value = identifier.trim();
    if (value.contains('@')) {
      await signIn(value, password);
      return;
    }
    final response = await client.functions.invoke(
      'username-login',
      body: {'username': value.replaceFirst(RegExp(r'^@'), '').toLowerCase(), 'password': password},
    );
    final data = response.data;
    if (data is! Map || data['access_token'] is! String || data['refresh_token'] is! String) {
      throw Exception('Username sign-in failed. Check your username and password.');
    }
    await client.auth.setSession(data['refresh_token'] as String);
  }

  Future<void> signUp({
    required String email, required String password, required String displayName,
    required String username, required String phoneNumber, required DateTime dateOfBirth,
    required bool consentAccepted,
  }) async {
    if (!consentAccepted) throw Exception('Please accept the terms and privacy consent.');
    if (ageOn(dateOfBirth) < 12) throw Exception('You must be at least 12 years old to use LAMA.');
    final cleanUsername = username.trim().replaceFirst(RegExp(r'^@'), '').toLowerCase();
    if (!await usernameAvailable(cleanUsername)) throw Exception('That username is already taken. Try another one.');
    await client.auth.signUp(email: email.trim(), password: password, data: {
      'display_name': displayName.trim(), 'username': cleanUsername, 'phone_number': phoneNumber.trim(),
      'date_of_birth': dateOfBirth.toIso8601String().split('T').first, 'consent_accepted': consentAccepted,
    });
  }

  static int ageOn(DateTime dob, {DateTime? today}) {
    final now = today ?? DateTime.now();
    var age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) age--;
    return age;
  }

  Future<void> signInWithGoogle() async {
    await client.auth.signInWithOAuth(OAuthProvider.google, redirectTo: 'io.supabase.flutter://login-callback/');
  }

  Future<bool> usernameAvailable(String value) async {
    final username = value.trim().replaceFirst(RegExp(r'^@'), '').toLowerCase();
    if (!RegExp(r'^[a-z0-9_]{1,35}$').hasMatch(username)) return false;
    final result = await client.rpc('is_username_available', params: {'candidate': username});
    return result == true;
  }

  Future<bool> needsProfileCompletion() async {
    final id = user!.id;
    final profile = await client.from('profiles').select('display_name,username').eq('id', id).maybeSingle();
    final private = await client.from('private_profile_details').select('phone_number,date_of_birth,consent_accepted').eq('user_id', id).maybeSingle();
    return profile == null || (profile['display_name'] ?? '').toString().trim().isEmpty ||
        private == null || (private['phone_number'] ?? '').toString().trim().isEmpty ||
        private['date_of_birth'] == null || private['consent_accepted'] != true;
  }

  Future<void> completeProfile({
    required String displayName, required String username, required String phoneNumber,
    required DateTime dateOfBirth, required bool consentAccepted,
  }) async {
    if (!consentAccepted) throw Exception('Please accept the terms and privacy consent.');
    if (ageOn(dateOfBirth) < 12) throw Exception('You must be at least 12 years old to use LAMA.');
    await client.rpc('complete_my_profile', params: {
      'p_display_name': displayName.trim(),
      'p_username': username.trim().replaceFirst(RegExp(r'^@'), '').toLowerCase(),
      'p_phone_number': phoneNumber.trim(),
      'p_date_of_birth': dateOfBirth.toIso8601String().split('T').first,
      'p_consent_accepted': consentAccepted,
    });
  }

  Future<void> signOut() => client.auth.signOut();

  Future<Map<String, dynamic>> myProfile() async {
    final row = await client.from('profiles').select().eq('id', user!.id).maybeSingle();
    if (row == null) return <String, dynamic>{};
    final private = await client.from('private_profile_details').select('phone_number,date_of_birth,consent_accepted').eq('user_id', user!.id).maybeSingle();
    return {...Map<String, dynamic>.from(row), if (private != null) ...Map<String, dynamic>.from(private)};
  }

  Future<void> updateProfile({required String displayName, required String bio, required String username, required bool isPrivate}) async {
    await client.from('profiles').update({
      'display_name': displayName.trim(),
      'bio': bio.trim(),
      'username': username.trim().replaceAll('@', ''),
      'is_private': isPrivate,
    }).eq('id', user!.id);
  }

  Future<List<Map<String, dynamic>>> people() async {
    final rows = await client.from('profiles').select().neq('id', user!.id).order('created_at', ascending: false).limit(100);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> posts() async {
    final rows = await client.from('posts').select().order('created_at', ascending: false).limit(100);
    final items = List<Map<String, dynamic>>.from(rows);
    if (items.isEmpty) return items;
    final ghostRows = await client.from('ghosted_posts').select('post_id').eq('user_id', user!.id);
    final ghostedIds = List<Map<String, dynamic>>.from(ghostRows).map((e) => e['post_id'].toString()).toSet();
    items.removeWhere((post) => ghostedIds.contains(post['id'].toString()));
    if (items.isEmpty) return items;
    final ids = items.map((e) => e['author_id'].toString()).toSet().toList();
    final profiles = await client.from('profiles').select('id,username,display_name,avatar_url').inFilter('id', ids);
    final byId = {for (final p in profiles) p['id'].toString(): Map<String, dynamic>.from(p)};
    for (final item in items) {
      item['author'] = byId[item['author_id'].toString()] ?? <String, dynamic>{};
    }
    final postIds = items.map((e) => e['id'].toString()).toList();
    final likes = await client.from('post_likes').select('post_id,user_id').inFilter('post_id', postIds);
    final likeRows = List<Map<String, dynamic>>.from(likes);
    final commentRows = await client.from('comments').select('post_id').inFilter('post_id', postIds);
    final comments = List<Map<String, dynamic>>.from(commentRows);
    for (final item in items) {
      final own = likeRows.any((l) => l['post_id'] == item['id'] && l['user_id'] == user!.id);
      item['liked_by_me'] = own;
      item['likes_count'] = likeRows.where((l) => l['post_id'] == item['id']).length;
      item['comments_count'] = comments.where((c) => c['post_id'] == item['id']).length;
    }
    return items;
  }

  Future<void> createPost(String body) async {
    await client.from('posts').insert({'author_id': user!.id, 'body': body.trim()});
  }

  Future<void> ghostPost(String postId) async {
    await client.from('ghosted_posts').upsert({'user_id': user!.id, 'post_id': postId}, onConflict: 'user_id,post_id');
  }

  Future<List<Map<String, dynamic>>> comments(String postId) async {
    final rows = await client.from('comments').select().eq('post_id', postId).order('created_at');
    final items = List<Map<String, dynamic>>.from(rows);
    if (items.isEmpty) return items;
    final ids = items.map((e) => e['author_id'].toString()).toSet().toList();
    final people = await client.from('profiles').select('id,display_name,username,avatar_url').inFilter('id', ids);
    final byId = {for (final p in people) p['id'].toString(): Map<String, dynamic>.from(p)};
    for (final item in items) {
      item['author'] = byId[item['author_id'].toString()] ?? <String, dynamic>{};
    }
    return items;
  }

  Future<void> addComment(String postId, String body) async {
    await client.from('comments').insert({'post_id': postId, 'author_id': user!.id, 'body': body.trim()});
  }

  Future<void> toggleLike(String postId, bool currentlyLiked) async {
    if (currentlyLiked) {
      await client.from('post_likes').delete().eq('post_id', postId).eq('user_id', user!.id);
    } else {
      await client.from('post_likes').insert({'post_id': postId, 'user_id': user!.id});
    }
  }

  Future<List<Map<String, dynamic>>> communities() async {
    final rows = await client.from('communities').select().order('name');
    final members = await client.from('community_members').select('community_id').eq('user_id', user!.id);
    final joined = List<Map<String, dynamic>>.from(members).map((e) => e['community_id'].toString()).toSet();
    return List<Map<String, dynamic>>.from(rows).map((row) {
      row['joined_by_me'] = joined.contains(row['id'].toString());
      return row;
    }).toList();
  }

  Future<void> toggleCommunity(String communityId, bool joined) async {
    if (joined) {
      await client.from('community_members').delete().eq('community_id', communityId).eq('user_id', user!.id);
    } else {
      await client.from('community_members').insert({'community_id': communityId, 'user_id': user!.id});
    }
  }

  Future<List<Map<String, dynamic>>> friendRequests() async {
    final rows = await client.from('friendships').select().or('requester_id.eq.${user!.id},addressee_id.eq.${user!.id}').order('created_at', ascending: false);
    final items = List<Map<String, dynamic>>.from(rows);
    final ids = items.map((e) => (e['requester_id'] == user!.id ? e['addressee_id'] : e['requester_id']).toString()).toSet().toList();
    if (ids.isEmpty) return items;
    final people = await client.from('profiles').select('id,username,display_name,avatar_url').inFilter('id', ids);
    final byId = {for (final p in people) p['id'].toString(): Map<String, dynamic>.from(p)};
    for (final item in items) {
      final otherId = item['requester_id'] == user!.id ? item['addressee_id'] : item['requester_id'];
      item['other'] = byId[otherId.toString()] ?? <String, dynamic>{};
    }
    return items;
  }

  Future<void> sendFriendRequest(String otherId) async {
    await client.from('friendships').insert({'requester_id': user!.id, 'addressee_id': otherId, 'status': 'pending'});
  }

  Future<void> respondFriendRequest(String requestId, String status) async {
    await client.from('friendships').update({'status': status, 'updated_at': DateTime.now().toIso8601String()}).eq('id', requestId);
  }

  Future<List<Map<String, dynamic>>> conversations() async {
    final memberships = await client.from('conversation_members').select('conversation_id').eq('user_id', user!.id);
    final ids = List<Map<String, dynamic>>.from(memberships).map((e) => e['conversation_id'].toString()).toList();
    if (ids.isEmpty) return [];
    final rows = await client.from('conversations').select().inFilter('id', ids).order('created_at', ascending: false);
    final result = <Map<String, dynamic>>[];
    for (final row in List<Map<String, dynamic>>.from(rows)) {
      final members = await client.from('conversation_members').select('user_id').eq('conversation_id', row['id']);
      final otherIds = List<Map<String, dynamic>>.from(members).map((e) => e['user_id'].toString()).where((id) => id != user!.id).toList();
      final profiles = otherIds.isEmpty ? [] : await client.from('profiles').select('id,display_name,username').inFilter('id', otherIds);
      final latest = await client.from('messages').select('body,created_at').eq('conversation_id', row['id']).order('created_at', ascending: false).limit(1).maybeSingle();
      row['other_name'] = profiles.isNotEmpty ? profiles.first['display_name'] : (row['title'] ?? 'Group conversation');
      row['other_ids'] = otherIds;
      row['last_message'] = latest?['body'] ?? 'Say hello 👋';
      result.add(Map<String, dynamic>.from(row));
    }
    return result;
  }

  Future<String> startConversation(String otherId) async {
    final result = await client.rpc('create_direct_conversation', params: {'other_user_id': otherId});
    return result.toString();
  }

  Future<List<Map<String, dynamic>>> messages(String conversationId) async {
    final rows = await client.from('messages').select().eq('conversation_id', conversationId).order('created_at');
    final items = List<Map<String, dynamic>>.from(rows);
    if (items.isEmpty) return items;
    final ids = items.map((e) => e['sender_id'].toString()).toSet().toList();
    final people = await client.from('profiles').select('id,display_name').inFilter('id', ids);
    final byId = {for (final p in people) p['id'].toString(): p['display_name'].toString()};
    for (final item in items) {
      item['sender_name'] = byId[item['sender_id'].toString()] ?? 'Friend';
    }
    return items;
  }

  Future<void> sendMessage(String conversationId, String body) async {
    await client.from('messages').insert({'conversation_id': conversationId, 'sender_id': user!.id, 'body': body.trim()});
  }

  Future<void> report({String? userId, String? postId, required String reason}) async {
    await client.from('reports').insert({'reporter_id': user!.id, 'reported_user_id': userId, 'post_id': postId, 'reason': reason.trim()});
  }

  Future<void> block(String otherId) async {
    await client.from('blocks').upsert({'blocker_id': user!.id, 'blocked_id': otherId});
  }
}
