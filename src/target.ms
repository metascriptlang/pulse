import { MotionValue, ValueKind, colorValue, numberValue } from "./document";

export enum Composition {
	Replace,
	Blend,
	None,
}

export class TargetClaim {
	composition: Composition;
	end: MotionValue;
	offset: MotionValue;
	delta: MotionValue;
	onReplaced: () => void;

	constructor(
		composition: Composition,
		end: MotionValue,
		offset: MotionValue,
		delta: MotionValue,
		onReplaced: () => void,
	) {
		this.composition = composition;
		this.end = end;
		this.offset = offset;
		this.delta = delta;
		this.onReplaced = onReplaced;
	}
}

function fail(message: string): never {
	throw new Error("motion: " + message);
}

function channels(value: MotionValue): float64[] {
	if (value.kind === ValueKind.Number) { return [value.number]; }
	return [value.color.r, value.color.g, value.color.b, value.color.a];
}

function fromChannels(kind: ValueKind, parts: float64[]): MotionValue {
	if (kind === ValueKind.Number) { return numberValue(parts[0]); }
	return colorValue(parts[0], parts[1], parts[2], parts[3]);
}

function sameKind(a: MotionValue, b: MotionValue, label: string): void {
	if (a.kind !== b.kind) { fail(label + " blends a number with a colour"); }
}

function combine(a: MotionValue, b: MotionValue, weight: float64, label: string): MotionValue {
	sameKind(a, b, label);
	const left = channels(a);
	const right = channels(b);
	const out: float64[] = [];
	for (let i: int32 = 0; i < left.length; i += 1) { out.push(left[i] + right[i] * weight); }
	return fromChannels(a.kind, out);
}

function plus(a: MotionValue, b: MotionValue, label: string): MotionValue {
	return combine(a, b, 1, label);
}

function minus(a: MotionValue, b: MotionValue, label: string): MotionValue {
	return combine(a, b, -1, label);
}

export class MotionTarget {
	read: (() => MotionValue) | null;
	write: ((value: MotionValue) => void) | null;
	onClaim: (() => void) | null = null;
	private claims: TargetClaim[] = [];
	private base: MotionValue = numberValue(0);

	constructor(
		read: (() => MotionValue) | null = null,
		write: ((value: MotionValue) => void) | null = null,
	) {
		this.read = read;
		this.write = write;
	}

	get writers(): int32 {
		return this.claims.length;
	}

	shown(fallback: MotionValue, label: string): MotionValue {
		const read = this.read;
		if (read === null) { return fallback; }
		const value = read();
		if (value.kind !== fallback.kind) { fail(label + " reads a value of another kind from its target"); }
		return value;
	}

	blendFrom(previous: TargetClaim | null, fallback: MotionValue, label: string): MotionValue {
		if (this.claims.length === 0 || this.claims[0].composition !== Composition.Blend) {
			return fallback;
		}
		return previous === null ? this.base : plus(this.base, previous.delta, label);
	}

	claim(
		composition: Composition,
		start: MotionValue,
		end: MotionValue,
		label: string,
		previous: TargetClaim | null,
		onReplaced: () => void,
	): TargetClaim {
		if (composition === Composition.None) {
			fail(label + " composes with None and claims no target");
		}
		const claimed = this.onClaim;
		if (claimed !== null) { claimed(); }
		if (composition === Composition.Replace) {
			const claim = new TargetClaim(composition, end, numberValue(0), numberValue(0), onReplaced);
			this.replaceAll(claim, previous);
			return claim;
		}
		const from = this.blendFrom(previous, start, label);
		sameKind(start, end, label);
		const offset = minus(from, start, label);
		const delta = minus(from, end, label);
		const claim = new TargetClaim(composition, end, offset, delta, onReplaced);
		if (this.claims.length > 0 && this.claims[0].composition === Composition.Replace) {
			this.replaceAll(claim, previous);
		} else {
			this.drop(previous);
			this.claims.push(claim);
		}
		this.base = end;
		return claim;
	}

	blended(claim: TargetClaim, value: MotionValue, offsetLeft: float64, label: string): MotionValue {
		claim.delta = combine(minus(value, claim.end, label), claim.offset, offsetLeft, label);
		let out = this.base;
		for (const other of this.claims) { out = plus(out, other.delta, label); }
		return out;
	}

	release(claim: TargetClaim, hold: boolean): void {
		if (hold && claim.composition === Composition.Blend && this.claims.includes(claim)) {
			this.base = plus(this.base, claim.delta, "a released writer");
		}
		this.drop(claim);
	}

	private drop(claim: TargetClaim | null): void {
		if (claim === null) { return; }
		this.claims = this.claims.filter((other: TargetClaim): boolean => other !== claim);
	}

	private replaceAll(claim: TargetClaim, previous: TargetClaim | null): void {
		const older = this.claims.filter((other: TargetClaim): boolean => other !== previous);
		this.claims = [claim];
		for (const other of older) { other.onReplaced(); }
	}
}
