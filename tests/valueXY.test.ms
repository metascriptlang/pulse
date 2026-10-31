import { Easing } from "../src/easing";
import { ManualClock } from "../src/clock";
import { MotionPolicy } from "../src/policy";
import { createSpring, springByStiffness } from "../src/spring";
import { AnimationSpec, spring, timing } from "../src/value";
import { AnimatedValueXY, PointXY } from "../src/valueXY";

function linear(to: float64, duration: float64): AnimationSpec {
	return timing(to, { duration, easing: Easing.linear });
}

function near(actual: float64, expected: float64): boolean {
	return Math.abs(actual - expected) <= 1e-9;
}

function throws(run: () => void): string {
	let message = "";
	try { run(); } catch (e) { message = e.message; }
	return message;
}

function panAt(x: float64, y: float64, clock: ManualClock): AnimatedValueXY {
	return new AnimatedValueXY({ x, y }, clock.clock, new MotionPolicy());
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

test "set writes both axes and a subscriber reads the pair" {
	const clock = new ManualClock();
	const pan = panAt(1, 2, clock);
	const seen: PointXY[] = [];
	pan.subscribe((p: PointXY): void => { seen.push(p); });
	assert pan.get().x === 1 && pan.get().y === 2;
	pan.set({ x: 5, y: 6 });
	assert pan.x.get() === 5 && pan.y.get() === 6;
	assert seen.length === 2;
	assert seen[0].x === 5 && seen[0].y === 2;
	assert seen[1].x === 5 && seen[1].y === 6;
}

test "animate runs one spec per axis and ends once, after both" {
	const clock = new ManualClock();
	const pan = panAt(0, 0, clock);
	const ends = new Ends();
	pan.animate(linear(10, 100), linear(20, 200), ends.handler);
	clock.advance(100);
	assert pan.get().x === 10 && pan.get().y === 10;
	assert ends.finished === 0;
	clock.advance(100);
	assert pan.get().y === 20;
	assert ends.finished === 1 && ends.cancelled === 0;
	assert clock.pending() === 0;
}

test "a released gesture springs each axis with its own velocity" {
	const clock = new ManualClock();
	const config = springByStiffness(100, 10, 1);
	const pan = panAt(40, -30, clock);
	pan.animate(spring(0, config, 500), spring(0, config, -200));
	clock.advance(80);
	assert near(pan.get().x, createSpring(config, 40, 0, 500).position(80));
	assert near(pan.get().y, createSpring(config, -30, 0, -200).position(80));
}

test "cancel and a new animate end the running pair unfinished once" {
	const clock = new ManualClock();
	const pan = panAt(0, 0, clock);
	const first = new Ends();
	pan.animate(linear(10, 100), linear(10, 100), first.handler);
	clock.advance(50);
	const second = new Ends();
	pan.animate(linear(0, 100), linear(0, 100), second.handler);
	assert first.cancelled === 1 && first.finished === 0;
	pan.cancel();
	assert second.cancelled === 1 && second.finished === 0;
	assert pan.get().x === 5 && pan.get().y === 5;
	assert clock.pending() === 0;
}

test "dispose ends both axes and refuses later use" {
	const clock = new ManualClock();
	const pan = panAt(0, 0, clock);
	pan.dispose();
	assert pan.x.disposed && pan.y.disposed;
	assert throws((): void => { pan.get(); }) ===
		"motion: an AnimatedValue is used after dispose";
}
