import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ============================================================
// Widget Tests for Login Screen
// ============================================================

void main() {
  group('LoginScreen Widget Tests', () {
    testWidgets('renders login form correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TestLoginForm(),
          ),
        ),
      );

      // 验证表单元素存在
      expect(find.byType(TextFormField), findsNWidgets(2)); // username + password
      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('shows validation error for empty username',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TestLoginForm(),
          ),
        ),
      );

      // 点击登录按钮，不输入任何内容
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      // 验证错误消息显示
      expect(find.text('Username is required'), findsOneWidget);
    });

    testWidgets('shows validation error for empty password',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TestLoginForm(),
          ),
        ),
      );

      // 只输入用户名
      await tester.enterText(
        find.byKey(const Key('username_field')),
        'testuser',
      );
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      // 验证密码错误消息
      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('can input username and password', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TestLoginForm(),
          ),
        ),
      );

      // 输入用户名
      await tester.enterText(
        find.byKey(const Key('username_field')),
        'testuser',
      );

      // 输入密码
      await tester.enterText(
        find.byKey(const Key('password_field')),
        'password123',
      );

      await tester.pump();

      // 验证输入已填充
      expect(find.text('testuser'), findsOneWidget);
    });

    testWidgets('password field obscures text', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TestLoginForm(),
          ),
        ),
      );

      // Find the EditableText widget inside the password field
      final editableTextFinder = find.descendant(
        of: find.byKey(const Key('password_field')),
        matching: find.byType(EditableText),
      );
      final editableText = tester.widget<EditableText>(editableTextFinder);

      expect(editableText.obscureText, isTrue);
    });

    testWidgets('shows loading indicator when submitting',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TestLoginFormWithLoading(isLoading: true),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('RegisterScreen Widget Tests', () {
    testWidgets('renders registration form correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TestRegisterForm(),
          ),
        ),
      );

      // 验证表单元素
      expect(find.byType(TextFormField), findsNWidgets(4)); // username, email, password, confirm
      expect(find.text('Register'), findsOneWidget);
    });

    testWidgets('validates password confirmation match',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TestRegisterForm(),
          ),
        ),
      );

      // 输入不匹配的密码
      await tester.enterText(
        find.byKey(const Key('password_field')),
        'Password123!',
      );
      await tester.enterText(
        find.byKey(const Key('confirm_password_field')),
        'DifferentPass!',
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(find.text('Passwords do not match'), findsOneWidget);
    });

    testWidgets('validates email format', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TestRegisterForm(),
          ),
        ),
      );

      // 输入无效邮箱
      await tester.enterText(
        find.byKey(const Key('email_field')),
        'invalid-email',
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(find.text('Invalid email format'), findsOneWidget);
    });
  });

  group('ChatRoom Widget Tests', () {
    testWidgets('renders chat room correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TestChatRoom(),
          ),
        ),
      );

      // 验证聊天室元素
      expect(find.byType(ListView), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget); // 消息输入框
      expect(find.byIcon(Icons.send), findsOneWidget);
    });

    testWidgets('can input and clear message', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TestChatRoom(),
          ),
        ),
      );

      // 输入消息
      await tester.enterText(
        find.byKey(const Key('message_input')),
        'Hello, World!',
      );
      await tester.pump();

      expect(find.text('Hello, World!'), findsOneWidget);
    });

    testWidgets('shows message list', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TestChatRoomWithMessages(
              messages: [
                TestMessage(id: '1', content: 'First message', senderId: 'user1'),
                TestMessage(id: '2', content: 'Second message', senderId: 'user2'),
                TestMessage(id: '3', content: 'Third message', senderId: 'user1'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('First message'), findsOneWidget);
      expect(find.text('Second message'), findsOneWidget);
      expect(find.text('Third message'), findsOneWidget);
    });

    testWidgets('send button is disabled when input is empty',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TestChatRoom(),
          ),
        ),
      );

      final sendButtonFinder = find.ancestor(
        of: find.byIcon(Icons.send),
        matching: find.byType(IconButton),
      );
      final sendButton = tester.widget<IconButton>(sendButtonFinder);

      expect(sendButton.onPressed, isNull);
    });

    testWidgets('send button is enabled when input has text',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TestChatRoom(),
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('message_input')),
        'Hello',
      );
      await tester.pump();

      final sendButtonFinder = find.ancestor(
        of: find.byIcon(Icons.send),
        matching: find.byType(IconButton),
      );
      final sendButton = tester.widget<IconButton>(sendButtonFinder);

      expect(sendButton.onPressed, isNotNull);
    });
  });

  group('RoomList Widget Tests', () {
    testWidgets('renders room list correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TestRoomList(
              rooms: [
                TestRoom(id: '1', name: 'Room 1', type: 'group'),
                TestRoom(id: '2', name: 'Room 2', type: 'direct'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Room 1'), findsOneWidget);
      expect(find.text('Room 2'), findsOneWidget);
    });

    testWidgets('shows empty state when no rooms', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TestRoomList(rooms: []),
          ),
        ),
      );

      expect(find.text('No rooms yet'), findsOneWidget);
    });

    testWidgets('can tap on room to select it', (WidgetTester tester) async {
      String? selectedRoomId;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TestRoomList(
              rooms: [
                TestRoom(id: '1', name: 'Selectable Room', type: 'group'),
              ],
              onRoomTap: (roomId) => selectedRoomId = roomId,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Selectable Room'));
      await tester.pump();

      expect(selectedRoomId, equals('1'));
    });
  });

  // ============================================================
  // Message Bubble Widget Tests
  // ============================================================

  group('MessageBubble Widget Tests', () {
    testWidgets('renders text message correctly for sender',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TestMessageBubble(
              message: TestMessageEntity(
                id: '1',
                roomId: 'room1',
                senderId: 'me',
                senderName: 'Me',
                content: 'Hello World',
                type: TestMessageType.text,
                status: TestMessageStatus.sent,
              ),
              isMe: true,
            ),
          ),
        ),
      );

      expect(find.text('Hello World'), findsOneWidget);
      expect(find.byKey(const Key('status_sent')), findsOneWidget);
    });

    testWidgets('renders text message correctly for receiver',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TestMessageBubble(
              message: TestMessageEntity(
                id: '1',
                roomId: 'room1',
                senderId: 'other',
                senderName: 'John',
                content: 'Hi there!',
                type: TestMessageType.text,
              ),
              isMe: false,
              showSender: true,
            ),
          ),
        ),
      );

      expect(find.text('Hi there!'), findsOneWidget);
      expect(find.byKey(const Key('sender_name')), findsOneWidget);
      expect(find.text('John'), findsOneWidget);
      expect(find.byKey(const Key('sender_avatar')), findsOneWidget);
    });

    testWidgets('shows sending status indicator', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TestMessageBubble(
              message: TestMessageEntity(
                id: '1',
                roomId: 'room1',
                senderId: 'me',
                senderName: 'Me',
                content: 'Sending...',
                status: TestMessageStatus.sending,
              ),
              isMe: true,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('status_sending')), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows failed status with retry option',
        (WidgetTester tester) async {
      bool retried = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TestMessageBubble(
              message: TestMessageEntity(
                id: '1',
                roomId: 'room1',
                senderId: 'me',
                senderName: 'Me',
                content: 'Failed message',
                status: TestMessageStatus.failed,
              ),
              isMe: true,
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('status_failed')), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      await tester.tap(find.byKey(const Key('status_failed')));
      await tester.pump();

      expect(retried, isTrue);
    });

    testWidgets('shows read status correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TestMessageBubble(
              message: TestMessageEntity(
                id: '1',
                roomId: 'room1',
                senderId: 'me',
                senderName: 'Me',
                content: 'Read message',
                status: TestMessageStatus.read,
              ),
              isMe: true,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('status_read')), findsOneWidget);
      expect(find.byIcon(Icons.done_all), findsOneWidget);
    });

    testWidgets('renders image message correctly', (WidgetTester tester) async {
      bool mediaTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TestMessageBubble(
              message: TestMessageEntity(
                id: '1',
                roomId: 'room1',
                senderId: 'me',
                senderName: 'Me',
                content: '',
                type: TestMessageType.image,
                mediaUrl: 'https://example.com/image.jpg',
              ),
              isMe: true,
              onMediaTap: () => mediaTapped = true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.image), findsOneWidget);
      expect(find.text('[图片]'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.image));
      await tester.pump();

      expect(mediaTapped, isTrue);
    });

    testWidgets('renders video message correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TestMessageBubble(
              message: TestMessageEntity(
                id: '1',
                roomId: 'room1',
                senderId: 'me',
                senderName: 'Me',
                content: '',
                type: TestMessageType.video,
              ),
              isMe: true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.videocam), findsOneWidget);
      expect(find.text('[视频]'), findsOneWidget);
    });

    testWidgets('renders audio message correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TestMessageBubble(
              message: TestMessageEntity(
                id: '1',
                roomId: 'room1',
                senderId: 'me',
                senderName: 'Me',
                content: '',
                type: TestMessageType.audio,
              ),
              isMe: true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(find.text('[语音]'), findsOneWidget);
    });

    testWidgets('renders file message correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TestMessageBubble(
              message: TestMessageEntity(
                id: '1',
                roomId: 'room1',
                senderId: 'me',
                senderName: 'Me',
                content: 'document.pdf',
                type: TestMessageType.file,
              ),
              isMe: true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.attach_file), findsOneWidget);
      expect(find.text('document.pdf'), findsOneWidget);
    });

    testWidgets('renders system message correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TestMessageBubble(
              message: TestMessageEntity(
                id: '1',
                roomId: 'room1',
                senderId: 'system',
                senderName: 'System',
                content: 'User joined the room',
                type: TestMessageType.system,
              ),
              isMe: false,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('system_message')), findsOneWidget);
      expect(find.text('User joined the room'), findsOneWidget);
    });

    testWidgets('long press triggers callback', (WidgetTester tester) async {
      bool longPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TestMessageBubble(
              message: TestMessageEntity(
                id: '1',
                roomId: 'room1',
                senderId: 'me',
                senderName: 'Me',
                content: 'Long press me',
              ),
              isMe: true,
              onLongPress: () => longPressed = true,
            ),
          ),
        ),
      );

      await tester.longPress(find.byKey(const Key('message_bubble_container')));
      await tester.pump();

      expect(longPressed, isTrue);
    });

    testWidgets('formats time correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TestMessageBubble(
              message: TestMessageEntity(
                id: '1',
                roomId: 'room1',
                senderId: 'me',
                senderName: 'Me',
                content: 'Test',
                createdAt: DateTime(2024, 1, 15, 9, 5),
              ),
              isMe: true,
            ),
          ),
        ),
      );

      expect(find.text('09:05'), findsOneWidget);
    });
  });

  // ============================================================
  // Member Management Widget Tests
  // ============================================================

  group('MemberList Widget Tests', () {
    testWidgets('renders member list correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TestMemberListPage(
            members: [
              TestMember(userId: '1', displayName: 'Alice', role: TestMemberRole.owner),
              TestMember(userId: '2', displayName: 'Bob', role: TestMemberRole.admin),
              TestMember(userId: '3', displayName: 'Charlie', role: TestMemberRole.member),
            ],
          ),
        ),
      );

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Charlie'), findsOneWidget);
      expect(find.text('群成员 (3)'), findsOneWidget);
    });

    testWidgets('shows role badges correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TestMemberListPage(
            members: [
              TestMember(userId: '1', displayName: 'Owner', role: TestMemberRole.owner),
              TestMember(userId: '2', displayName: 'Admin', role: TestMemberRole.admin),
            ],
          ),
        ),
      );

      expect(find.text('群主'), findsOneWidget);
      expect(find.text('管理员'), findsOneWidget);
    });

    testWidgets('shows empty state when no members', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TestMemberListPage(members: []),
        ),
      );

      expect(find.byKey(const Key('empty_members')), findsOneWidget);
      expect(find.text('暂无成员'), findsOneWidget);
    });

    testWidgets('owner can see remove option for members',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TestMemberListPage(
            members: [
              TestMember(userId: '1', displayName: 'Owner', role: TestMemberRole.owner),
              TestMember(userId: '2', displayName: 'Member', role: TestMemberRole.member),
            ],
            currentUserId: '1',
            currentUserRole: TestMemberRole.owner,
          ),
        ),
      );

      // Owner should see menu for member
      expect(find.byKey(const Key('member_menu_2')), findsOneWidget);
      // Owner should not see menu for themselves
      expect(find.byKey(const Key('member_menu_1')), findsNothing);
    });

    testWidgets('member cannot see remove option', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TestMemberListPage(
            members: [
              TestMember(userId: '1', displayName: 'Owner', role: TestMemberRole.owner),
              TestMember(userId: '2', displayName: 'Member', role: TestMemberRole.member),
            ],
            currentUserId: '2',
            currentUserRole: TestMemberRole.member,
          ),
        ),
      );

      // Member should not see any remove menu
      expect(find.byKey(const Key('member_menu_1')), findsNothing);
      expect(find.byKey(const Key('member_menu_2')), findsNothing);
    });

    testWidgets('admin can remove member but not owner',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TestMemberListPage(
            members: [
              TestMember(userId: '1', displayName: 'Owner', role: TestMemberRole.owner),
              TestMember(userId: '2', displayName: 'Admin', role: TestMemberRole.admin),
              TestMember(userId: '3', displayName: 'Member', role: TestMemberRole.member),
            ],
            currentUserId: '2',
            currentUserRole: TestMemberRole.admin,
          ),
        ),
      );

      // Admin can remove member
      expect(find.byKey(const Key('member_menu_3')), findsOneWidget);
      // Admin cannot remove owner
      expect(find.byKey(const Key('member_menu_1')), findsNothing);
      // Admin cannot remove themselves
      expect(find.byKey(const Key('member_menu_2')), findsNothing);
    });

    testWidgets('shows confirmation dialog when removing member',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TestMemberListPage(
            members: [
              TestMember(userId: '1', displayName: 'Owner', role: TestMemberRole.owner),
              TestMember(userId: '2', displayName: 'ToRemove', role: TestMemberRole.member),
            ],
            currentUserId: '1',
            currentUserRole: TestMemberRole.owner,
          ),
        ),
      );

      // Open popup menu
      await tester.tap(find.byKey(const Key('member_menu_2')));
      await tester.pumpAndSettle();

      // Tap remove option
      await tester.tap(find.text('移除成员'));
      await tester.pumpAndSettle();

      // Verify confirmation dialog
      expect(find.byKey(const Key('remove_confirm_dialog')), findsOneWidget);
      expect(find.text('确定要将 ToRemove 移出群组吗？'), findsOneWidget);
      expect(find.byKey(const Key('cancel_button')), findsOneWidget);
      expect(find.byKey(const Key('confirm_remove_button')), findsOneWidget);
    });

    testWidgets('can cancel remove member', (WidgetTester tester) async {
      TestMember? removedMember;

      await tester.pumpWidget(
        MaterialApp(
          home: TestMemberListPage(
            members: [
              TestMember(userId: '1', displayName: 'Owner', role: TestMemberRole.owner),
              TestMember(userId: '2', displayName: 'Member', role: TestMemberRole.member),
            ],
            currentUserId: '1',
            currentUserRole: TestMemberRole.owner,
            onRemoveMember: (member) => removedMember = member,
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('member_menu_2')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('移除成员'));
      await tester.pumpAndSettle();

      // Cancel
      await tester.tap(find.byKey(const Key('cancel_button')));
      await tester.pumpAndSettle();

      expect(removedMember, isNull);
      expect(find.byKey(const Key('remove_confirm_dialog')), findsNothing);
    });

    testWidgets('can confirm remove member', (WidgetTester tester) async {
      TestMember? removedMember;

      await tester.pumpWidget(
        MaterialApp(
          home: TestMemberListPage(
            members: [
              TestMember(userId: '1', displayName: 'Owner', role: TestMemberRole.owner),
              TestMember(userId: '2', displayName: 'ToRemove', role: TestMemberRole.member),
            ],
            currentUserId: '1',
            currentUserRole: TestMemberRole.owner,
            onRemoveMember: (member) => removedMember = member,
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('member_menu_2')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('移除成员'));
      await tester.pumpAndSettle();

      // Confirm
      await tester.tap(find.byKey(const Key('confirm_remove_button')));
      await tester.pumpAndSettle();

      expect(removedMember, isNotNull);
      expect(removedMember!.userId, equals('2'));
    });
  });

  // ============================================================
  // Settings Page Widget Tests
  // ============================================================

  group('Settings Page Widget Tests', () {
    testWidgets('renders settings page correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TestSettingsPage(),
        ),
      );

      expect(find.text('设置'), findsOneWidget);
      expect(find.text('深色模式'), findsOneWidget);
      expect(find.text('推送通知'), findsOneWidget);
      expect(find.text('关于'), findsOneWidget);
      expect(find.text('退出登录'), findsOneWidget);
    });

    testWidgets('can toggle dark mode', (WidgetTester tester) async {
      bool? darkModeValue;

      await tester.pumpWidget(
        MaterialApp(
          home: TestSettingsPage(
            initialDarkMode: false,
            onDarkModeChanged: (value) => darkModeValue = value,
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('dark_mode_switch')));
      await tester.pump();

      expect(darkModeValue, isTrue);
    });

    testWidgets('can toggle notifications', (WidgetTester tester) async {
      bool? notificationsValue;

      await tester.pumpWidget(
        MaterialApp(
          home: TestSettingsPage(
            initialNotifications: true,
            onNotificationsChanged: (value) => notificationsValue = value,
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('notifications_switch')));
      await tester.pump();

      expect(notificationsValue, isFalse);
    });

    testWidgets('preserves initial settings values', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TestSettingsPage(
            initialDarkMode: true,
            initialNotifications: false,
          ),
        ),
      );

      final darkModeSwitch = tester.widget<SwitchListTile>(
        find.byKey(const Key('dark_mode_switch')),
      );
      final notificationsSwitch = tester.widget<SwitchListTile>(
        find.byKey(const Key('notifications_switch')),
      );

      expect(darkModeSwitch.value, isTrue);
      expect(notificationsSwitch.value, isFalse);
    });
  });

  // ============================================================
  // Error and Loading State Widget Tests
  // ============================================================

  group('Error and Loading State Widget Tests', () {
    testWidgets('renders error view correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TestErrorView(errorMessage: 'Network error occurred'),
          ),
        ),
      );

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Network error occurred'), findsOneWidget);
    });

    testWidgets('error view shows retry button when callback provided',
        (WidgetTester tester) async {
      bool retried = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TestErrorView(
              errorMessage: 'Something went wrong',
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('retry_button')), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);

      await tester.tap(find.byKey(const Key('retry_button')));
      await tester.pump();

      expect(retried, isTrue);
    });

    testWidgets('error view hides retry button when no callback',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TestErrorView(errorMessage: 'Error'),
          ),
        ),
      );

      expect(find.byKey(const Key('retry_button')), findsNothing);
    });

    testWidgets('renders loading view correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TestLoadingView(),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('loading view shows message when provided',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TestLoadingView(message: 'Loading data...'),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading data...'), findsOneWidget);
    });
  });

  // ============================================================
  // Input Validation Tests
  // ============================================================

  group('Input Validation Tests', () {
    testWidgets('validates password strength', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TestPasswordValidator(),
          ),
        ),
      );

      // Test weak password
      await tester.enterText(find.byKey(const Key('password_input')), '123');
      await tester.tap(find.text('Validate'));
      await tester.pump();

      expect(find.text('Password too weak'), findsOneWidget);

      // Test strong password
      await tester.enterText(
          find.byKey(const Key('password_input')), 'StrongP@ss123');
      await tester.tap(find.text('Validate'));
      await tester.pump();

      expect(find.text('Password is strong'), findsOneWidget);
    });

    testWidgets('validates username length', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TestUsernameValidator(),
          ),
        ),
      );

      // Test too short
      await tester.enterText(find.byKey(const Key('username_input')), 'ab');
      await tester.tap(find.text('Validate'));
      await tester.pump();

      expect(find.text('Username must be at least 3 characters'), findsOneWidget);

      // Test valid username
      await tester.enterText(find.byKey(const Key('username_input')), 'validuser');
      await tester.tap(find.text('Validate'));
      await tester.pump();

      expect(find.text('Username is valid'), findsOneWidget);
    });
  });
}

