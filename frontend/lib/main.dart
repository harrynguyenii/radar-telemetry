import 'dart:ffi' as ffi;
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'radar_compass_panel.dart';
import 'package:wifi_scan/wifi_scan.dart';

// 1. Define the FFI signature for the C function

typedef ComputeHammingC = ffi.Int32 Function(ffi.Int32 val1, ffi.Int32 val2);
typedef ComputeHammingDart = int Function(int val1, int val2);

void main() {
	runApp(const RadarTelemetryApp());
}

class RadarTelemetryApp extends StatelessWidget {
	const RadarTelemetryApp({super.key});

	@override
	Widget build(BuildContext context) {
		return MaterialApp(
			title: 'Radar Telemetry Simulator',
			theme: ThemeData.dark(),
			home: const RadarDashboard(),
		);
	}
}

class RadarDashboard extends StatefulWidget {
	const RadarDashboard({super.key});

	@override
	State<RadarDashboard> createState() => _RadarDashboardState();
}

class _RadarDashboardState extends State<RadarDashboard> {
	Timer? _sweepTimer;
	double _currentSweepAngle = 0.0;
	final double _lastHammingDistance = 4.0;
	late ComputeHammingDart computeHamming;
	List<double> wavePoints = [];
	int lastHammingDistance = 0;
	int _lastSequence = -1;
	int _droppedPackets = 0;
	double _currentLatencyMs = 0.0;
	final ValueNotifier<String> statsNotifier = ValueNotifier<String>("0 dropped | 0.0ms latency");
	final ValueNotifier<List<double>> wavePointsNotifier = ValueNotifier<List<double>>([]);
	double _sensitivityThreshold = 0.75;
	String _selectedRadarProfileMode = 'High-Resolution Scan';
	bool _isCalibrating = false;
	late RawDatagramSocket _udpSocket;
	bool isEmergencyActive = false;
	late TelemetryProvider activeProvider;

	@override
	void initState() {
		super.initState();
		_initC(0, 0);
		_initUdpSocket();
		_sweepTimer = Timer.periodic(const Duration(milliseconds: 40), (timer) {
			setState(() {
				_currentSweepAngle += 0.05;

				if (_currentSweepAngle > 6.28) {
					_currentSweepAngle = 0.0;
				}
			});
		});
		activeProvider = UdpSimulationProvider();
		activeProvider.initialize();
	}


	void switchDataSource(bool useHardwareRF) {
		activeProvider.dispose();
		setState(() {
			if (useHardwareRF) {
				activeProvider = RfHardwareScanProvider();
			} else {
				activeProvider = UdpSimulationProvider();
			}
			activeProvider.initialize();
		});
	}

	int _initC(int val1, int val2) {
		final libraryPath = './libcorrelator.so';
		final dylib = ffi.DynamicLibrary.open(libraryPath);
		final computeHamming = dylib.lookup<ffi.NativeFunction<ComputeHammingC>>('compute_hamming').asFunction<ComputeHammingDart>();

		return computeHamming(val1, val2);
	}

