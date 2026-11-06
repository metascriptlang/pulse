import { Easing } from "../src/easing";
import { ManualClock } from "../src/clock";
import { MotionPolicy } from "../src/policy";
import { AnimatedValue, AnimationSpec, sequence, timing } from "../src/value";
import {
	CompositeAnimation,
	animation,
	loop,
	parallel,
	staggered,
} from "../src/composite";

function linear(to: float64, duration: float64): AnimationSpec {
	return timing(to, { duration, easing: Easing.linear });
}

function throws(run: () => void): string {
	let message = "";
	try { run(); } catch (e) { message = e.message; }
	return message;
}

class Ends {
	finished: int32 = 0;
	cancelled: int32 = 0;
	handler: (finished: boolean) => void;

	constructor() {
		this.handler = (finished: boolean): void => {
			if (finished) { this.finished += 1; } else { this.cancelled += 1; }
		};
	}
}

class Scene {
	manual: ManualClock = new ManualClock();
	policy: MotionPolicy = new MotionPolicy();

	value(start: float64): AnimatedValue {
		return new AnimatedValue(start, this.manual.clock, this.policy);
	}
}

test "an animation binds a spec to a value: start, stop and reset" {
	const scene = new Scene();
	const value = scene.value(0);
	const run = animation(value, linear(100, 100));
	const ends = new Ends();
	run.start(ends.handler);
	scene.manual.advance(40);
	assert value.get() === 40;
	run.stop();
	assert value.get() === 40;
	assert ends.cancelled === 1 && ends.finished === 0;
	run.reset();
	assert value.get() === 0;
	run.start(ends.handler);
	scene.manual.advance(100);
	assert value.get() === 100 && ends.finished === 1;
}

test "parallel starts every child at once and ends after the last" {
	const scene = new Scene();
	const a = scene.value(0);
	const b = scene.value(0);
	const ends = new Ends();
	parallel([
		animation(a, linear(10, 100)),
		animation(b, linear(10, 200)),
	]).start(ends.handler);
	scene.manual.advance(100);
	assert a.get() === 10 && b.get() === 5;
	assert ends.finished === 0;
	scene.manual.advance(100);
	assert b.get() === 10;
	assert ends.finished === 1 && ends.cancelled === 0;
	assert scene.manual.pending() === 0;
}

test "parallel stops together by default when one child is stopped" {
	const scene = new Scene();
	const a = scene.value(0);
	const b = scene.value(0);
	const ends = new Ends();
	parallel([
		animation(a, linear(10, 100)),
		animation(b, linear(10, 100)),
	]).start(ends.handler);
	scene.manual.advance(50);
	a.cancel();
	assert b.get() === 5 && !b.isAnimating();
	assert ends.cancelled === 1 && ends.finished === 0;
	assert scene.manual.pending() === 0;
}

test "parallel without stopTogether lets the others finish" {
	const scene = new Scene();
	const a = scene.value(0);
	const b = scene.value(0);
	const ends = new Ends();
	parallel([
		animation(a, linear(10, 100)),
		animation(b, linear(10, 100)),
	], false).start(ends.handler);
	scene.manual.advance(50);
	a.cancel();
	assert b.isAnimating();
	scene.manual.advance(50);
	assert b.get() === 10;
	assert ends.finished === 1 && ends.cancelled === 0, "the last child reports";
}

test "an empty parallel ends at once, finished" {
	const ends = new Ends();
	parallel([]).start(ends.handler);
	assert ends.finished === 1;
}

test "a parallel started again can still be stopped" {
	const scene = new Scene();
	const a = scene.value(0);
	const group = parallel([
		animation(a, sequence(linear(10, 100), linear(0, 100))),
	]);
	group.start(null);
	scene.manual.advance(100);
	scene.manual.advance(100);
	assert a.get() === 0 && !a.isAnimating();
	group.start(null);
	scene.manual.advance(50);
	group.stop();
	assert a.get() === 5 && !a.isAnimating();
}

test "staggered starts each child its offset later" {
	const scene = new Scene();
	const values = [scene.value(0), scene.value(0), scene.value(0)];
	const runs: CompositeAnimation[] = [];
	for (const value of values) { runs.push(animation(value, linear(10, 100))); }
	const ends = new Ends();
	staggered(50, runs, scene.manual.clock, scene.policy).start(ends.handler);
	scene.manual.advance(50);
	assert values[0].get() === 5 && values[1].get() === 0;
	assert !values[2].isAnimating();
	scene.manual.advance(50);
	assert values[0].get() === 10 && values[1].get() === 5;
	assert values[2].get() === 0 && values[2].isAnimating();
	scene.manual.advance(50);
	assert values[1].get() === 10;
	assert values[2].get() === 5 && ends.finished === 0;
	scene.manual.advance(50);
	assert values[2].get() === 10 && ends.finished === 1;
}

