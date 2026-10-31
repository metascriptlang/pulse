// Ported from RN Libraries/Animated/__tests__/Easing-test.js and bezier-test.js.

import { Easing, EasingFunction, bezier, bezierAt } from "../src/easing";

function near(a: number, b: number, digits: int32): boolean {
	return Math.abs(a - b) < Math.pow(10, -(digits as number)) / 2;
}

function sample(easing: EasingFunction): number[] {
	const out: number[] = [];
	const ticks: int32 = 18;
	for (let i: int32 = 0; i <= ticks; i += 1) { out.push(easing((i as number) / (ticks as number))); }
	return out;
}

function matches(easing: EasingFunction, expected: number[]): boolean {
	const got = sample(easing);
	for (let i: int32 = 0; i < expected.length; i += 1) {
		if (!near(got[i], expected[i], 2)) { return false; }
	}
	return true;
}

test "linear and in/out of linear are the identity" {
	assert Easing.linear(0) === 0 && Easing.linear(0.5) === 0.5 && Easing.linear(1) === 1;
	const i = Easing.in(Easing.linear);
	assert i(0.8) === 0.8;
	const o = Easing.out(Easing.linear);
	assert o(0) === 0 && o(0.5) === 0.5 && o(0.6) === 0.6 && o(1) === 1, "out linear " + o(0.6).toString();
}

test "in quad is t squared, out quad is -t(t - 2), inOut quad matches its closed form" {
	const i = Easing.in(Easing.quad);
	for (let k: int32 = -5; k < 15; k += 1) {
		const t = (k as number) / 10;
		assert i(t) === t * t;
	}
	const o = Easing.out(Easing.quad);
	assert o(1) === 1;
	const io = Easing.inOut(Easing.quad);
	for (let k: int32 = -5; k < 15; k += 1) {
		const t2 = (k as number) / 10 * 2;
		const expected = t2 < 1 ? 0.5 * t2 * t2 : -((t2 - 1) * (t2 - 3) - 1) / 2;
		assert near(io((k as number) / 10), expected, 4), "inOut quad at " + k.toString();
	}
}

test "elastic keeps its boundary conditions" {
	for (let k: int32 = 0; k < 14; k += 1) {
		const e = Easing.elastic((k as number) * 0.3);
		assert e(0) === 0 && e(1) === 1, "elastic " + k.toString();
	}
	const plain = Easing.elastic();
	assert plain(0) === 0 && plain(1) === 1;
}

test "sampled curves match RN's table" {
	assert matches(Easing.in(Easing.quad), [0, 0.0030864197530864196, 0.012345679012345678, 0.027777777777777776, 0.04938271604938271, 0.0771604938271605, 0.1111111111111111, 0.15123456790123457, 0.19753086419753085, 0.25, 0.308641975308642, 0.37345679012345684, 0.4444444444444444, 0.5216049382716049, 0.6049382716049383, 0.6944444444444445, 0.7901234567901234, 0.8919753086419753, 1]), "in quad";
	assert matches(Easing.inOut(Easing.cubic), [0, 0.0006858710562414266, 0.0054869684499314125, 0.018518518518518517, 0.0438957475994513, 0.08573388203017834, 0.14814814814814814, 0.23525377229080935, 0.3511659807956104, 0.5, 0.6488340192043895, 0.7647462277091908, 0.8518518518518519, 0.9142661179698217, 0.9561042524005487, 0.9814814814814815, 0.9945130315500685, 0.9993141289437586, 1]), "inOut cubic";
	assert matches(Easing.out(Easing.sin), [0, 0.08715574274765817, 0.17364817766693033, 0.25881904510252074, 0.3420201433256687, 0.42261826174069944, 0.49999999999999994, 0.573576436351046, 0.6427876096865393, 0.7071067811865475, 0.766044443118978, 0.8191520442889918, 0.8660254037844386, 0.9063077870366499, 0.9396926207859083, 0.9659258262890683, 0.984807753012208, 0.9961946980917455, 1]), "out sin";
	assert matches(Easing.inOut(Easing.exp), [0, 0.0010547458387620175, 0.002278377030422103, 0.004921566601151844, 0.010631171876362321, 0.022964601441806228, 0.049606282874006216, 0.1071554978566341, 0.23146867807182253, 0.5, 0.7685313219281775, 0.892844502143366, 0.9503937171259937, 0.9770353985581938, 0.9893688281236377, 0.9950784333988482, 0.9977216229695779, 0.998945254161238, 1]), "inOut exp";
	assert matches(Easing.in(Easing.circle), [0, 0.0015444024660317135, 0.006192010000093506, 0.013986702816730645, 0.025003956956430873, 0.03935464078941209, 0.057190958417936644, 0.07871533601238889, 0.10419358352238339, 0.1339745962155614, 0.1685205807169019, 0.20845517506805522, 0.2546440075000701, 0.3083389112228482, 0.37146063894529113, 0.4472292016074334, 0.5418771527091488, 0.6713289009389102, 1]), "in circle";
	assert matches(Easing.out(Easing.back()), [2.220446049250313e-16, 0.24189928326474652, 0.44705229080932807, 0.6182384259259258, 0.7582370919067215, 0.8698276920438959, 0.9557896296296297, 1.0189023079561044, 1.0619451303155008, 1.0876975, 1.0989388203017834, 1.0984484945130315, 1.089005925925926, 1.0733905178326475, 1.0543816735253773, 1.0347587962962963, 1.0173012894375857, 1.0047885562414267, 1]), "out back";
}

