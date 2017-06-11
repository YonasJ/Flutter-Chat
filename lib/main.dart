import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:async';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_database/ui/firebase_animated_list.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:math';
import 'dart:io';


final googleSignIn = new GoogleSignIn();
final analytics = new FirebaseAnalytics();
final auth = FirebaseAuth.instance;
final reference = FirebaseDatabase.instance.reference().child('messages');

final ThemeData kIOSTheme = new ThemeData(
    primarySwatch: Colors.amber,
    primaryColor: Colors.grey[200],
    primaryColorBrightness: Brightness.light
);

final ThemeData kDefaultTheme = new ThemeData(
  primarySwatch: Colors.indigo,
  accentColor: Colors.blueAccent,
);

void main() {
  runApp(new MyApp());
}


class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'Flutter Chat',
      theme: defaultTargetPlatform == TargetPlatform.iOS ? kIOSTheme: kDefaultTheme,
      home: new chatScreen(),
    );
  }
}

class chatScreen extends StatefulWidget {

  @override
  State createState() => new ChatScreenState();
}

class ChatScreenState extends State<chatScreen> {
  final TextEditingController _textController = new TextEditingController();
  bool _isTyping = false;

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text("Flutter Chat"),
        elevation: Theme.of(context).platform == TargetPlatform.iOS ? 0.0 : 4.0,
      ),
      body: new Container(
          child: new Column(
            children: <Widget>[
              new Flexible(
                  child: new FirebaseAnimatedList(
                    query: reference,
                    sort: (a,b) => b.key.compareTo(a.key),
                    padding: new EdgeInsets.all(8.0),
                    reverse: true,
                    itemBuilder: (_, DataSnapshot snapshot, Animation<double> animation) {
                      return new ChatMessage(
                          snapshot: snapshot,
                          animation: animation
                      );
                    },
                  )
              ),
              new Divider(height: 1.0),
              new Container(
                decoration: new BoxDecoration(
                    color: Theme.of(context).cardColor),
                child: _buildTestComposer(),
              ),
            ],
          ),
          decoration: Theme.of(context).platform == TargetPlatform.iOS ? new BoxDecoration(border: new Border(top: new BorderSide(color: Colors.grey[200]))) : null),//new
    );
  }

  Widget _buildTestComposer() {
    return new IconTheme(
        data: new IconThemeData(color: Theme.of(context).accentColor),
        child: new Container(
          margin: const EdgeInsets.symmetric(horizontal: 8.0),
          child: new Row(
              children: <Widget>[
                new Container(
                  margin: new EdgeInsets.symmetric(horizontal: 4.0),
                  child: new IconButton(
                      icon: new Icon(Icons.photo_camera),
                      onPressed: () async {
                        await _ensureLoggedIn();
                        File image = await ImagePicker.pickImage();
                        int r = new Random().nextInt(100000);
                        StorageReference ref = FirebaseStorage.instance.ref().child("image_$r.jpg");
                        StorageUploadTask upload = ref.put(image);
                        Uri  downloadUrl = (await upload.future).downloadUrl;
                        _sendMessage(imageUrl: downloadUrl.toString());
                      }
                  ),
                ),
                new Flexible(
                  child: new TextField(
                    controller: _textController,
                    onChanged: (String text) {
                      setState(() {
                        _isTyping = true;
                      });
                    },
                    onSubmitted: _handleSubmitted,
                    decoration: new InputDecoration.collapsed(hintText: "Enter a message"),
                  ),
                ),
                new Container(
                  margin: new EdgeInsets.symmetric(horizontal: 4.0),
                  child: Theme.of(context).platform == TargetPlatform.iOS ?
                  new CupertinoButton(
                    child: new Text("Send"),
                    onPressed: _isTyping ? () =>_handleSubmitted(_textController.text) : null,
                  ) :

                  new IconButton(
                    icon: new Icon(Icons.send),
                    onPressed: _isTyping ?
                        () => _handleSubmitted(_textController.text) :
                    null,
                  ),
                ),

              ]
          ),
        )
    );
  }

  Future<Null> _handleSubmitted(String text) async {
    _textController.clear();
    setState(() {
      _isTyping = false;
    });
    await _ensureLoggedIn();
    _sendMessage(text:text);
  }

  void _sendMessage({ String text, String imageUrl}) {
    reference.push().set({
      'text': text,
      'imageUrl': imageUrl,
      'senderName': googleSignIn.currentUser.displayName,
      'senderPhotoUrl': googleSignIn.currentUser.photoUrl,
    });
    analytics.logEvent(name: 'send_message');
  }

  Future<Null> _ensureLoggedIn() async {
    GoogleSignInAccount user = googleSignIn.currentUser;
    if (user == null)
      user = await googleSignIn.signInSilently();
    if (user == null) {
      await googleSignIn.signIn();
      analytics.logLogin();
    }
    if (auth.currentUser == null) {
      GoogleSignInAuthentication credentials = await googleSignIn.currentUser.authentication;
      await auth.signInWithGoogle(idToken: credentials.idToken, accessToken: credentials.accessToken);
    }
  }

}

class ChatMessage extends StatelessWidget {
  ChatMessage({this.snapshot, this.animation});
  final DataSnapshot snapshot;
  final Animation animation;
  @override
  Widget build(BuildContext context) {
    return new SizeTransition(
        sizeFactor: new CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut
        ),
        axisAlignment: 0.0,
        child: new Container(
          margin: const EdgeInsets.symmetric(vertical: 10.0),
          child: new Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              new Container(
                margin: const EdgeInsets.only(right: 16.0),
                child: new GoogleUserCircleAvatar(snapshot.value['senderPhotoUrl']),
              ),
              new Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  new Text(snapshot.value['senderName'], style: Theme.of(context).textTheme.subhead),
                  new Container(
                    margin: const EdgeInsets.only(top: 5.0),
                    child: snapshot.value['imageUrl'] != null ?
                      new Image.network(
                        snapshot.value['imageUrl'],
                        width: 250.0,
                      ) : new Text(snapshot.value['text']),
                  ),
                ],
              ),
            ],
          ),
        )
    );
  }
}