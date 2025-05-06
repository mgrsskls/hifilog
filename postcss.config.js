export default {
	plugins: {
		"@tailwindcss/postcss": {},
		"postcss-import": {},
		"postcss-preset-env": {
			browsers: "> 0.3% and not dead",
		},
		cssnano: {},
	},
};
