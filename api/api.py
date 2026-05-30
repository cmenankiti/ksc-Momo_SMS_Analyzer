"""
MoMo SMS Analyzer – REST API
Team KSC: Chigozirim Menankiti, Samuel Nizeyimana, Mamashenge Kendra

Implements:
  - XML parsing (Task 1)
  - CRUD endpoints (Task 2)
  - Basic Authentication (Task 3)

Run:  python api.py
Default port: 8080
"""

import json
import re
import base64
import xml.etree.ElementTree as ET
from http.server import BaseHTTPRequestHandler, HTTPServer
from datetime import datetime
from typing import Optional

# ─────────────────────────────────────────────
# 1.  CONFIGURATION
# ─────────────────────────────────────────────
PORT = 8080
XML_FILE = "modified_sms_v2.xml"

# Credentials store  { username: password }
USERS = {
    "admin": "ksc_admin123",
    "analyst": "ksc_read456",
}

# ─────────────────────────────────────────────
# 2.  XML PARSER  (Task 1)
# ─────────────────────────────────────────────

def _extract_amount(body: str, label: str) -> Optional[float]:
    """Pull a labelled RWF amount from the SMS body text."""
    pattern = rf"{label}[\s:]*(?:RWF\s*)?([\d,]+)"
    m = re.search(pattern, body, re.IGNORECASE)
    if m:
        return float(m.group(1).replace(",", ""))
    return None


def _extract_txn_id(body: str) -> Optional[str]:
    m = re.search(r"TxnID[:\s]*([\w]+)", body, re.IGNORECASE)
    return m.group(1) if m else None


def _extract_phone(body: str) -> Optional[str]:
    m = re.search(r"\((\d{10,13})\)", body)
    return m.group(1) if m else None


def _extract_counterpart_name(body: str, txn_type: str) -> dict:
    """Return sender_name / receiver_name based on transaction type."""
    names = {"sender_name": None, "receiver_name": None}
    if txn_type == "Incoming":
        m = re.search(r"received [\d,]+ RWF from ([A-Za-z ]+)\s*\(", body)
        if m:
            names["sender_name"] = m.group(1).strip()
    elif txn_type in ("Transfer", "Bank_Deposit"):
        m = re.search(r"transferred to ([A-Za-z ]+)\s*\(", body)
        if m:
            names["receiver_name"] = m.group(1).strip()
    elif txn_type == "Withdrawal":
        m = re.search(r"agent ([A-Za-z ]+)\s*\(", body)
        if m:
            names["receiver_name"] = m.group(1).strip()
    elif txn_type == "Payment":
        m = re.search(r"made to ([A-Za-z ]+)\s*\(", body)
        if m:
            names["receiver_name"] = m.group(1).strip()
    return names


def parse_xml(filepath: str) -> list[dict]:
    """Parse the MoMo SMS XML file and return a list of transaction dicts."""
    tree = ET.parse(filepath)
    root = tree.getroot()
    transactions = []

    for sms in root.findall("sms"):
        body = sms.get("body", "")
        txn_type = sms.get("type", "Unknown")
        date_str = sms.get("date", "")

        # Parse date
        try:
            txn_date = datetime.strptime(date_str, "%Y-%m-%d %H:%M:%S").isoformat()
        except ValueError:
            txn_date = date_str

        # Extract financials
        amount = _extract_amount(body, r"(?:received|withdrawn|transferred|purchased|deposited|Payment of|payment of)")
        if amount is None:
            # Fallback: first big number in body
            m = re.search(r"([\d,]+)\s*RWF", body)
            amount = float(m.group(1).replace(",", "")) if m else 0.0

        fee = _extract_amount(body, "Fee")
        balance = _extract_amount(body, r"(?:new balance|balance)")

        names = _extract_counterpart_name(body, txn_type)
        phone = _extract_phone(body)

        txn = {
            "id": int(sms.get("id", 0)),
            "externalTransactionId": _extract_txn_id(body),
            "transactionType": txn_type,
            "transactionStatus": "Completed",
            "amount": amount,
            "fee": fee if fee is not None else 0.0,
            "balanceAfter": balance,
            "currency": "RWF",
            "senderName": names["sender_name"],
            "receiverName": names["receiver_name"],
            "phoneNumber": phone,
            "transactionDate": txn_date,
            "rawMessage": body,
            "createdAt": datetime.utcnow().isoformat() + "Z",
        }
        transactions.append(txn)

    return transactions