test "stopping a stagger during an offset stops every child" {
	const scene = new Scene();
	const a = scene.value(0);
	const b = scene.value(0);
	const ends = new Ends();
	const group = staggered(100, [
		animation(a, linear(10, 100)),
		animation(b, linear(10, 100)),
	], scene.manual.clock, scene.policy);
	group.start(ends.handler);
	scene.manual.advance(50);
	group.stop();
	scene.manual.advance(200);
	assert a.get() === 5 && b.get() === 0;
	assert ends.cancelled === 1 && ends.finished === 0;
	assert scene.manual.pending() === 0;
}

test "reduced motion drops the stagger offsets as it drops delays" {
	const scene = new Scene();
	scene.policy.reducedMotion = true;
	const a = scene.value(0);
	const b = scene.value(0);
	const ends = new Ends();
	staggered(100, [
		animation(a, linear(10, 100)),
		animation(b, linear(20, 100)),
	], scene.manual.clock, scene.policy).start(ends.handler);
	assert a.get() === 10 && b.get() === 20;
	assert ends.finished === 1;
}

test "a stagger offset is finite and not negative" {
	const scene = new Scene();
	assert throws((): void => {
		staggered(-1, [], scene.manual.clock, scene.policy);
	}) === "motion: a stagger offset must be finite and not negative, got -1";
}

test "loop resets and replays for its iterations, then ends finished" {
	const scene = new Scene();
	const spin = scene.value(0);
	const ends = new Ends();
	const seen: float64[] = [];
	spin.subscribe((v: float64): void => { seen.push(v); });
	loop(animation(spin, linear(1, 100)), 3).start(ends.handler);
	scene.manual.advance(50);
	assert spin.get() === 0.5;
	scene.manual.advance(50);
	assert spin.get() === 0;
	scene.manual.advance(50);
	assert spin.get() === 0.5;
	scene.manual.advance(50);
	assert spin.get() === 0 && ends.finished === 0;
	scene.manual.advance(100);
	assert spin.get() === 1 && ends.finished === 1;
	assert seen.filter((v: float64): boolean => v === 1).length === 3;
}

test "a loop an end handler starts is stopped and reported when the interrupting call supersedes it" {
	const scene = new Scene();
	const spin = scene.value(0);
	const looped = new Ends();
	const outer = new Ends();
	spin.animate(linear(1, 100), (finished: boolean): void => {
		if (!finished) { loop(animation(spin, linear(-1, 100))).start(looped.handler); }
	});
	scene.manual.advance(50);
	spin.animate(linear(2, 100), outer.handler);
	assert looped.cancelled === 1 && looped.finished === 0;
	assert scene.manual.pending() === 1;
	scene.manual.advance(100);
	assert spin.get() === 2 && outer.finished === 1;
	assert looped.cancelled === 1 && !spin.isAnimating();
}

test "an endless loop runs until it is stopped" {
	const scene = new Scene();
	const spin = scene.value(0);
	const ends = new Ends();
	const forever = loop(animation(spin, linear(1, 100)));
	forever.start(ends.handler);
	for (let i: int32 = 0; i < 20; i += 1) { scene.manual.advance(50); }
	assert spin.isAnimating() && ends.finished === 0;
	forever.stop();
	assert ends.cancelled === 1 && !spin.isAnimating();
	assert scene.manual.pending() === 0;
}

test "a loop without reset continues from where the last iteration ended" {
	const scene = new Scene();
	const value = scene.value(0);
	const ends = new Ends();
	loop(
		animation(value, sequence(linear(10, 100), linear(5, 100))),
		2,
		false,
	).start(ends.handler);
	scene.manual.advance(100);
	assert value.get() === 10;
	scene.manual.advance(100);
	assert value.get() === 5;
	scene.manual.advance(50);
	assert value.get() === 7.5;
	scene.manual.advance(50);
	scene.manual.advance(100);
	assert value.get() === 5 && ends.finished === 1;
}

test "a loop of a parallel replays every child" {
	const scene = new Scene();
	const a = scene.value(0);
	const b = scene.value(0);
	const ends = new Ends();
	loop(parallel([
		animation(a, linear(10, 100)),
		animation(b, linear(20, 100)),
	]), 2).start(ends.handler);
	scene.manual.advance(100);
	assert a.get() === 0 && b.get() === 0 && ends.finished === 0;
	scene.manual.advance(50);
	assert a.get() === 5 && b.get() === 10;
	scene.manual.advance(50);
	assert a.get() === 10 && b.get() === 20 && ends.finished === 1;
}

