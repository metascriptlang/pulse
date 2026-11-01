export enum ScrollAxis {
	Block,
	Inline,
	X,
	Y,
}

export enum ViewRange {
	Cover,
	Contain,
	Entry,
	Exit,
}

export interface ScrollSource {
	offset: (axis: ScrollAxis) => float64;
	max: (axis: ScrollAxis) => float64;
	viewport: (axis: ScrollAxis) => float64;
}

export interface ViewSubject {
	start: (axis: ScrollAxis) => float64;
	size: (axis: ScrollAxis) => float64;
}

export struct ViewInset {
	start: float64;
	end: float64;
}

export enum TimeSourceKind {
	Time,
	Scroll,
	View,
}

export struct TimeSource = match (kind: TimeSourceKind) {
	TimeSourceKind.Time => {},
	TimeSourceKind.Scroll => { scroller: ScrollSource, axis: ScrollAxis },
	TimeSourceKind.View => {
		scroller: ScrollSource,
		axis: ScrollAxis,
		subject: ViewSubject,
		range: ViewRange,
		inset: ViewInset,
	},
};

export function timeSource(): TimeSource {
	return { kind: TimeSourceKind.Time };
}

export function scrollSource(
	scroller: ScrollSource,
	axis: ScrollAxis = ScrollAxis.Block,
): TimeSource {
	return { kind: TimeSourceKind.Scroll, scroller, axis };
}

export function viewSource(
	scroller: ScrollSource,
	subject: ViewSubject,
	range: ViewRange = ViewRange.Cover,
	inset: ViewInset = { start: 0, end: 0 },
	axis: ScrollAxis = ScrollAxis.Block,
): TimeSource {
	return {
		kind: TimeSourceKind.View,
		scroller,
		subject,
		axis,
		range,
		inset,
	};
}

function clampedProgress(
	offset: float64,
	start: float64,
	end: float64,
): float64 | null {
	if (!(end > start)) { return null; }
	return Math.min(Math.max((offset - start) / (end - start), 0), 1);
}

function viewProgress(
	scroller: ScrollSource,
	subject: ViewSubject,
	axis: ScrollAxis,
	range: ViewRange,
	inset: ViewInset,
): float64 | null {
	const start = subject.start(axis);
	const end = start + subject.size(axis);
	const visibleStart = inset.start;
	const visibleEnd = scroller.viewport(axis) - inset.end;
	const coverStart = start - visibleEnd;
	const coverEnd = end - visibleStart;
	const startsAligned = start - visibleStart;
	const endsAligned = end - visibleEnd;
	const containStart = Math.min(startsAligned, endsAligned);
	const containEnd = Math.max(startsAligned, endsAligned);
	const offset = scroller.offset(axis);
	return match (range) {
		ViewRange.Cover => clampedProgress(offset, coverStart, coverEnd),
		ViewRange.Contain => clampedProgress(offset, containStart, containEnd),
		ViewRange.Entry => clampedProgress(offset, coverStart, containStart),
		ViewRange.Exit => clampedProgress(offset, containEnd, coverEnd),
	};
}

export function sourceProgress(source: TimeSource): float64 | null {
	if (source.kind === TimeSourceKind.Time) { return null; }
	const max = source.scroller.max(source.axis);
	if (!(max > 0)) { return null; }
	if (source.kind === TimeSourceKind.Scroll) {
		return clampedProgress(source.scroller.offset(source.axis), 0, max);
	}
	return viewProgress(
		source.scroller,
		source.subject,
		source.axis,
		source.range,
		source.inset,
	);
}
