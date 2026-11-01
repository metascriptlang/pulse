import {
	ConformanceAdapter,
	ConformanceCase,
	ConformanceProperty,
	ConformanceResult,
	ConformanceSupport,
	ConformanceTiming,
	ConformanceValue,
	GOLDEN_PRECISION,
	runConformance,
} from "../src/conformance";
import { conformanceCases } from "../src/conformanceCases";
import { MotionDocument } from "../src/document";
import { headlessAdapter } from "../src/headless";
import { MotionPolicy } from "../src/policy";
import { Composition } from "../src/target";
import { CONFORMANCE_GOLDEN } from "./conformanceGolden";

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
		"composite.parallel",
		"composite.staggered",
		"composite.loop",
		"valueXY",
		"event",
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
