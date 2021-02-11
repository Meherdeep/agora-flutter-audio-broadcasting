import 'dart:convert';

import 'package:agora_audio_broadcast/Utils/utils.dart';
import 'package:agora_audio_broadcast/Widgets/user_view.dart';
import 'package:agora_rtm/agora_rtm.dart';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/rtc_engine.dart';


class CallScreen extends StatefulWidget {
  final String channelName;
  final String usernName;
  final ClientRole role;

  CallScreen({this.channelName, this.usernName, this.role});

  @override
  _CallScreenState createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final _users = <int>[];
  final _infoStrings = <String>[];
  bool muted = false;
  int localUid = 0;
  final _audience = <String>[];
  final _broadcaster = <String>[];
  final _allUsers = <String>[];
  bool _isLogin = false;
  bool _isInChannel = false;
  final Map<int, String> broadcasterMap = {};
  int count = 0;

  RtcEngine _engine;
  AgoraRtmClient _client;
  AgoraRtmChannel _channel;

  @override
  void dispose() {
    // clear users
    _users.clear();
    // destroy sdk
    _engine.leaveChannel();
    _engine.destroy();
    _channel.leave();
    _client.logout();
    _client.destroy();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // initialize agora sdk
    initialize();
    _createClient();
  }

  Future<void> initialize() async {
    
    if (appID.isEmpty) {
      setState(() {
        _infoStrings.add(
          'APP_ID missing, please provide your APP_ID in utils.dart',
        );
        _infoStrings.add('Agora Engine is not starting');
      });
      return;
    }

    await _initAgoraRtcEngine();
    _addAgoraEventHandlers();
    await _engine.enableWebSdkInteroperability(true);
    VideoEncoderConfiguration configuration = VideoEncoderConfiguration();
    configuration.dimensions = VideoDimensions(1920, 1080);
    await _engine.setVideoEncoderConfiguration(configuration);
    await _engine.joinChannel(null, widget.channelName, null, 0);
  }

  Future<void> _initAgoraRtcEngine() async {
    _engine = await RtcEngine.create(appID);
    await _engine.disableVideo();
    await _engine.enableAudio();
    await _engine.setChannelProfile(ChannelProfile.LiveBroadcasting);
    await _engine.setClientRole(widget.role);
    await _engine.enableAudioVolumeIndication(200, 3, true);
  }

  void _addAgoraEventHandlers() {
    _engine.setEventHandler(RtcEngineEventHandler(error: (code) {
      setState(() {
        final info = 'onError: $code';
        _infoStrings.add(info);
      });
    }, joinChannelSuccess: (channel, uid, elapsed) async {
      setState(() {
        final info = 'onJoinChannel: $channel, uid: $uid';
        _infoStrings.add(info);
        localUid = uid;
      });
      if (widget.role == ClientRole.Audience) {
        setState(() {
          // _audience.add(widget.usernName);
        });
      } else {
        setState(() {
          _broadcaster.add(widget.usernName);
          broadcasterMap[localUid] = widget.usernName;
        });
        await _channel.sendMessage(AgoraRtmMessage.fromText('$uid'));
      print('Local user message sent');
      }
    }, leaveChannel: (stats) {
      setState(() {
        _infoStrings.add('onLeaveChannel');
        _users.clear();
        broadcasterMap.remove(localUid);
      });
      print('User left: $localUid');
    }, userJoined: (uid, elapsed) async {
      await _channel.sendMessage(AgoraRtmMessage.fromText('$localUid'));
      print('Remote hosts added - $uid');
      setState(() {
        final info = 'userJoined: $uid';
        _infoStrings.add(info);
        _users.add(uid);
      });
    }, userOffline: (uid, elapsed) async {
      await _channel.sendMessage(AgoraRtmMessage.fromText('$uid'));
      print('Remote hosts removed - uid sent');
      setState(() {
        final info = 'userOffline: $uid';
        _infoStrings.add(info);
        _users.remove(uid);
        broadcasterMap.remove(uid);
      });
    }));
  }
  
  void _createClient() async {
    _client = await AgoraRtmClient.createInstance(appID);
    _client.onConnectionStateChanged = (int state, int reason) {
      print('Connection state changed: ' +
          state.toString() +
          ', reason: ' +
          reason.toString());
      if (state == 5) {
        _client.logout();
        print('Logout.');
        setState(() {
          _isLogin = false;
        });
      }
    };

    String userId = widget.usernName;
    await _client.login(null, userId);
        print('Login success: ' + userId);
        setState(() {
          _isLogin = true;
    });
    _channel = await _createChannel(widget.channelName);
        await _channel.join();
        print('Join channel success.');
        setState(() {
          _isInChannel = true;
        });
    
    
    // await returnAudienceMembers(); 
    // print('List of broadcaster: ${broadcasterMap.values}');
    // print('List of audience member: $_audience');
  }

