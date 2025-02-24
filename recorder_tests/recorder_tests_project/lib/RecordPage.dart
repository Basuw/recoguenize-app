// ignore_for_file: prefer_const_constructors

import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';
import 'package:avatar_glow/avatar_glow.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_sound/public/flutter_sound_recorder.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'customPopup/custom_dialog_widget.dart';

import 'recorder.dart';


class RecordPage extends StatefulWidget {
  const RecordPage({super.key, required this.title});

  final String title;

  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> with SingleTickerProviderStateMixin {
  late AudioPlayer audioPlayer;
  bool isGlobalRecording = false;
  bool isSearching = false;
  String audioPath = '';
  int recNum = 0;
  int tapNb = 0;
  String ipAddress = '51.120.246.62';
  late AnimationController _controller;
  late Animation<double> _animation;
  Recorder recorder = Recorder();
  FlutterSoundRecorder audioRecord = FlutterSoundRecorder();

  Future<String> get dirPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  @override
  void initState() {
    audioRecord.openRecorder();
    audioPlayer = AudioPlayer();

    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    )
    ..addListener(() {
      setState(() { });
    })
    ..addStatusListener((status) {
      if(status == AnimationStatus.completed) {
        _controller.stop();
      }
    });

    super.initState();
  }

  @override
  void dispose() {
    audioRecord.closeRecorder();
    audioPlayer.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> startGlobalRecording() async {
    try{
      print("start");
      _controller.repeat();
      setState(() {
        isGlobalRecording = true;
      });
      while(isGlobalRecording){
        recNum = await recorder.startRecording(audioRecord, audioPath, recNum);
        await Future.delayed(const Duration(milliseconds: 10000));
        await recorder.stopRecording(audioRecord);
        bool sendCompleted = await sendWavToBack();
        if(sendCompleted){
          print("Getting song info");
          var response = await getSongInfo();
          await showInfo(context, response);
          setState(() {
            isSearching=false;
          });
        }
        print("boucle $recNum");
      }
      audioPath = await dirPath;
      audioPath += "/rec";
      audioPath +=  recNum.toString();
      audioPath += ".wav";
    }
    catch(e){
      print("crash during globalreccording : $e");
    }
  }

  Future<void> stopGlobalRecording() async {
    print("stop");
    _controller.forward(from: _controller.value);
    setState(() {
      isGlobalRecording = false;
      isSearching=true;
    });

  }

  Future<void> tapDetection(TapDownDetails details) async {
    isGlobalRecording ? stopGlobalRecording() : startGlobalRecording();
  }

  Future<bool> sendWavToBack() async {
    try {
      print("Sending file $recNum to backend");
      Int16List fileBytes = await readAudioFileAsBytes("rec$recNum.wav");

      String jsonName = "json$recNum";

      var requestBody = {
        "sample_rate": 44100,
        "channels": 1,
        "audio": fileBytes,
        "name": jsonName
      };

      var response = await http.post(
        Uri.parse('http://$ipAddress:8000/upload-json/'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      //print(response.statusCode);
      //print(response.body);
      return response.statusCode == 200;
    }
    catch (e) {
      print("Error sending wav file to backend: $e");
      return false;
    }
  }

  Future<http.Response> getSongInfo() async {

    String jsonName = "json$recNum";

    var info = {
      "name": jsonName,
    };

    final response = await http.post(
      Uri.parse('http://$ipAddress:8000/jsontowav/'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(info),
    );

    //print(response.statusCode);
    //print(response.body);
    return response;
  }

  Future<void> showInfo(BuildContext context, http.Response response) async {
    var json = jsonDecode(response.body);
    String titre;
    String artiste;
    String album;

    if (json == null){
      titre = "Aucune musique trouvée :(";
      artiste = "";
      album = "";
    } else {
      stopGlobalRecording();
      titre = json['title'];
      artiste = json['artists'][0]['name'];
      album = json['albums'][0]['title'];
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Musique trouvée !"),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Musique: $titre'),
                Text('Artiste: $artiste'),
                Text('Artiste: $album')
                // Ajoutez d'autres informations si nécessaire
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Fermer'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<Int16List> readAudioFileAsBytes(String fileName) async {
    try {
      String filePath = await getFilePath(fileName);
      File audioFile = File(filePath);
      Uint8List fileBytes = await audioFile.readAsBytes();
      return fileBytes.buffer.asInt16List();
    }
    catch (e) {
      print("Error reading audio file: $e");
      return Int16List(0);
    }
  }

  Future<String> getFilePath(String fileName) async {
    Directory directory = await getApplicationDocumentsDirectory();
    String filePath = '${directory.path}/$fileName';
    return filePath;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF42958f),
      body: SingleChildScrollView(
        child : Container(
          height: MediaQuery.of(context).size.height,
          width: MediaQuery.of(context).size.width,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              if (isGlobalRecording)
                Text(
                  'Recoguenizing...',
                  style: TextStyle(color: Color(0xFFfdfefc), fontSize: 30, fontFamily: 'Arial_Rounded'),
                ),
              if (isSearching)
                Text(
                  'Searching for a match...',
                  style: TextStyle(color: Color(0xFFfdfefc), fontSize: 30, fontFamily: 'Arial_Rounded'),
                ),
              if (!isGlobalRecording && ! isSearching)
                Text(
                  'Tap to recoguenize',
                  style: TextStyle(color: Color(0xFFfdfefc), fontSize: 30, fontFamily: 'Arial_Rounded'),
                ),
              SizedBox(
                height: 40,
              ),
              AvatarGlow(
                endRadius: 200.0,
                animate: isGlobalRecording,
                child: GestureDetector(
                  onTapDown: tapDetection,
                  child: AnimatedBuilder(
                    animation: _animation,
                    child: Material(
                      shape: CircleBorder(),
                      elevation: 8,
                      child: Container(
                          padding: EdgeInsets.all(2),
                          height: 200,
                          width: 200,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle, color: Color(0xFFFFFFFF)),
                          child: Image.asset(
                            'assets/vinyle_simple.png',
                            fit: BoxFit.cover,
                          )
                      ),
                    ),
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _animation.value * 5.0 * 3.141592653589793,
                        child: child,
                      );
                    },
                  ),
                ),
              ),
              Text('Entrer une adresse IP manuellement :'),
              TextField(
                decoration: InputDecoration(
                  hintText: "IP vm par défaut",
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    ipAddress = value;
                  });
                },
              ),
            ],
          ),
        ),
      )
    );
  }
}
