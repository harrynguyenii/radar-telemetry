import socket
import struct
from rtlsdr import RtlSdr

UDP_IP = "127.0.0.1"
UDP_PORT = 5005
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

sdr = RtlSdr()
sdr.sample_rate = 2.048e6
sdr.center_freq = 100.0e6
sdr.gain = 'auto'

print(f"[*] Streaming live RF data from SDR to {UDP_IP}:{UDP_PORT}...")

try:
	while True:
		samples = sdr.read_samples(256)
		for sample in samples:
			payload = struct.pack('ff', float(sample.real), float(sample.imag))
			sock.sendto(payload, (UDP_IP, UDP_PORT))
except KeyboardInterrupt:
	print("\n[!] Stopping SDR stream...")
finally:
	sdr.close()
	sock.close()