# ─────────────────────────────────────────────
# 3.  DATA STORE  (in-memory, dict-backed)
# ─────────────────────────────────────────────

class DataStore:
    def __init__(self, records: list[dict]):
        # Primary store: dict for O(1) lookup
        self._store: dict[int, dict] = {r["id"]: r for r in records}
        self._next_id: int = max(self._store.keys(), default=0) + 1

    # ── READ ────────────────────────────────
    def all(self) -> list[dict]:
        return list(self._store.values())

    def get(self, txn_id: int) -> Optional[dict]:
        return self._store.get(txn_id)

    # ── CREATE ──────────────────────────────
    def create(self, data: dict) -> dict:
        txn_id = self._next_id
        self._next_id += 1
        data["id"] = txn_id
        data.setdefault("transactionStatus", "Completed")
        data.setdefault("currency", "RWF")
        data.setdefault("createdAt", datetime.utcnow().isoformat() + "Z")
        self._store[txn_id] = data
        return data

    # ── UPDATE ──────────────────────────────
    def update(self, txn_id: int, data: dict) -> Optional[dict]:
        if txn_id not in self._store:
            return None
        self._store[txn_id].update(data)
        self._store[txn_id]["updatedAt"] = datetime.utcnow().isoformat() + "Z"
        return self._store[txn_id]

    # ── DELETE ──────────────────────────────
    def delete(self, txn_id: int) -> bool:
        if txn_id not in self._store:
            return False
        del self._store[txn_id]
        return True


# Load data at startup
_raw = parse_xml(XML_FILE)
db = DataStore(_raw)


# ─────────────────────────────────────────────
# 4.  AUTHENTICATION  (Task 3)
# ─────────────────────────────────────────────

def check_auth(handler: "MoMoHandler") -> bool:
    """Validate Basic Auth credentials. Returns True if valid."""
    auth_header = handler.headers.get("Authorization", "")
    if not auth_header.startswith("Basic "):
        return False
    try:
        decoded = base64.b64decode(auth_header[6:]).decode("utf-8")
        username, password = decoded.split(":", 1)
        return USERS.get(username) == password
    except Exception:
        return False


# ─────────────────────────────────────────────
# 5.  HTTP HANDLER  (Task 2 – CRUD endpoints)
# ─────────────────────────────────────────────

