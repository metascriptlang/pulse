import { Easing, EasingFunction, easingOr } from "./easing";

class Listener {
	callback: (value: float64) => void;
	live: boolean = true;

	constructor(callback: (value: float64) => void) {
		this.callback = callback;
	}
}

export class Listeners {
	private entries: Listener[] = [];

	add(callback: (value: float64) => void): () => void {
		const listener = new Listener(callback);
		this.entries.push(listener);
		return (): void => {
			listener.live = false;
			this.entries = this.entries.filter(
				(other: Listener): boolean => other !== listener,
			);
		};
	}

	notify(value: float64): void {
		for (const listener of this.entries.slice(0)) {
			if (listener.live) { listener.callback(value); }
		}
	}

	clear(): void {
		for (const listener of this.entries) {
			listener.live = false;
		}
		this.entries = [];
	}
}

export interface ValueSource {
	get: () => float64;
	subscribe: (callback: (value: float64) => void) => () => void;
}

export enum Extrapolate {
	Extend,
	Clamp,
	Identity,
}

export interface InterpolationConfig {
	inputRange: float64[];
	outputRange: float64[];
	easing?: EasingFunction;
	extrapolate?: Extrapolate;
	extrapolateLeft?: Extrapolate;
	extrapolateRight?: Extrapolate;
}

function fail(message: string): never {
	throw new Error("motion: " + message);
}

export class DerivedValue {
	private value: float64;
	private compute: () => float64;
	private listeners: Listeners = new Listeners();
	private unsubscribes: (() => void)[] = [];
	private isDisposed: boolean = false;

	constructor(inputs: ValueSource[], compute: () => float64) {
		this.compute = compute;
		this.value = compute();
		for (const input of inputs) {
			this.unsubscribes.push(
				input.subscribe((changed: float64): void => { this.update(); }),
			);
		}
	}

	get(): float64 {
		this.requireAlive();
		return this.value;
	}

	subscribe(callback: (value: float64) => void): () => void {
		this.requireAlive();
		return this.listeners.add(callback);
	}

	source(): ValueSource {
		return {
			get: (): float64 => this.get(),
			subscribe: (callback: (value: float64) => void): (() => void) =>
				this.subscribe(callback),
		};
	}

	interpolate(config: InterpolationConfig): DerivedValue {
		this.requireAlive();
		return interpolated(this.source(), config);
	}

	dispose(): void {
		this.requireAlive();
		this.isDisposed = true;
		for (const unsubscribe of this.unsubscribes) {
			unsubscribe();
		}
		this.unsubscribes = [];
		this.listeners.clear();
	}

	private requireAlive(): void {
		if (this.isDisposed) {
			fail("a DerivedValue is used after dispose");
		}
	}

	private update(): void {
		const next = this.compute();
		if (next === this.value) {
			return;
		}
		this.value = next;
		this.listeners.notify(next);
	}
}

function checkInfiniteRange(name: string, range: float64[]): void {
	if (range.length < 2) {
		fail(name + " must have at least 2 elements");
	}
	if (range.length === 2 && range[0] === -Infinity && range[1] === Infinity) {
		fail(name + " cannot be ]-infinity;+infinity[");
	}
}

function checkValidRanges(config: InterpolationConfig): void {
	const input = config.inputRange;
	const output = config.outputRange;
	checkInfiniteRange("outputRange", output);
	checkInfiniteRange("inputRange", input);
	for (let i: int32 = 1; i < input.length; i += 1) {
		if (!(input[i] >= input[i - 1])) {
			fail(
				"inputRange must be monotonically non-decreasing, got " +
					input.join(","),
			);
		}
	}
	if (input.length !== output.length) {
		fail(
			"inputRange (" + input.length.toString() + ") and outputRange (" +
				output.length.toString() + ") must have the same length",
		);
	}
	for (const out of output) {
		if (Number.isNaN(out)) { fail("outputRange must not hold NaN"); }
	}
}

