import { Clock, ManualClock } from "./clock";
import { flatten } from "./compose";
import {
	ConformanceAdapter,
	ConformanceCase,
	ConformancePlayer,
	ConformanceProperty,
	ConformanceSupport,
	ConformanceTiming,
	ConformanceValue,
} from "./conformance";
import { MotionDocument, MotionValue, numberValue } from "./document";
import { MotionBinding, MotionPlayer, motionOptions } from "./player";
import { MotionPolicy } from "./policy";
import { Composition, MotionTarget } from "./target";
import { AnimatedValue, AnimationSpec } from "./value";

export const CONFORMANCE_FRAME_MS: float64 = 4;

function fail(message: string): never {
	throw new Error("motion: headless: " + message);
}

class Stage {
	manual: ManualClock = new ManualClock();
	policy: MotionPolicy;
	names: string[] = [];
	shown: float64[] = [];
	targets: MotionTarget[] = [];

	constructor(properties: ConformanceProperty[], policy: MotionPolicy) {
		this.policy = policy;
		for (const property of properties) {
			const index = this.names.length;
			this.names.push(property.name);
			this.shown.push(property.initial);
			this.targets.push(
				new MotionTarget(
					(): MotionValue => numberValue(this.shown[index]),
					(value: MotionValue): void => {
						this.shown[index] = value.number;
					},
				),
			);
		}
	}

	index(property: string): int32 {
		const index = this.names.indexOf(property) as int32;
		if (index < 0) {
			fail("unknown property " + property);
		}
		return index;
	}

	binding(slot: string, property: string): MotionBinding {
		const index = this.index(slot + "." + property);
		return {
			slot,
			property,
			write: (value: MotionValue): void => {
				this.shown[index] = value.number;
			},
			read: (): MotionValue => numberValue(this.shown[index]),
			target: this.targets[index],
		};
	}

	player(
		document: MotionDocument,
		timing: ConformanceTiming,
		emit: (event: string) => void,
	): ConformancePlayer {
		const keys: string[] = [];
		const bindings: MotionBinding[] = [];
		for (const writer of flatten(document)) {
			const key = writer.slot + "." + writer.track.property;
			if (keys.includes(key)) {
				continue;
			}
			keys.push(key);
			bindings.push(this.binding(writer.slot, writer.track.property));
		}
		const player = new MotionPlayer(document, bindings, {
			...motionOptions(this.manual.clock),
			delay: timing.delay,
			repeat: timing.repeat,
			repeatDelay: timing.repeatDelay,
			yoyo: timing.yoyo,
			timeScale: timing.timeScale,
			paused: timing.paused,
			composition: timing.composition,
		});
		player.onStart = (): void => {
			emit("start");
		};
		player.onRepeat = (): void => {
			emit("repeat");
		};
		player.onComplete = (): void => {
			emit("complete");
		};
		player.onReverseComplete = (): void => {
			emit("reverseComplete");
		};
		return {
			play: (): void => {
				player.play();
			},
			pause: (): void => {
				player.pause();
			},
			seek: (position: float64, suppressEvents: boolean): void => {
				player.seek(position, suppressEvents);
			},
			reverse: (): void => {
				player.reverse();
			},
			setTimeScale: (rate: float64): void => {
				player.setTimeScale(rate);
			},
			cancel: (): void => {
				player.cancel();
			},
			finish: (): void => {
				player.finish();
			},
			revert: (): void => {
				player.revert();
			},
			dispose: (): void => {
				player.dispose();
			},
		};
	}

	value(property: string, composition: Composition): ConformanceValue {
		const index = this.index(property);
		const value = new AnimatedValue(
			this.shown[index],
			this.manual.clock,
			this.policy,
			this.targets[index],
			composition,
		);
		value.subscribe((next: float64): void => {
			this.shown[index] = next;
		});
		return {
			get: (): float64 => value.get(),
			set: (next: float64): void => {
				value.set(next);
			},
			animate: (
				spec: AnimationSpec,
				onEnd: ((finished: boolean) => void) | null,
			): void => {
				value.animate(spec, onEnd);
			},
			cancel: (): void => {
				value.cancel();
			},
			dispose: (): void => {
				value.dispose();
			},
			subscribe: (callback: (next: float64) => void): (() => void) =>
				value.subscribe(callback),
		};
	}

	advanceTo(time: float64): void {
		while (this.manual.time < time) {
			this.manual.advance(
				Math.min(CONFORMANCE_FRAME_MS, time - this.manual.time),
			);
		}
	}
}

class Headless {
	stage: Stage = new Stage([], new MotionPolicy());
	adapter: ConformanceAdapter;

	constructor() {
		this.adapter = {
			name: "headless",
			support: (testCase: ConformanceCase): ConformanceSupport =>
				ConformanceSupport.Evaluator,
			begin: (
				properties: ConformanceProperty[],
				policy: MotionPolicy,
			): void => {
				this.stage = new Stage(properties, policy);
			},
			player: (
				document: MotionDocument,
				timing: ConformanceTiming,
				emit: (event: string) => void,
			): ConformancePlayer => this.stage.player(document, timing, emit),
			value: (property: string, composition: Composition): ConformanceValue =>
				this.stage.value(property, composition),
			clock: (): Clock => this.stage.manual.clock,
			advanceTo: (time: float64): void => {
				this.stage.advanceTo(time);
			},
			read: (property: string): float64 =>
				this.stage.shown[this.stage.index(property)],
			end: (): void => {
				this.stage = new Stage([], new MotionPolicy());
			},
		};
	}
}

export function headlessAdapter(): ConformanceAdapter {
	return new Headless().adapter;
}
