import type { EngineCastingState } from "./types";

async function readError(response: Response): Promise<string> {
  try {
    const body = (await response.json()) as { error?: string };
    if (body.error) return body.error;
  } catch {
    // The engine may return an empty body on failure.
  }
  return `Request failed (${response.status})`;
}

export async function fetchInitialCasting(): Promise<EngineCastingState> {
  const response = await fetch("/casting/initial");
  if (!response.ok) throw new Error(await readError(response));
  return response.json() as Promise<EngineCastingState>;
}

export async function fetchNextCasting(state: EngineCastingState): Promise<EngineCastingState> {
  const response = await fetch("/casting/next", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(state),
  });
  if (!response.ok) throw new Error(await readError(response));
  return response.json() as Promise<EngineCastingState>;
}
