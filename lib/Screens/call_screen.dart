import 'package:agora_audio_broadcast/Utils/utils.dart';
import 'package:agora_audio_broadcast/Widgets/user_view.dart';
import 'package:agora_rtm/agora_rtm.dart';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/rtc_engine.dart';
import 'package:agora_rtc_engine/rtc_local_view.dart' as RtcLocalView;
import 'package:agora_rtc_engine/rtc_remote_view.dart' as RtcRemoteView;

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
  RtcEngine _engine;
  final _audience = <String>[];
  final _broadcaster = <String>[];

  bool _isLogin = false;
  bool _isInChannel = false;

  AgoraRtmClient _client;
  AgoraRtmChannel _channel;

  String textMessage = '';

  @override
  void dispose() {
    // clear users
    _users.clear();
    // destroy sdk
    _engine.leaveChannel();
    _engine.destroy();
    _broadcaster.clear();
    _audience.clear();
    textMessage = '';
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
    }, audioVolumeIndication: (speakers, totalVolume) {
      setState(() {
        final info =
            'Speaker $speakers is speaking with a volume of $totalVolume';
        _infoStrings.add(info);
      });
    }, joinChannelSuccess: (channel, uid, elapsed) async {
      await _channel.sendMessage(
          AgoraRtmMessage.fromText('${widget.role}: ${widget.usernName}'));
      if (widget.role == ClientRole.Audience) {
        _audience.add(widget.usernName);
      } else {
        _broadcaster.add(widget.usernName);
      }
      setState(() {
        final info = 'onJoinChannel: $channel, uid: $uid';
        _infoStrings.add(info);
      });
    }, leaveChannel: (stats) {
      setState(() {
        _infoStrings.add('onLeaveChannel');
        _users.clear();
      });
    }, userJoined: (uid, elapsed) {
      setState(() {
        final info = 'userJoined: $uid';
        _infoStrings.add(info);
        _users.add(uid);
      });
    }, userOffline: (uid, elapsed) {
      setState(() {
        final info = 'userOffline: $uid';
        _infoStrings.add(info);
        _users.remove(uid);
      });
    }));
  }

  void _createClient() async {
    _client = await AgoraRtmClient.createInstance(appID);
    _client.onMessageReceived = (AgoraRtmMessage message, String peerId) {
      print("Peer msg: " + peerId + ", msg: " + message.text);
    };
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
    print('Login success: ' + userId + ' and user role: ${widget.role}');
    setState(() {
      _isLogin = true;
    });
    String channelName = widget.channelName;
    _channel = await _createChannel(channelName);
    await _channel.join();
    print('Join channel success.');
    setState(() {
      _isInChannel = true;
    });

    await _channel.sendMessage(
      AgoraRtmMessage.fromText('${widget.role}: ${widget.usernName}')
    );
  }

  Future<AgoraRtmChannel> _createChannel(String name) async {
    AgoraRtmChannel channel = await _client.createChannel(name);
    channel.onMemberJoined = (AgoraRtmMember member) {
      print("Member joined: " + member.userId + ', channel: ' + member.channelId);
    };
    channel.onMemberLeft = (AgoraRtmMember member) {
      print("Member left: " + member.userId + ', channel: ' + member.channelId);
    };
    channel.onMessageReceived = (AgoraRtmMessage message, AgoraRtmMember member) {
      print('Messager received - ${message.text} ');
      if (message.text.split(': ')[0] == 'ClientRole.Broadcaster') {
        _broadcaster.add(message.text.split(': ')[1]);
        print('Broadcaster added: ${message.text.split(': ')[1]}');
      }
      else{
        _audience.add(message.text.split(': ')[1]);
        print('Audience added: ${message.text.split(': ')[1]}');
      }
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
                itemCount: _broadcaster.length,
                itemBuilder: (BuildContext context, int index) {
                  return Column(
                    children: [
                      UserView(
                        isSpeaking: true,
                        role: ClientRole.Broadcaster,
                      ),
                      Text(_broadcaster[index]),
                    ],
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
                itemCount: _audience.length,
                itemBuilder: (BuildContext context, int index) {
                  return Column(
                    children: [
                      UserView(
                        isSpeaking: true,
                        role: ClientRole.Audience,
                      ),
                      Text(_audience[index]),
                    ],
                  );
                }),
          ),
          _toolbar()
        ],
      )),
    );
  }
}