  List<String> returnAudienceMembers() {
  _allUsers.forEach((element) { 
      if (!broadcasterMap.values.contains(element)) {
        setState(() {
          _audience.add(element);
        });
      }
    });
    print('List of audience member (inside): $_audience');
    return ['$_audience'];
  }

  Future<AgoraRtmChannel> _createChannel(String name) async {
    AgoraRtmChannel channel = await _client.createChannel(name);
    channel.onMemberJoined = (AgoraRtmMember member) {
      print("Member joined: " + member.userId + ', channel: ' + member.channelId);
      _client.sendMessageToPeer(widget.usernName, AgoraRtmMessage.fromText('$localUid'));
    };
    channel.onMemberLeft = (AgoraRtmMember member) {
      print("Member left: " + member.userId + ', channel: ' + member.channelId);
    };
    channel.onMessageReceived = (AgoraRtmMessage message, AgoraRtmMember member) {
      print('Message Received - ${message.text} from ${member.userId}');
      broadcasterMap[int.parse(message.text)] = member.userId;
    };
    channel.onMemberCountUpdated = (int memberCount){
      channel.getMembers().then((value) {
      for (var i = 0; i < memberCount; i++) {
         setState(() {
          _allUsers.add(value[i].userId);
        });
        print('All users in the channel ${_allUsers}');
      }
      _allUsers.forEach((element) { 
      if (!broadcasterMap.values.contains(element)) {
        setState(() {
          _audience.add(element);
        });
      }
    });
    print('List of audience: $_audience');
    });
      _allUsers.clear();
    };
    
    channel.onMemberLeft = (AgoraRtmMember member){
      print('Member left - ${member.userId}');
      setState(() {
        _audience.remove(member.userId);
      });
      print('List of audience when user left: $_audience');
    };
    return channel;
  }
  
  Widget _toolbar() {
    if (widget.role == ClientRole.Audience) return Container();
    return Container(
      alignment: Alignment.bottomCenter,
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          RawMaterialButton(
            onPressed: _onToggleMute,
            child: Icon(
              muted ? Icons.mic_off : Icons.mic,
              color: muted ? Colors.white : Colors.blueAccent,
              size: 20.0,
            ),
            shape: CircleBorder(),
            elevation: 2.0,
            fillColor: muted ? Colors.blueAccent : Colors.white,
            padding: const EdgeInsets.all(12.0),
          ),
          RawMaterialButton(
            onPressed: () => _onCallEnd(context),
            child: Icon(
              Icons.call_end,
              color: Colors.white,
              size: 35.0,
            ),
            shape: CircleBorder(),
            elevation: 2.0,
            fillColor: Colors.redAccent,
            padding: const EdgeInsets.all(15.0),
          ),
          RawMaterialButton(
            onPressed: _onSwitchCamera,
            child: Icon(
              Icons.switch_camera,
              color: Colors.blueAccent,
              size: 20.0,
            ),
            shape: CircleBorder(),
            elevation: 2.0,
            fillColor: Colors.white,
            padding: const EdgeInsets.all(12.0),
          )
        ],
      ),
    );
  }

  void _onSwitchCamera() {
    _engine.switchCamera();
  }

  void _onCallEnd(BuildContext context) {
    Navigator.pop(context);
  }

  void _onToggleMute() {
    setState(() {
      muted = !muted;
    });
    _engine.muteLocalAudioStream(muted);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
          child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Broadcaster',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          Container(
            height: MediaQuery.of(context).size.height * 0.2,
            width: double.infinity,
            child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: broadcasterMap.length,
                itemBuilder: (BuildContext context, int index) {
                  return Text(
                    '${broadcasterMap.values}'
                  );
                }),
          ),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.1,
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Audience',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          Container(
            height: MediaQuery.of(context).size.height * 0.2,
            width: double.infinity,
            child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _audience.toSet().length,
                itemBuilder: (BuildContext context, int index) {
                  return Text('${_audience.toSet().toList()[index]}');
                }),
          ),
          _toolbar()
        ],
      )),
    );
  }
}
