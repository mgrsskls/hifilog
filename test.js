async function getCategoryFiles(category, limit = 500) {
	const baseURL = "https://commons.wikimedia.org/w/api.php";
	let files = [];
	let cmcontinue = null;

	do {
		const params = new URLSearchParams({
			action: "query",
			list: "categorymembers",
			cmtitle: `Category:${category}`,
			cmtype: "file",
			cmlimit: limit.toString(),
			format: "json",
			origin: "*", // required for CORS if running in browser
		});
		if (cmcontinue) {
			params.append("cmcontinue", cmcontinue);
		}

		const response = await fetch(`${baseURL}?${params.toString()}`, {
			method: "GET",
			headers: new Headers({
				"Api-User-Agent":
					"HiFiLog/0.0 (https://www.hifilog.com; info@hifilog.com)",
			}),
		});
		const data = await response.json();

		if (data.query?.categorymembers) {
			files.push(...data.query.categorymembers);
		}

		cmcontinue = data.continue?.cmcontinue || null;
	} while (cmcontinue);

	return files;
}

async function getImageMetadata(title) {
	const baseURL = "https://commons.wikimedia.org/w/api.php";
	const params = new URLSearchParams({
		action: "query",
		titles: title,
		prop: "imageinfo",
		iiprop: "url|user|extmetadata|mime",
		format: "json",
		origin: "*", // required for CORS
	});

	const response = await fetch(`${baseURL}?${params.toString()}`);
	const data = await response.json();
	const pages = data.query?.pages;

	const page = Object.values(pages)[0];
	const info = page?.imageinfo?.[0];

	if (!info) return null;

	const meta = info.extmetadata || {};

	return {
		title: page.title,
		url: info.url,
		mime: info.mime,
		author: meta.Artist?.value || "",
		license: meta.LicenseShortName?.value || "",
		description: meta.ImageDescription?.value || "",
		usageTerms: meta.UsageTerms?.value || "",
	};
}

// Example usage
(async () => {
	const category = "Hi-Fi_amplifiers"; // change as needed
	const files = await getCategoryFiles(category);
	const results = [];

	for (const file of files) {
		const metadata = await getImageMetadata(file.title);
		if (metadata) {
			results.push(metadata);
			console.log(metadata); // or store to array, file, etc.
		}
	}

	// Optionally do something with `results`
})();
