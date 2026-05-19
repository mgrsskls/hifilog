import { spawn } from "node:child_process";
const PATHS = [
	"/",
	"/user/sign_up",
	"/user/sign_in",
	"/user/password/new",
	"/user/confirmation/new",
	"/users",
	"/about",
	"/changelog",
	"/imprint",
	"/products",
	"/products/saba-9240-s-electronic",
	"/brands",
	"/brands/mains",
	"/search?query=concept",
];

const urls = PATHS.map(
	(path) =>
		`${new URL(path, process.env.A11Y_HOST || "http://127.0.0.1:3000").toString()}`,
);
const spawnArgs = [...urls, "--exit", "--show-errors"];

// #region agent log
fetch("http://127.0.0.1:7459/ingest/d73d3430-5b16-40ef-b2cf-6e39c5aaefc3", {
	method: "POST",
	headers: {
		"Content-Type": "application/json",
		"X-Debug-Session-Id": "f791c1",
	},
	body: JSON.stringify({
		sessionId: "f791c1",
		runId: "pre-fix",
		hypothesisId: "A",
		location: "run-axe.js:spawnArgs",
		message: "spawn args shape before spawn",
		data: {
			spawnArgsLength: spawnArgs.length,
			firstArgIsArray: Array.isArray(spawnArgs[0]),
			firstArgLength: Array.isArray(spawnArgs[0]) ? spawnArgs[0].length : null,
			firstArgType: typeof spawnArgs[0],
			firstArgStringified: String(spawnArgs[0]),
			firstArgSample: Array.isArray(spawnArgs[0])
				? spawnArgs[0].slice(0, 2)
				: spawnArgs[0],
			urlCount: urls.length,
		},
		timestamp: Date.now(),
	}),
}).catch(() => {});
// #endregion

const ls = spawn("node_modules/.bin/axe", spawnArgs);

// #region agent log
ls.on("spawn", () => {
	fetch("http://127.0.0.1:7459/ingest/d73d3430-5b16-40ef-b2cf-6e39c5aaefc3", {
		method: "POST",
		headers: {
			"Content-Type": "application/json",
			"X-Debug-Session-Id": "f791c1",
		},
		body: JSON.stringify({
			sessionId: "f791c1",
			runId: "pre-fix",
			hypothesisId: "B",
			location: "run-axe.js:spawn",
			message: "child process spawned",
			data: {
				pid: ls.pid,
				spawnfile: ls.spawnfile,
				spawnargsLength: ls.spawnargs?.length,
				spawnargsFirstType: typeof ls.spawnargs?.[0],
				spawnargsFirstIsArray: Array.isArray(ls.spawnargs?.[0]),
				spawnargsFirst: ls.spawnargs?.[0],
				spawnargsSecond: ls.spawnargs?.[1],
				spawnargsThird: ls.spawnargs?.[2],
			},
			timestamp: Date.now(),
		}),
	}).catch(() => {});
});
// #endregion

ls.stdout.on("data", (data) => {
	console.log(`stdout: ${data}`);
});

ls.stderr.on("data", (data) => {
	console.error(`stderr: ${data}`);
});

ls.on("close", (code) => {
	console.log(`child process exited with code ${code}`);
});
