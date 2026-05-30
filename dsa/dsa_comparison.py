"""
MoMo SMS Analyzer – DSA Comparison
Team KSC: Chigozirim Menankiti, Samuel Nizeyimana, Mamashenge Kendra

Task 5: Compare Linear Search vs Dictionary Lookup for transaction retrieval.
Runs timing benchmarks over 25 transactions and prints a detailed report.
"""

import sys
import time
import xml.etree.ElementTree as ET
import re
from typing import Optional

# ─────────────────────────────────────────────────────────────
# 1.  Reuse the same parser from api.py (standalone version)
# ─────────────────────────────────────────────────────────────

def parse_xml(filepath: str) -> list[dict]:
    tree = ET.parse(filepath)
    root = tree.getroot()
    records = []
    for sms in root.findall("sms"):
        body = sms.get("body", "")
        m_amount = re.search(r"([\d,]+)\s*RWF", body)
        m_fee = re.search(r"Fee[:\s]*([\d,]+)", body, re.IGNORECASE)
        m_bal = re.search(r"balance[:\s]*([\d,]+)", body, re.IGNORECASE)
        m_txn = re.search(r"TxnID[:\s]*([\w]+)", body, re.IGNORECASE)
        records.append({
            "id": int(sms.get("id", 0)),
            "externalTransactionId": m_txn.group(1) if m_txn else None,
            "transactionType": sms.get("type", "Unknown"),
            "transactionStatus": "Completed",
            "amount": float(m_amount.group(1).replace(",", "")) if m_amount else 0.0,
            "fee": float(m_fee.group(1).replace(",", "")) if m_fee else 0.0,
            "balanceAfter": float(m_bal.group(1).replace(",", "")) if m_bal else None,
            "currency": "RWF",
            "transactionDate": sms.get("date", ""),
            "rawMessage": body,
        })
    return records


# ─────────────────────────────────────────────────────────────
# 2.  DATA STRUCTURES
# ─────────────────────────────────────────────────────────────

def build_list(records: list[dict]) -> list[dict]:
    """Returns a plain list (used for linear search)."""
    return records[:]


def build_dict(records: list[dict]) -> dict[int, dict]:
    """Returns id→transaction dictionary (used for O(1) lookup)."""
    return {r["id"]: r for r in records}


# ─────────────────────────────────────────────────────────────
# 3.  SEARCH ALGORITHMS
# ─────────────────────────────────────────────────────────────

def linear_search(data: list[dict], target_id: int) -> Optional[dict]:
    """O(n) – Scan every record until the target ID is found."""
    for record in data:
        if record["id"] == target_id:
            return record
    return None


def dict_lookup(data: dict[int, dict], target_id: int) -> Optional[dict]:
    """O(1) – Direct hash-map access by key."""
    return data.get(target_id)


# ─────────────────────────────────────────────────────────────
# 4.  BENCHMARK
# ─────────────────────────────────────────────────────────────

ITERATIONS = 100_000   # repeat each search this many times to get stable ns timings