	Future<void> _initUdpSocket() async {
		try {
			_udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 5005);
			_udpSocket.listen((RawSocketEvent event) {
				if (event == RawSocketEvent.read) {
					Datagram? datagram = _udpSocket.receive();

					if (datagram != null && datagram.data.length >= 20) {
						final byteData = ByteData.sublistView(datagram.data);
						debugPrint("Received packet of length: ${datagram.data.length}");

						// Parse the 20-byte binary packet structure: <Idii
						int sequenceNumber = byteData.getUint32(0, Endian.little);
						double timestamp = byteData.getFloat64(4, Endian.little);
						int val1 = byteData.getInt32(12, Endian.little);
						int val2 = byteData.getInt32(16, Endian.little);
						parseIncomingPacket(datagram.data);	

						if (_lastSequence != 01 && sequenceNumber > _lastSequence + 1) {
							_droppedPackets += (sequenceNumber - _lastSequence - 1);
						}
						_lastSequence = sequenceNumber;

						// 2. Estimate transit latency (local time vs packet timestamp)
						double localTimeMs = DateTime.now().millisecondsSinceEpoch.toDouble();
						_currentLatencyMs = (localTimeMs - (timestamp * 1000.0)).clamp(0.0, 999.9);

						// 3. Push stats update to the notifier
						statsNotifier.value = "$_droppedPackets dropped | ${_currentLatencyMs.toStringAsFixed(1)}ms latency";
						
						// 4. Existing wave points processing
						double dist = computeHamming(val1, val2).toDouble();
						final currentPoints = List<double>.from(wavePointsNotifier.value);
						currentPoints.add(dist * _sensitivityThreshold);
						
						if (!mounted) return;

						if (currentPoints.length > 50) {
							currentPoints.removeAt(0);
						}
						debugPrint("Pushing ${currentPoints.length} points to oscilloscope. Sample: ${currentPoints.isNotEmpty ? currentPoints.last : 'empty'}");
						wavePointsNotifier.value = List.from(currentPoints);
					}
				}
			});
		} catch (e) {
			debugPrint("UDP Socket error: $e");
		}
	}

	void parseIncomingPacket(Uint8List rawBytes) {
		if (rawBytes.isEmpty) return;
		int packetType = rawBytes[0];

		if (packetType == 0x01) {
			parseRadarTelemetry(rawBytes);
		} else if (packetType == 0x02) {
			parseEmergencyAlert(rawBytes);
		}
	}

	void parseRadarTelemetry(Uint8List bytes) {
		if (bytes.length < 20) return;

		final byteData = ByteData.sublistView(bytes);

		int sequenceNumber = byteData.getUint32(0, Endian.little);
		double timestamp = byteData.getFloat64(4, Endian.little);
		int val1 = byteData.getInt32(12, Endian.little);
		int val2 = byteData.getInt32(16, Endian.little);
		setState(() {
			_lastSequence = sequenceNumber;
			timestamp = timestamp;
			val1 = val1;
			val2 = val2;	
		});
	}

	void parseEmergencyAlert(Uint8List bytes) {
		setState(() {
			isEmergencyActive = true;
			debugPrint("CRITICAL: Civil Defense Emergency Alert triggered via UDP stream!");
		});
	}

	Widget _buildControlPanel() {
		return Padding(
			padding: const EdgeInsets.all(16.0),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					const Text(
						'Radar Response Customization',
						style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
					),
					const SizedBox(height: 12),
					DropdownButtonFormField<String>(
						initialValue: _selectedRadarProfileMode,
						dropdownColor: Colors.grey[900],
						style: const TextStyle(color: Colors.white),
						decoration: InputDecoration(
							labelText: 'Signal Profile',
							labelStyle: const TextStyle(color: Colors.cyanAccent),
							enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent.withValues(alpha: 1.0))),
						),
						items: ['High-Resolution Scan', 'Wide-Angle Sweep', 'Low-Power Eco Mode'].
							map((profile) => DropdownMenuItem(value: profile, child: Text(profile))).toList(),
						onChanged: (val) {
							setState(() {
								_selectedRadarProfileMode = val!;
							});
						},
					),
					const SizedBox(height: 16),
					Row(
						mainAxisAlignment: MainAxisAlignment.center,
						children: [
							const Icon(Icons.explore, color: Colors.cyanAccent, size: 18),
							const SizedBox(width: 8),
							Text(
								'Heading Bearing: ${(_currentSweepAngle * (180 / 3.14159)).toStringAsFixed(1)} Degree(s)',
								style: const TextStyle(color: Colors.white70, fontSize: 14),
							),
						],
					),
					Text(
						'Signal Power | Sensitivity Threshold: ${(_sensitivityThreshold * 100).toStringAsFixed(0)} dBm',
						style: const TextStyle(color: Colors.white70),
					),
					Slider(
						value: _sensitivityThreshold,
						min: 0.1,
						max: 1.0,
						divisions: 9,
						activeColor: Colors.cyanAccent,
						inactiveColor: Colors.grey,
						onChanged: (val) {
							setState(() {
								_sensitivityThreshold = val;
							});
						},
					),
					const SizedBox(height: 16),
					Row(
						mainAxisAlignment: MainAxisAlignment.spaceEvenly,
						children: [
							ElevatedButton.icon(
								style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan[800]),
								icon: const Icon(Icons.tune),
								label: const Text('Calibrate Signal'),
								onPressed: () {
									setState(() => _isCalibrating = true);
									Future.delayed(const Duration(seconds: 1), () {
										setState(() => _isCalibrating = false);
									});
								},
							),
							ElevatedButton.icon(
								style: ElevatedButton.styleFrom(backgroundColor: _isCalibrating ? Colors.orange : Colors.red[800]),
								icon: const Icon(Icons.refresh),
								label: const Text('Reset Buffer'),
								onPressed: () {},
							),
						],
					),
				],
			),
		);
	}

	@override
	void dispose() {
		_udpSocket.close();
		_sweepTimer?.cancel();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: const Text('Defense-Grade Radar Telemetry Engine (UDP Stream)'),
				backgroundColor: Colors.black87,
				actions: [
					Padding(
						padding: const EdgeInsets.symmetric(horizontal: 16.0),
						child: Center(
							child: ValueListenableBuilder<String>(
									valueListenable: statsNotifier,
									builder: (context, stats, child) {
										return Text(
											"Link Status: $stats",
											style: const TextStyle(
												color: Colors.greenAccent,
												fontFamily: 'monospace',
												fontSize: 12,
										),
									);
								},
							),
						),
					),
				],
			),
			body: Padding(
				padding: const EdgeInsets.all(16.0),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
					const Text(
						'SIGNAL CORRELATION OSCILLOSCOPE (LIVE SOCKET FEED)',
						style: TextStyle(color: Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.bold),
					),
					const SizedBox(height: 10),
					Expanded(
						child: ValueListenableBuilder<List<double>>(
							valueListenable: wavePointsNotifier,
							builder: (context, wavePoints, child) {
								return Container(
									decoration: BoxDecoration(
										color: Colors.black, 
										border: Border.all(color: Colors.greenAccent, width: 2),
					),
							child: CustomPaint(
								painter: OscilloscopePainter(wavePoints),
								child: const SizedBox.expand(),
							),
						);
					},
				),
			),
					RadarCompassBenchmarkPanel(
						sweepAngle: _currentSweepAngle,
						blips: [
							RadarBlip(
								azimuthAngle: _currentSweepAngle,
								distanceRatio: (_lastHammingDistance / 10.0).clamp(0.0, 1.0),
								),
						],
					),
					const SizedBox(height: 20),
					Text(
						'Latest Hamming Distance Metric: $_lastHammingDistance m',
						style: const TextStyle(fontSize: 18, color: Colors.white70),
						),
						_buildControlPanel(),
					],
				),
			),
		);
	}
}

