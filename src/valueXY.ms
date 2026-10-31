import { Clock } from "./clock";
import { animation, parallel } from "./composite";
import { MotionPolicy } from "./policy";
import { AnimatedValue, AnimationSpec } from "./value";

export struct PointXY {
	x: float64;
	y: float64;
}

export class AnimatedValueXY {
	x: AnimatedValue;
	y: AnimatedValue;

	constructor(value: PointXY, clock: Clock, policy: MotionPolicy) {
		this.x = new AnimatedValue(value.x, clock, policy);
		this.y = new AnimatedValue(value.y, clock, policy);
	}

	get(): PointXY {
		return { x: this.x.get(), y: this.y.get() };
	}

	set(value: PointXY): void {
		this.x.set(value.x);
		this.y.set(value.y);
	}

	animate(
		x: AnimationSpec,
		y: AnimationSpec,
		onEnd: ((finished: boolean) => void) | null = null,
	): void {
		parallel([animation(this.x, x), animation(this.y, y)], false)
			.start(onEnd);
	}

	cancel(): void {
		this.x.cancel();
		this.y.cancel();
	}

	subscribe(callback: (value: PointXY) => void): () => void {
		const joint = (changed: float64): void => { callback(this.get()); };
		const offX = this.x.subscribe(joint);
		const offY = this.y.subscribe(joint);
		return (): void => {
			offX();
			offY();
		};
	}

	dispose(): void {
		this.x.dispose();
		this.y.dispose();
	}
}
