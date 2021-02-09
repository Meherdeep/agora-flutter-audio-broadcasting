import 'package:agora_rtc_engine/rtc_engine.dart';
import 'package:flutter/material.dart';

class UserView extends StatefulWidget {
  final bool isSpeaking;
  final String userName;
  final ClientRole role;

  const UserView({Key key, this.isSpeaking, this.userName, this.role}) : super(key: key);
   
  @override
  _UserViewState createState() => _UserViewState();
}

class _UserViewState extends State<UserView> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: MediaQuery.of(context).size.width * 0.2,
          decoration: BoxDecoration(
            color: widget.role == ClientRole.Audience ?  Colors.blueAccent : Colors.deepPurpleAccent,
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.isSpeaking ? Colors.green : Colors.red,
              width: 2
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(
                Icons.person,
                color: Colors.white
              ),
            ),
          ),
        ),
      ],
    );
  }
}