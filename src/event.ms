import { AnimatedValue } from "./value";

export struct EventPayload {
	x: float64;
	y: float64;
	width: float64;
	height: float64;
	contentWidth: float64;
	contentHeight: float64;
}

export interface EventMapping {
	x?: AnimatedValue;
	y?: AnimatedValue;
	width?: AnimatedValue;
	height?: AnimatedValue;
	contentWidth?: AnimatedValue;
	contentHeight?: AnimatedValue;
}

function drive(value: AnimatedValue | null, to: float64): void {
	if (value !== null) { value.set(to); }
}

export function event(
	mapping: EventMapping,
	listener: ((payload: EventPayload) => void) | null = null,
): (payload: EventPayload) => void {
	return (payload: EventPayload): void => {
		drive(mapping.x, payload.x);
		drive(mapping.y, payload.y);
		drive(mapping.width, payload.width);
		drive(mapping.height, payload.height);
		drive(mapping.contentWidth, payload.contentWidth);
		drive(mapping.contentHeight, payload.contentHeight);
		if (listener !== null) { listener(payload); }
	};
}
