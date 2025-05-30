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
	"/privacy-policy",
	"/products",
	"/products/saba-9240-s-electronic",
	"/brands",
	"/brands/mains",
	"/search?query=concept",
];

const ls = spawn("node_modules/.bin/axe", [
	PATHS.map(
		(path) => `${process.env.A11Y_HOST || "http://127.0.0.1:3000"}${path}`,
	),
	"--exit",
	"--show-errors",
]);

ls.stdout.on("data", (data) => {
	console.log(`stdout: ${data}`);
});

ls.stderr.on("data", (data) => {
	console.error(`stderr: ${data}`);
});

ls.on("close", (code) => {
	console.log(`child process exited with code ${code}`);
});
