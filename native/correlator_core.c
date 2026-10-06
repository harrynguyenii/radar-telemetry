#include <stdint.h>

// Computes the bitwise XOR and Hamming disntance metric
// for radar telemetry pattern matching.

int32_t compute_hamming(int32_t val1, int32_t val2) {
	int32_t xor_result = val1 ^ val2;
	int32_t distance = 0;

	// Count set bits (Hamming weight)

	while (xor_result > 0) {
		distance += xor_result & 1;
		xor_result >>= 1;
	}

	return distance;
}
