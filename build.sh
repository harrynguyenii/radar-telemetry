set -e

echo "[*] Compiling native C shared library (libcorrelator.so)..."
gcc -shared -fPIC -O3 correlator.c -o libcorrelator.so -lm

echo "[*] Moving library to Flutter frontend directory..."
cp libcorrelator.so frontend/

echo "[*] Cleaning and fetching Flutter dependencies..."
cd frontend
flutter clean
flutter pub get

echo "[*] Building Linux application bundle..."
flutter build linux --debug

echo "[*] Copying shared library into debug bundle output..."
mkdir -p build/linux/x64/debug/bundle/
cp ../libcorrelator.so build/linux/x64/debug/bundle/

echo "[+] Build and packaging complete successfully!"