// ============================================================
// Test Widget Implementations
// ============================================================

class TestLoginForm extends StatefulWidget {
  const TestLoginForm({super.key});

  @override
  State<TestLoginForm> createState() => _TestLoginFormState();
}

class _TestLoginFormState extends State<TestLoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            key: const Key('username_field'),
            controller: _usernameController,
            decoration: const InputDecoration(labelText: 'Username'),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Username is required';
              }
              return null;
            },
          ),
          TextFormField(
            key: const Key('password_field'),
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Password is required';
              }
              return null;
            },
          ),
          ElevatedButton(
            onPressed: () {
              _formKey.currentState?.validate();
            },
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }
}

class TestLoginFormWithLoading extends StatelessWidget {
  final bool isLoading;

  const TestLoginFormWithLoading({super.key, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return const TestLoginForm();
  }
}

class TestRegisterForm extends StatefulWidget {
  const TestRegisterForm({super.key});

  @override
  State<TestRegisterForm> createState() => _TestRegisterFormState();
}

class _TestRegisterFormState extends State<TestRegisterForm> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            key: const Key('username_field'),
            decoration: const InputDecoration(labelText: 'Username'),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Username is required';
              }
              return null;
            },
          ),
          TextFormField(
            key: const Key('email_field'),
            decoration: const InputDecoration(labelText: 'Email'),
            validator: (value) {
              if (value != null && value.isNotEmpty && !value.contains('@')) {
                return 'Invalid email format';
              }
              return null;
            },
          ),
          TextFormField(
            key: const Key('password_field'),
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
          ),
          TextFormField(
            key: const Key('confirm_password_field'),
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Confirm Password'),
            validator: (value) {
              if (value != _passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          ElevatedButton(
            onPressed: () {
              _formKey.currentState?.validate();
            },
            child: const Text('Register'),
          ),
        ],
      ),
    );
  }
}

