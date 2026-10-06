import subprocess
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

app = FastAPI()

class RadarPayload(BaseModel):
	stream: str
	threshold: int = 1

@app.post("/api/correlate")

def run_correlator(payload: RadarPayload):
	if not all(c in "01" for c in payload.stream):
		raise HTTPException(status_code=400, detail="Stream must contain only '0' and '1' characters.")

	try:
		process = subprocess.run(
			["./correlator", str(payload.threshold)],
			input = payload.stream,
			stdout = subprocess.PIPE,
			stderr = subprocess.PIPE,
			text = True,
			timeout = 2
			)

		if process.returncode != 0:
			raise HTTPException(status_code=500, detail=process.stderr.strip())

		output_lines = [line for line in process.stdout.strip().split("\n") if line]

		return {
			"status": "success",
			"stream_length": len(payload.stream),
			"threshold": payload.threshold,
			"matches_found": len(output_lines),
			"telemetry_log": output_lines
		}

	except subprocess.TimeoutExpired:
		raise HTTPException(status_code=504, detail="Correlator execution timed out.")
