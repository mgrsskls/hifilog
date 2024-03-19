import {
	Editor,
	rootCtx,
	defaultValueCtx,
	editorViewOptionsCtx,
} from "@milkdown/core";
import {
	commonmark,
	toggleEmphasisCommand,
	toggleStrongCommand,
	wrapInBlockquoteCommand,
	wrapInBulletListCommand,
	wrapInOrderedListCommand,
	insertHrCommand,
} from "@milkdown/preset-commonmark";
import { listener, listenerCtx } from "@milkdown/plugin-listener";
import { gfm, toggleStrikethroughCommand } from "@milkdown/preset-gfm";
import { callCommand } from "@milkdown/utils";

const textInput = document.querySelector('[name="note[text]"]');

document.querySelectorAll(".NoteEditor-option button").forEach((button) => {
	button.addEventListener("click", () => {
		switch (button.dataset.type) {
			case "bold":
				call(toggleStrongCommand.key);
				break;
			case "italic":
				call(toggleEmphasisCommand.key);
				break;
			case "strikethrough":
				call(toggleStrikethroughCommand.key);
				break;
			case "ul":
				call(wrapInBulletListCommand.key);
				break;
			case "ol":
				call(wrapInOrderedListCommand.key);
				break;
			case "quote":
				call(wrapInBlockquoteCommand.key);
				break;
			case "hr":
				call(insertHrCommand.key);
				break;
		}
	});
});

let editor;

Editor.make()
	.config((ctx) => {
		ctx.set(rootCtx, "#NoteEditor-text");
		ctx.set(defaultValueCtx, textInput.value);
		const listener = ctx.get(listenerCtx);

		ctx.update(editorViewOptionsCtx, (prev) => ({
			...prev,
			attributes: { spellcheck: "false" },
		}));

		listener.markdownUpdated((ctx, markdown, prevMarkdown) => {
			if (markdown !== prevMarkdown) {
				textInput.value = markdown;
			}
		});
	})
	.use(listener)
	.use(commonmark)
	.use(gfm)
	.create()
	.then((e) => {
		editor = e;

		document.querySelector("#NoteEditor-text .editor").focus();
	});

function call(command) {
	return editor.action(callCommand(command));
}
