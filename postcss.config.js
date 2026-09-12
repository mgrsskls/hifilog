export default (api) => {
	const isActiveAdmin = api.file.basename == "active_admin.css";

	return {
		plugins: {
			"@tailwindcss/postcss": {},
			"postcss-import": {},
			"postcss-preset-env": {
				browsers: isActiveAdmin
					? "baseline widely available"
					: ">0.2%, defaults",
			},
			cssnano: {},
		},
	};
};