class TestChatRoom extends StatefulWidget {
  const TestChatRoom({super.key});

  @override
  State<TestChatRoom> createState() => _TestChatRoomState();
}

class _TestChatRoomState extends State<TestChatRoom> {
  final _messageController = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(() {
      setState(() {
        _hasText = _messageController.text.isNotEmpty;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            children: const [],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('message_input'),
                controller: _messageController,
                decoration: const InputDecoration(hintText: 'Type a message'),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: _hasText ? () {} : null,
            ),
          ],
        ),
      ],
    );
  }
}

class TestMessage {
  final String id;
  final String content;
  final String senderId;

  TestMessage({
    required this.id,
    required this.content,
    required this.senderId,
  });
}

class TestChatRoomWithMessages extends StatelessWidget {
  final List<TestMessage> messages;

  const TestChatRoomWithMessages({super.key, required this.messages});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: messages.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(messages[index].content),
              );
            },
          ),
        ),
        const Row(
          children: [
            Expanded(
              child: TextField(
                key: Key('message_input'),
              ),
            ),
            IconButton(
              icon: Icon(Icons.send),
              onPressed: null,
            ),
          ],
        ),
      ],
    );
  }
}

class TestRoom {
  final String id;
  final String name;
  final String type;

  TestRoom({
    required this.id,
    required this.name,
    required this.type,
  });
}

