"use strict";
const form = document.querySelector("#casting-form");
const status = document.querySelector("#status");
const error = document.querySelector("#error");
const preview = document.querySelector("#pair-preview");
const reading = document.querySelector("#reading");
const raw = document.querySelector("#raw-context");
const buttons = [...form.querySelectorAll("button")];
let busy = false;
function element(tag, text, className) {
  const node = document.createElement(tag);
  if (text !== undefined) node.textContent = text;
  if (className) node.className = className;
  return node;
}
async function request(url, payload) {
  const response = await fetch(url, payload ? {method: "POST", headers: {"Content-Type": "application/json"}, body: JSON.stringify(payload)} : {});
  let data;
  try { data = await response.json(); } catch { throw new Error("The test server returned an unreadable response. Check that it is running."); }
  if (!response.ok) throw new Error(data.error || `Request failed (${response.status})`);
  return data;
}
function showPreview(context) {
  preview.replaceChildren();
  const pair = element("div", undefined, "hexagrams");
  for (const [title, hex] of [["Primary", context.contemplationPrimaryHexagram], ["Resulting", context.contemplationResultingHexagram]]) {
    const column = element("div", undefined, "hexagram");
    column.append(element("p", title), element("div", hex.textUnicodeSymbol, "symbol"), element("p", `${hex.textHexagramNumber} · ${hex.textChineseName} · ${hex.textPinyin}`));
    pair.append(column);
  }
  preview.append(pair);
  const lines = context.contemplationChangingLines;
  preview.append(element("p", lines.length ? lines.map(line => `Line ${line.changingLineNumber}: changing ${line.changingLineValue === 9 ? "Yang" : "Yin"} (${line.changingLineValue})`).join(" · ") : "No changing lines: the two hexagrams are identical.", "line-list"));
  preview.hidden = false;
  document.querySelector("#context-json").textContent = JSON.stringify(context, null, 2);
  raw.hidden = false;
}
function showReading(result) {
  reading.replaceChildren(element("p", "AI-assisted contemplation", "eyebrow"));
  const value = result.modelContemplation;
  for (const [title, content] of [["Context", value.context], ["Primary hexagram", value.primary_hexagram], ["Changing lines", value.changing_lines], ["Transformation", value.transformation], ["Possible readings", value.possible_readings], ["Questions for contemplation", value.questions_for_contemplation]]) {
    reading.append(element("h3", title));
    if (Array.isArray(content)) {
      if (!content.length) reading.append(element("p", "No changing-line reflections."));
      else { const list = element("ul"); content.forEach(item => list.append(element("li", item))); reading.append(list); }
    } else reading.append(element("p", content));
  }
  reading.append(element("p", `${result.modelName} · ${result.modelInputTokens} input tokens · ${result.modelOutputTokens} output tokens · ${(result.modelLatencyMilliseconds / 1000).toFixed(1)}s`, "usage"));
  reading.hidden = false;
}
form.addEventListener("input", () => {
  if (busy) return;
  preview.hidden = reading.hidden = raw.hidden = error.hidden = true;
  status.textContent = "Your inputs have changed. Preview or interpret this pair again.";
});
form.addEventListener("submit", async event => {
  event.preventDefault();
  if (busy) return;
  const live = event.submitter?.id === "interpret";
  const payload = {primary: Number(form.elements.primary.value), resulting: Number(form.elements.resulting.value), question: form.elements.question.value.trim(), leelaState: Number(form.elements.leelaState.value)};
  if (!payload.question) { error.textContent = "Please enter a question."; error.hidden = false; return; }
  busy = true;
  [...form.elements].forEach(control => control.disabled = true);
  document.querySelector(".result-card").setAttribute("aria-busy", "true");
  error.hidden = reading.hidden = preview.hidden = raw.hidden = true;
  status.textContent = "Preparing your casting…";
  try {
    showPreview(await request("/api/preview", payload));
    if (live) {
      status.textContent = "Reflecting with OpenAI. This may take a little time…";
      showReading(await request("/api/interpret", payload));
      status.textContent = "Your interpretation is ready.";
    } else status.textContent = "Preview ready. No AI request was made.";
  } catch (err) {
    status.textContent = "The request could not be completed.";
    error.textContent = err.message;
    error.hidden = false;
  } finally {
    busy = false;
    [...form.elements].forEach(control => control.disabled = false);
    document.querySelector(".result-card").setAttribute("aria-busy", "false");
  }
});
(async () => {
  try {
    const states = await request("/api/states");
    const select = form.elements.leelaState;
    select.replaceChildren(...states.map(state => {
      const option = element("option", `${state.stateId} · ${state.stateName}`);
      option.value = state.stateId;
      return option;
    }));
    if (!states.length) throw new Error("No Leela states are available.");
    buttons.forEach(button => button.disabled = false);
  } catch (err) { error.textContent = err.message; error.hidden = false; }
})();
