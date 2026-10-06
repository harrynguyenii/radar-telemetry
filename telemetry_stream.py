import socket
import struct
import time
import sys
import select

UDP_IP = "127.0.0.1"
UDP_PORT = 5005

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
print(f"[*] Starting Python UDP Telemetry Stream on {UDP_IP}:{UDP_PORT}...")
print(f"[*] Streaming to {UDP_IP}:{UDP_PORT}")
print(f"[*] Controls: Press [ENTER] or [SPACEBAR] + Enter to fire an EMERGENCY ALERT (0x02).")
print(f"[*] Running radar telemetry stream (0x01) automatically...\n")

sequence = 0

try:
	while True:
		if sys.stdin in select.select([sys.stdin], [], [], 0.04)[0]:
			press = sys.stdin.readline()
			emergency_packet = struct.pack("<B I 6s", 0x02, sequence, b"ALRT01")
			sock.sendto(emergency_packet, (UDP_IP, UDP_PORT))
			print(f"[!] EMERGENCY ALERT! (Packet Type 0x02, Seq: {sequence})")
			sequence += 1
		else:
			timestamp = time.time()
			val1 = 42 # Example telemetry metric 1
			val2 = 99 # Example telemetry metric 2
			radar_packet = struct.pack("<B I d i i", 0x01, sequence, timestamp, val1, val2)
			sock.sendto(radar_packet, (UDP_IP, UDP_PORT))

			# Print status tick to terminal
			sys.stdout.write(f"\r[>] Sent Radar Packet 0x01 | Seq: {sequence}")
			sys.stdout.flush()

			sequence += 1
			time.sleep(0.05) # ~20 packets per second

except KeyboardInterrupt:
	print("\n[i] Telemetry stream stopped by user.")
	sock.close()