class OscilloscopePainter extends CustomPainter {
	final List<double> points;
	OscilloscopePainter(this.points);

	@override
	void paint(Canvas canvas, Size size) {
		final paint = Paint()..color = Colors.greenAccent..strokeWidth = 2.0..style = PaintingStyle.stroke;
		final path = Path();

		if (points.isEmpty) return;

		double stepX = size.width / (points.length > 1 ? points.length - 1 : 1);

		for (int i = 0; i < points.length; i++) {
			double x = i * stepX;
			double y = size.height - (points[i] * 10);
			y = y.clamp(0.0, size.height);

			// Scale point to canvas height within bounds

			if (i == 0) {
				path.moveTo(x, y);
			} else {
				path.lineTo(x ,y);
			}
		}

		canvas.drawPath(path, paint);
	}

	@override
	bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

abstract class TelemetryProvider {
	Stream<TelemetryPacket> get packetStream;
	Future<void> initialize();
	Future<void> dispose();
}

class TelemetryPacket {
	final int length;
	final double sampleValue;
	final int sourceId;

	TelemetryPacket({
		required this.length,
		required this.sampleValue,
		required this.sourceId,
	});
}

class UdpSimulationProvider implements TelemetryProvider {
	RawDatagramSocket? _socket;
	final _controller = StreamController<TelemetryPacket>();

	@override
	Stream<TelemetryPacket> get packetStream => _controller.stream;

	@override
	Future<void> initialize() async {
		_socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 5005);
		_socket!.listen((RawSocketEvent event) {
			if (event == RawSocketEvent.read) {
				Datagram? datagram = _socket!.receive();

				if (datagram != null) {
					double sample = _extractSampleValue(datagram.data);
					var packet = TelemetryPacket(
						length: datagram.data.length,
						sampleValue: sample,
						sourceId: 5005,
					);

					_controller.add(packet);
				}
			}
		});
	}

	@override
	Future<void> dispose() async {
		_socket?.close();
		await _controller.close();
	}

	double _extractSampleValue(Uint8List data) {
		if (data.length >= 8) {
			ByteData byteData = ByteData.view(data.buffer, data.offsetInBytes);
			return byteData.getFloat64(0, Endian.little);
		}
		return 0.0;
	}
}

class RfHardwareScanProvider implements TelemetryProvider {
	final StreamController<TelemetryPacket> _controller = StreamController.broadcast();
	Timer? _scanTimer;

	@override
	Stream<TelemetryPacket> get packetStream => _controller.stream;

	@override
	Future<void> initialize() async {
		final canScan = await WiFiScan.instance.canStartScan();

		if (canScan != CanStartScan.yes) return;

		_scanTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
			final success = await WiFiScan.instance.startScan();

			if (success) {
				final results = await WiFiScan.instance.getScannedResults();

				for (var accessPoint in results) {
					double normalizedSignal = (accessPoint.level + 100).toDouble();
					var packet = TelemetryPacket(
						length: 24,
						sampleValue: normalizedSignal,
						sourceId: accessPoint.bssid.hashCode,
					);
					_controller.add(packet);
				}
			}
		});
	}

	@override
	Future<void> dispose() async {
		_scanTimer?.cancel();
		await _controller.close();
	}
}
