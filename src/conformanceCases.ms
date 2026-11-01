import {
	ConformanceCase,
	ConformancePlayerSpec,
	ConformanceProperty,
	ConformanceScene,
	ConformanceStep,
	ConformanceTiming,
	ConformanceValueSpec,
	conformanceTiming,
} from "./conformance";
import { loop, parallel, staggered } from "./composite";
import { decayConfig } from "./decay";
import {
	Extrapolate,
	add,
	diffClamp,
	interpolated,
	interpolatedColor,
} from "./derived";
import {
	MotionColor,
	MotionDocument,
	ValueKind,
	linearKeyframe,
} from "./document";
import { EventPayload, event } from "./event";
import { Easing } from "./easing";
import { ReduceMotion } from "./policy";
import { springByDuration, springByStiffness } from "./spring";
import { Composition } from "./target";
import {
	AnimationSpec,
	decay,
	delay,
	repeat,
	sequence,
	spring,
	timing,
} from "./value";

const KEYFRAME_TOLERANCE: float64 = 0.01;
const SAMPLED_TOLERANCE: float64 = 0.5;

function ramp(from: float64, to: float64): MotionDocument {
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
						keyframes: [
							linearKeyframe("from", 0, from),
							linearKeyframe("to", 1000, to),
						],
					},
				],
				placements: [],
				labels: [],
			},
		],
	};
}

function linear(to: float64, duration: float64): AnimationSpec {
	return timing(to, { duration, easing: Easing.linear });
}

function at(
	time: float64,
	run: (scene: ConformanceScene) => void,
): ConformanceStep {
	return { at: time, run };
}

function property(name: string, initial: float64 = 0): ConformanceProperty {
	return { name, initial };
}

function player(
	name: string,
	document: MotionDocument,
	timing: ConformanceTiming = conformanceTiming(),
): ConformancePlayerSpec {
	return { name, document, timing };
}

function value(
	name: string,
	property: string,
	composition: Composition = Composition.Replace,
): ConformanceValueSpec {
	return { name, property, composition };
}

function blank(name: string): ConformanceCase {
	return {
		name,
		properties: [property("box.x")],
		players: [],
		values: [],
		reducedMotion: false,
		steps: [],
		checkpoints: [],
		reads: ["box.x"],
		tolerance: KEYFRAME_TOLERANCE,
	};
}

function rampCase(
	name: string,
	timing: ConformanceTiming,
	steps: ConformanceStep[],
	checkpoints: float64[],
): ConformanceCase {
	return {
		...blank(name),
		players: [player("p", ramp(0, 100), timing)],
		steps,
		checkpoints,
	};
}

function timeCases(): ConformanceCase[] {
	const base = conformanceTiming();
	return [
		rampCase("time.duration", base, [], [0, 250, 500, 1000, 1200]),
		{
			...rampCase(
				"time.delay",
				{ ...base, delay: 200 },
				[],
				[0, 100, 200, 450, 1200, 1400],
			),
			properties: [property("box.x", 50)],
		},
		rampCase(
			"time.repeat",
			{ ...base, repeat: 2, repeatDelay: 100 },
			[],
			[500, 1050, 1600, 2150, 2700, 3200, 3400],
		),
		rampCase(
			"time.yoyo",
			{ ...base, repeat: 1, yoyo: true },
			[],
			[500, 1000, 1500, 1750, 2000, 2200],
		),
		rampCase(
			"time.rate",
			{ ...base, timeScale: 2 },
			[
				at(200, (s: ConformanceScene): void => {
					s.player("p").setTimeScale(0.5);
				}),
			],
			[100, 200, 400, 1400, 1600],
		),
	];
}

