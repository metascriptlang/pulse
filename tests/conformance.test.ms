import {
	ConformanceAdapter,
	ConformanceCase,
	ConformanceProperty,
	ConformanceResult,
	ConformanceSupport,
	ConformanceTiming,
	ConformanceTrace,
	ConformanceValue,
	GOLDEN_PRECISION,
	compare,
	runConformance,
} from "../src/conformance";
import { conformanceCases } from "../src/conformanceCases";
import { ManualClock } from "../src/clock";
import { MotionDocument, MotionValue } from "../src/document";
import { headlessAdapter } from "../src/headless";
import { MotionBinding, MotionPlayer, motionOptions } from "../src/player";
import { MotionPolicy } from "../src/policy";
import { Composition } from "../src/target";
import { CONFORMANCE_GOLDEN } from "../src/conformanceGolden";

function failures(results: ConformanceResult[]): string[] {
	const out: string[] = [];
	for (const result of results) {
		for (const failure of result.failures) {
			out.push(failure);
		}
	}
	return out;
}

function only(name: string): ConformanceCase[] {
	return conformanceCases().filter(
		(testCase: ConformanceCase): boolean => testCase.name === name,
	);
}

function drifting(base: ConformanceAdapter, by: float64): ConformanceAdapter {
	return {
		name: "drifting",
		support: base.support,
		begin: base.begin,
		player: base.player,
		value: base.value,
		clock: base.clock,
		advanceTo: base.advanceTo,
		read: (property: string): float64 => base.read(property) + by,
		end: base.end,
	};
}

class RefusingDecay {
	base: ConformanceAdapter = headlessAdapter();
	refuses: boolean;
	current: string = "";
	adapter: ConformanceAdapter;

	constructor(refuses: boolean) {
		this.refuses = refuses;
		const base = this.base;
		this.adapter = {
			name: "refusing",
			support: (testCase: ConformanceCase): ConformanceSupport => {
				this.current = testCase.name;
				return testCase.name === "decay"
					? ConformanceSupport.Refused
					: ConformanceSupport.Evaluator;
			},
			begin: (
				properties: ConformanceProperty[],
				policy: MotionPolicy,
			): void => {
				if (this.refuses && this.current === "decay") {
					throw new Error("motion: refusing: decay has no engine here");
				}
				base.begin(properties, policy);
			},
			player: (
				document: MotionDocument,
				timing: ConformanceTiming,
				emit: (event: string) => void,
			) => base.player(document, timing, emit),
			value: (property: string, composition: Composition): ConformanceValue =>
				base.value(property, composition),
			clock: base.clock,
			advanceTo: base.advanceTo,
			read: base.read,
			end: base.end,
		};
	}
}

test "Pulse's headless binding matches the golden in every case" {
	const results = runConformance(
		headlessAdapter(),
		conformanceCases(),
		CONFORMANCE_GOLDEN,
		GOLDEN_PRECISION,
	);
	const found = failures(results);
	assert found.length === 0, found.join("\n");
	assert results.length === conformanceCases().length;
}

test "the golden holds one trace per case, in the suite's order" {
	const cases = conformanceCases();
	assert CONFORMANCE_GOLDEN.length === cases.length;
	for (let i: int32 = 0; i < cases.length; i += 1) {
		assert CONFORMANCE_GOLDEN[i].name === cases[i].name, cases[i].name;
		assert CONFORMANCE_GOLDEN[i].error === "", cases[i].name;
	}
}

