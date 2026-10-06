import 'dart:ffi' as ffi;
import 'dart:io';

// 1. Define the C function signature type
typedef NativeHamming = ffi.Int32 Function(ffi.Int32, ffi.Int32);
// 2. Define the corresponding Dart function type
typedef DartHamming = int Function(int, int);

class CorrelatorBridge {
	late final DartHamming hammingFunc;

	CorrelatorBridge() {
		// Load the compiled shared library depending on the platform
		final libraryPath = Platform.isLinux ? 'libcorrelator.so' : 'correlator.dll';
		final dylib = ffi.DynamicLibrary.open(libraryPath);

		// Look up the C function by name and map it to a callable Dart function
		hammingFunc = dylib.lookup<ffi.NativeFunction<NativeHamming>>('compute_hamming').asFunction();
	}

	int execute(int a, int b) {
		return hammingFunc(a, b); // Direct memory execution!
	}
}
