export function exportCsv(notes: Note[]) {
  return notes.map((n) => [n.id, n.title].join(",")).join("\n");
}