class MoMoHandler(BaseHTTPRequestHandler):

    # ── Helpers ─────────────────────────────

    def _send_json(self, code: int, payload) -> None:
        body = json.dumps(payload, indent=2).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _require_auth(self) -> bool:
        if not check_auth(self):
            self._send_json(401, {
                "error": "Unauthorized",
                "message": "Valid Basic Authentication credentials required.",
                "hint": 'Set header: Authorization: Basic <base64(username:password)>'
            })
            return False
        return True

    def _read_body(self) -> Optional[dict]:
        length = int(self.headers.get("Content-Length", 0))
        if length == 0:
            return {}
        try:
            return json.loads(self.rfile.read(length))
        except json.JSONDecodeError:
            return None

    def _parse_id(self, path: str) -> Optional[int]:
        """Extract integer ID from path like /transactions/5."""
        parts = [p for p in path.strip("/").split("/") if p]
        if len(parts) == 2 and parts[1].isdigit():
            return int(parts[1])
        return None

    def log_message(self, fmt, *args):
        """Override to add timestamp to server logs."""
        print(f"[{datetime.now().strftime('%H:%M:%S')}] {fmt % args}")

    # ── Route dispatcher ────────────────────

    def do_GET(self):
        if not self._require_auth():
            return

        if self.path == "/transactions" or self.path == "/transactions/":
            txns = db.all()
            self._send_json(200, {
                "status": "success",
                "count": len(txns),
                "transactions": txns
            })

        elif self.path.startswith("/transactions/"):
            txn_id = self._parse_id(self.path)
            if txn_id is None:
                self._send_json(400, {"error": "Bad Request", "message": "Invalid transaction ID."})
                return
            txn = db.get(txn_id)
            if txn is None:
                self._send_json(404, {"error": "Not Found", "message": f"Transaction {txn_id} not found."})
            else:
                self._send_json(200, {"status": "success", "transaction": txn})

        elif self.path == "/" or self.path == "":
            self._send_json(200, {
                "service": "MoMo SMS Analyzer API",
                "version": "1.0",
                "team": "KSC",
                "endpoints": [
                    "GET  /transactions",
                    "GET  /transactions/{id}",
                    "POST /transactions",
                    "PUT  /transactions/{id}",
                    "DELETE /transactions/{id}",
                ]
            })
        else:
            self._send_json(404, {"error": "Not Found", "message": f"Route '{self.path}' does not exist."})

    def do_POST(self):
        if not self._require_auth():
            return

        if self.path == "/transactions" or self.path == "/transactions/":
            body = self._read_body()
            if body is None:
                self._send_json(400, {"error": "Bad Request", "message": "Request body must be valid JSON."})
                return

            required = ["transactionType", "amount", "rawMessage"]
            missing = [f for f in required if f not in body]
            if missing:
                self._send_json(422, {
                    "error": "Unprocessable Entity",
                    "message": f"Missing required fields: {', '.join(missing)}"
                })
                return

            # Validate amount
            try:
                body["amount"] = float(body["amount"])
                if body["amount"] <= 0:
                    raise ValueError
            except (ValueError, TypeError):
                self._send_json(422, {"error": "Unprocessable Entity", "message": "'amount' must be a positive number."})
                return

            # Validate transactionType
            valid_types = ["Incoming", "Transfer", "Withdrawal", "Payment",
                           "Airtime", "Bank_Deposit", "Bundle_Purchase"]
            if body["transactionType"] not in valid_types:
                self._send_json(422, {
                    "error": "Unprocessable Entity",
                    "message": f"'transactionType' must be one of: {', '.join(valid_types)}"
                })
                return

            txn = db.create(body)
            self._send_json(201, {"status": "created", "transaction": txn})
        else:
            self._send_json(404, {"error": "Not Found", "message": f"Route '{self.path}' does not exist."})

    def do_PUT(self):
        if not self._require_auth():
            return

        if self.path.startswith("/transactions/"):
            txn_id = self._parse_id(self.path)
            if txn_id is None:
                self._send_json(400, {"error": "Bad Request", "message": "Invalid transaction ID."})
                return

            body = self._read_body()
            if body is None:
                self._send_json(400, {"error": "Bad Request", "message": "Request body must be valid JSON."})
                return

            # Prevent overwriting immutable fields
            for locked in ("id", "createdAt", "externalTransactionId"):
                body.pop(locked, None)

            txn = db.update(txn_id, body)
            if txn is None:
                self._send_json(404, {"error": "Not Found", "message": f"Transaction {txn_id} not found."})
            else:
                self._send_json(200, {"status": "updated", "transaction": txn})
        else:
            self._send_json(404, {"error": "Not Found", "message": f"Route '{self.path}' does not exist."})

    def do_DELETE(self):
        if not self._require_auth():
            return

        if self.path.startswith("/transactions/"):
            txn_id = self._parse_id(self.path)
            if txn_id is None:
                self._send_json(400, {"error": "Bad Request", "message": "Invalid transaction ID."})
                return

            deleted = db.delete(txn_id)
            if not deleted:
                self._send_json(404, {"error": "Not Found", "message": f"Transaction {txn_id} not found."})
            else:
                self._send_json(200, {"status": "deleted", "message": f"Transaction {txn_id} successfully deleted."})
        else:
            self._send_json(404, {"error": "Not Found", "message": f"Route '{self.path}' does not exist."})


# ─────────────────────────────────────────────
# 6.  ENTRY POINT
# ─────────────────────────────────────────────

if __name__ == "__main__":
    server = HTTPServer(("0.0.0.0", PORT), MoMoHandler)
    print(f"[MoMo API] Loaded {len(db.all())} transactions from '{XML_FILE}'")
    print(f"[MoMo API] Server running at http://localhost:{PORT}/")
    print(f"[MoMo API] Basic Auth credentials: admin / ksc_admin123")
    print("[MoMo API] Press Ctrl+C to stop.\n")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[MoMo API] Server stopped.")
