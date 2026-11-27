// "Who handles this?" Names first, deterministic, no model (docs/crew.md §2, ADR 0009).

export type Route = { to: string[]; text: string; explicit: boolean };

/** `roster` maps lowercase name to id. Understands "scout, find x", "scout: find x", "hey scout find x", "@scout find x",
 *  and several @mentions ("@sprout @pip fix and open it"). No name: the coordinator. */
export function route(input: string, roster: Record<string, string>, coordinator: string): Route {
  const text = input.trim();
  const names = Object.keys(roster).map((n) => n.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")).join("|");
  if (!names) return { to: [coordinator], text, explicit: false };

  const mentions = [...text.matchAll(new RegExp(`(?:^|\\s)@(${names})\\b`, "gi"))].map((m) => roster[m[1]!.toLowerCase()]!);
  if (mentions.length) {
    const rest = text.replace(new RegExp(`(?:^|\\s)@(?:${names})\\b[,:]?`, "gi"), " ").replace(/\s+/g, " ").trim();
    return { to: [...new Set(mentions)], text: rest || text, explicit: true };
  }
  const lead = text.match(new RegExp(`^(?:hey |hi |ok |okay )?(${names})\\b\\s*[,:\\-]\\s*(.+)$`, "is"));
  if (lead) return { to: [roster[lead[1]!.toLowerCase()]!], text: lead[2]!.trim(), explicit: true };
  return { to: [coordinator], text, explicit: false };
}