function playbackCases(): ConformanceCase[] {
	const base = conformanceTiming();
	const paused = { ...base, paused: true };
	return [
		rampCase(
			"seek.silent",
			paused,
			[
				at(100, (s: ConformanceScene): void => {
					s.player("p").seek(300, true);
				}),
				at(200, (s: ConformanceScene): void => {
					s.player("p").seek(1000, true);
				}),
				at(300, (s: ConformanceScene): void => {
					s.player("p").seek(0, true);
				}),
			],
			[0, 100, 200, 300],
		),
		rampCase(
			"seek.events",
			paused,
			[
				at(100, (s: ConformanceScene): void => {
					s.player("p").seek(500, false);
				}),
				at(200, (s: ConformanceScene): void => {
					s.player("p").seek(1000, false);
				}),
				at(300, (s: ConformanceScene): void => {
					s.player("p").seek(0, false);
				}),
			],
			[100, 200, 300],
		),
		rampCase(
			"cancel.holds",
			base,
			[
				at(400, (s: ConformanceScene): void => {
					s.player("p").cancel();
				}),
				at(900, (s: ConformanceScene): void => {
					s.player("p").play();
				}),
			],
			[400, 800, 1200, 1600],
		),
		rampCase(
			"finish.forward",
			base,
			[
				at(300, (s: ConformanceScene): void => {
					s.player("p").finish();
				}),
			],
			[300, 600],
		),
		rampCase(
			"finish.reversed",
			base,
			[
				at(600, (s: ConformanceScene): void => {
					s.player("p").reverse();
				}),
				at(700, (s: ConformanceScene): void => {
					s.player("p").finish();
				}),
			],
			[600, 700, 900],
		),
		rampCase(
			"reverse",
			base,
			[
				at(600, (s: ConformanceScene): void => {
					s.player("p").reverse();
				}),
			],
			[600, 800, 1200, 1400],
		),
	];
}

function retargetCases(): ConformanceCase[] {
	return [
		{
			...blank("retarget.timing"),
			values: [value("a", "box.x")],
			steps: [
				at(0, (s: ConformanceScene): void => {
					s.animate("a", linear(100, 1000));
				}),
				at(500, (s: ConformanceScene): void => {
					s.animate("a", linear(0, 500));
				}),
			],
			checkpoints: [250, 500, 750, 1000, 1200],
		},
		{
			...blank("retarget.spring"),
			values: [value("a", "box.x")],
			steps: [
				at(0, (s: ConformanceScene): void => {
					s.animate("a", spring(100));
				}),
				at(200, (s: ConformanceScene): void => {
					s.animate("a", spring(0));
				}),
			],
			checkpoints: [100, 196, 200, 204, 300, 600, 1000, 3000],
			tolerance: SAMPLED_TOLERANCE,
		},
	];
}

function contentionCases(): ConformanceCase[] {
	const takeover = (s: ConformanceScene): void => {
		s.animate("b", linear(0, 500));
	};
	const first = (s: ConformanceScene): void => {
		s.animate("a", linear(100, 1000));
	};
	return [
		{
			...blank("contention.replace"),
			values: [value("a", "box.x"), value("b", "box.x")],
			steps: [at(0, first), at(500, takeover)],
			checkpoints: [250, 500, 750, 1000, 1200],
		},
		{
			...blank("contention.blend"),
			values: [
				value("a", "box.x", Composition.Blend),
				value("b", "box.x", Composition.Blend),
			],
			steps: [
				at(0, first),
				at(500, (s: ConformanceScene): void => {
					s.animate("b", linear(200, 500));
				}),
			],
			checkpoints: [250, 500, 750, 1000, 1200],
		},
		{
			...blank("contention.none"),
			values: [
				value("a", "box.x", Composition.None),
				value("b", "box.x", Composition.None),
			],
			steps: [
				at(0, first),
				at(500, (s: ConformanceScene): void => {
					s.animate("b", linear(50, 500));
				}),
			],
			checkpoints: [250, 750, 1000],
			reads: ["a", "b"],
		},
		{
			...blank("contention.players"),
			players: [
				player("p", ramp(0, 100)),
				player("q", ramp(100, 0), { ...conformanceTiming(), paused: true }),
			],
			steps: [
				at(500, (s: ConformanceScene): void => {
					s.player("q").play();
				}),
			],
			checkpoints: [250, 500, 750, 1000, 1500, 1700],
		},
	];
}

function lifecycleCases(): ConformanceCase[] {
	return [
		{
			...blank("lifecycle.dispose"),
			properties: [property("box.x"), property("box.y")],
			players: [player("p", ramp(0, 100))],
			values: [value("a", "box.y")],
			steps: [
				at(0, (s: ConformanceScene): void => {
					s.animate("a", linear(100, 1000));
				}),
				at(300, (s: ConformanceScene): void => {
					s.player("p").dispose();
					s.value("a").dispose();
				}),
			],
			checkpoints: [300, 600, 1200],
			reads: ["box.x", "box.y"],
		},
		{
			...rampCase(
				"lifecycle.revert",
				conformanceTiming(),
				[
					at(300, (s: ConformanceScene): void => {
						s.player("p").revert();
					}),
				],
				[300, 600],
			),
			properties: [property("box.x", 7)],
		},
	];
}

