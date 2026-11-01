import { Clock } from "./clock";
import { CompositeAnimation } from "./composite";
import { DerivedValue, ValueSource } from "./derived";
import { MotionDocument } from "./document";
import { MotionPolicy } from "./policy";
import { Composition } from "./target";
import { AnimationSpec } from "./value";

export const GOLDEN_PRECISION: float64 = 1e-6;

export enum ConformanceSupport {
	Engine,
	Evaluator,
	Refused,
}

export struct ConformanceProperty {
	name: string;
	initial: float64;
}

export struct ConformanceTiming {
	delay: float64;
	repeat: int32;
	repeatDelay: float64;
	yoyo: boolean;
	timeScale: float64;
	paused: boolean;
	composition: Composition;
}

export function conformanceTiming(): ConformanceTiming {
	return {
		delay: 0,
		repeat: 0,
		repeatDelay: 0,
		yoyo: false,
		timeScale: 1,
		paused: false,
		composition: Composition.Replace,
	};
}

export struct ConformancePlayerSpec {
	name: string;
	document: MotionDocument;
	timing: ConformanceTiming;
}

export struct ConformanceValueSpec {
	name: string;
	property: string;
	composition: Composition;
}

export interface ConformancePlayer {
	play: () => void;
	pause: () => void;
	seek: (position: float64, suppressEvents: boolean) => void;
	reverse: () => void;
	setTimeScale: (rate: float64) => void;
	cancel: () => void;
	finish: () => void;
	revert: () => void;
	dispose: () => void;
}

export interface ConformanceValue {
	get: () => float64;
	set: (value: float64) => void;
	animate: (
		spec: AnimationSpec,
		onEnd: ((finished: boolean) => void) | null,
	) => void;
	cancel: () => void;
	dispose: () => void;
	subscribe: (callback: (value: float64) => void) => () => void;
}

export interface ConformanceAdapter {
	name: string;
	support: (testCase: ConformanceCase) => ConformanceSupport;
	begin: (properties: ConformanceProperty[], policy: MotionPolicy) => void;
	player: (
		document: MotionDocument,
		timing: ConformanceTiming,
		emit: (event: string) => void,
	) => ConformancePlayer;
	value: (property: string, composition: Composition) => ConformanceValue;
	clock: () => Clock;
	advanceTo: (time: float64) => void;
	read: (property: string) => float64;
	end: () => void;
}

export struct ConformanceStep {
	at: float64;
	run: (scene: ConformanceScene) => void;
}

export struct ConformanceCase {
	name: string;
	properties: ConformanceProperty[];
	players: ConformancePlayerSpec[];
	values: ConformanceValueSpec[];
	reducedMotion: boolean;
	steps: ConformanceStep[];
	checkpoints: float64[];
	reads: string[];
	tolerance: float64;
}

export struct ConformanceCheckpoint {
	at: float64;
	values: float64[];
	events: string[];
}

export struct ConformanceTrace {
	name: string;
	error: string;
	checkpoints: ConformanceCheckpoint[];
}

export struct ConformanceResult {
	name: string;
	support: ConformanceSupport;
	failures: string[];
}

function fail(message: string): never {
	throw new Error("motion: conformance: " + message);
}

function endEvent(name: string, finished: boolean): string {
	return name + (finished ? ":finished" : ":interrupted");
}

export class ConformanceScene {
	readonly adapter: ConformanceAdapter;
	readonly policy: MotionPolicy;
	private playerNames: string[] = [];
	private players: ConformancePlayer[] = [];
	private valueNames: string[] = [];
	private values: ConformanceValue[] = [];
	private derivedNames: string[] = [];
	private derived: DerivedValue[] = [];
	private log: string[] = [];

	constructor(adapter: ConformanceAdapter, testCase: ConformanceCase) {
		this.adapter = adapter;
		this.policy = new MotionPolicy(testCase.reducedMotion);
		adapter.begin(testCase.properties, this.policy);
		for (const spec of testCase.players) {
			const name = spec.name;
			this.playerNames.push(name);
			this.players.push(
				adapter.player(spec.document, spec.timing, (event: string): void => {
					this.record(name + ":" + event);
				}),
			);
		}
		for (const spec of testCase.values) {
			this.valueNames.push(spec.name);
			this.values.push(adapter.value(spec.property, spec.composition));
		}
	}