test "every contract item of docs/ANIMATION.md has a case" {
	const names = conformanceCases().map(
		(testCase: ConformanceCase): string => testCase.name,
	);
	const items = [
		"time.delay",
		"time.duration",
		"time.repeat",
		"time.yoyo",
		"time.rate",
		"seek.silent",
		"seek.events",
		"cancel.holds",
		"finish.forward",
		"finish.reversed",
		"reverse",
		"retarget.timing",
		"retarget.spring",
		"contention.replace",
		"contention.blend",
		"contention.none",
		"lifecycle.dispose",
		"lifecycle.revert",
		"reducedMotion",
		"spring",
		"decay",
		"sequence",
		"derived",
		"derived.color",
		"composite.parallel",
		"composite.staggered",
		"composite.loop",
		"valueXY",
		"event",
		"scroll.progress",
		"scroll.delay",
		"scroll.reverseEvents",
		"scroll.inactive",
		"view.cover",
		"view.entry",
	];
	for (const item of items) {
		assert names.includes(item), item;
	}
}

test "an adapter whose presented value drifts fails, naming the case, time and property" {
	const results = runConformance(
		drifting(headlessAdapter(), 1),
		only("time.duration"),
		CONFORMANCE_GOLDEN,
	);
	const found = failures(results);
	assert found.length === 5, found.join("\n");
	assert found[1].startsWith("time.duration at 250: box.x is 26"), found[1];
}

test "a drift inside the case tolerance passes" {
	const results = runConformance(
		drifting(headlessAdapter(), 0.005),
		only("time.duration"),
		CONFORMANCE_GOLDEN,
	);
	assert failures(results).length === 0;
}

test "a colour mixed in sRGB fails the colour case, whatever it declares" {
	const testCase = only("derived.color")[0];
	const golden = CONFORMANCE_GOLDEN.filter(
		(trace: ConformanceTrace): boolean => trace.name === "derived.color",
	)[0];
	const halfway = golden.checkpoints[1];
	assert halfway.at === 250;
	const srgb: ConformanceTrace = {
		...golden,
		checkpoints: [
			golden.checkpoints[0],
			{ ...halfway, values: [0.5, 0, 0.5, 1, ...halfway.values.slice(4)] },
			...golden.checkpoints.slice(2),
		],
	};
	const declared = [ConformanceSupport.Engine, ConformanceSupport.Evaluator];
	for (const support of declared) {
		const found = compare(testCase, support, golden, srgb, testCase.tolerance);
		assert found.length === 3, found.join("\n");
		assert found[0].startsWith("derived.color at 250: tint.r is 0.5"), found[0];
	}
}

test "an adapter that loses an event fails at the checkpoint where it was due" {
	const base = headlessAdapter();
	const losing: ConformanceAdapter = {
		name: "losing",
		support: base.support,
		begin: base.begin,
		player: (
			document: MotionDocument,
			timing: ConformanceTiming,
			emit: (event: string) => void,
		) =>
			base.player(document, timing, (event: string): void => {
				if (event !== "complete") {
					emit(event);
				}
			}),
		value: base.value,
		clock: base.clock,
		advanceTo: base.advanceTo,
		read: base.read,
		end: base.end,
	};
	const found = failures(
		runConformance(losing, only("time.duration"), CONFORMANCE_GOLDEN),
	);
	assert found.length === 1, found.join("\n");
	assert found[0] ===
		"time.duration at 1000: events [], golden [p:complete]", found[0];
}

test "a case declared refused passes only when construction throws a motion error" {
	const ran = failures(
		runConformance(
			new RefusingDecay(false).adapter,
			only("decay"),
			CONFORMANCE_GOLDEN,
		),
	);
	assert ran.length === 1 &&
		ran[0] === "decay: declared refused at construction, but it ran", ran.join(
		"\n",
	);
	const refused = new RefusingDecay(true).adapter;
	const results = runConformance(refused, only("decay"), CONFORMANCE_GOLDEN);
	assert failures(results).length === 0;
	assert results[0].support === ConformanceSupport.Refused;
}