function reducedMotionCase(): ConformanceCase {
	return {
		...blank("reducedMotion"),
		properties: [property("box.a"), property("box.b"), property("box.c")],
		values: [value("a", "box.a"), value("b", "box.b"), value("c", "box.c")],
		reducedMotion: true,
		steps: [
			at(0, (s: ConformanceScene): void => {
				s.animate("a", linear(100, 1000));
				s.animate("b", {
					...linear(100, 1000),
					reduceMotion: ReduceMotion.Never,
				});
				s.animate("c", spring(100));
			}),
		],
		checkpoints: [0, 500, 1000],
		reads: ["box.a", "box.b", "box.c"],
	};
}

function physicsCases(): ConformanceCase[] {
	const springs = [property("box.a"), property("box.b"), property("box.c")];
	return [
		{
			...blank("spring"),
			properties: springs,
			values: [value("a", "box.a"), value("b", "box.b"), value("c", "box.c")],
			steps: [
				at(0, (s: ConformanceScene): void => {
					s.animate("a", spring(100));
					s.animate("b", spring(100, springByDuration(500, 0.5)));
					s.animate("c", spring(100, springByStiffness(100, 40, 1)));
				}),
			],
			checkpoints: [50, 100, 200, 400, 800, 1600, 3000],
			reads: ["box.a", "box.b", "box.c"],
			tolerance: SAMPLED_TOLERANCE,
		},
		{
			...blank("decay"),
			properties: [property("box.a"), property("box.b")],
			values: [value("a", "box.a"), value("b", "box.b")],
			steps: [
				at(0, (s: ConformanceScene): void => {
					s.animate("a", decay(decayConfig(), 1000));
					s.animate(
						"b",
						decay({ ...decayConfig(), clampMin: -200, clampMax: 200 }, 1000),
					);
				}),
			],
			checkpoints: [100, 300, 600, 1200, 3000],
			reads: ["box.a", "box.b"],
		},
		{
			...blank("sequence"),
			values: [value("a", "box.x")],
			steps: [
				at(0, (s: ConformanceScene): void => {
					s.animate(
						"a",
						sequence(
							linear(100, 300),
							delay(200, linear(0, 300)),
							repeat(linear(50, 100), 2, true),
						),
					);
				}),
			],
			checkpoints: [150, 300, 400, 500, 650, 800, 850, 900, 1000],
		},
	];
}

function derivedCase(): ConformanceCase {
	return {
		...blank("derived"),
		properties: [property("box.a"), property("box.b")],
		values: [value("a", "box.a"), value("b", "box.b")],
		steps: [
			at(0, (s: ConformanceScene): void => {
				s.derive(
					"unit",
					interpolated(s.source("a"), {
						inputRange: [0, 100],
						outputRange: [0, 1],
						extrapolate: Extrapolate.Clamp,
					}),
				);
				s.derive("sum", add(s.source("a"), s.source("b")));
				s.derive("clamped", diffClamp(s.source("a"), 0, 30));
				s.animate("a", linear(100, 1000));
				s.animate("b", linear(50, 500));
			}),
			at(1000, (s: ConformanceScene): void => {
				s.animate("a", linear(80, 200));
			}),
		],
		checkpoints: [0, 250, 500, 1000, 1200],
		reads: ["unit", "sum", "clamped"],
	};
}

function colorCase(): ConformanceCase {
	const red: MotionColor = { r: 1, g: 0, b: 0, a: 1 };
	const blue: MotionColor = { r: 0, g: 0, b: 1, a: 1 };
	const white: MotionColor = { r: 1, g: 1, b: 1, a: 0.5 };
	const dim: MotionColor = { r: 0.2, g: 0.3, b: 0.2, a: 1 };
	const mid: MotionColor = { r: 0.4, g: 0.5, b: 0.3, a: 1 };
	return {
		...blank("derived.color"),
		properties: [property("box.a")],
		values: [value("a", "box.a")],
		steps: [
			at(0, (s: ConformanceScene): void => {
				s.deriveColor(
					"tint",
					interpolatedColor(s.source("a"), {
						inputRange: [0, 50, 100],
						outputRange: [red, blue, white],
						extrapolate: Extrapolate.Clamp,
					}),
				);
				s.deriveColor(
					"wide",
					interpolatedColor(s.source("a"), {
						inputRange: [0, 100],
						outputRange: [dim, mid],
					}),
				);
				s.animate("a", linear(100, 1000));
			}),
			at(1000, (s: ConformanceScene): void => {
				s.animate("a", linear(150, 500));
			}),
		],
		checkpoints: [0, 250, 500, 750, 1000, 1250, 1500],
		reads: [
			"tint.r",
			"tint.g",
			"tint.b",
			"tint.a",
			"wide.r",
			"wide.g",
			"wide.b",
		],
	};
}