	player(name: string): ConformancePlayer {
		const index = this.playerNames.indexOf(name);
		if (index < 0) {
			fail("unknown player " + name);
		}
		return this.players[index];
	}

	value(name: string): ConformanceValue {
		const index = this.valueNames.indexOf(name);
		if (index < 0) {
			fail("unknown value " + name);
		}
		return this.values[index];
	}

	source(name: string): ValueSource {
		const value = this.value(name);
		return { get: value.get, subscribe: value.subscribe };
	}

	animate(name: string, spec: AnimationSpec): void {
		this.value(name).animate(spec, (finished: boolean): void => {
			this.record(endEvent(name, finished));
		});
	}

	animation(name: string, spec: AnimationSpec): CompositeAnimation {
		const value = this.value(name);
		const startValue = value.get();
		return {
			start: (onEnd: ((finished: boolean) => void) | null): void => {
				value.animate(spec, onEnd);
			},
			stop: (): void => {
				value.cancel();
			},
			reset: (): void => {
				value.set(startValue);
			},
		};
	}

	start(label: string, composite: CompositeAnimation): void {
		composite.start((finished: boolean): void => {
			this.record(endEvent(label, finished));
		});
	}

	derive(name: string, value: DerivedValue): void {
		this.derivedNames.push(name);
		this.derived.push(value);
	}

	record(event: string): void {
		this.log.push(event);
	}

	read(name: string): float64 {
		const derived = this.derivedNames.indexOf(name);
		if (derived >= 0) {
			return this.derived[derived].get();
		}
		const value = this.valueNames.indexOf(name);
		if (value >= 0) {
			return this.values[value].get();
		}
		return this.adapter.read(name);
	}

	drain(): string[] {
		const out = this.log;
		this.log = [];
		return out;
	}
}

function requireSorted(times: float64[], what: string, name: string): void {
	for (let i: int32 = 1; i < times.length; i += 1) {
		if (times[i] < times[i - 1]) {
			fail(what + " of " + name + " are not sorted");
		}
	}
}

function play(
	adapter: ConformanceAdapter,
	testCase: ConformanceCase,
): ConformanceCheckpoint[] {
	const stepTimes = testCase.steps.map(
		(step: ConformanceStep): float64 => step.at,
	);
	requireSorted(stepTimes, "steps", testCase.name);
	requireSorted(testCase.checkpoints, "checkpoints", testCase.name);
	const scene = new ConformanceScene(adapter, testCase);
	const out: ConformanceCheckpoint[] = [];
	let step: int32 = 0;
	let checkpoint: int32 = 0;
	while (checkpoint < testCase.checkpoints.length) {
		const at = testCase.checkpoints[checkpoint];
		if (step < stepTimes.length && stepTimes[step] <= at) {
			adapter.advanceTo(stepTimes[step]);
			testCase.steps[step].run(scene);
			step += 1;
			continue;
		}
		adapter.advanceTo(at);
		out.push({
			at,
			values: testCase.reads.map((name: string): float64 => scene.read(name)),
			events: scene.drain(),
		});
		checkpoint += 1;
	}
	if (step < stepTimes.length) {
		fail("a step of " + testCase.name + " lies after its last checkpoint");
	}
	return out;
}

export function observe(
	adapter: ConformanceAdapter,
	testCase: ConformanceCase,
): ConformanceTrace {
	let checkpoints: ConformanceCheckpoint[] = [];
	let error = "";
	try {
		checkpoints = play(adapter, testCase);
	} catch (e) {
		error = e.message;
	}
	adapter.end();
	return { name: testCase.name, error, checkpoints };
}

