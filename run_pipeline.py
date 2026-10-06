import subprocess
import sys

def run_command(cmd):
	result = subprocess.run(cmd, shell=True, input=input_data, capture_output=True, text=True)

	if result.returncode != 0:
		print(f"Failed executing: {cmd}\n{result.stderr}")
		sys.exit(1);
	return result.stdout

print("[+] Compiling C Correlator...")
run_command("gcc correlator.c -o correlator")

print("[+] Testing Pipe / Stdin Ingestion Stream...")
with open("radar_data.bin", "rb") as f:
	raw_bytes = f.read()
pipe_output = run_command("./radar_sim")
print(pipe_output)

print("[+] Running Yosys Hardware Synthesis Check...")
synthesis_result = run_cmd("yosys -s synth.ys")

print(synthesis_result[-500:]) # Print tail of synthesis statistics
print("Advanced pipeline execution successful!")
