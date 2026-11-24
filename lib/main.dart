import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:proximity_sensor/proximity_sensor.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(const RoverBrainApp());
}

class RoverBrainApp extends StatelessWidget {
  const RoverBrainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rover Brain',
      theme: ThemeData.dark(),
      home: const SensorScreen(),
    );
  }
}

class SensorScreen extends StatefulWidget {
  const SensorScreen({super.key});

  @override
  State<SensorScreen> createState() => _SensorScreenState();
}

class _SensorScreenState extends State<SensorScreen>
    with WidgetsBindingObserver {
  CameraController? cameraController;
  String cameraStatus = 'Starting camera...';

  bool? isNear;
  StreamSubscription<int>? proximitySubscription;

  Position? currentPosition;
  String gpsStatus = 'Waiting for GPS permission...';
  StreamSubscription<Position>? gpsSubscription;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    startCamera();
    startProximitySensor();
    startGPS();
  }

  Future<void> startCamera() async {
    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        setState(() {
          cameraStatus = 'No camera found';
        });
        return;
      }

      final rearCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        rearCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      cameraController = controller;

      await controller.initialize();

      if (!mounted) return;

      setState(() {
        cameraStatus = 'Camera ready';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        cameraStatus = 'Camera error: $e';
      });
    }
  }

  void startProximitySensor() {
    proximitySubscription = ProximitySensor.events.listen((event) {
      if (!mounted) return;

      setState(() {
        isNear = event > 0;
      });
    });
  }

  Future<void> startGPS() async {
    try {
      bool serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        setState(() {
          gpsStatus = 'Please turn ON phone location';
        });
        return;
      }

      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        setState(() {
          gpsStatus = 'Location permission denied';
        });
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          gpsStatus = 'Enable location permission in Settings';
        });
        return;
      }

      setState(() {
        gpsStatus = 'Searching for GPS location...';
      });

      gpsSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 2,
        ),
      ).listen(
        (Position position) {
          if (!mounted) return;

          setState(() {
            currentPosition = position;
            gpsStatus = 'GPS location received';
          });
        },
        onError: (error) {
          if (!mounted) return;

          setState(() {
            gpsStatus = 'GPS error: $error';
          });
        },
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        gpsStatus = 'GPS error: $e';
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      cameraController?.dispose();
      cameraController = null;
    } else if (state == AppLifecycleState.resumed) {
      startCamera();
    }
  }

  Widget sensorCard(String title, String values) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(values, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rover Brain - Sensors'),
      ),
      body: ListView(
        children: [
          sensorCard(
            'GPS / Location',
            currentPosition == null
                ? gpsStatus
                : 'Latitude: ${currentPosition!.latitude}\n'
                    'Longitude: ${currentPosition!.longitude}\n'
                    'Accuracy: ${currentPosition!.accuracy.toStringAsFixed(1)} m\n'
                    'Speed: ${currentPosition!.speed.toStringAsFixed(2)} m/s\n'
                    'Altitude: ${currentPosition!.altitude.toStringAsFixed(1)} m',
          ),

          sensorCard(
            'Proximity Sensor',
            isNear == null
                ? 'Waiting for sensor...'
                : isNear!
                    ? 'Object is NEAR'
                    : 'Object is FAR',
          ),

          sensorCard(
            'Camera',
            cameraStatus,
          ),

          if (cameraController != null &&
              cameraController!.value.isInitialized)
            Padding(
              padding: const EdgeInsets.all(8),
              child: SizedBox(
                height: 260,
                child: CameraPreview(cameraController!),
              ),
            ),

          StreamBuilder<AccelerometerEvent>(
            stream: accelerometerEventStream(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return sensorCard('Accelerometer', 'Waiting...');
              }

              final e = snapshot.data!;
              return sensorCard(
                'Accelerometer',
                'X: ${e.x.toStringAsFixed(2)}\n'
                    'Y: ${e.y.toStringAsFixed(2)}\n'
                    'Z: ${e.z.toStringAsFixed(2)}',
              );
            },
          ),

          StreamBuilder<GyroscopeEvent>(
            stream: gyroscopeEventStream(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return sensorCard('Gyroscope', 'Waiting...');
              }

              final e = snapshot.data!;
              return sensorCard(
                'Gyroscope',
                'X: ${e.x.toStringAsFixed(2)}\n'
                    'Y: ${e.y.toStringAsFixed(2)}\n'
                    'Z: ${e.z.toStringAsFixed(2)}',
              );
            },
          ),

          StreamBuilder<MagnetometerEvent>(
            stream: magnetometerEventStream(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return sensorCard('Magnetometer', 'Waiting...');
              }

              final e = snapshot.data!;
              return sensorCard(
                'Magnetometer',
                'X: ${e.x.toStringAsFixed(2)}\n'
                    'Y: ${e.y.toStringAsFixed(2)}\n'
                    'Z: ${e.z.toStringAsFixed(2)}',
              );
            },
          ),

          StreamBuilder<BarometerEvent>(
            stream: barometerEventStream(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return sensorCard(
                  'Barometer',
                  'Waiting or not available',
                );
              }

              final e = snapshot.data!;
              return sensorCard(
                'Barometer',
                'Pressure: ${e.pressure.toStringAsFixed(2)} hPa',
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    proximitySubscription?.cancel();
    gpsSubscription?.cancel();
    cameraController?.dispose();
    super.dispose();
  }
}