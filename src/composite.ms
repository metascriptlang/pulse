import { Clock } from "./clock";
import { MotionPolicy } from "./policy";
import {
	AnimatedValue,
	AnimationSpec,
	chainedEndTime,
	delay,
	timing,
} from "./value";

export interface CompositeAnimation {
	start: (onEnd: ((finished: boolean) => void) | null) => void;
	stop: () => void;
	reset: () => void;
}

function fail(message: string): never {
	throw new Error("motion: " + message);
}

function report(
	onEnd: ((finished: boolean) => void) | null,
	finished: boolean,
): void {
	if (onEnd !== null) { onEnd(finished); }
}

export function animation(
	value: AnimatedValue,
	spec: AnimationSpec,
): CompositeAnimation {
	const startValue = value.get();
	return {
		start: (onEnd: ((finished: boolean) => void) | null): void => {
			value.animate(spec, onEnd);
		},
		stop: (): void => { value.cancel(); },
		reset: (): void => { value.set(startValue); },
	};
}

function sequenceOf(animations: CompositeAnimation[]): CompositeAnimation {
	let current: int32 = 0;
	return {
		start: (onEnd: ((finished: boolean) => void) | null): void => {
			if (animations.length === 0) {
				report(onEnd, true);
				return;
			}
			const onComplete = (finished: boolean): void => {
				if (!finished) {
					report(onEnd, false);
					return;
				}
				current += 1;
				if (current === animations.length) {
					current = 0;
					report(onEnd, true);
					return;
				}
				animations[current].start(onComplete);
			};
			animations[current].start(onComplete);
		},
		stop: (): void => {
			if (current < animations.length) { animations[current].stop(); }
		},
		reset: (): void => {
			for (let i: int32 = 0; i < animations.length; i += 1) {
				if (i <= current) { animations[i].reset(); }
			}
			current = 0;
		},
	};
}

export function parallel(
	animations: CompositeAnimation[],
	stopTogether: boolean = true,
): CompositeAnimation {
	let doneCount: int32 = 0;
	const hasEnded: boolean[] = animations.map(
		(child: CompositeAnimation): boolean => false,
	);
	const stop = (): void => {
		for (let i: int32 = 0; i < animations.length; i += 1) {
			if (!hasEnded[i]) { animations[i].stop(); }
			hasEnded[i] = true;
		}
	};
	return {
		start: (onEnd: ((finished: boolean) => void) | null): void => {
			if (doneCount === animations.length) {
				report(onEnd, true);
				return;
			}
			for (let i: int32 = 0; i < animations.length; i += 1) {
				const index = i;
				hasEnded[index] = false;
				animations[index].start((finished: boolean): void => {
					hasEnded[index] = true;
					doneCount += 1;
					if (doneCount === animations.length) {
						doneCount = 0;
						report(onEnd, finished);
						return;
					}
					if (!finished && stopTogether) { stop(); }
				});
			}
		},
		stop,
		reset: (): void => {
			for (let i: int32 = 0; i < animations.length; i += 1) {
				animations[i].reset();
				hasEnded[i] = false;
			}
			doneCount = 0;
		},
	};
}

function wait(
	ms: float64,
	clock: Clock,
	policy: MotionPolicy,
): CompositeAnimation {
	return animation(
		new AnimatedValue(0, clock, policy),
		delay(ms, timing(0, { duration: 0 })),
	);
}

export function staggered(
	each: float64,
	animations: CompositeAnimation[],
	clock: Clock,
	policy: MotionPolicy,
): CompositeAnimation {
	if (!Number.isFinite(each) || each < 0) {
		fail("a stagger offset must be finite and not negative, got " + each);
	}
	const staged: CompositeAnimation[] = [];
	for (let i: int32 = 0; i < animations.length; i += 1) {
		staged.push(sequenceOf([
			wait(each * (i as float64), clock, policy),
			animations[i],
		]));
	}
	return parallel(staged);
}

export function loop(
	animation: CompositeAnimation,
	iterations: int32 = -1,
	resetBeforeIteration: boolean = true,
): CompositeAnimation {
	if (iterations < -1) {
		fail("loop iterations must be -1 or more, got " + iterations.toString());
	}
	let isFinished = false;
	let iterationsSoFar: int32 = 0;
	let starting = false;
	let iterationStart: float64 | null = null;
	return {
		start: (onEnd: ((finished: boolean) => void) | null): void => {
			const restart = (finished: boolean): void => {
				if (isFinished || iterationsSoFar === iterations || !finished) {
					report(onEnd, finished);
					return;
				}
				const endTime = chainedEndTime();
				const tookNoTime = iterationStart === null ||
					endTime === iterationStart;
				if (starting && iterations === -1 && tookNoTime) {
					fail("an endless loop needs an iteration that takes time");
				}
				iterationsSoFar += 1;
				if (resetBeforeIteration) { animation.reset(); }
				iterationStart = endTime;
				starting = true;
				try {
					animation.start(restart);
				} finally {
					starting = false;
				}
			};
			if (iterations === 0) {
				report(onEnd, true);
				return;
			}
			restart(true);
		},
		stop: (): void => {
			isFinished = true;
			animation.stop();
		},
		reset: (): void => {
			iterationsSoFar = 0;
			isFinished = false;
			animation.reset();
		},
	};
}
