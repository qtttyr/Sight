"use client";

/**
 * A deterministic, client-side echo of the rules engine.
 * The patterns come from the real implied RLFS RuleLibrary and the eval corpus
 * (SightCoreTests/RegressionTests). On-device the same decisions take ~5 ms.
 */

export type Category =
  | "screenshots"
  | "documents"
  | "invoices"
  | "audio"
  | "archives"
  | null;

export type PlayFile = {
  id: number;
  name: string;
  /** extension shown as a micro tag */
  tag: string;
  category: Category;
  confidence: number; // 0..1, 0 = no category close enough
  /** generated icon or a fallback glyph */
  kind: "photo" | "doc" | "audio" | "archive" | "paper";
};

export const FOLDERS: {
  id: Exclude<Category, null>;
  name: string;
  rule: string;
  iconName: "photo" | "doc" | "audio" | "archive";
}[] = [
  { id: "screenshots", name: "Screenshots", rule: "screenshots, iOS captures", iconName: "photo" },
  { id: "documents", name: "Documents", rule: "papers, drafts, agreements", iconName: "doc" },
  { id: "invoices", name: "Invoices", rule: "invoices & receipts", iconName: "doc" },
  { id: "audio", name: "Audio", rule: "recordings, podcasts, stems", iconName: "audio" },
  { id: "archives", name: "Archives", rule: "zips and bundles", iconName: "archive" },
];

export const CORPUS: PlayFile[] = [
  { id: 1, name: "Screenshot 2026-10-24 at 13.41.02.png", tag: "PNG", category: "screenshots", confidence: 0.94, kind: "photo" },
  { id: 2, name: "lease_agreement.pdf", tag: "PDF", category: "documents", confidence: 0.91, kind: "doc" },
  { id: 3, name: "invoice_2026_0032.xlsx", tag: "XLSX", category: "invoices", confidence: 0.9, kind: "doc" },
  { id: 4, name: "IMG_4032.HEIC", tag: "HEIC", category: "screenshots", confidence: 0.71, kind: "photo" },
  { id: 5, name: "podcast_ep_104.mp3", tag: "MP3", category: "audio", confidence: 0.9, kind: "audio" },
  { id: 6, name: "receipt_cafe_feb.pdf", tag: "PDF", category: "invoices", confidence: 0.93, kind: "doc" },
  { id: 7, name: "backup_2026.zip", tag: "ZIP", category: "archives", confidence: 0.96, kind: "archive" },
  { id: 8, name: "Снимок экрана.png", tag: "PNG", category: "screenshots", confidence: 0.88, kind: "photo" },
  { id: 9, name: "CV_final_v7.docx", tag: "DOCX", category: "documents", confidence: 0.86, kind: "doc" },
  { id: 10, name: "voice_memo_idea.m4a", tag: "M4A", category: "audio", confidence: 0.79, kind: "audio" },
  { id: 11, name: "mixdown_track_1.wav", tag: "WAV", category: "audio", confidence: 0.76, kind: "audio" },
  { id: 12, name: "coffee_chat_notes.txt", tag: "TXT", category: "documents", confidence: 0.58, kind: "paper" },
  { id: 13, name: "docs_scan.tar.gz", tag: "TAR", category: "archives", confidence: 0.85, kind: "archive" },
  { id: 14, name: "game_asset_unknown.bin", tag: "BIN", category: null, confidence: 0, kind: "paper" },
];

/** A tiny deterministic pseudo-fingerprint (32 bars), per rule — for visuals. */
export function fingerprint(seed: number, bars = 32): number[] {
  const out: number[] = [];
  let s = seed * 9301 + 49297;
  for (let i = 0; i < bars; i++) {
    s = (s * 233280 + 49297) % 2147483647;
    out.push(0.15 + (s / 2147483647) * 0.85);
  }
  return out;
}

export const categoryLabel = (c: Category) =>
  c ? FOLDERS.find((f) => f.id === c)?.name ?? "?" : "No category is close enough";
