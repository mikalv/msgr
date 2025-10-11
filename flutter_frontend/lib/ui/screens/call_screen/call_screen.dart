import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class VideoCallScreen extends StatefulWidget {

  @override
  _VideoCallScreenState createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  RTCVideoRenderer localRenderer = RTCVideoRenderer();
  RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  @override
  void initState() {
    super.initState();
    // Initialize local and remote video renderers
  }

  @override
  void dispose() {
    super.dispose();
    localRenderer.dispose();
    remoteRenderer.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // ...
      ),
      body: Stack(
        children: [
          // Display local video stream
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              width: MediaQuery.of(context).size.width / 2,
              height: MediaQuery.of(context).size.height / 2,
              child: RTCVideoView(localRenderer),
            ),
          ),
          // Display remote video stream (replace with appropriate widget)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: MediaQuery.of(context).size.width / 2,
              height: MediaQuery.of(context).size.height / 2,
              child: Text('Remote Stream'),


            ),
          ),
          // Call control buttons (answer, hang up)
          // ...
        ],
      ),
    );
  }
}