class TestRoomList extends StatelessWidget {
  final List<TestRoom> rooms;
  final Function(String)? onRoomTap;

  const TestRoomList({
    super.key,
    required this.rooms,
    this.onRoomTap,
  });

  @override
  Widget build(BuildContext context) {
    if (rooms.isEmpty) {
      return const Center(child: Text('No rooms yet'));
    }

    return ListView.builder(
      itemCount: rooms.length,
      itemBuilder: (context, index) {
        return ListTile(
          title: Text(rooms[index].name),
          onTap: () => onRoomTap?.call(rooms[index].id),
        );
      },
    );
  }
}

// ============================================================
// Extended Test Widgets - Message Bubble
// ============================================================

enum TestMessageType { text, image, video, audio, file, system }
enum TestMessageStatus { sending, sent, delivered, read, failed }
enum TestMemberRole { owner, admin, moderator, member }

class TestMessageEntity {
  final String id;
  final String roomId;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final String content;
  final TestMessageType type;
  final TestMessageStatus status;
  final String? mediaUrl;
  final DateTime createdAt;

  TestMessageEntity({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.content,
    this.type = TestMessageType.text,
    this.status = TestMessageStatus.sent,
    this.mediaUrl,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

class TestMessageBubble extends StatelessWidget {
  final TestMessageEntity message;
  final bool isMe;
  final bool showSender;
  final VoidCallback? onLongPress;
  final VoidCallback? onRetry;
  final VoidCallback? onMediaTap;

  const TestMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.showSender = false,
    this.onLongPress,
    this.onRetry,
    this.onMediaTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            _buildAvatar(theme),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (showSender && !isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 4),
                    child: Text(
                      message.senderName,
                      key: const Key('sender_name'),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                GestureDetector(
                  onLongPress: onLongPress,
                  child: Container(
                    key: const Key('message_bubble_container'),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.7,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isMe
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isMe ? 16 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 16),
                      ),
                    ),
                    child: _buildContent(theme),
                  ),
                ),
                const SizedBox(height: 2),
                _buildStatusRow(theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(ThemeData theme) {
    return CircleAvatar(
      key: const Key('sender_avatar'),
      radius: 16,
      backgroundColor: theme.colorScheme.secondaryContainer,
      child: Text(
        message.senderName.isNotEmpty ? message.senderName[0].toUpperCase() : '?',
        style: TextStyle(
          color: theme.colorScheme.onSecondaryContainer,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    final textColor = isMe ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;
    
    switch (message.type) {
      case TestMessageType.image:
        return GestureDetector(
          onTap: onMediaTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.image, color: textColor, size: 20),
              const SizedBox(width: 8),
              Text('[图片]', style: TextStyle(color: textColor)),
            ],
          ),
        );
      case TestMessageType.video:
        return GestureDetector(
          onTap: onMediaTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam, color: textColor, size: 20),
              const SizedBox(width: 8),
              Text('[视频]', style: TextStyle(color: textColor)),
            ],
          ),
        );
      case TestMessageType.audio:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mic, color: textColor, size: 20),
            const SizedBox(width: 8),
            Text('[语音]', style: TextStyle(color: textColor)),
          ],
        );
      case TestMessageType.file:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.attach_file, color: textColor, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message.content.isNotEmpty ? message.content : '[文件]',
                style: TextStyle(color: textColor),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      case TestMessageType.system:
        return Text(
          message.content,
          key: const Key('system_message'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        );
      default:
        return Text(
          message.content,
          key: const Key('message_content'),
          style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
        );
    }
  }

  Widget _buildStatusRow(ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatTime(),
          key: const Key('message_time'),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        if (isMe) ...[
          const SizedBox(width: 4),
          _buildStatusIcon(theme),
        ],
      ],
    );
  }

  Widget _buildStatusIcon(ThemeData theme) {
    switch (message.status) {
      case TestMessageStatus.sending:
        return SizedBox(
          key: const Key('status_sending'),
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: theme.colorScheme.outline,
          ),
        );
      case TestMessageStatus.sent:
        return Icon(
          Icons.check,
          key: const Key('status_sent'),
          size: 14,
          color: theme.colorScheme.outline,
        );
      case TestMessageStatus.delivered:
        return Icon(
          Icons.done_all,
          key: const Key('status_delivered'),
          size: 14,
          color: theme.colorScheme.outline,
        );
      case TestMessageStatus.read:
        return Icon(
          Icons.done_all,
          key: const Key('status_read'),
          size: 14,
          color: theme.colorScheme.primary,
        );
      case TestMessageStatus.failed:
        return GestureDetector(
          onTap: onRetry,
          child: Icon(
            Icons.error_outline,
            key: const Key('status_failed'),
            size: 14,
            color: theme.colorScheme.error,
          ),
        );
    }
  }

  String _formatTime() {
    final time = message.createdAt;
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

// ============================================================
// Member Management Test Widgets
// ============================================================

class TestMember {
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final TestMemberRole role;

  TestMember({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    this.role = TestMemberRole.member,
  });
}

class TestMemberListPage extends StatefulWidget {
  final List<TestMember> members;
  final String? currentUserId;
  final TestMemberRole? currentUserRole;
  final Function(TestMember)? onRemoveMember;

  const TestMemberListPage({
    super.key,
    required this.members,
    this.currentUserId,
    this.currentUserRole,
    this.onRemoveMember,
  });

  @override
  State<TestMemberListPage> createState() => _TestMemberListPageState();
}

class _TestMemberListPageState extends State<TestMemberListPage> {
  bool _canRemoveMember(TestMember member) {
    if (widget.currentUserRole == null) return false;
    if (widget.currentUserId == member.userId) return false;
    if (member.role == TestMemberRole.owner) return false;
    
    const roleLevel = {
      TestMemberRole.owner: 4,
      TestMemberRole.admin: 3,
      TestMemberRole.moderator: 2,
      TestMemberRole.member: 1,
    };
    
    return roleLevel[widget.currentUserRole]! > roleLevel[member.role]!;
  }

  void _showRemoveConfirmDialog(TestMember member) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('remove_confirm_dialog'),
        title: const Text('移除成员'),
        content: Text('确定要将 ${member.displayName} 移出群组吗？'),
        actions: [
          TextButton(
            key: const Key('cancel_button'),
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            key: const Key('confirm_remove_button'),
            onPressed: () {
              Navigator.pop(dialogContext);
              widget.onRemoveMember?.call(member);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('移除'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('群成员 (${widget.members.length})'),
      ),
      body: widget.members.isEmpty
          ? const Center(
              key: Key('empty_members'),
              child: Text('暂无成员'),
            )
          : ListView.builder(
              itemCount: widget.members.length,
              itemBuilder: (context, index) {
                final member = widget.members[index];
                return ListTile(
                  key: Key('member_${member.userId}'),
                  leading: CircleAvatar(
                    child: Text(member.displayName[0].toUpperCase()),
                  ),
                  title: Row(
                    children: [
                      Text(member.displayName),
                      const SizedBox(width: 8),
                      if (member.role == TestMemberRole.owner)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('群主', style: TextStyle(fontSize: 10)),
                        )
                      else if (member.role == TestMemberRole.admin)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('管理员', style: TextStyle(fontSize: 10)),
                        ),
                    ],
                  ),
                  trailing: _canRemoveMember(member)
                      ? PopupMenuButton<String>(
                          key: Key('member_menu_${member.userId}'),
                          onSelected: (value) {
                            if (value == 'remove') {
                              _showRemoveConfirmDialog(member);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'remove',
                              child: Text('移除成员', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        )
                      : null,
                );
              },
            ),
    );
  }
}

// ============================================================
// Settings Page Test Widgets
// ============================================================

class TestSettingsPage extends StatefulWidget {
  final bool initialDarkMode;
  final bool initialNotifications;
  final Function(bool)? onDarkModeChanged;
  final Function(bool)? onNotificationsChanged;

  const TestSettingsPage({
    super.key,
    this.initialDarkMode = false,
    this.initialNotifications = true,
    this.onDarkModeChanged,
    this.onNotificationsChanged,
  });

  @override
  State<TestSettingsPage> createState() => _TestSettingsPageState();
}

class _TestSettingsPageState extends State<TestSettingsPage> {
  late bool _darkMode;
  late bool _notifications;

  @override
  void initState() {
    super.initState();
    _darkMode = widget.initialDarkMode;
    _notifications = widget.initialNotifications;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          SwitchListTile(
            key: const Key('dark_mode_switch'),
            title: const Text('深色模式'),
            value: _darkMode,
            onChanged: (value) {
              setState(() => _darkMode = value);
              widget.onDarkModeChanged?.call(value);
            },
          ),
          SwitchListTile(
            key: const Key('notifications_switch'),
            title: const Text('推送通知'),
            value: _notifications,
            onChanged: (value) {
              setState(() => _notifications = value);
              widget.onNotificationsChanged?.call(value);
            },
          ),
          ListTile(
            key: const Key('about_tile'),
            title: const Text('关于'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            key: const Key('logout_tile'),
            title: const Text('退出登录', style: TextStyle(color: Colors.red)),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Error State Test Widgets
// ============================================================

class TestErrorView extends StatelessWidget {
  final String errorMessage;
  final VoidCallback? onRetry;

  const TestErrorView({
    super.key,
    required this.errorMessage,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            errorMessage,
            key: const Key('error_message'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 24),
            ElevatedButton(
              key: const Key('retry_button'),
              onPressed: onRetry,
              child: const Text('重试'),
            ),
          ],
        ],
      ),
    );
  }
}

class TestLoadingView extends StatelessWidget {
  final String? message;

  const TestLoadingView({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message!, key: const Key('loading_message')),
          ],
        ],
      ),
    );
  }
}

