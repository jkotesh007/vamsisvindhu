import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:grocery_store/config/config.dart';
import 'package:grocery_store/screens/home_screen.dart';
import 'package:grocery_store/screens/my_orders_screen.dart';
import 'package:grocery_store/screens/product_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

dynamic notificationData;
FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

class FirebaseService {
  static init(context, uid, User currentUser) {
    initDynamicLinks(context);
    updateFirebaseToken(currentUser);
    initFCM(uid, context, currentUser);
    configureFirebaseListeners(context, currentUser);
  }
}

initDynamicLinks(context) async {
  PendingDynamicLinkData data =
      await FirebaseDynamicLinks.instance.getInitialLink();
  Uri deepLink = data?.link;

  if (deepLink != null) {
    print('LAUNCH');
    print('DEEP LINK URL ::: $deepLink ');
    print(deepLink.toString());
    // print(deepLink.queryParameters['link']);

    // print(
    //     deepLink.queryParameters['link'].split('${Config().urlPrefix}/')[1]);

    // var tempLink = deepLink.queryParameters['${Config().urlPrefix}/'];
    String pid = deepLink.toString().split('${Config().urlPrefix}/')[1];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductScreen(
          productId: pid,
        ),
      ),
    );
  }

  FirebaseDynamicLinks.instance.onLink(
      onSuccess: (PendingDynamicLinkData dynamicLink) async {
    Uri deepLink = dynamicLink?.link;

    if (deepLink != null) {
      print('ON_LINK');
      print('DEEP LINK URL ::: $deepLink ');
      // print(deepLink.queryParametersAll);
      // print(deepLink.queryParameters['link']);

      // print(deepLink.queryParameters['link']
      //     .split('${Config().urlPrefix}/')[1]);

      // var tempLink = deepLink.queryParameters['${Config().urlPrefix}/'];
      String pid = deepLink.toString().split('${Config().urlPrefix}/')[1];

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProductScreen(
            productId: pid,
          ),
        ),
      );
    }
  }, onError: (OnLinkErrorException e) async {
    print('onLinkError');
    print(e.message);
  });
}

//FCM
updateFirebaseToken(User currentUser) {
  FirebaseMessaging firebaseMessaging = FirebaseMessaging.instance;

  firebaseMessaging.getToken().then((token) {
    print(token);
    FirebaseFirestore.instance.collection('Users').doc(currentUser.uid).update({
      'tokenId': token,
    });
  });
}

initFCM(String uid, context, User currentUser) async {
  flutterLocalNotificationsPlugin = new FlutterLocalNotificationsPlugin();
  var android = new AndroidInitializationSettings('grocery');
  var ios = new IOSInitializationSettings();
  var initSetting = new InitializationSettings(iOS: ios, android: android);
  flutterLocalNotificationsPlugin.initialize(
    initSetting,
    onSelectNotification: (data) async {
      print('Send to my orders ::: $notificationData');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MyOrdersScreen(
            currentUser: currentUser,
          ),
        ),
      );
    },
  );
}

configureFirebaseListeners(context, User currentUser) async {
  FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage message) {
    print('INITIAL MESSAGE :: $message');

    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => HomeScreen(),
    //   ),
    // );
  });

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('ON MESSAGE :: $message');

    RemoteNotification notification = message.notification;
    AndroidNotification android = message.notification?.android;

    if (notification != null && android != null) {
      showNotification(
        notification,
      );
    }
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('A new onMessageOpenedApp event was published!');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HomeScreen(),
      ),
    );
  });

  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true, // Required to display a heads up notification
    badge: true,
    sound: true,
  );

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel', // id
    'High Importance Notifications', // title
    'This channel is used for important notifications.', // description
    importance: Importance.max,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // FirebaseMessaging firebaseMessaging = FirebaseMessaging.instance;
  // FirebaseMessaging.onMessage.listen((RemoteMessage event) {
  //   print('onMessage: ${event}');
  //   RemoteMessage notificationData = event;
  //   // showNotification(
  //   //   notificationData,
  //   //   notificationData['data']['type'],
  //   //   context,
  //   // );
  // });

  // FirebaseMessaging.onBackgroundMessage((message) {
  //   notificationData = message;
  //   print(notificationData);

  //   return Future<void>.value();
  // });
  // firebaseMessaging.configure(
  //   onBackgroundMessage: firebaseBackgroundMessageHandler,
  //   onMessage: (Map<String, dynamic> message) async {
  //     print('onMessage: $message');
  //     notificationData = message;
  //     showNotification(
  //       notificationData,
  //       notificationData['data']['type'],
  //       context,
  //     );
  //   },
  //   onLaunch: (Map<String, dynamic> message) async {
  //     notificationData = message;
  //     print('onLaunch: $notificationData');
  //     //send user to my orders

  //     Navigator.push(
  //       context,
  //       MaterialPageRoute(
  //         builder: (context) => MyOrdersScreen(
  //           currentUser: currentUser,
  //         ),
  //       ),
  //     );
  //   },
  //   onResume: (Map<String, dynamic> message) async {
  //     notificationData = message;
  //     print('onResume: $notificationData');

  //     //send to my orders
  //     Navigator.push(
  //       context,
  //       MaterialPageRoute(
  //         builder: (context) => MyOrdersScreen(
  //           currentUser: currentUser,
  //         ),
  //       ),
  //     );
  //   },
  // );
}

showNotification(
  RemoteNotification data,
) async {
  var aNdroid = new AndroidNotificationDetails(
    'channelId',
    'channel_name',
    'desc',
    importance: Importance.high,
  );
  var iOS = new IOSNotificationDetails();
  var platform = new NotificationDetails(android: aNdroid, iOS: iOS);

  await flutterLocalNotificationsPlugin.show(
    Random().nextInt(100),
    data.title,
    data.body,
    platform,
  );
}

Future<dynamic> firebaseBackgroundMessageHandler(
    Map<String, dynamic> message) async {
  notificationData = message;
  print(notificationData);

  return Future<void>.value();
}

Future<void> _firebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  print('ON MESSAGE :: $message');

  RemoteNotification notification = message.notification;
  AndroidNotification android = message.notification?.android;

  if (notification != null && android != null) {
    showNotification(
      notification,
    );
  }
}
