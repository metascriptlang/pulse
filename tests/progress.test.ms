import { Easing } from "../src/easing";
import { ProgressCurve, cssLinear, sampleEasing, sampleSpring } from "../src/progress";
import {
	SpringSimulation,
	createSpring,
	isDone,
	position,
	retarget,
	springByDuration,
	springByStiffness,
	velocity,
} from "../src/spring";

function near(actual: float64, expected: float64, tolerance: float64): boolean {
	return Math.abs(actual - expected) <= tolerance;
}

function throws(run: () => void): string {
	let message = "";
	try { run(); } catch (e) { message = e.message; }
	return message;
}

function lastOf(curve: ProgressCurve): float64 {
	return curve.progress[curve.progress.length - 1];
}

function stepMs(curve: ProgressCurve): float64 {
	return curve.durationMs / ((curve.progress.length - 1) as float64);
}

test "an easing is sampled at an even 10 ms step across its duration" {
	const curve = sampleEasing(Easing.linear, 1000);
	assert curve.durationMs === 1000;
	assert curve.progress.length === 100;
	assert curve.progress[0] === 0 && lastOf(curve) === 1;
	assert curve.progress[33] === 33.0 / 99.0;
	const quad = sampleEasing(Easing.quad, 500);
	assert quad.progress.length === 50;
	assert quad.progress[7] === (7.0 / 49.0) * (7.0 / 49.0);
}

test "a short easing keeps at least its two endpoints, and rounds its count" {
	assert sampleEasing(Easing.linear, 0).progress.length === 2;
	assert sampleEasing(Easing.linear, 14).progress.length === 2;
	assert sampleEasing(Easing.linear, 25).progress.length === 3;
	assert sampleEasing(Easing.linear, 34).progress.length === 3;
}

test "a negative or non-finite duration is refused" {
	const empty = (t: float64): float64 => t;
	assert throws(() => { sampleEasing(empty, -1); }).startsWith("motion: ");
	assert throws(() => { sampleEasing(empty, Infinity); }).startsWith("motion: ");
	assert throws(() => { sampleEasing(empty, NaN); }).startsWith("motion: ");
}

test "a spring lasts until the first 50 ms step where it is done" {
	const spring = createSpring(springByStiffness(100, 10, 1), 0, 100);
	const curve = sampleSpring(spring);
	assert curve.durationMs % 50 === 0 && curve.durationMs > 0;
	assert spring.isDone(curve.durationMs);
	assert !spring.isDone(curve.durationMs - 50);
	assert curve.progress.length ===
		(Math.round(curve.durationMs / 10) as int32);
	assert curve.progress[0] === 0 && lastOf(curve) === 1;
}

test "a spring's progress is its position between from and to" {
	const spring = createSpring(springByStiffness(100, 10, 1), 20, 120);
	const curve = sampleSpring(spring);
	const last = (curve.progress.length - 1) as float64;
	let highest: float64 = 0;
	for (let k: int32 = 0; k < curve.progress.length; k += 1) {
		const t = curve.durationMs * ((k as float64) / last);
		assert curve.progress[k] === (spring.position(t) - 20) / 100;
		highest = Math.max(highest, curve.progress[k]);
	}
	assert highest > 1.1, "an under-damped spring overshoots";
}

test "a spring's progress does not depend on its distance or direction" {
	const config = springByStiffness(170, 26, 1);
	const up = sampleSpring(createSpring(config, 0, 100));
	const down = sampleSpring(createSpring(config, 50, -150));
	assert up.durationMs === down.durationMs;
	for (let k: int32 = 0; k < up.progress.length; k += 1) {
		assert near(up.progress[k], down.progress[k], 1e-12);
	}
}

test "a spring that does not settle in 20 s is cut at 20 s" {
	const spring = createSpring(springByStiffness(100, 0.001, 1), 0, 1);
	const curve = sampleSpring(spring);
	assert curve.durationMs === 20000;
	assert curve.progress.length === 2000;
	assert lastOf(curve) !== 1;
}

test "an instant spring is one step on its target" {
	const curve = sampleSpring(createSpring(springByDuration(0), 0, 10));
	assert curve.durationMs === 0;
	assert curve.progress.length === 2;
	assert curve.progress[0] === 1 && curve.progress[1] === 1;
}

test "a spring that starts on its target is refused" {
	const spring = createSpring(springByStiffness(100, 10, 1), 5, 5, 3);
	assert throws(() => { sampleSpring(spring); }).startsWith("motion: ");
}

test "cssLinear writes motion's linear() string: four decimals, no negative zero" {
	assert cssLinear(sampleEasing(Easing.linear, 30)) === "linear(0, 0.5, 1)";
	const curve: ProgressCurve = {
		durationMs: 50,
		progress: [0, 0.123456, -0.00001, 1.05, 1],
	};
	assert cssLinear(curve) === "linear(0, 0.1235, 0, 1.05, 1)", cssLinear(curve);
}

function acceleration(s: SpringSimulation, tMs: float64): float64 {
	const mass = s.config.mass;
	return -(s.stiffness / mass) * (s.position(tMs) - s.to) -
		(s.config.damping / mass) * s.velocity(tMs);
}

function valueAt(s: SpringSimulation, curve: ProgressCurve, k: int32): float64 {
	return s.from + (s.to - s.from) * curve.progress[k];
}

test "a retarget joins two sampled springs with continuous value and velocity" {
	const first = createSpring(springByStiffness(100, 10, 1), 0, 100);
	const firstCurve = sampleSpring(first);
	const joint: int32 = 12;
	const firstStep = stepMs(firstCurve);
	const tMs = (joint as float64) * firstStep;
	const second = first.retarget(tMs, 40);
	const secondCurve = sampleSpring(second);
	const secondStep = stepMs(secondCurve);
	assert second.from === first.position(tMs);
	assert near(second.velocity(0), first.velocity(tMs), 1e-9);
	assert near(valueAt(first, firstCurve, joint), valueAt(second, secondCurve, 0), 1e-9);
	const before = (valueAt(first, firstCurve, joint) -
		valueAt(first, firstCurve, joint - 1)) / (firstStep / 1000);
	const after = (valueAt(second, secondCurve, 1) -
		valueAt(second, secondCurve, 0)) / (secondStep / 1000);
	const tolerance = 1.5 * (
		firstStep * Math.abs(acceleration(first, tMs)) +
			secondStep * Math.abs(acceleration(second, 0))
	) / 2 / 1000;
	assert Math.abs(first.velocity(tMs)) > 4 * tolerance, "the joint moves";
	assert near(before, after, tolerance),
		before.toString() + " vs " + after.toString() + " within " +
			tolerance.toString();
}