test "an adapter that refuses a case it declared supported fails" {
	const adapter = new RefusingDecay(true).adapter;
	const evaluator: ConformanceAdapter = {
		name: "evaluator",
		support: (testCase: ConformanceCase): ConformanceSupport => {
			adapter.support(testCase);
			return ConformanceSupport.Evaluator;
		},
		begin: adapter.begin,
		player: adapter.player,
		value: adapter.value,
		clock: adapter.clock,
		advanceTo: adapter.advanceTo,
		read: adapter.read,
		end: adapter.end,
	};
	const found = failures(
		runConformance(evaluator, only("decay"), CONFORMANCE_GOLDEN),
	);
	assert found.length === 1 &&
		found[0].startsWith("decay: threw motion: refusing"), found.join("\n");
}

test "an adapter that cannot drive scroll has the scroll cases refused" {
	const scrolling = conformanceCases().filter(
		(testCase: ConformanceCase): boolean => testCase.scroll !== null,
	);
	assert scrolling.length === 6;
	const results = runConformance(
		drifting(headlessAdapter(), 0),
		scrolling,
		CONFORMANCE_GOLDEN,
	);
	assert failures(results).length === 0, failures(results).join("\n");
	for (const result of results) {
		assert result.support === ConformanceSupport.Refused, result.name;
	}
}

function engineCounting(
	base: ConformanceAdapter,
	declared: ConformanceSupport,
	live: int32,
): ConformanceAdapter {
	return {
		name: "counting",
		support: (testCase: ConformanceCase): ConformanceSupport => declared,
		begin: base.begin,
		player: base.player,
		value: base.value,
		clock: base.clock,
		advanceTo: base.advanceTo,
		read: base.read,
		end: base.end,
		engineAnimations: (): int32 => live,
	};
}

test "an adapter that counts its engine animations proves what it declared" {
	const cases = only("time.duration");
	const idle = failures(runConformance(
		engineCounting(headlessAdapter(), ConformanceSupport.Engine, 0),
		cases,
		CONFORMANCE_GOLDEN,
	));
	assert idle.length === 1 && idle[0] ===
		"time.duration: declared Engine, but no platform-engine animation was live at a checkpoint",
		idle.join("\n");
	const busy = failures(runConformance(
		engineCounting(headlessAdapter(), ConformanceSupport.Evaluator, 2),
		cases,
		CONFORMANCE_GOLDEN,
	));
	assert busy.length === 1 && busy[0] ===
		"time.duration at 0: declared Evaluator, but 2 platform-engine animations were live",
		busy.join("\n");
	const honest = [
		engineCounting(headlessAdapter(), ConformanceSupport.Engine, 1),
		engineCounting(headlessAdapter(), ConformanceSupport.Evaluator, 0),
	];
	for (const adapter of honest) {
		const found = failures(runConformance(adapter, cases, CONFORMANCE_GOLDEN));
		assert found.length === 0, found.join("\n");
	}
}

class WebTiming {
	delay: float64 = 0;
	iterations: float64 = 1;
	gap: float64 = 0;
	alternate: boolean = false;
	initial: float64 = 0;
}

function webTiming(configure: (timing: WebTiming) => void): WebTiming {
	const timing = new WebTiming();
	configure(timing);
	return timing;
}

const RAMP_DURATION: float64 = 1000;
const RAMP_SPAN: float64 = 100;

function rampByWebAnimations(timing: WebTiming, local: float64): float64 {
	if (local < timing.delay) {
		return timing.initial;
	}
	const activeDuration = RAMP_DURATION * timing.iterations + timing.gap * (timing.iterations - 1);
	const active = Math.min(local - timing.delay, activeDuration);
	const cycle = RAMP_DURATION + timing.gap;
	let iteration: float64 = timing.iterations - 1;
	let progress: float64 = 1;
	if (active < activeDuration) {
		iteration = Math.floor(active / cycle);
		progress = Math.min(active - iteration * cycle, RAMP_DURATION) / RAMP_DURATION;
	}
	const directed = timing.alternate && iteration % 2 === 1 ? 1 - progress : progress;
	return RAMP_SPAN * directed;
}

