import { Easing } from "../src/easing";
import { ManualClock } from "../src/clock";
import { MotionPolicy } from "../src/policy";
import { AnimatedValue, timing } from "../src/value";
import {
	Extrapolate,
	add,
	diffClamp,
	divide,
	modulo,
	multiply,
	subtract,
} from "../src/derived";

function near(actual: float64, expected: float64): boolean {
	return Math.abs(actual - expected) <= 1e-9;
}

function throws(run: () => void): string {
	let message = "";
	try { run(); } catch (e) { message = e.message; }
	return message;
}

function valueAt(start: float64): AnimatedValue {
	return new AnimatedValue(start, new ManualClock().clock, new MotionPolicy());
}

test "interpolate maps each input segment onto its output segment" {
	const input = valueAt(0);
	const out = input.interpolate({
		inputRange: [0, 10, 20],
		outputRange: [0, 100, 0],
	});
	assert out.get() === 0;
	input.set(5);
	assert out.get() === 50;
	input.set(10);
	assert out.get() === 100;
	input.set(15);
	assert out.get() === 50;
}

test "interpolate follows a running animation and notifies on change only" {
	const clock = new ManualClock();
	const spin = new AnimatedValue(0, clock.clock, new MotionPolicy());
	const degrees = spin.interpolate({
		inputRange: [0, 1],
		outputRange: [0, 360],
	});
	const seen: float64[] = [];
	degrees.subscribe((v: float64): void => { seen.push(v); });
	spin.animate(timing(1, { duration: 100, easing: Easing.linear }));
	clock.advance(25);
	assert degrees.get() === 90;
	clock.advance(75);
	assert degrees.get() === 360;
	assert seen.length === 2 && seen[0] === 90 && seen[1] === 360;
}

test "extend extrapolates the edge segments, clamp holds the edge outputs" {
	const input = valueAt(-10);
	const extended = input.interpolate({
		inputRange: [0, 10],
		outputRange: [0, 100],
	});
	const clamped = input.interpolate({
		inputRange: [0, 120],
		outputRange: [110, 56],
		extrapolate: Extrapolate.Clamp,
	});
	assert extended.get() === -100;
	assert clamped.get() === 110;
	input.set(240);
	assert extended.get() === 2400;
	assert clamped.get() === 56;
}

test "identity returns the input, and each side overrides extrapolate" {
	const input = valueAt(-5);
	const mixed = input.interpolate({
		inputRange: [0, 10],
		outputRange: [100, 200],
		extrapolate: Extrapolate.Clamp,
		extrapolateLeft: Extrapolate.Identity,
	});
	assert mixed.get() === -5;
	input.set(30);
	assert mixed.get() === 200;
	const right = input.interpolate({
		inputRange: [0, 10],
		outputRange: [100, 200],
		extrapolateRight: Extrapolate.Identity,
	});
	assert right.get() === 30;
	input.set(-1);
	assert right.get() === 90;
}

test "the easing shapes the progress inside each segment" {
	const input = valueAt(5);
	const eased = input.interpolate({
		inputRange: [0, 10, 20],
		outputRange: [0, 100, 200],
		easing: Easing.quad,
	});
	assert eased.get() === 25;
	input.set(15);
	assert eased.get() === 125;
}

test "a repeated input stop jumps, and an infinite edge stays linear" {
	const input = valueAt(0);
	const step = input.interpolate({
		inputRange: [0, 0, 1],
		outputRange: [0, 10, 20],
	});
	const open = input.interpolate({
		inputRange: [-Infinity, 0],
		outputRange: [-Infinity, 0],
	});
	assert step.get() === 0;
	input.set(0.5);
	assert step.get() === 15;
	input.set(-7);
	assert open.get() === -7;
}

test "an interpolation of an interpolation follows the root value" {
	const input = valueAt(0);
	const percent = input.interpolate({
		inputRange: [0, 1],
		outputRange: [0, 100],
	});
	const half = percent.interpolate({
		inputRange: [0, 100],
		outputRange: [0, 50],
	});
	input.set(0.5);
	assert half.get() === 25;
}

test "ranges the reference only warns about are refused" {
	const input = valueAt(0);
	assert throws((): void => {
		input.interpolate({ inputRange: [0, 1, 2], outputRange: [0, 1] });
	}) === "motion: inputRange (3) and outputRange (2) must have the same length";
	assert throws((): void => {
		input.interpolate({ inputRange: [0, 2, 1], outputRange: [0, 1, 2] });
	}) === "motion: inputRange must be monotonically non-decreasing, got 0,2,1";
	assert throws((): void => {
		input.interpolate({ inputRange: [0], outputRange: [0] });
	}) === "motion: outputRange must have at least 2 elements";
	assert throws((): void => {
		input.interpolate({
			inputRange: [-Infinity, Infinity],
			outputRange: [0, 1],
		});
	}) === "motion: inputRange cannot be ]-infinity;+infinity[";
	assert throws((): void => {
		input.interpolate({ inputRange: [0, 1], outputRange: [0, NaN] });
	}) === "motion: outputRange must not hold NaN";
}

test "arithmetic follows both operands" {
	const a = valueAt(6);
	const b = valueAt(3);
	const sum = add(a.source(), b.source());
	const difference = subtract(a.source(), b.source());
	const product = multiply(a.source(), b.source());
	const quotient = divide(a.source(), b.source());
	assert sum.get() === 9 && difference.get() === 3;
	assert product.get() === 18 && quotient.get() === 2;
	b.set(4);
	assert sum.get() === 10 && difference.get() === 2;
	assert product.get() === 24 && quotient.get() === 1.5;
	const nested = add(sum.source(), a.source());
	a.set(1);
	assert nested.get() === 6;
}

test "dividing by zero is refused at construction and on change" {
	const a = valueAt(1);
	const zero = valueAt(0);
	assert throws((): void => {
		divide(a.source(), zero.source());
	}) === "motion: divide by zero";
	const b = valueAt(2);
	const quotient = divide(a.source(), b.source());
	assert throws((): void => { b.set(0); }) === "motion: divide by zero";
	assert quotient.get() === 0.5;
}

test "modulo stays non-negative and refuses a zero modulus" {
	const a = valueAt(-1);
	const wrapped = modulo(a.source(), 360);
	assert wrapped.get() === 359;
	a.set(725);
	assert wrapped.get() === 5;
	assert throws((): void => {
		modulo(a.source(), 0);
	}) === "motion: modulo needs a finite, non-zero modulus, got 0";
}

test "diffClamp moves by the input's change and holds inside its bounds" {
	const scroll = valueAt(0);
	const offset = diffClamp(scroll.source(), 0, 40);
	assert offset.get() === 0;
	scroll.set(50);
	assert offset.get() === 40;
	scroll.set(30);
	assert offset.get() === 20;
	scroll.set(-100);
	assert offset.get() === 0;
	scroll.set(-90);
	assert offset.get() === 10;
	assert throws((): void => {
		diffClamp(scroll.source(), 5, 1);
	}) === "motion: diffClamp min must not exceed max, got 5 and 1";
}

test "a disposed derived value stops following and refuses use" {
	const input = valueAt(0);
	const out = input.interpolate({ inputRange: [0, 1], outputRange: [0, 2] });
	let calls: int32 = 0;
	out.subscribe((v: float64): void => { calls += 1; });
	out.dispose();
	input.set(1);
	assert calls === 0;
	assert throws((): void => { out.get(); }) ===
		"motion: a DerivedValue is used after dispose";
	assert near(input.get(), 1);
}
