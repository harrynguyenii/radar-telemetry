import os
import sys
import subprocess
import math
import customtkinter as ctk
import tkinter as tk

# Determine base path for the external C binary
if getattr(sys, 'frozen', False):
	base_path = os.path.dirname(sys.executable)
else:
	base_path = os.path.dirname(os.path.abspath(__file__))

correlator_path = os.path.join(base_path, 'correlator')

ctk.set_appearance_mode("Dark")
ctk.set_default_color_theme("blue")
ctk.set_window_scaling(1.0)
ctk.set_widget_scaling(1.0)

class RadarApp(ctk.CTk):
	def __init__(self):
		super().__init__()

		self.title("Radar Telemetry & Signal Generator Control")
		self.geometry("900x880")
		self.resizable(False, False)

		# --- Top Configuration Panel (Instrument Style) ---
		self.param_frame = ctk.CTkFrame(self)
		self.param_frame.pack(fill="x", padx=15, pady=10)

		# Row 1: Amplitude & Frequency
		self.amp_label = ctk.CTkLabel(self.param_frame, text="Amplitude (Vpp)", font=("Arial", 12, "bold"))
		self.amp_label.grid(row=0, column=0, sticky="w", padx=10, pady=(10, 2))
		self.amp_entry = ctk.CTkEntry(self.param_frame, width=150)
		self.amp_entry.grid(row=1, column=0, padx=10, pady=(0, 10))
		self.amp_entry.insert(0, "6.0000")

		self.freq_label = ctk.CTkLabel(self.param_frame, text="Frequency (Hz)", font=("Arial", 12, "bold"))
		self.freq_label.grid(row=0, column=1, sticky="w", padx=10, pady=(10, 2))
		self.freq_entry = ctk.CTkEntry(self.param_frame, width=150)
		self.freq_entry.grid(row=1, column=1, padx=10, pady=(0,10))
		self.freq_entry.insert(0,"1000000.0")

		# Row 2: Offset & Phase
		self.offset_label = ctk.CTkLabel(self.param_frame, text="Offset (V)", font=("Arial", 12, "bold"))
		self.offset_label.grid(row=2, column=0, sticky="w", padx=10, pady=(5, 2))
		self.offset_entry = ctk.CTkEntry(self.param_frame, width=150)
		self.offset_entry.grid(row=3, column=0, padx=10, pady=(0, 10))
		self.offset_entry.insert(0, "0.0000")

		self.phase_label = ctk.CTkLabel(self.param_frame, text="Phase (deg)", font=("Arial", 12, "bold"))
		self.phase_label.grid(row=3, column=1, sticky="w", padx=10, pady=(5, 2))
		self.phase_entry = ctk.CTkEntry(self.param_frame, width=150)
		self.phase_entry.grid(row=3, column=1, padx=10, pady=(0, 10))
		self.phase_entry.insert(0, "0.00")

		# Row 3: Waveform & Mode Selectors
		self.wave_label = ctk.CTkLabel(self.param_frame, text="Waveform Type", font=("Arial", 12, "bold"))
		self.wave_label.grid(row=0, column=2, sticky="w", padx=10, pady=(10, 2))
		self.wave_menu = ctk.CTkOptionMenu(self.param_frame, values=["Sine", "Pulse", "Square", "Ramp"], width=150, command=lambda e: self.draw_waveform())
		self.wave_menu.grid(row=1, column=2, padx=10, pady=(0,10))
		self.wave_menu.set("Pulse")

		self.mode_label = ctk.CTkLabel(self.param_frame, text="Run Mode", font=("Arial", 12, "bold"))
		self.mode_label.grid(row=2, column=2, sticky="w", padx=10, pady=(5, 2))
		self.mode_menu = ctk.CTkOptionMenu(self.param_frame, values=["Continuous", "Burst", "Triggered"], width=150)
		self.mode_menu.grid(row=3, column=2, padx=10, pady=(0, 10))
		self.mode_menu.set("Continuous")

		# --- Visualizer Panel (Oscilloscope / Radar Graph) ---
		self.vis_frame = ctk.CTkFrame(self)
		self.vis_frame.pack(fill="x", padx=15, pady=5)

		self.vis_label = ctk.CTkLabel(self.vis_frame, text="Real-Time Signal & Pulse Visualizer (Oscilloscope View):", font=("Arial", 12, "bold"))
		self.vis_label.pack(anchor="w", padx=10, pady=(5, 2))

		self.canvas = tk.Canvas(self.vis_frame, width=860, height=130, bg="#0d0d0d", highlightthickness=0)
		self.canvas.pack(padx=10, pady=(0, 10))

		# --- Middle Core Panel: Binary Stream & Hamming Threshold ---
		self.core_frame = ctk.CTkFrame(self)
		self.core_frame.pack(fill="x", padx=15, pady=5)

		self.stream_label = ctk.CTkLabel(self.core_frame, text="Binary Stream / Telemetry Data:", font=("Arial", 12, "bold"))
		self.stream_label.pack(anchor="w", padx=10, pady=(8, 2))

		self.stream_box = ctk.CTkTextbox(self.core_frame, height=50)
		self.stream_box.pack(fill="x", padx=10, pady=(0, 8))
		self.stream_box.insert("0.0", "000110111000110011000000110111000110011001100110101010")

		self.thresh_label = ctk.CTkLabel(self.core_frame, text="Hamming Threshold:", font=("Arial", 12, "bold"))
		self.thresh_label.pack(anchor="w", padx=10, pady=(0, 2))

		self.thresh_entry = ctk.CTkEntry(self.core_frame)
		self.thresh_entry.pack(fill="x", padx=10, pady=(0, 8))
		self.thresh_entry.insert(0, "5")

		# Execution Button
		self.exec_btn = ctk.CTkButton(self, text="Execute Correlator Pipeline", fg_color="#1f538d", hover_color="#14375e", command=self.run_correlator, height=35, font=("Arial", 13, "bold"))
		self.exec_btn.pack(fill="x", padx=15, pady=5)

		# --- Bottom Console / Logs Panel ---
		self.log_frame = ctk.CTkFrame(self)
		self.log_frame.pack(fill="both", expand=True, padx=15, pady=(5, 15))

		self.log_label = ctk.CTkLabel(self.log_frame, text="Telemetry Output/ Benchmark Logs:", font=("Arial", 12, "bold"))
		self.log_label.pack(anchor="w", padx=10, pady=(5, 2))

		self.log_box = ctk.CTkTextbox(self.log_frame, font=("Monospace", 11))
		self.log_box.pack(fill="both", expand=True, padx=10, pady=(0, 10))

		# Initial render of the waveform graph
		self.draw_waveform()

	def draw_waveform(self):
		self.canvas.delete("all")
		width = 860
		height = 130
		mid_y = height / 2

		# Draw oscilloscope background grid lines
		for x in range(0, width, 40):
			self.canvas.create_line(x, 0, x, height, fill="#1f1f1f", dash=(2, 4))
		for y in range(0, height, 30):
			self.canvas.create_line(0, y, width, y, fill="#1f1f1f", dash=(2, 4))

		# Center reference axis
		self.canvas.create_line(0, mid_y, width, mid_y, fill="#333333")

		wave_type = self.wave_menu.get()
		points = []

		for x in range(0, width, 2):
			angle = (x / width) * 4 * math.pi
			if wave_type == "Sine":
				y = mid_y - math.sin(angle) * 40
			elif wave_type == "Square":
				y = mid_y - (40 if math.sin(angle) >= 0 else -40)
			elif wave_type == "Pulse":
				val = math.sin(angle) * math.exp(-((x % 215 - 107) ** 2) / 1000)
				y = mid_y - val * 50
			elif wave_type == "Ramp":
				y = mid_y - (((x % 100) / 50) - 1) * 40
			else:
				y = mid_y
			points.append((x, y))

		flat_points = [coord for pt in points for coord in pt]
		self.canvas.create_line(flat_points, fill="#00ffcc", width=2, smooth=True)

	def run_correlator(self):
		stream_data = self.stream_box.get("1.0", "end-1c").strip()
		threshold = self.thresh_entry.get().strip()
		frequency = self.freq_entry.get().strip()
		amplitude = self.amp_entry.get().strip()
		wave_type = self.wave_menu.get()

		if not stream_data or not threshold:
			self.log_box.insert("end", "Error: Binary stream or threshold cannot be empty.\n")
			return

		payload = f"{stream_data}\n"

		try:
			self.log_box.insert("end", f"[*] Executing pipeline | Freq: {frequency}Hz | Amp: {amplitude}V | Wave: {wave_type}\n")
			process = subprocess.Popen(
				[correlator_path, threshold],
				stdin = subprocess.PIPE,
				stdout = subprocess.PIPE,
				stderr = subprocess.PIPE,
				text = True
			)
			stdout, stderr = process.communicate(input=payload, timeout=5)

			if stdout:
				self.log_box.insert("end", stdout)
			if stderr:
				self.log_box.insert("end", f"Error: {stderr}\n")

			self.log_box.see("end")
		except Exception as e:
			self.log_box.insert("end", f"Execution Exception: {e}\n")

if __name__ == "__main__":
	app = RadarApp()
	app.mainloop()

