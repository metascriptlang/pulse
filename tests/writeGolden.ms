import { ConformanceCase, goldenSource, observe } from "../src/conformance";
import { conformanceCases } from "../src/conformanceCases";
import { headlessAdapter } from "../src/headless";

const adapter = headlessAdapter();
console.log(
	goldenSource(
		conformanceCases().map((testCase: ConformanceCase) =>
			observe(adapter, testCase),
		),
	),
);
