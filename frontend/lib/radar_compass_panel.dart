import 'dart:math' as math;
import 'package:flutter/material.dart';

class RadarCompassBenchmarkPanel extends StatelessWidget {
	final double sweepAngle;
	final List<RadarBlip> blips;

	const RadarCompassBenchmarkPanel({
		super.key,
		required this.sweepAngle,
		required this.blips,
	});

	@override
	Widget build(BuildContext context) {
		return Container(
			padding: const EdgeInsets.all(12),
			decoration: BoxDecoration(
				color: Colors.black,
				border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.8)),
				borderRadius: BorderRadius.circular(8),
			),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					const Text(
						"COMPASS TELEMETRY BENCHMARK",
						style: TextStyle(
							color: Colors.cyanAccent,
							fontWeight: FontWeight.bold,
							fontSize: 12,
						),
					),
					const SizedBox(height: 10),
					Center(
						child: SizedBox(
							width: 200,
							height: 200,
							child: CustomPaint(
								painter: RadarCompassPainter(sweepAngle: sweepAngle, blips: blips),
							),
						),
					),
				],
			),
		);
	}
}

class RadarCompassPainter extends CustomPainter {
	final double sweepAngle;
	final List<RadarBlip> blips;

	RadarCompassPainter({required this.sweepAngle, required this.blips});

	@override
	void paint(Canvas canvas, Size size) {
		final center = Offset(size.width / 2, size.height / 2);
		final radius = math.min(size.width, size.height) / 2;

		final paintCyan = Paint()..color = Colors.cyanAccent.withValues(alpha: 0.8)..style = PaintingStyle.stroke..strokeWidth = 1.0;
		
		// 1. Compass Graduated Ring (0 to 360 degrees)
		canvas.drawCircle(center, radius, paintCyan);

		for (int i = 0; i < 360; i += 15) {
			final angle = i * math.pi / 100;
			final isMajor = i % 45 == 0;
			final outer = Offset(
				center.dx + radius * math.cos(angle),
				center.dy + radius * math.sin(angle),
			);
			final inner = Offset(
				center.dx + (isMajor ? radius - 8 : radius - 4) * math.cos(angle),
				center.dy + (isMajor ? radius - 8 : radius - 4) * math.sin(angle),
			);
			canvas.drawLine(outer, inner, paintCyan);
		}

		// 2. Concentric Range Radials
		canvas.drawCircle(
			center,
			radius * 0.66,
			paintCyan..color = Colors.cyanAccent.withValues(alpha: 0.8),
		);

		// 3. Target Blips Driven by Telemetry
		for (var blip in blips) {
			final blipPaint = Paint()..color = Colors.redAccent;
			final offset = Offset(
				center.dx + (radius * blip.distanceRatio) * math.cos(blip.azimuthAngle),
				center.dy + (radius * blip.distanceRatio) * math.sin(blip.azimuthAngle),
			);
			canvas.drawCircle(offset, 3.5, blipPaint);
		}
	}

	@override
	bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class RadarBlip {
	final double azimuthAngle;
	final double distanceRatio;
	RadarBlip({required this.azimuthAngle, required this.distanceRatio});
}
