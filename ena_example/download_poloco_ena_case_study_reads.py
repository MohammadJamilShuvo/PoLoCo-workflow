#!/usr/bin/env python3
"""Download PoLoCo case-study FASTQ files from ENA into workflow-ready folders.

This script uses a local PoLoCo ENA manifest and the ENA Portal API. It does not store
FASTQ files in GitHub. It downloads them into:

  01_raw_reads/assembly/
  01_raw_reads/pools/

The manifest identifies which library is the assembly pool and which libraries are
Pool-seq population libraries.
"""
from __future__ import annotations
import argparse
import hashlib
import sys
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import pandas as pd

ENA_FILE_REPORT = "https://www.ebi.ac.uk/ena/portal/api/filereport"
FIELDS = [
    "run_accession", "sample_accession", "sample_alias", "sample_title",
    "experiment_accession", "experiment_alias", "library_name",
    "fastq_ftp", "fastq_md5", "fastq_bytes",
    "submitted_ftp", "submitted_md5", "submitted_bytes",
]


def md5sum(path: Path, block_size: int = 1024 * 1024) -> str:
    h = hashlib.md5()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(block_size), b""):
            h.update(block)
    return h.hexdigest()


def as_https(url: str) -> str:
    url = url.strip()
    if not url:
        return url
    if url.startswith("ftp://"):
        return "https://" + url[len("ftp://"):]
    if url.startswith("http://") or url.startswith("https://"):
        return url
    # ENA file reports often return paths without scheme, e.g. ftp.sra.ebi.ac.uk/...
    return "https://" + url


def split_field(value: object) -> List[str]:
    if value is None or pd.isna(value):
        return []
    text = str(value).strip()
    if not text:
        return []
    return [x.strip() for x in text.split(";") if x.strip()]


def fetch_ena_report(accession: str) -> pd.DataFrame:
    params = {
        "accession": accession,
        "result": "read_run",
        "fields": ",".join(FIELDS),
        "format": "tsv",
        "download": "true",
    }
    url = ENA_FILE_REPORT + "?" + urllib.parse.urlencode(params)
    print(f"[INFO] Fetching ENA file report for {accession}")
    try:
        with urllib.request.urlopen(url, timeout=120) as response:
            text = response.read().decode("utf-8")
    except Exception as exc:
        raise SystemExit(f"[ERROR] Could not fetch ENA report: {exc}\nURL: {url}")
    if not text.strip() or text.startswith("Error"):
        raise SystemExit(f"[ERROR] ENA returned no usable file report for {accession}.\nURL: {url}\n{text[:500]}")
    from io import StringIO
    return pd.read_csv(StringIO(text), sep="\t")


def row_search_text(row: pd.Series) -> str:
    values = []
    for col in row.index:
        values.extend(split_field(row[col]))
        values.append(str(row[col]))
    return "\n".join(values)


def find_matching_run(report: pd.DataFrame, manifest_row: pd.Series) -> Optional[pd.Series]:
    sample_id = str(manifest_row["sample_id"])
    submitted_r1_base = Path(str(manifest_row["submitted_read1"])).name
    submitted_r2_base = Path(str(manifest_row["submitted_read2"])).name
    library_name = str(manifest_row.get("library_name", ""))

    # First, match by submitted file basename. This is most reliable when submitted_ftp is present.
    for _, row in report.iterrows():
        text = row_search_text(row)
        if submitted_r1_base in text and submitted_r2_base in text:
            return row

    # Then match by sample/library aliases.
    for _, row in report.iterrows():
        aliases = "\n".join(str(row.get(c, "")) for c in ["sample_alias", "sample_title", "experiment_alias", "library_name"])
        if sample_id in aliases or (library_name and library_name in aliases):
            return row

    return None


def choose_urls_and_md5(run_row: pd.Series, manifest_row: pd.Series) -> Tuple[List[str], List[str]]:
    """Return paired URLs and MD5s.

    Prefer submitted_ftp because the manifest records submitted filenames and MD5s.
    Fall back to fastq_ftp from ENA-generated FASTQs.
    """
    submitted_urls = split_field(run_row.get("submitted_ftp"))
    submitted_md5 = split_field(run_row.get("submitted_md5"))
    fastq_urls = split_field(run_row.get("fastq_ftp"))
    fastq_md5 = split_field(run_row.get("fastq_md5"))

    r1_base = Path(str(manifest_row["submitted_read1"])).name
    r2_base = Path(str(manifest_row["submitted_read2"])).name

    if submitted_urls:
        # Try to preserve R1/R2 order by matching the submitted filenames.
        ordered_urls = []
        ordered_md5 = []
        for base, fallback_md5 in [(r1_base, str(manifest_row["read1_md5"])), (r2_base, str(manifest_row["read2_md5"]))]:
            hit_index = None
            for i, u in enumerate(submitted_urls):
                if base in u:
                    hit_index = i
                    break
            if hit_index is None:
                break
            ordered_urls.append(as_https(submitted_urls[hit_index]))
            ordered_md5.append(submitted_md5[hit_index] if hit_index < len(submitted_md5) else fallback_md5)
        if len(ordered_urls) == 2:
            return ordered_urls, ordered_md5

    if len(fastq_urls) >= 2:
        urls = [as_https(u) for u in fastq_urls[:2]]
        md5s = fastq_md5[:2] if len(fastq_md5) >= 2 else [str(manifest_row["read1_md5"]), str(manifest_row["read2_md5"])]
        return urls, md5s

    raise SystemExit(f"[ERROR] Could not identify paired FASTQ URLs for sample {manifest_row['sample_id']}")


