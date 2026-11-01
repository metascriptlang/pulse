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