function compareCheckpoints(
	testCase: ConformanceCase,
	golden: ConformanceTrace,
	observed: ConformanceTrace,
	tolerance: float64,
): string[] {
	const failures: string[] = [];
	if (golden.checkpoints.length !== observed.checkpoints.length) {
		failures.push(
			testCase.name +
				": " +
				observed.checkpoints.length.toString() +
				" checkpoints, golden " +
				golden.checkpoints.length.toString(),
		);
		return failures;
	}
	for (let i: int32 = 0; i < golden.checkpoints.length; i += 1) {
		const want = golden.checkpoints[i];
		const got = observed.checkpoints[i];
		const where = testCase.name + " at " + want.at.toString();
		for (let r: int32 = 0; r < testCase.reads.length; r += 1) {
			if (!(Math.abs(got.values[r] - want.values[r]) <= tolerance)) {
				failures.push(
					where +
						": " +
						testCase.reads[r] +
						" is " +
						got.values[r].toString() +
						", golden " +
						want.values[r].toString(),
				);
			}
		}
		const gotEvents = got.events.join(" ");
		const wantEvents = want.events.join(" ");
		if (gotEvents !== wantEvents) {
			failures.push(
				where + ": events [" + gotEvents + "], golden [" + wantEvents + "]",
			);
		}
	}
	return failures;
}

export function compare(
	testCase: ConformanceCase,
	support: ConformanceSupport,
	golden: ConformanceTrace,
	observed: ConformanceTrace,
	tolerance: float64,
): string[] {
	if (support === ConformanceSupport.Refused) {
		if (observed.error.startsWith("motion: ")) {
			return [];
		}
		const ran = observed.error === "" ? "it ran" : "it threw " + observed.error;
		return [testCase.name + ": declared refused at construction, but " + ran];
	}
	if (observed.error !== "") {
		return [testCase.name + ": threw " + observed.error];
	}
	return compareCheckpoints(testCase, golden, observed, tolerance);
}

function goldenFor(
	golden: ConformanceTrace[],
	name: string,
): ConformanceTrace | null {
	for (const trace of golden) {
		if (trace.name === name) {
			return trace;
		}
	}
	return null;
}

export function runConformance(
	adapter: ConformanceAdapter,
	cases: ConformanceCase[],
	golden: ConformanceTrace[],
	tolerance: float64 | null = null,
): ConformanceResult[] {
	const results: ConformanceResult[] = [];
	for (const testCase of cases) {
		const support = adapter.support(testCase);
		const expected = goldenFor(golden, testCase.name);
		if (expected === null) {
			results.push({
				name: testCase.name,
				support,
				failures: [testCase.name + ": no golden trace"],
			});
			continue;
		}
		const observed = observe(adapter, testCase);
		const failures = compare(
			testCase,
			support,
			expected,
			observed,
			tolerance ?? testCase.tolerance,
		);
		results.push({ name: testCase.name, support, failures });
	}
	return results;
}

function goldenNumber(value: float64): string {
	const text = value.toFixed(6);
	let end = text.length;
	while (text.charAt(end - 1) === "0") {
		end -= 1;
	}
	if (text.charAt(end - 1) === ".") {
		end -= 1;
	}
	const trimmed = text.substring(0, end);
	return trimmed === "-0" ? "0" : trimmed;
}

function quoted(texts: string[]): string {
	return texts.map((text: string): string => '"' + text + '"').join(", ");
}

export function goldenSource(traces: ConformanceTrace[]): string {
	const lines: string[] = [
		'import { ConformanceTrace } from "./conformance";',
		"",
		"export const CONFORMANCE_GOLDEN: ConformanceTrace[] = [",
	];
	for (const trace of traces) {
		lines.push("\t{");
		lines.push('\t\tname: "' + trace.name + '",');
		lines.push('\t\terror: "' + trace.error + '",');
		lines.push("\t\tcheckpoints: [");
		for (const checkpoint of trace.checkpoints) {
			const values = checkpoint.values.map(goldenNumber).join(", ");
			lines.push(
				"\t\t\t{ at: " +
					goldenNumber(checkpoint.at) +
					", values: [" +
					values +
					"], events: [" +
					quoted(checkpoint.events) +
					"] },",
			);
		}
		lines.push("\t\t],");
		lines.push("\t},");
	}
	lines.push("];");
	return lines.join("\n");
}