def download_file(url: str, out_path: Path, expected_md5: str, skip_existing: bool = True, verify_md5: bool = True) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    if skip_existing and out_path.exists() and out_path.stat().st_size > 0:
        print(f"[SKIP] Existing file: {out_path}")
    else:
        print(f"[DOWNLOAD] {url}")
        print(f"           -> {out_path}")
        try:
            urllib.request.urlretrieve(url, out_path)
        except Exception as exc:
            raise SystemExit(f"[ERROR] Download failed for {url}: {exc}")

    if verify_md5 and expected_md5 and expected_md5.lower() not in {"nan", "none", ""}:
        observed = md5sum(out_path)
        if observed.lower() != expected_md5.lower():
            raise SystemExit(
                f"[ERROR] MD5 mismatch for {out_path}\n"
                f"Expected: {expected_md5}\nObserved: {observed}"
            )
        print(f"[OK] MD5 verified: {out_path.name}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Download PoLoCo manuscript case-study reads from ENA.")
    parser.add_argument("--manifest", default="ena_example/poloco_ena_case_study_manifest.tsv",
                        help="Path to PoLoCo ENA case-study manifest TSV.")
    parser.add_argument("--outdir", default="01_raw_reads",
                        help="Output directory for downloaded reads.")
    parser.add_argument("--accession", default="PRJEB111482",
                        help="ENA BioProject/study accession.")
    parser.add_argument("--max-pools", type=int, default=None,
                        help="Optional: download only the first N Pool-seq libraries plus the assembly library for a smaller example run.")
    parser.add_argument("--dry-run", action="store_true",
                        help="Print planned downloads without downloading files.")
    parser.add_argument("--no-md5", action="store_true",
                        help="Do not verify MD5 checksums after download.")
    args = parser.parse_args()

    manifest_path = Path(args.manifest)
    if not manifest_path.exists():
        raise SystemExit(f"[ERROR] Manifest not found: {manifest_path}")
    manifest = pd.read_csv(manifest_path, sep="\t")

    assembly = manifest[manifest["library_role"] == "assembly"]
    pools = manifest[manifest["library_role"] == "poolseq"]
    if len(assembly) != 1:
        raise SystemExit(f"[ERROR] Expected exactly 1 assembly library, found {len(assembly)}")
    if args.max_pools is not None:
        pools = pools.head(args.max_pools)
    selected = pd.concat([assembly, pools], ignore_index=True)

    report = fetch_ena_report(args.accession)
    print(f"[INFO] ENA report contains {len(report)} run(s).")
    print(f"[INFO] Manifest selected {len(selected)} libraries: 1 assembly + {len(pools)} Pool-seq.")

    planned = []
    for _, mrow in selected.iterrows():
        run_row = find_matching_run(report, mrow)
        if run_row is None:
            raise SystemExit(
                f"[ERROR] Could not match manifest sample to ENA run: {mrow['sample_id']}\n"
                "Check whether ENA records are public and whether submitted filenames/sample aliases match."
            )
        urls, md5s = choose_urls_and_md5(run_row, mrow)
        subdir = "assembly" if mrow["library_role"] == "assembly" else "pools"
        out1 = Path(args.outdir) / subdir / str(mrow["standard_read1"])
        out2 = Path(args.outdir) / subdir / str(mrow["standard_read2"])
        planned.append((urls[0], out1, md5s[0], mrow["sample_id"]))
        planned.append((urls[1], out2, md5s[1], mrow["sample_id"]))

    print("[INFO] Planned FASTQ files:")
    for url, out, _, sample in planned[:10]:
        print(f"  {sample}: {out}")
    if len(planned) > 10:
        print(f"  ... {len(planned) - 10} more files")

    if args.dry_run:
        print("[OK] Dry run completed. No files downloaded.")
        return

    for url, out, expected_md5, _sample in planned:
        download_file(url, out, expected_md5, skip_existing=True, verify_md5=not args.no_md5)

    print("[OK] ENA read download completed.")
    print(f"[OK] Assembly reads: {Path(args.outdir) / 'assembly'}")
    print(f"[OK] Pool-seq reads: {Path(args.outdir) / 'pools'}")


if __name__ == "__main__":
    main()