// ============================================================
// Input Validation Test Widgets
// ============================================================

class TestPasswordValidator extends StatefulWidget {
  const TestPasswordValidator({super.key});

  @override
  State<TestPasswordValidator> createState() => _TestPasswordValidatorState();
}

class _TestPasswordValidatorState extends State<TestPasswordValidator> {
  final _controller = TextEditingController();
  String? _result;

  void _validate() {
    final password = _controller.text;
    if (password.length < 8 ||
        !RegExp(r'[A-Z]').hasMatch(password) ||
        !RegExp(r'[a-z]').hasMatch(password) ||
        !RegExp(r'[0-9]').hasMatch(password)) {
      setState(() => _result = 'Password too weak');
    } else {
      setState(() => _result = 'Password is strong');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextField(
          key: const Key('password_input'),
          controller: _controller,
          obscureText: true,
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _validate,
          child: const Text('Validate'),
        ),
        if (_result != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(_result!),
          ),
      ],
    );
  }
}

class TestUsernameValidator extends StatefulWidget {
  const TestUsernameValidator({super.key});

  @override
  State<TestUsernameValidator> createState() => _TestUsernameValidatorState();
}

class _TestUsernameValidatorState extends State<TestUsernameValidator> {
  final _controller = TextEditingController();
  String? _result;

  void _validate() {
    final username = _controller.text;
    if (username.length < 3) {
      setState(() => _result = 'Username must be at least 3 characters');
    } else if (username.length > 20) {
      setState(() => _result = 'Username must be at most 20 characters');
    } else if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
      setState(() => _result = 'Username contains invalid characters');
    } else {
      setState(() => _result = 'Username is valid');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextField(
          key: const Key('username_input'),
          controller: _controller,
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _validate,
          child: const Text('Validate'),
        ),
        if (_result != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(_result!),
          ),
      ],
    );
  }
}
