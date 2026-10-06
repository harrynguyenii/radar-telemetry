#include <stdint.h>
#include <stdlib.h>
#include <math.h>

// Pillar 1: Radar Telemetry - Hamming Distance calculation
__attribute__((visibility("default"))) __attribute__((used))
int32_t compute_hamming(int32_t val1, int32_t val2) {
	uint32_t x = (uint32_t)(val1 ^ val2);
	int32_t dist = 0;

	while (x > 0) {
		dist += x & 1;
		x >>= 1;
	}
	return dist;
}

// Pillar 2: Biomedical ECG Mode - Simulated QRS filter / amplitude metric
__attribute__((visibility("default"))) __attribute__((used))
int32_t compute_ecg_metric(int32_t raw_sample, int32_t baseline) {
	int32_t diff = raw_sample - baseline;
	return (int32_t)(sqrt((double)(diff * diff)) * 0.75);
}

// Updated signature accepting the slider value (sensitivity_threshold)
int32_t process_radar_stream(int32_t* input_buffer, int length, float sensitivity_threshold) {
	int32_t aggregated_signal = 0;

	for (int i = 0; i < length; i++) {
		// Apply the dynamic sensitivity threshold to the telemetry data
		float adjusted_value = (float)input_buffer[i] * sensitivity_threshold;
		aggregated_signal += (int32_t)adjusted_value;
	}
	return aggregated_signal;
}