function compositeCases(): ConformanceCase[] {
	const pair = [property("box.a"), property("box.b")];
	const both = (s: ConformanceScene): void => {
		s.start(
			"both",
			parallel([
				s.animation("a", linear(100, 500)),
				s.animation("b", linear(50, 1000)),
			]),
		);
	};
	return [
		{
			...blank("composite.parallel"),
			properties: pair,
			values: [value("a", "box.a"), value("b", "box.b")],
			steps: [at(0, both)],
			checkpoints: [250, 500, 1000],
			reads: ["box.a", "box.b"],
		},
		{
			...blank("composite.parallelStop"),
			properties: pair,
			values: [value("a", "box.a"), value("b", "box.b")],
			steps: [
				at(0, both),
				at(250, (s: ConformanceScene): void => {
					s.value("a").cancel();
				}),
			],
			checkpoints: [250, 500],
			reads: ["box.a", "box.b"],
		},
		{
			...blank("composite.staggered"),
			properties: [property("box.a"), property("box.b"), property("box.c")],
			values: [value("a", "box.a"), value("b", "box.b"), value("c", "box.c")],
			steps: [
				at(0, (s: ConformanceScene): void => {
					s.start(
						"wave",
						staggered(
							100,
							[
								s.animation("a", linear(100, 300)),
								s.animation("b", linear(100, 300)),
								s.animation("c", linear(100, 300)),
							],
							s.adapter.clock(),
							s.policy,
						),
					);
				}),
			],
			checkpoints: [100, 200, 300, 400, 500, 600],
			reads: ["box.a", "box.b", "box.c"],
		},
		{
			...blank("composite.loop"),
			values: [value("a", "box.x")],
			steps: [
				at(0, (s: ConformanceScene): void => {
					s.start("cycle", loop(s.animation("a", linear(100, 200)), 3));
				}),
			],
			checkpoints: [100, 200, 300, 500, 600, 700],
		},
	];
}

function valueXYCases(): ConformanceCase[] {
	const xy = [property("box.x"), property("box.y")];
	return [
		{
			...blank("valueXY"),
			properties: xy,
			values: [value("x", "box.x"), value("y", "box.y")],
			steps: [
				at(0, (s: ConformanceScene): void => {
					s.start(
						"xy",
						parallel(
							[
								s.animation("x", linear(100, 400)),
								s.animation("y", spring(50)),
							],
							false,
						),
					);
				}),
			],
			checkpoints: [200, 400, 1000, 3000],
			reads: ["box.x", "box.y"],
			tolerance: SAMPLED_TOLERANCE,
		},
		{
			...blank("event"),
			properties: xy,
			values: [value("x", "box.x"), value("y", "box.y")],
			steps: [
				at(0, (s: ConformanceScene): void => {
					s.animate("x", linear(100, 1000));
				}),
				at(300, (s: ConformanceScene): void => {
					const onScroll = event(
						{ x: s.writable("x"), y: s.writable("y") },
						(payload: EventPayload): void => {
							s.record("listener");
						},
					);
					onScroll({
						x: 10,
						y: 20,
						width: 0,
						height: 0,
						contentWidth: 0,
						contentHeight: 0,
					});
				}),
			],
			checkpoints: [300, 600],
			reads: ["box.x", "box.y"],
		},
	];
}

export function conformanceCases(): ConformanceCase[] {
	return [
		...timeCases(),
		...playbackCases(),
		...retargetCases(),
		...contentionCases(),
		...lifecycleCases(),
		reducedMotionCase(),
		...physicsCases(),
		derivedCase(),
		colorCase(),
		...compositeCases(),
		...valueXYCases(),
	];
}
