import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:proximity_sensor/proximity_sensor.dart';
import 'package:camera/camera.dart';
import 'dart:io';
// ignore: library_prefixes
import 'package:socket_io_client/socket_io_client.dart' as IO;

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool isNear = false;
  bool securityMode = false; 
  CameraController? _cameraController;
  late List<CameraDescription> cameras;
  late IO.Socket socket;
  bool isConnected = false; 
  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _connectToServer();
    _listenProximitySensor();
  }

  void _initializeCamera() async {
    cameras = await availableCameras();
    _cameraController = CameraController(cameras[0], ResolutionPreset.medium);
    await _cameraController!.initialize();
  }

  void _connectToServer() {
    if (kDebugMode) {
      print("🔌 Tentando conectar ao servidor...");
    }
    socket = IO.io('http://192.168.0.102:5000', IO.OptionBuilder()
       .setTransports(['websocket'])
       .setExtraHeaders({'Connection': 'Upgrade', 'Upgrade': 'websocket'})
       .build());

    socket.onConnect((_) {
      if (kDebugMode) {
        print("✅ Conectado ao servidor!");
      }
      setState(() {
        isConnected = true;
      });
    });

    socket.onDisconnect((_) {
      if (kDebugMode) {
        print("❌ Desconectado do servidor.");
      }
      setState(() {
        isConnected = false;
      });
    });

    socket.onConnectError((data) {
      if (kDebugMode) {
        print("⚠️ Erro ao conectar: $data");
      }
      setState(() {
        isConnected = false;
      });
    });

    socket.connect();
  }

  void _listenProximitySensor() {
    ProximitySensor.events.listen((int event) {
      if (securityMode) {
        setState(() {
          isNear = event == 1;
        });
        if (isNear) {
          _sendAlert();
        }
      }
    });
  }

  Future<void> _sendAlert() async {
    if (isConnected) { 
      if (kDebugMode) {
        print("📩 Enviando ALERTA ao servidor...");
      }
      socket.emit('ALERTA');
      _captureAndSendImage();
    } else {
      if (kDebugMode) {
        print("❌ Erro: Socket não está conectado. Tentando reconectar...");
      }
      _connectToServer();
    }
  }

  Future<void> _captureAndSendImage() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    final image = await _cameraController!.takePicture();
    final File imageFile = File(image.path);

    List<int> imageBytes = await imageFile.readAsBytes();
    Uint8List uint8list = Uint8List.fromList(imageBytes);

    if (isConnected) {
      if (kDebugMode) {
        print("📸 Enviando imagem ao servidor...");
      }
      socket.emit('imagem', uint8list);
    } else {
      if (kDebugMode) {
        print("❌ Erro: Socket não conectado. Imagem não enviada.");
      }
    }
  }

  void _toggleSecurityMode() {
    setState(() {
      securityMode = !securityMode;
      isNear = false; 
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('Sensor de Proximidade')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, color: securityMode ? Colors.red : Colors.green, size: 16),
                  SizedBox(width: 8),
                  Text(
                    securityMode ? 'Segurança ATIVADA' : 'Segurança DESATIVADA',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Text(
                securityMode
                    ? (isNear ? "🚨 Movimento Detectado!" : "✅ Nenhuma Atividade")
                    : "⚠️ Ative a segurança para monitorar",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                isConnected ? "🟢 Servidor Conectado" : "🔴 Sem conexão com o servidor",
                style: TextStyle(fontSize: 16, color: isConnected ? Colors.green : Colors.red),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _toggleSecurityMode,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  textStyle: TextStyle(fontSize: 18),
                ),
                child: Text(securityMode ? "Desativar Segurança" : "Ativar Segurança"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