def benchmark(records: list[dict]) -> None:
    txn_list = build_list(records)
    txn_dict = build_dict(records)
    n = len(records)

    print("=" * 65)
    print("  MoMo SMS Analyzer – DSA Benchmark Report")
    print("  Team KSC | Transactions loaded:", n)
    print("=" * 65)
    print(f"\n{'ID':>4}  {'Type':<16}  {'Linear (ns)':>12}  {'Dict (ns)':>10}  {'Speedup':>8}")
    print("-" * 65)

    total_linear_ns = 0
    total_dict_ns   = 0

    for rec in records:
        tid = rec["id"]

        # ── Linear search timing ──────────────
        t0 = time.perf_counter_ns()
        for _ in range(ITERATIONS):
            linear_search(txn_list, tid)
        t1 = time.perf_counter_ns()
        avg_linear = (t1 - t0) / ITERATIONS

        # ── Dict lookup timing ────────────────
        t0 = time.perf_counter_ns()
        for _ in range(ITERATIONS):
            dict_lookup(txn_dict, tid)
        t1 = time.perf_counter_ns()
        avg_dict = (t1 - t0) / ITERATIONS

        speedup = avg_linear / avg_dict if avg_dict > 0 else float("inf")

        total_linear_ns += avg_linear
        total_dict_ns   += avg_dict

        print(f"{tid:>4}  {rec['transactionType']:<16}  {avg_linear:>12.1f}  "
              f"{avg_dict:>10.1f}  {speedup:>7.1f}x")

    avg_lin_total = total_linear_ns / n
    avg_dic_total = total_dict_ns   / n
    overall_speedup = avg_lin_total / avg_dic_total if avg_dic_total > 0 else float("inf")

    print("-" * 65)
    print(f"{'AVG':>4}  {'(all types)':<16}  {avg_lin_total:>12.1f}  "
          f"{avg_dic_total:>10.1f}  {overall_speedup:>7.1f}x")
    print("=" * 65)

    print("\n── SUMMARY ─────────────────────────────────────────────────")
    print(f"  Records:              {n}")
    print(f"  Iterations per ID:    {ITERATIONS:,}")
    print(f"  Avg linear search:    {avg_lin_total:.1f} ns")
    print(f"  Avg dict lookup:      {avg_dic_total:.1f} ns")
    print(f"  Overall speedup:      {overall_speedup:.1f}x  (dict is faster)")

    # ── Worst-case comparison ─────────────────
    last_id = records[-1]["id"]
    t0 = time.perf_counter_ns()
    for _ in range(ITERATIONS):
        linear_search(txn_list, last_id)
    t1 = time.perf_counter_ns()
    worst_linear = (t1 - t0) / ITERATIONS

    t0 = time.perf_counter_ns()
    for _ in range(ITERATIONS):
        dict_lookup(txn_dict, last_id)
    t1 = time.perf_counter_ns()
    worst_dict = (t1 - t0) / ITERATIONS

    print(f"\n  Worst-case (last record, ID={last_id}):")
    print(f"    Linear: {worst_linear:.1f} ns")
    print(f"    Dict:   {worst_dict:.1f} ns")
    print(f"    Speedup: {worst_linear/worst_dict:.1f}x")

    print("\n── REFLECTION ──────────────────────────────────────────────")
    print("""
  Why is dictionary lookup faster than linear search?
  ─────────────────────────────────────────────────────
  Linear search has O(n) time complexity: to find a record by ID,
  the algorithm must check each element one-by-one until a match
  is found. In the worst case (last element or absent), all n
  records are visited. As the dataset grows, search time scales
  linearly.

  Dictionary (hash-map) lookup achieves O(1) average time
  complexity. Python's dict computes a hash of the key and maps
  it directly to a memory slot, so the lookup cost is constant
  regardless of how many records are stored. Only a hash collision
  (rare, handled by chaining/probing) slightly degrades this.

  Alternative data structures & algorithms:
  ─────────────────────────────────────────
  1. Binary Search Tree (BST) / Sorted Array + Binary Search
       - O(log n) search; useful when ordering by date/amount
         matters more than ID lookup.
  2. B-Tree / B+ Tree (used by SQL databases)
       - Optimal for range queries (e.g., transactions between
         two dates) while keeping O(log n) point lookups.
  3. Trie (Prefix Tree)
       - Efficient for prefix-based searches on externalTxnID
         strings; O(m) where m = key length.
  4. Hash Index (already our dict approach)
       - Best for exact-match ID lookups in memory.
  For this dataset a dictionary is the best in-memory choice for
  ID-based retrieval; a B-Tree index would be preferred in a
  production SQL database for mixed query workloads.
""")


# ─────────────────────────────────────────────────────────────
# 5.  MAIN
# ─────────────────────────────────────────────────────────────

if __name__ == "__main__":
    xml_path = sys.argv[1] if len(sys.argv) > 1 else "../api/modified_sms_v2.xml"
    try:
        records = parse_xml(xml_path)
    except FileNotFoundError:
        print(f"[ERROR] XML file not found: {xml_path}")
        sys.exit(1)

    benchmark(records)
