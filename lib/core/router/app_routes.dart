class AppRoutes {
  static const root = '/';
  static const home = '/home';
  static const search = '/search';
  static const chats = '/chats';
  static const challenges = '/challenges';
  static const profile = '/profile';

  static const stories = '/stories';
  static const notifications = '/notifications';
  static const contactSupport = '/contact-support';

  static String chat(String id) => '/chat/$id';
  static String profileView(String id) => '/profile/$id';
}