function findRange(input: float64, inputRange: float64[]): int32 {
	let i: int32 = 1;
	while (i < inputRange.length - 1 && !(inputRange[i] >= input)) {
		i += 1;
	}
	return i - 1;
}

function interpolateSegment(
	input: float64,
	inputMin: float64,
	inputMax: float64,
	outputMin: float64,
	outputMax: float64,
	easing: EasingFunction,
	extrapolateLeft: Extrapolate,
	extrapolateRight: Extrapolate,
): float64 {
	let result = input;
	if (result < inputMin) {
		if (extrapolateLeft === Extrapolate.Identity) { return result; }
		if (extrapolateLeft === Extrapolate.Clamp) { result = inputMin; }
	}
	if (result > inputMax) {
		if (extrapolateRight === Extrapolate.Identity) { return result; }
		if (extrapolateRight === Extrapolate.Clamp) { result = inputMax; }
	}
	if (outputMin === outputMax) { return outputMin; }
	if (inputMin === inputMax) {
		return input <= inputMin ? outputMin : outputMax;
	}
	if (inputMin === -Infinity) {
		result = -result;
	} else if (inputMax === Infinity) {
		result = result - inputMin;
	} else {
		result = (result - inputMin) / (inputMax - inputMin);
	}
	result = easing(result);
	if (outputMin === -Infinity) {
		result = -result;
	} else if (outputMax === Infinity) {
		result = result + outputMin;
	} else {
		result = result * (outputMax - outputMin) + outputMin;
	}
	return result;
}

export function interpolated(
	input: ValueSource,
	config: InterpolationConfig,
): DerivedValue {
	checkValidRanges(config);
	const inputRange = config.inputRange.slice(0);
	const outputRange = config.outputRange.slice(0);
	const easing = easingOr(config.easing, Easing.linear);
	const left = config.extrapolateLeft ?? config.extrapolate ??
		Extrapolate.Extend;
	const right = config.extrapolateRight ?? config.extrapolate ??
		Extrapolate.Extend;
	return new DerivedValue([input], (): float64 => {
		const at = input.get();
		const range = findRange(at, inputRange);
		return interpolateSegment(
			at,
			inputRange[range],
			inputRange[range + 1],
			outputRange[range],
			outputRange[range + 1],
			easing,
			left,
			right,
		);
	});
}

export function add(a: ValueSource, b: ValueSource): DerivedValue {
	return new DerivedValue([a, b], (): float64 => a.get() + b.get());
}

export function subtract(a: ValueSource, b: ValueSource): DerivedValue {
	return new DerivedValue([a, b], (): float64 => a.get() - b.get());
}

export function multiply(a: ValueSource, b: ValueSource): DerivedValue {
	return new DerivedValue([a, b], (): float64 => a.get() * b.get());
}

export function divide(a: ValueSource, b: ValueSource): DerivedValue {
	return new DerivedValue([a, b], (): float64 => {
		const divisor = b.get();
		if (divisor === 0) { fail("divide by zero"); }
		return a.get() / divisor;
	});
}

export function modulo(a: ValueSource, modulus: float64): DerivedValue {
	if (!Number.isFinite(modulus) || modulus === 0) {
		fail("modulo needs a finite, non-zero modulus, got " + modulus);
	}
	return new DerivedValue(
		[a],
		(): float64 => ((a.get() % modulus) + modulus) % modulus,
	);
}

export function diffClamp(
	a: ValueSource,
	min: float64,
	max: float64,
): DerivedValue {
	if (!(min <= max)) {
		fail("diffClamp min must not exceed max, got " + min + " and " + max);
	}
	let last = a.get();
	let value = last;
	return new DerivedValue([a], (): float64 => {
		const input = a.get();
		value = Math.min(Math.max(value + (input - last), min), max);
		last = input;
		return value;
	});
}
