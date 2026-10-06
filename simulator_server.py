import socket
import random
import time

UDP_IP = "127.0.0.1"
UDP_PORT = 5005

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

print(f"[*] Radar Telemetry UDP Streamer active on {UDP_IP}:{UDP_PORT}")

while True:
	val1 = random.randint(0, 1023)
	val2 = random.randint(0, 1023)

	# Pack as binary integers (little-endian 32-bit ints)
	payload = val1.to_bytes(4, byteorder='little') + val2.to_bytes(4, byteorder='little')

	sock.sendto(payload, (UDP_IP, UDP_PORT))
	time.sleep(0.05)
