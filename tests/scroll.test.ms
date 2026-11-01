import {
	ScrollAxis,
	ScrollSource,
	ViewRange,
	ViewSubject,
	scrollSource,
	sourceProgress,
	timeSource,
	viewSource,
} from "../src/scroll";

class Scroller {
	at: float64 = 0;
	range: float64 = 1000;
	port: float64 = 100;
	subjectStart: float64 = 500;
	subjectSize: float64 = 50;
	axes: ScrollAxis[] = [];

	get source(): ScrollSource {
		return {
			offset: (axis: ScrollAxis): float64 => {
				this.axes.push(axis);
				return this.at;
			},
			max: (axis: ScrollAxis): float64 => this.range,
			viewport: (axis: ScrollAxis): float64 => this.port,
		};
	}

	get subject(): ViewSubject {
		return {
			start: (axis: ScrollAxis): float64 => this.subjectStart,
			size: (axis: ScrollAxis): float64 => this.subjectSize,
		};
	}
}

function near(value: float64 | null, want: float64): boolean {
	return value !== null && Math.abs(value - want) <= 1e-9;
}

function progressAt(
	scroller: Scroller,
	range: ViewRange,
	offset: float64,
): float64 | null {
	scroller.at = offset;
	return sourceProgress(
		viewSource(scroller.source, scroller.subject, range),
	);
}

test "a time source has no scroll progress" {
	assert sourceProgress(timeSource()) === null;
}

test "scroll progress is the offset over the scroll range, read on its axis" {
	const scroller = new Scroller();
	scroller.at = 250;
	assert near(sourceProgress(scrollSource(scroller.source)), 0.25);
	assert scroller.axes[0] === ScrollAxis.Block;
	sourceProgress(scrollSource(scroller.source, ScrollAxis.X));
	assert scroller.axes[1] === ScrollAxis.X;
	scroller.at = 1200;
	assert near(sourceProgress(scrollSource(scroller.source)), 1);
}

test "a scroller with no scroll range is an inactive timeline" {
	const scroller = new Scroller();
	scroller.range = 0;
	assert sourceProgress(scrollSource(scroller.source)) === null;
	assert progressAt(scroller, ViewRange.Cover, 450) === null;
}

test "cover runs from the subject entering the end edge to leaving the start" {
	const scroller = new Scroller();
	assert near(progressAt(scroller, ViewRange.Cover, 300), 0);
	assert near(progressAt(scroller, ViewRange.Cover, 400), 0);
	assert near(progressAt(scroller, ViewRange.Cover, 475), 0.5);
	assert near(progressAt(scroller, ViewRange.Cover, 550), 1);
}

test "contain, entry and exit split cover where the subject is wholly visible" {
	const scroller = new Scroller();
	assert near(progressAt(scroller, ViewRange.Contain, 450), 0);
	assert near(progressAt(scroller, ViewRange.Contain, 475), 0.5);
	assert near(progressAt(scroller, ViewRange.Contain, 500), 1);
	assert near(progressAt(scroller, ViewRange.Entry, 425), 0.5);
	assert near(progressAt(scroller, ViewRange.Exit, 525), 0.5);
}

test "contain of a subject larger than the viewport is where it covers it" {
	const scroller = new Scroller();
	scroller.subjectSize = 300;
	assert near(progressAt(scroller, ViewRange.Contain, 500), 0);
	assert near(progressAt(scroller, ViewRange.Contain, 700), 1);
	assert near(progressAt(scroller, ViewRange.Entry, 450), 0.5);
}

test "insets shrink the visibility range from each edge" {
	const scroller = new Scroller();
	scroller.at = 445;
	const entry = viewSource(
		scroller.source,
		scroller.subject,
		ViewRange.Entry,
		{ start: 10, end: 20 },
	);
	assert near(sourceProgress(entry), 0.5);
}

test "a range of zero length is an inactive timeline" {
	const scroller = new Scroller();
	scroller.subjectSize = 100;
	assert progressAt(scroller, ViewRange.Contain, 500) === null;
}
