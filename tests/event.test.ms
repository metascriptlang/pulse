import { Easing } from "../src/easing";
import { ManualClock } from "../src/clock";
import { MotionPolicy } from "../src/policy";
import { AnimatedValue, timing } from "../src/value";
import { EventPayload, event } from "../src/event";

function payload(x: float64, y: float64): EventPayload {
	return { x, y, width: 320, height: 480, contentWidth: 320, contentHeight: 2000 };
}

function valueAt(start: float64, clock: ManualClock): AnimatedValue {
	return new AnimatedValue(start, clock.clock, new MotionPolicy());
}

test "a mapped field sets its value before the listener runs" {
	const clock = new ManualClock();
	const scrollY = valueAt(0, clock);
	const header = scrollY.interpolate({
		inputRange: [0, 120],
		outputRange: [110, 56],
	});
	let heard: float64 = -1;
	let shown: float64 = -1;
	const onScroll = event({ y: scrollY }, (e: EventPayload): void => {
		heard = e.y;
		shown = header.get();
	});
	onScroll(payload(0, 60));
	assert scrollY.get() === 60;
	assert heard === 60 && shown === 83;
}

test "every field of the payload can drive a value" {
	const clock = new ManualClock();
	const x = valueAt(0, clock);
	const y = valueAt(0, clock);
	const width = valueAt(0, clock);
	const height = valueAt(0, clock);
	const contentWidth = valueAt(0, clock);
	const contentHeight = valueAt(0, clock);
	const handler = event({ x, y, width, height, contentWidth, contentHeight });
	handler(payload(7, 9));
	assert x.get() === 7 && y.get() === 9;
	assert width.get() === 320 && height.get() === 480;
	assert contentWidth.get() === 320 && contentHeight.get() === 2000;
}

test "an unmapped field leaves values alone and an event stops a running animation" {
	const clock = new ManualClock();
	const y = valueAt(0, clock);
	const other = valueAt(5, clock);
	let ended = "";
	y.animate(timing(100, { duration: 100, easing: Easing.linear }), (finished: boolean): void => {
		ended = finished ? "finished" : "stopped";
	});
	clock.advance(50);
	event({ y })(payload(1, 20));
	assert y.get() === 20 && !y.isAnimating();
	assert ended === "stopped";
	assert other.get() === 5;
	assert clock.pending() === 0;
}
