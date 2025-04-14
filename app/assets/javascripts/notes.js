import {
	Editor,
	rootCtx,
	defaultValueCtx,
	editorViewOptionsCtx,
} from "@milkdown/kit/core";
import {
	commonmark,
	toggleEmphasisCommand,
	toggleStrongCommand,
	wrapInBlockquoteCommand,
	wrapInBulletListCommand,
	wrapInOrderedListCommand,
} from "@milkdown/kit/preset/commonmark";
import { listener, listenerCtx } from "@milkdown/kit/plugin/listener";
import { callCommand } from "@milkdown/kit/utils";

const textInput = document.querySelector("[data-note-textarea]");

document.querySelectorAll(".NoteEditor-option button").forEach((button) => {
	button.addEventListener("click", () => {
		switch (button.dataset.type) {
			case "bold":
				call(toggleStrongCommand.key);
				break;
			case "italic":
				call(toggleEmphasisCommand.key);
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
	.create()
	.then((e) => {
		editor = e;

		if (textInput?.dataset.noteTextarea === "focus") {
			document.querySelector("#NoteEditor-text .editor").focus();
		}
	});

function call(command) {
	return editor.action(callCommand(command));
}
