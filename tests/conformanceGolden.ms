import { ConformanceTrace } from "../src/conformance";

export const CONFORMANCE_GOLDEN: ConformanceTrace[] = [
	{
		name: "time.duration",
		error: "",
		checkpoints: [
			{ at: 0, values: [0], events: [] },
			{ at: 250, values: [25], events: ["p:start"] },
			{ at: 500, values: [50], events: [] },
			{ at: 1000, values: [100], events: ["p:complete"] },
			{ at: 1200, values: [100], events: [] },
		],
	},
	{
		name: "time.delay",
		error: "",
		checkpoints: [
			{ at: 0, values: [50], events: [] },
			{ at: 100, values: [50], events: [] },
			{ at: 200, values: [0], events: [] },
			{ at: 450, values: [25], events: ["p:start"] },
			{ at: 1200, values: [100], events: ["p:complete"] },
			{ at: 1400, values: [100], events: [] },
		],
	},
	{
		name: "time.repeat",
		error: "",
		checkpoints: [
			{ at: 500, values: [50], events: ["p:start"] },
			{ at: 1050, values: [100], events: [] },
			{ at: 1600, values: [50], events: ["p:repeat"] },
			{ at: 2150, values: [100], events: [] },
			{ at: 2700, values: [50], events: ["p:repeat"] },
			{ at: 3200, values: [100], events: ["p:complete"] },
			{ at: 3400, values: [100], events: [] },
		],
	},
	{
		name: "time.yoyo",
		error: "",
		checkpoints: [
			{ at: 500, values: [50], events: ["p:start"] },
			{ at: 1000, values: [100], events: [] },
			{ at: 1500, values: [50], events: ["p:repeat"] },
			{ at: 1750, values: [25], events: [] },
			{ at: 2000, values: [0], events: ["p:complete"] },
			{ at: 2200, values: [0], events: [] },
		],
	},
	{
		name: "time.rate",
		error: "",
		checkpoints: [
			{ at: 100, values: [20], events: ["p:start"] },
			{ at: 200, values: [40], events: [] },
			{ at: 400, values: [50], events: [] },
			{ at: 1400, values: [100], events: ["p:complete"] },
			{ at: 1600, values: [100], events: [] },
		],
	},
	{
		name: "seek.silent",
		error: "",
		checkpoints: [
			{ at: 0, values: [0], events: [] },
			{ at: 100, values: [30], events: [] },
			{ at: 200, values: [100], events: [] },
			{ at: 300, values: [0], events: [] },
		],
	},
	{
		name: "seek.events",
		error: "",
		checkpoints: [
			{ at: 100, values: [50], events: ["p:start"] },
			{ at: 200, values: [100], events: ["p:complete"] },
			{ at: 300, values: [0], events: ["p:reverseComplete"] },
		],
	},
	{
		name: "cancel.holds",
		error: "",
		checkpoints: [
			{ at: 400, values: [40], events: ["p:start"] },
			{ at: 800, values: [40], events: [] },
			{ at: 1200, values: [70], events: [] },
			{ at: 1600, values: [100], events: ["p:complete"] },
		],
	},
	{
		name: "finish.forward",
		error: "",
		checkpoints: [
			{ at: 300, values: [100], events: ["p:start", "p:complete"] },
			{ at: 600, values: [100], events: [] },
		],
	},
	{
		name: "finish.reversed",
		error: "",
		checkpoints: [
			{ at: 600, values: [60], events: ["p:start"] },
			{ at: 700, values: [0], events: ["p:reverseComplete"] },
			{ at: 900, values: [0], events: [] },
		],
	},
	{
		name: "reverse",
		error: "",
		checkpoints: [
			{ at: 600, values: [60], events: ["p:start"] },
			{ at: 800, values: [40], events: [] },
			{ at: 1200, values: [0], events: ["p:reverseComplete"] },
			{ at: 1400, values: [0], events: [] },
		],
	},
	{
		name: "retarget.timing",
		error: "",
		checkpoints: [
			{ at: 250, values: [25], events: [] },
			{ at: 500, values: [50], events: ["a:interrupted"] },
			{ at: 750, values: [25], events: [] },
			{ at: 1000, values: [0], events: ["a:finished"] },
			{ at: 1200, values: [0], events: [] },
		],
	},
	{
		name: "retarget.spring",
		error: "",
		checkpoints: [
			{ at: 100, values: [44.21746], events: [] },
			{ at: 196, values: [79.170903], events: [] },
			{ at: 200, values: [80.085173], events: ["a:interrupted"] },
			{ at: 204, values: [79.946658], events: [] },
			{ at: 300, values: [44.673543], events: [] },
			{ at: 600, values: [1.389579], events: [] },
			{ at: 1000, values: [0.006397], events: [] },
			{ at: 3000, values: [0], events: ["a:finished"] },
		],
	},
	{
		name: "contention.replace",
		error: "",
		checkpoints: [
			{ at: 250, values: [25], events: [] },
			{ at: 500, values: [50], events: ["a:interrupted"] },
			{ at: 750, values: [25], events: [] },
			{ at: 1000, values: [0], events: ["b:finished"] },
			{ at: 1200, values: [0], events: [] },
		],
	},
	{
		name: "contention.blend",
		error: "",
		checkpoints: [
			{ at: 250, values: [25], events: [] },
			{ at: 500, values: [50], events: [] },
			{ at: 750, values: [125], events: [] },
			{ at: 1000, values: [200], events: ["a:finished", "b:finished"] },
			{ at: 1200, values: [200], events: [] },
		],
	},
	{
		name: "contention.none",
		error: "",
		checkpoints: [
			{ at: 250, values: [25, 0], events: [] },
			{ at: 750, values: [75, 25], events: [] },
			{ at: 1000, values: [100, 50], events: ["a:finished", "b:finished"] },
		],
	},
	{
		name: "contention.players",
		error: "",
		checkpoints: [
			{ at: 250, values: [25], events: ["p:start"] },
			{ at: 500, values: [50], events: [] },
			{ at: 750, values: [75], events: ["q:start"] },
			{ at: 1000, values: [50], events: [] },
			{ at: 1500, values: [0], events: ["q:complete"] },
			{ at: 1700, values: [0], events: [] },
		],
	},
	{
		name: "lifecycle.dispose",
		error: "",
		checkpoints: [
			{ at: 300, values: [30, 30], events: ["p:start", "a:interrupted"] },
			{ at: 600, values: [30, 30], events: [] },
			{ at: 1200, values: [30, 30], events: [] },
		],
	},
	{
		name: "lifecycle.revert",
		error: "",
		checkpoints: [
			{ at: 300, values: [7], events: ["p:start"] },
			{ at: 600, values: [7], events: [] },
		],
	},
	{
		name: "reducedMotion",
		error: "",
		checkpoints: [
			{ at: 0, values: [100, 0, 100], events: ["a:finished", "c:finished"] },
			{ at: 500, values: [100, 50, 100], events: [] },
			{ at: 1000, values: [100, 100, 100], events: ["b:finished"] },
		],
	},
	{
		name: "spring",
		error: "",
		checkpoints: [
			{ at: 50, values: [17.335853, 67.161532, 6.970521], events: [] },
			{ at: 100, values: [44.21746, 114.896604, 17.773658], events: [] },
			{ at: 200, values: [80.085173, 98.358814, 36.963998], events: [] },
			{ at: 400, values: [98.264873, 100.053879, 63.112309], events: [] },
			{ at: 800, values: [99.992013, 100, 87.369921], events: ["b:finished"] },
			{ at: 1600, values: [100, 100, 98.51934], events: ["a:finished"] },
			{ at: 3000, values: [100, 100, 99.965223], events: [] },
		],
	},
	{
		name: "decay",
		error: "",
		checkpoints: [
			{ at: 100, values: [99.006633, 99.006633], events: [] },
			{ at: 300, values: [291.177332, 200], events: ["b:finished"] },
			{ at: 600, values: [565.397816, 200], events: [] },
			{ at: 1200, values: [1066.860695, 200], events: [] },
			{ at: 3000, values: [2255.94182, 200], events: [] },
		],
	},
	{
		name: "sequence",
		error: "",
		checkpoints: [
			{ at: 150, values: [50], events: [] },
			{ at: 300, values: [100], events: [] },
			{ at: 400, values: [100], events: [] },
			{ at: 500, values: [100], events: [] },
			{ at: 650, values: [50], events: [] },
			{ at: 800, values: [0], events: [] },
			{ at: 850, values: [25], events: [] },
			{ at: 900, values: [50], events: [] },
			{ at: 1000, values: [0], events: ["a:finished"] },
		],
	},
	{
		name: "derived",
		error: "",
		checkpoints: [
			{ at: 0, values: [0, 0, 0], events: [] },
			{ at: 250, values: [0.25, 50, 25], events: [] },
			{ at: 500, values: [0.5, 100, 30], events: ["b:finished"] },
			{ at: 1000, values: [1, 150, 30], events: ["a:finished"] },
			{ at: 1200, values: [0.8, 130, 10], events: ["a:finished"] },
		],
	},
	{
		name: "composite.parallel",
		error: "",
		checkpoints: [
			{ at: 250, values: [50, 12.5], events: [] },
			{ at: 500, values: [100, 25], events: [] },
			{ at: 1000, values: [100, 50], events: ["both:finished"] },
		],
	},
	{
		name: "composite.parallelStop",
		error: "",
		checkpoints: [
			{ at: 250, values: [50, 12.5], events: ["both:interrupted"] },
			{ at: 500, values: [50, 12.5], events: [] },
		],
	},
	{
		name: "composite.staggered",
		error: "",
		checkpoints: [
			{ at: 100, values: [33.333333, 0, 0], events: [] },
			{ at: 200, values: [66.666667, 33.333333, 0], events: [] },
			{ at: 300, values: [100, 66.666667, 33.333333], events: [] },
			{ at: 400, values: [100, 100, 66.666667], events: [] },
			{ at: 500, values: [100, 100, 100], events: ["wave:finished"] },
			{ at: 600, values: [100, 100, 100], events: [] },
		],
	},
	{
		name: "composite.loop",
		error: "",
		checkpoints: [
			{ at: 100, values: [50], events: [] },
			{ at: 200, values: [0], events: [] },
			{ at: 300, values: [50], events: [] },
			{ at: 500, values: [50], events: [] },
			{ at: 600, values: [100], events: ["cycle:finished"] },
			{ at: 700, values: [100], events: [] },
		],
	},
	{
		name: "valueXY",
		error: "",
		checkpoints: [
			{ at: 200, values: [50, 40.042586], events: [] },
			{ at: 400, values: [100, 49.132437], events: [] },
			{ at: 1000, values: [100, 50], events: ["xy:finished"] },
			{ at: 3000, values: [100, 50], events: [] },
		],
	},
	{
		name: "event",
		error: "",
		checkpoints: [
			{ at: 300, values: [10, 20], events: ["x:interrupted", "listener"] },
			{ at: 600, values: [10, 20], events: [] },
		],
	},
];
