import {
	AnimatedValue,
	AnimatedValueXY,
	EventPayload,
	Extrapolate,
	ManualClock,
	MotionDocument,
	MotionPlayer,
	MotionPolicy,
	MotionValue,
	ValueKind,
	createDecay,
	createSpring,
	animation,
	cssLinear,
	decayConfig,
	diffClamp,
	event,
	linearKeyframe,
	loop,
	motionOptions,
	parallel,
	sampleSpring,
	springByStiffness,
	staggered,
	timing,
} from "../src/index";

function ramp(): MotionDocument {
	return {
		version: 1,
		root: "main",
		clips: [
			{
				id: "main",
				duration: 1000,
				tracks: [
					{
						slot: "box",
						property: "x",
						kind: ValueKind.Number,
						keyframes: [linearKeyframe("a", 0, 0), linearKeyframe("b", 1000, 100)],
					},
				],
				placements: [],
				labels: [],
			},
		],
	};
}

test "a headless program plays a document through the public entry alone" {
	const manual = new ManualClock();
	let last: float64 = -1;
	const player = new MotionPlayer(ramp(), [{
		slot: "box",
		property: "x",
		write: (value: MotionValue): void => { last = value.number; },
		read: null,
	}], motionOptions(manual.clock));
	manual.advance(250);
	assert Math.abs(last - 25) < 1e-6;
	manual.advance(750);
	assert Math.abs(last - 100) < 1e-6;
	assert manual.pending() === 0;
	player.dispose();
}

test "spring and decay simulations read through the same accessor names" {
	const s = createSpring(springByStiffness(), 0, 100);
	const d = createDecay(decayConfig(), 0, 500);
	assert s.position(0) === 0;
	assert d.position(0) === 0;
	assert s.position(5000) > 99.9;
	assert d.velocity(0) > 0;
	assert s.isDone(10000);
}

test "a spring retargeted mid-flight hands a platform its sampled progress" {
	const s = createSpring(springByStiffness(), 0, 100);
	const moved = s.retarget(200, 50);
	assert moved.from === s.position(200);
	const curve = sampleSpring(moved);
	assert curve.progress[0] === 0;
	assert curve.progress[curve.progress.length - 1] === 1;
	assert cssLinear(curve).startsWith("linear(0, ");
}

test "an animated value runs on a manual clock with an explicit policy" {
	const manual = new ManualClock();
	const policy = new MotionPolicy();
	const value = new AnimatedValue(0, manual.clock, policy);
	value.animate(timing(10, { duration: 100 }));
	manual.advance(16);
	manual.advance(200);
	assert value.get() === 10;
	assert manual.pending() === 0;
	value.dispose();
}

test "derived values, events, composites and a 2D value through the public entry" {
	const manual = new ManualClock();
	const policy = new MotionPolicy();
	const scrollY = new AnimatedValue(0, manual.clock, policy);
	const header = scrollY.interpolate({
		inputRange: [0, 100],
		outputRange: [100, 50],
		extrapolate: Extrapolate.Clamp,
	});
	const hidden = diffClamp(scrollY.source(), 0, 50);
	const onScroll = event({ y: scrollY });
	const scrolled: EventPayload = {
		x: 0,
		y: 200,
		width: 0,
		height: 0,
		contentWidth: 0,
		contentHeight: 0,
	};
	onScroll(scrolled);
	assert header.get() === 50 && hidden.get() === 50;
	const pan = new AnimatedValueXY({ x: 0, y: 0 }, manual.clock, policy);
	const spin = new AnimatedValue(0, manual.clock, policy);
	let ended = false;
	parallel([
		staggered(10, [animation(pan.x, timing(1, { duration: 10 }))], manual.clock, policy),
		loop(animation(spin, timing(1, { duration: 10 })), 2),
	]).start((finished: boolean): void => { ended = finished; });
	manual.advance(10);
	manual.advance(10);
	assert ended && pan.get().x === 1 && spin.get() === 1;
	assert manual.pending() === 0;
}