class Rows {
	checked: int32 = 0;
	mismatches: string[] = [];

	check(name: string, timing: WebTiming, local: (at: float64) => float64): void {
		const rows = CONFORMANCE_GOLDEN.filter(
			(trace: ConformanceTrace): boolean => trace.name === name,
		)[0].checkpoints;
		for (const row of rows) {
			const want = rampByWebAnimations(timing, local(row.at));
			if (!(Math.abs(row.values[0] - want) <= GOLDEN_PRECISION)) {
				this.mismatches.push(
					name + " at " + row.at.toString() + ": golden " + row.values[0].toString() +
						", Web Animations " + want.toString(),
				);
			}
			this.checked += 1;
		}
	}
}

test "the golden's time rows agree with the Web Animations timing model computed by hand" {
	const clockTime = (at: float64): float64 => at;
	const rows = new Rows();
	rows.check("time.duration", new WebTiming(), clockTime);
	rows.check(
		"time.delay",
		webTiming((t: WebTiming): void => { t.delay = 200; t.initial = 50; }),
		clockTime,
	);
	rows.check(
		"time.repeat",
		webTiming((t: WebTiming): void => { t.iterations = 3; t.gap = 100; }),
		clockTime,
	);
	rows.check(
		"time.yoyo",
		webTiming((t: WebTiming): void => { t.iterations = 2; t.alternate = true; }),
		clockTime,
	);
	rows.check(
		"time.rate",
		new WebTiming(),
		(at: float64): float64 => at <= 200 ? 2 * at : 400 + 0.5 * (at - 200),
	);
	rows.check(
		"reverse",
		new WebTiming(),
		(at: float64): float64 => at <= 600 ? at : Math.max(0, 600 - (at - 600)),
	);
	assert rows.mismatches.length === 0, rows.mismatches.join("\n");
	assert rows.checked >= 20, rows.checked.toString();
}

function seekedRamp(name: string, position: float64): float64 {
	const spec = only(name)[0].players[0];
	const clock = new ManualClock();
	let shown: float64 = NaN;
	const binding: MotionBinding = {
		slot: "box",
		property: "x",
		write: (value: MotionValue): void => { shown = value.number; },
		read: null,
	};
	const player = new MotionPlayer(spec.document, [binding], {
		...motionOptions(clock.clock),
		repeat: spec.timing.repeat,
		repeatDelay: spec.timing.repeatDelay,
		yoyo: spec.timing.yoyo,
		paused: true,
	});
	player.seek(position);
	return shown;
}

function probeMismatch(name: string, timing: WebTiming, at: float64): string {
	const want = rampByWebAnimations(timing, at);
	const got = seekedRamp(name, at);
	if (Math.abs(got - want) <= GOLDEN_PRECISION) {
		return "";
	}
	return name + " at " + at.toString() + ": player " + got.toString() + ", Web Animations " +
		want.toString();
}

test "the player agrees with the Web Animations timing model an epsilon either side of each boundary" {
	const epsilon: float64 = 1e-3;
	const repeated = webTiming((t: WebTiming): void => { t.iterations = 3; t.gap = 100; });
	const boundaries: float64[] = [1000, 1100, 2100, 2200, 3200];
	for (const boundary of boundaries) {
		const before = probeMismatch("time.repeat", repeated, boundary - epsilon);
		assert before === "", before;
		const after = probeMismatch("time.repeat", repeated, boundary + epsilon);
		assert after === "", after;
	}
	const yoyo = webTiming((t: WebTiming): void => { t.iterations = 2; t.alternate = true; });
	const probes: float64[] = [1000 - epsilon, 1000, 1000 + epsilon, 2000 - epsilon, 2000, 2000 + epsilon];
	for (const at of probes) {
		const mismatch = probeMismatch("time.yoyo", yoyo, at);
		assert mismatch === "", mismatch;
	}
}
