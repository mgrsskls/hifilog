import * as Sentry from "@sentry/browser";

Sentry.init({
	dsn: "https://d7ece5fba6feddea5518995e105b6c53@o4507924018561024.ingest.de.sentry.io/4507924105396304",
	integrations: [
		Sentry.browserTracingIntegration({
			instrumentNavigation: true,
			instrumentPageLoad: true,
			enableInp: true,
		}),
	],
	tracesSampleRate: 1.0,
});
