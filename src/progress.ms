import { EasingFunction } from "./easing";
import { SpringSimulation, isDone, position } from "./spring";

export struct ProgressCurve {
	durationMs: float64;
	progress: float64[];
}

const POINT_STEP_MS: float64 = 10;
const DURATION_STEP_MS: float64 = 50;
const MAX_DURATION_MS: float64 = 20000;
const CSS_PRECISION: float64 = 10000;

function requireDuration(durationMs: float64): void {
	if (!Number.isFinite(durationMs) || durationMs < 0) {
		throw new Error(
			"motion: progress duration must be finite and not negative, got " +
				durationMs,
		);
	}
}

export function sampleEasing(
	easing: EasingFunction,
	durationMs: float64,
): ProgressCurve {
	requireDuration(durationMs);
	const count = Math.max(Math.round(durationMs / POINT_STEP_MS), 2) as int32;
	const last = (count - 1) as float64;
	const progress: float64[] = [];
	for (let i: int32 = 0; i < count; i += 1) {
		progress.push(easing((i as float64) / last));
	}
	return { durationMs, progress };
}

function springDurationMs(s: SpringSimulation): float64 {
	let durationMs: float64 = 0;
	while (!s.isDone(durationMs) && durationMs < MAX_DURATION_MS) {
		durationMs += DURATION_STEP_MS;
	}
	return durationMs;
}

export function sampleSpring(s: SpringSimulation): ProgressCurve {
	if (s.from === s.to) {
		throw new Error(
			"motion: a spring that starts on its target has no progress to sample",
		);
	}
	const durationMs = springDurationMs(s);
	const span = s.to - s.from;
	return sampleEasing(
		(t: float64): float64 => (s.position(durationMs * t) - s.from) / span,
		durationMs,
	);
}

function cssPoint(progress: float64): string {
	const rounded = Math.round(progress * CSS_PRECISION) / CSS_PRECISION;
	return String(rounded === 0 ? 0.0 : rounded);
}

export function cssLinear(curve: ProgressCurve): string {
	let text = "linear(";
	for (let i: int32 = 0; i < curve.progress.length; i += 1) {
		if (i > 0) { text += ", "; }
		text += cssPoint(curve.progress[i]);
	}
	return text + ")";
}