test "zero iterations end at once; an endless loop that takes no time is refused" {
	const scene = new Scene();
	const value = scene.value(0);
	const ends = new Ends();
	loop(animation(value, linear(1, 100)), 0).start(ends.handler);
	assert ends.finished === 1 && !value.isAnimating();
	assert throws((): void => {
		loop(animation(value, linear(1, 100)), -2);
	}) === "motion: loop iterations must be -1 or more, got -2";
	const still = scene.value(1);
	assert throws((): void => {
		loop(animation(still, linear(1, 100))).start(null);
	}) === "motion: an endless loop needs an iteration that takes time";
}

test "an endless loop whose iteration threw on start can start again" {
	const scene = new Scene();
	const spin = scene.value(0);
	const ends = new Ends();
	let failing = true;
	const flaky: CompositeAnimation = {
		start: (onEnd: ((finished: boolean) => void) | null): void => {
			if (failing) {
				failing = false;
				throw new Error("motion: the first start fails");
			}
			spin.animate(linear(1, 100), onEnd);
		},
		stop: (): void => { spin.cancel(); },
		reset: (): void => { spin.set(0); },
	};
	const forever = loop(flaky);
	assert throws((): void => { forever.start(ends.handler); }) === "motion: the first start fails";
	const again = throws((): void => { forever.start(ends.handler); });
	assert again === "", again;
	scene.manual.advance(50);
	assert spin.get() === 0.5 && spin.isAnimating();
	forever.stop();
	assert ends.cancelled === 1;
}

test "an endless loop of iterations shorter than a frame keeps running" {
	const scene = new Scene();
	const spin = scene.value(0);
	const forever = loop(animation(spin, linear(1, 3)));
	forever.start(null);
	for (let i: int32 = 0; i < 10; i += 1) { scene.manual.advance(16); }
	assert spin.isAnimating() && Math.abs(spin.get() - 1.0 / 3.0) < 1e-12;
	forever.stop();
}

const FRAMES_PER_100_MS: int32[] = [25, 6, 3, 12];

function traced(
	framesPer100: int32,
	horizon: int32,
	build: (scene: Scene, values: AnimatedValue[]) => CompositeAnimation,
): float64[] {
	const scene = new Scene();
	const values: AnimatedValue[] = [];
	const probe = scene.value(0);
	build(scene, values).start((finished: boolean): void => {
		probe.animate(linear(1e6, 1e6));
	});
	const samples: float64[] = [];
	for (let frame: int32 = 1; frame <= framesPer100 * horizon; frame++) {
		const time = ((frame * 100) as float64) / (framesPer100 as float64);
		scene.manual.advance(time - scene.manual.time);
		if (frame % framesPer100 === 0) {
			for (const value of values) { samples.push(value.get()); }
		}
	}
	samples.push(scene.manual.time - probe.get());
	return samples;
}

function sameAtEveryFrameRate(
	horizon: int32,
	end: float64,
	build: (scene: Scene, values: AnimatedValue[]) => CompositeAnimation,
): boolean {
	const reference = traced(FRAMES_PER_100_MS[0], horizon, build);
	if (Math.abs(reference[reference.length - 1] - end) > 1e-9) { return false; }
	for (const framesPer100 of FRAMES_PER_100_MS) {
		const samples = traced(framesPer100, horizon, build);
		for (let i: int32 = 0; i < samples.length; i++) {
			if (Math.abs(samples[i] - reference[i]) > 1e-9) { return false; }
		}
	}
	return true;
}

test "a stagger is the same at every frame rate: each child starts at its offset" {
	assert sameAtEveryFrameRate(
		4,
		245,
		(scene: Scene, values: AnimatedValue[]): CompositeAnimation => {
			const runs: CompositeAnimation[] = [];
			for (let i: int32 = 0; i < 3; i += 1) {
				const value = scene.value(0);
				values.push(value);
				const steps = sequence(linear(10, 70), linear(0, 85));
				runs.push(animation(value, steps));
			}
			return staggered(45, runs, scene.manual.clock, scene.policy);
		},
	);
}

test "a loop is the same at every frame rate: each iteration starts where the last ended" {
	assert sameAtEveryFrameRate(
		4,
		280,
		(scene: Scene, values: AnimatedValue[]): CompositeAnimation => {
			const value = scene.value(0);
			values.push(value);
			return loop(animation(value, linear(100, 70)), 4);
		},
	);
	assert sameAtEveryFrameRate(
		4,
		330,
		(scene: Scene, values: AnimatedValue[]): CompositeAnimation => {
			const value = scene.value(0);
			values.push(value);
			const steps = sequence(linear(30, 45), linear(5, 65));
			return loop(animation(value, steps), 3, false);
		},
	);
}