test "bounce is continuous at its seams and lands on 1" {
	assert Easing.bounce(0) === 0;
	assert near(Easing.bounce(1), 1, 6);
	assert near(Easing.bounce(1 / 2.75 - 0.000001), Easing.bounce(1 / 2.75), 4);
}

test "bezier: linear, extremes, symmetry, and range check" {
	const lin = bezier(0, 0, 1, 1);
	assert lin(0.3) === 0.3 && lin(0.7) === 0.7;
	const ease = bezier(0.25, 0.1, 0.25, 1);
	assert ease(0) === 0 && ease(1) === 1;
	const sym = bezier(0.5, 0.2, 0.5, 0.8);
	assert near(sym(0.5), 0.5, 2), "centre " + sym(0.5).toString();
	for (let k: int32 = 1; k < 10; k += 1) {
		const x = (k as number) / 10;
		assert near(sym(x) + sym(1 - x), 1, 2), "symmetry at " + k.toString();
	}
	let threw = false;
	try { bezier(0.5, 0.5, -5, 0.5); } catch (e) { threw = true; }
	assert threw, "x out of range throws";
	assert near(Easing.ease(0.5), bezier(0.42, 0, 1, 1)(0.5), 6);
}

test "bezierAt gives the table-built curve's values bit for bit, with no curve built" {
	const handles: number[][] = [
		[0.25, 0.1, 0.25, 1],
		[0.42, 0, 1, 1],
		[0.68, -0.55, 0.27, 1.55],
		[0.9, 0, 0.1, 1],
		[0.95, 0.05, 0.99, 0.1],
	];
	const xs: number[] = [0.05, 0.13, 0.31, 0.5, 0.77, 0.96, 0.999];
	const recorded: number[][] = [
		[
			0.03295154130590043, 0.14612555730742216, 0.5327325175550437,
			0.802403387584857, 0.9670385062684344, 0.9991252593157979,
			0.999999466341604,
		],
		[
			0.004474615295891681, 0.027975713147489492, 0.13734955234760832,
			0.31535681257253934, 0.6494450313709403, 0.933834037931688,
			0.9982843517685093,
		],
		[
			-0.037039730707276154, -0.07928541147347344, -0.039502650125060976,
			0.5965962920655999, 1.0919680778580254, 1.0282597959592972,
			1.0007523030575298,
		],
		[
			0.0010924851540558983, 0.008228660752439134, 0.06541853612167686,
			0.5, 0.9696297503028044, 0.9993094406676305, 0.9999995880025313,
		],
		[
			0.0026819144346507976, 0.0072575193756056, 0.019956553657745135,
			0.041403559541058246, 0.11995271639631012, 0.4003331961676815,
			0.9215934969866338,
		],
	];
	for (let i: int32 = 0; i < handles.length; i += 1) {
		const h = handles[i];
		const curve = bezier(h[0], h[1], h[2], h[3]);
		for (let k: int32 = 0; k < xs.length; k += 1) {
			const got = bezierAt(h[0], h[1], h[2], h[3], xs[k]);
			assert got === recorded[i][k],
				"handles " + i.toString() + " x " + xs[k].toString() + " got " +
					got.toString();
			assert curve(xs[k]) === got;
		}
	}
}

test "bezierAt returns x itself for linear handles and keeps the range check" {
	for (let k: int32 = 0; k <= 20; k += 1) {
		const x = (k as number) / 20;
		assert bezierAt(1.0 / 3.0, 1.0 / 3.0, 2.0 / 3.0, 2.0 / 3.0, x) === x;
	}
	assert bezierAt(0.25, 0.1, 0.25, 1, 0) === 0;
	assert bezierAt(0.25, 0.1, 0.25, 1, 1) === 1;
	let threw = false;
	try { bezierAt(0.5, 0.5, -5, 0.5, 0.5); } catch (e) { threw = true; }
	assert threw, "x out of range throws";
}
